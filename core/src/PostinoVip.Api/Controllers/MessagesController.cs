using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using PostinoVip.Api.Contracts;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Models;

namespace PostinoVip.Api.Controllers;

[ApiController]
[Route("messages")]
[Route("accounts/{accountId}/messages")]
public sealed class MessagesController(MailAccountRegistry accounts, ILogger<MessagesController> logger)
    : MailControllerBase(accounts)
{
    /// <summary>GET /messages/{folder}/{uid} — lettura con BODY.PEEK, non segna come letto.</summary>
    [HttpGet("{folder}/{uid}")]
    public async Task<ActionResult<MessageDetail>> GetMessage(string folder, uint uid, CancellationToken ct) =>
        Ok(await CurrentAccount.Reader.GetMessageAsync(FolderName.FromRoute(folder), uid, ct));

    /// <summary>PUT /messages/{folder}/{uid}/seen {"seen": true|false} — MODIFICA la casella (flag \Seen).</summary>
    [HttpPut("{folder}/{uid}/seen")]
    public async Task<ActionResult<SeenResponse>> SetSeen(string folder, uint uid, [FromBody] SeenRequest request, CancellationToken ct)
    {
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        var seen = await account.Writer.SetSeenAsync(name, uid, request.Seen!.Value, ct);
        // Solo l'operazione, mai contenuti.
        logger.LogInformation("[{Account}] STORE {Action}\\Seen {Folder} uid {Uid}", account.Id, request.Seen.Value ? "+" : "-", name, uid);
        return Ok(new SeenResponse(seen));
    }

    /// <summary>
    /// PUT /messages/{folder}/{uid}/flags {"followUp"?, "due"?, "categories"?} — MODIFICA la casella:
    /// contrassegno (\Flagged), completato ($Completed) e categorie (parole chiave). La scadenza resta
    /// solo nella copia locale.
    /// </summary>
    [HttpPut("{folder}/{uid}/flags")]
    public async Task<ActionResult<FlagsResponse>> SetFlags(string folder, uint uid, [FromBody] FlagsRequest request, CancellationToken ct)
    {
        var (add, remove) = FollowUpFlags(request.FollowUp, request.Due);
        if (request.Categories is { } categories)
        {
            var chosen = CategoryFlags(categories, "categories");
            (add, remove) = (add | chosen, remove | (MailFlags.Categories & ~chosen));
        }
        if (request.FollowUp is null && request.Categories is null)
            throw new FieldValidationException("followUp", "Indicare followUp o categories.");

        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        var flags = await account.Writer.UpdateFlagsAsync(name, uid, add, remove, ct);
        // Solo i flag cambiati, mai contenuti.
        logger.LogInformation("[{Account}] STORE +({Add}) -({Remove}) {Folder} uid {Uid}", account.Id, add, remove, name, uid);

        DateOnly? due = null;
        if (account.Bodies?.Cache is { } cache && cache.FindFolder(name) is { } cached)
            due = cache.SetFlags(cached.Id, uid, flags, request.Due, keepDue: request.FollowUp is null);
        return Ok(new FlagsResponse(flags.HasFlag(MailFlags.Flagged), flags.HasFlag(MailFlags.Completed), due,
            MailKeywords.CategoryNumbers(flags)));
    }

    /// <summary>POST /messages/{folder}/{uid}/move {"destination": "..."} — MODIFICA la casella.</summary>
    [HttpPost("{folder}/{uid}/move")]
    public async Task<ActionResult<MoveResponse>> Move(string folder, uint uid, [FromBody] MoveRequest request, CancellationToken ct)
    {
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        var movedTo = await account.Writer.MoveAsync(name, uid, request.Destination, ct);
        logger.LogInformation("[{Account}] MOVE {Folder} uid {Uid} -> {Destination}", account.Id, name, uid, movedTo);
        return Ok(new MoveResponse(movedTo));
    }

    /// <summary>
    /// DELETE /messages/{folder}/{uid} — MODIFICA la casella: sposta in Posta eliminata.
    /// Con ?permanent=true elimina DEFINITIVAMENTE, ammesso solo dentro Posta eliminata (altrimenti 409).
    /// </summary>
    [HttpDelete("{folder}/{uid}")]
    public async Task<ActionResult<MoveResponse>> Delete(string folder, uint uid, [FromQuery] bool permanent, CancellationToken ct)
    {
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        if (permanent)
        {
            await account.Writer.DeletePermanentlyAsync(name, uid, ct);
            logger.LogInformation("[{Account}] DELETE definitivo {Folder} uid {Uid}", account.Id, name, uid);
            return Ok(new MoveResponse(null, Permanent: true));
        }

        var movedTo = await account.Writer.MoveToTrashAsync(name, uid, ct);
        logger.LogInformation("[{Account}] DELETE (sposta) {Folder} uid {Uid} -> {Destination}", account.Id, name, uid, movedTo);
        return Ok(new MoveResponse(movedTo));
    }

    // ---------------------------------------------------------------------------------------------
    // In blocco (3.5a): più mail della stessa cartella con un solo comando IMAP. Le mail che non
    // esistono più vengono ignorate; la risposta elenca quelle trattate.
    // ---------------------------------------------------------------------------------------------

    /// <summary>Massimo di mail per richiesta in blocco.</summary>
    public const int MaxBatch = 1000;

    /// <summary>PUT /messages/{folder}/seen {"uids": [...], "seen": bool} — MODIFICA la casella.</summary>
    [HttpPut("{folder}/seen")]
    public async Task<ActionResult<BatchSeenResponse>> SetSeenBatch(string folder, [FromBody] BatchSeenRequest request, CancellationToken ct)
    {
        var uids = RequireUids(request.Uids);
        var seen = request.Seen ?? throw new FieldValidationException("seen", "Indicare seen.");
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        var result = await account.Writer.SetSeenAsync(name, uids, seen, ct);
        logger.LogInformation("[{Account}] STORE {Action}\\Seen {Folder} {Count} mail", account.Id, seen ? "+" : "-", name, result.Count);
        return Ok(new BatchSeenResponse(result.Keys.Order().ToList(), seen));
    }

    /// <summary>
    /// PUT /messages/{folder}/flags {"uids", "followUp"?, "due"?, "addCategories"?, "removeCategories"?} —
    /// MODIFICA la casella: contrassegno e categorie su più mail (scadenza solo nella copia locale).
    /// </summary>
    [HttpPut("{folder}/flags")]
    public async Task<ActionResult<BatchFlagsResponse>> SetFlagsBatch(string folder, [FromBody] BatchFlagsRequest request, CancellationToken ct)
    {
        var uids = RequireUids(request.Uids);
        var (add, remove) = FollowUpFlags(request.FollowUp, request.Due);
        var added = CategoryFlags(request.AddCategories ?? [], "addCategories");
        var removed = CategoryFlags(request.RemoveCategories ?? [], "removeCategories");
        if ((added & removed) != 0)
            throw new FieldValidationException("removeCategories", "Una categoria non può essere aggiunta e tolta insieme.").WithCode("unaCategoriaNonPuoEssere");
        (add, remove) = (add | added, remove | removed);
        if (add == MailFlags.None && remove == MailFlags.None)
            throw new FieldValidationException("followUp", "Indicare followUp, addCategories o removeCategories.");

        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        var flags = await account.Writer.UpdateFlagsAsync(name, uids, add, remove, ct);
        logger.LogInformation("[{Account}] STORE +({Add}) -({Remove}) {Folder} {Count} mail", account.Id, add, remove, name, flags.Count);

        var cache = account.Bodies?.Cache;
        var cached = cache?.FindFolder(name);
        var items = new List<BatchFlagsItem>();
        foreach (var (uid, f) in flags.OrderBy(p => p.Key))
        {
            var due = cache is not null && cached is not null
                ? cache.SetFlags(cached.Id, uid, f, request.Due, keepDue: request.FollowUp is null)
                : null;
            items.Add(new BatchFlagsItem(uid, f.HasFlag(MailFlags.Flagged), f.HasFlag(MailFlags.Completed), due,
                MailKeywords.CategoryNumbers(f)));
        }
        return Ok(new BatchFlagsResponse(items));
    }

    /// <summary>POST /messages/{folder}/move {"uids", "destination"} — MODIFICA la casella.</summary>
    [HttpPost("{folder}/move")]
    public async Task<ActionResult<BatchMoveResponse>> MoveBatch(string folder, [FromBody] BatchMoveRequest request, CancellationToken ct)
    {
        var uids = RequireUids(request.Uids);
        if (string.IsNullOrEmpty(request.Destination))
            throw new FieldValidationException("destination", "Indicare la cartella di destinazione.").WithCode("indicareLaCartellaDiDestinazione");
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        var result = await account.Writer.MoveAsync(name, uids, request.Destination, ct);
        logger.LogInformation("[{Account}] MOVE {Folder} {Count} mail -> {Destination}", account.Id, name, result.Uids.Count, result.Destination);
        return Ok(new BatchMoveResponse(result.Destination, false, result.Uids));
    }

    /// <summary>
    /// POST /messages/{folder}/copy {"uids", "destination"} — MODIFICA la casella (aggiunge copie nella
    /// destinazione; gli originali restano). Le copie entrano nella copia locale alla prossima sincronizzazione.
    /// </summary>
    [HttpPost("{folder}/copy")]
    public async Task<ActionResult<BatchCopyResponse>> CopyBatch(string folder, [FromBody] BatchMoveRequest request, CancellationToken ct)
    {
        var uids = RequireUids(request.Uids);
        if (string.IsNullOrEmpty(request.Destination))
            throw new FieldValidationException("destination", "Indicare la cartella di destinazione.").WithCode("indicareLaCartellaDiDestinazione");
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        var result = await account.Writer.CopyAsync(name, uids, request.Destination, ct);
        logger.LogInformation("[{Account}] COPY {Folder} {Count} mail -> {Destination}", account.Id, name, result.Uids.Count, result.Destination);
        return Ok(new BatchCopyResponse(result.Destination!, result.Uids));
    }

    /// <summary>
    /// POST /messages/{folder}/delete {"uids", "permanent"} — MODIFICA la casella: sposta in Posta eliminata;
    /// con permanent elimina DEFINITIVAMENTE, ammesso solo dentro Posta eliminata (altrimenti 409).
    /// </summary>
    [HttpPost("{folder}/delete")]
    public async Task<ActionResult<BatchMoveResponse>> DeleteBatch(string folder, [FromBody] BatchDeleteRequest request, CancellationToken ct)
    {
        var uids = RequireUids(request.Uids);
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        if (request.Permanent)
        {
            var deleted = await account.Writer.DeletePermanentlyAsync(name, uids, ct);
            logger.LogInformation("[{Account}] DELETE definitivo {Folder} {Count} mail", account.Id, name, deleted.Uids.Count);
            return Ok(new BatchMoveResponse(null, true, deleted.Uids));
        }
        var moved = await account.Writer.MoveToTrashAsync(name, uids, ct);
        logger.LogInformation("[{Account}] DELETE (sposta) {Folder} {Count} mail -> {Destination}", account.Id, name, moved.Uids.Count, moved.Destination);
        return Ok(new BatchMoveResponse(moved.Destination, false, moved.Uids));
    }

    private static IReadOnlyCollection<uint> RequireUids(uint[]? uids)
    {
        if (uids is null || uids.Length == 0)
            throw new FieldValidationException("uids", "Indicare almeno una mail.").WithCode("indicareAlmenoUnaMail");
        if (uids.Length > MaxBatch)
            throw new FieldValidationException("uids", $"Al massimo {MaxBatch} mail per volta.").WithCode("alMassimoMailPerVolta", ("maxBatch", MaxBatch));
        return uids.Distinct().ToList();
    }

    /// <summary>Flag da aggiungere e togliere per followUp ("none" | "flagged" | "completed"); null = nessun cambiamento.</summary>
    private static (MailFlags Add, MailFlags Remove) FollowUpFlags(string? followUp, DateOnly? due)
    {
        if (due is not null && followUp != "flagged")
            throw new FieldValidationException("due", "La scadenza vale solo con followUp \"flagged\".").WithCode("laScadenzaValeSoloCon");
        return followUp switch
        {
            null => (MailFlags.None, MailFlags.None),
            "none" => (MailFlags.None, MailFlags.Flagged | MailFlags.Completed),
            "flagged" => (MailFlags.Flagged, MailFlags.Completed),
            "completed" => (MailFlags.Completed, MailFlags.Flagged),
            _ => throw new FieldValidationException("followUp", "Valori ammessi: none, flagged, completed."),
        };
    }

    private static MailFlags CategoryFlags(int[] categories, string field)
    {
        if (categories.Any(c => c is < 1 or > 6))
            throw new FieldValidationException(field, "Le categorie sono numerate da 1 a 6.");
        return categories.Aggregate(MailFlags.None, (f, c) => f | MailKeywords.Category(c));
    }

    /// <summary>GET /messages/{folder}/{uid}/draft?mode=reply|replyAll|forward — bozza precompilata, non invia nulla.</summary>
    [HttpGet("{folder}/{uid}/draft")]
    public async Task<ActionResult<ComposeDraft>> GetDraft(string folder, uint uid, [FromQuery, BindRequired] DraftMode mode, CancellationToken ct)
    {
        // Il proprio indirizzo (escluso da "rispondi a tutti") è quello dell'account della mail.
        var account = CurrentAccount;
        return Ok(await account.Reader.GetDraftAsync(FolderName.FromRoute(folder), uid, mode, account.Address, ct));
    }

    /// <summary>
    /// GET /messages/{folder}/{uid}/compose — riapre una bozza (o qualsiasi mail) nella composizione (3.8): testo
    /// scritto e citazione separati, allegati da riprendere con .../attachments/{index}. Non modifica nulla.
    /// </summary>
    [HttpGet("{folder}/{uid}/compose")]
    public async Task<ActionResult<ComposeContent>> GetCompose(string folder, uint uid, CancellationToken ct) =>
        Ok(await CurrentAccount.Reader.GetComposeAsync(FolderName.FromRoute(folder), uid, ct));

    /// <summary>
    /// GET /messages/{folder}/{uid}/raw — il messaggio così com'è (message/rfc822), per «Salva con nome» .eml (E1).
    /// Dalla copia locale o con BODY.PEEK[]: non diventa letto.
    /// </summary>
    [HttpGet("{folder}/{uid}/raw")]
    public async Task<IActionResult> GetRaw(string folder, uint uid, CancellationToken ct) =>
        File(await CurrentAccount.Reader.GetRawAsync(FolderName.FromRoute(folder), uid, ct), "message/rfc822");

    /// <summary>GET /messages/{folder}/{uid}/attachments/{index} — contenuto dell'allegato con il suo Content-Type.</summary>
    [HttpGet("{folder}/{uid}/attachments/{index:int:min(0)}")]
    public async Task<IActionResult> GetAttachment(string folder, uint uid, int index, CancellationToken ct)
    {
        var attachment = await CurrentAccount.Reader.GetAttachmentAsync(FolderName.FromRoute(folder), uid, index, ct);
        // File() imposta Content-Disposition: attachment; filename=...
        return File(attachment.Data, attachment.ContentType, attachment.FileName);
    }
}
