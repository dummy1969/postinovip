using Microsoft.AspNetCore.Mvc;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Junk;

namespace PostinoVip.Api.Controllers;

/// <summary>Opzioni posta indesiderata con la cartella in uso (JunkFolder: scelta, del server o dal nome; null = nessuna).</summary>
public sealed record JunkOptionsResponse(JunkLevel Level, string? Folder, string? JunkFolder, bool TrustContacts,
    IReadOnlyList<string> SafeSenders, IReadOnlyList<string> SafeRecipients, IReadOnlyList<string> BlockedSenders);

/// <summary>Corpo dei comandi della posta indesiderata: mail della cartella (da 1 a MessagesController.MaxBatch).</summary>
public sealed class JunkCommandRequest
{
    public uint[]? Uids { get; set; }

    /// <summary>Solo «Non bloccare mai…»: sender, domain o group.</summary>
    public NeverBlockKind? Kind { get; set; }

    /// <summary>Solo «Non è posta indesiderata»: aggiungere i mittenti agli attendibili.</summary>
    public bool TrustSenders { get; set; }
}

/// <summary>
/// Posta indesiderata (J1). Le opzioni (GET/PUT …/junk) non modificano la casella: valgono per le mail che arrivano
/// da quel momento. «Blocca mittente» e «Non è posta indesiderata» MODIFICANO la casella (parole chiave e
/// spostamento); «Non bloccare mai…» cambia solo gli elenchi.
/// </summary>
[ApiController]
public sealed class JunkController(MailAccountRegistry accounts, RuleJobs jobs, ILogger<JunkController> logger)
    : MailControllerBase(accounts)
{
    private JunkStore Store =>
        CurrentAccount.Junk ?? throw new NotSupportedException("La posta indesiderata richiede la copia locale (Cache:Enabled=false).");

    private JunkFilter Filter => jobs.JunkFor(CurrentAccount) ?? throw new NotSupportedException("La posta indesiderata richiede la copia locale.");

    [HttpGet("junk")]
    [HttpGet("accounts/{accountId}/junk")]
    public async Task<ActionResult<JunkOptionsResponse>> Get(CancellationToken ct) => Ok(await ToResponse(Store.Load(), ct));

    /// <summary>PUT — sostituisce le opzioni; la cartella scelta deve esistere (400 sul campo "folder").</summary>
    [HttpPut("junk")]
    [HttpPut("accounts/{accountId}/junk")]
    public async Task<ActionResult<JunkOptionsResponse>> Put([FromBody] JunkSettings settings, CancellationToken ct)
    {
        var clean = JunkStore.Validate(settings);
        if (clean.Folder is { } folder)
        {
            var folders = await CurrentAccount.Reader.GetFoldersAsync(ct);
            if (folders.All(f => f.FullName != folder))
                throw new FieldValidationException("folder", "La cartella scelta non esiste.");
            if (folders.First(f => f.FullName == folder).SpecialUse is "inbox" or "sent" or "drafts" or "trash")
                throw new FieldValidationException("folder", "Scegliere una cartella diversa da Posta in arrivo, Posta inviata, Bozze e Posta eliminata.");
            if (folder == CurrentAccount.Archive?.Load().Folder)
                throw new FieldValidationException("folder", "È la cartella di archiviazione: sceglierne un'altra.");
        }
        return Ok(await ToResponse(Store.Save(clean), ct));
    }

    /// <summary>POST …/messages/{folder}/block {"uids"} — «Blocca mittente»: MODIFICA la casella (sposta nella posta indesiderata).</summary>
    [HttpPost("messages/{folder}/block")]
    [HttpPost("accounts/{accountId}/messages/{folder}/block")]
    public async Task<ActionResult<JunkCommandResult>> Block(string folder, [FromBody] JunkCommandRequest request, CancellationToken ct)
    {
        var result = await Filter.BlockAsync(FolderName.FromRoute(folder), RequireUids(request.Uids), ct);
        logger.LogInformation("[{Account}] blocca mittente: {Entries} voci, {Count} mail spostate", CurrentAccount.Id, result.Entries.Count, result.Moved.Count);
        return Ok(result);
    }

    /// <summary>POST …/messages/{folder}/never-block {"uids", "kind"} — «Non bloccare mai…»: solo gli elenchi.</summary>
    [HttpPost("messages/{folder}/never-block")]
    [HttpPost("accounts/{accountId}/messages/{folder}/never-block")]
    public async Task<ActionResult<JunkCommandResult>> NeverBlock(string folder, [FromBody] JunkCommandRequest request, CancellationToken ct)
    {
        var kind = request.Kind ?? throw new FieldValidationException("kind", "Indicare kind (sender, domain o group).");
        return Ok(await Filter.NeverBlockAsync(FolderName.FromRoute(folder), RequireUids(request.Uids), kind, ct));
    }

    /// <summary>POST …/messages/{folder}/not-junk {"uids", "trustSenders"} — MODIFICA la casella (riporta in Posta in arrivo).</summary>
    [HttpPost("messages/{folder}/not-junk")]
    [HttpPost("accounts/{accountId}/messages/{folder}/not-junk")]
    public async Task<ActionResult<JunkCommandResult>> NotJunk(string folder, [FromBody] JunkCommandRequest request, CancellationToken ct)
    {
        var result = await Filter.NotJunkAsync(FolderName.FromRoute(folder), RequireUids(request.Uids), request.TrustSenders, ct);
        logger.LogInformation("[{Account}] non è posta indesiderata: {Count} mail in Posta in arrivo", CurrentAccount.Id, result.Moved.Count);
        return Ok(result);
    }

    private async Task<JunkOptionsResponse> ToResponse(JunkSettings s, CancellationToken ct) =>
        new(s.Level, s.Folder, await Filter.JunkFolderAsync(ct), s.TrustContacts, s.SafeSenders, s.SafeRecipients, s.BlockedSenders);

    private static IReadOnlyCollection<uint> RequireUids(uint[]? uids)
    {
        if (uids is null || uids.Length == 0)
            throw new FieldValidationException("uids", "Indicare almeno una mail.");
        if (uids.Length > MessagesController.MaxBatch)
            throw new FieldValidationException("uids", $"Al massimo {MessagesController.MaxBatch} mail per volta.");
        return uids.Distinct().ToList();
    }
}
