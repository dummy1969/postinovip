using Microsoft.AspNetCore.Mvc;
using PostinoVip.Api.Contracts;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Conversations;

namespace PostinoVip.Api.Controllers;

/// <summary>Corpo di Ignora, Interrompi Ignora e Pulisci conversazione: mail della cartella (da 1 a MessagesController.MaxBatch).</summary>
public sealed class ConversationCommandRequest
{
    public uint[]? Uids { get; set; }
}

/// <summary>La conversazione di una mail è ignorata?</summary>
public sealed record IgnoredResponse(bool Ignored);

/// <summary>Esito di Pulisci: mail spostate in Posta eliminata e mail esaminate.</summary>
public sealed record CleanUpResponse(string? MovedTo, IReadOnlyList<uint> Uids, int Checked);

/// <summary>
/// Ignora conversazione e Pulisci conversazione (C1). Tutti i POST MODIFICANO la casella (spostamenti in Posta
/// eliminata o, per Interrompi Ignora, in Posta in arrivo); niente si elimina definitivamente. Serve la copia locale.
/// </summary>
[ApiController]
public sealed class ConversationToolsController(MailAccountRegistry accounts, RuleJobs jobs) : MailControllerBase(accounts)
{
    private ConversationTools Tools =>
        jobs.ConversationsFor(CurrentAccount) ?? throw new NotSupportedException("Ignora e Pulisci richiedono la copia locale (Cache:Enabled=false).").WithCode("ignoraPulisciRichiedonoLaCopia");

    /// <summary>GET …/messages/{folder}/{uid}/ignored — sola lettura: per il pulsante «Ignora» premuto.</summary>
    [HttpGet("messages/{folder}/{uid}/ignored")]
    [HttpGet("accounts/{accountId}/messages/{folder}/{uid}/ignored")]
    public async Task<ActionResult<IgnoredResponse>> Ignored(string folder, uint uid, CancellationToken ct) =>
        Ok(new IgnoredResponse(await Tools.IsIgnoredAsync(FolderName.FromRoute(folder), [uid], ct)));

    /// <summary>POST …/messages/{folder}/ignore {"uids"} — MODIFICA: le mail delle conversazioni in questa cartella vanno in Posta eliminata.</summary>
    [HttpPost("messages/{folder}/ignore")]
    [HttpPost("accounts/{accountId}/messages/{folder}/ignore")]
    public async Task<ActionResult<BatchMoveResponse>> Ignore(string folder, [FromBody] ConversationCommandRequest request, CancellationToken ct)
    {
        var result = await Tools.IgnoreAsync(FolderName.FromRoute(folder), RequireUids(request.Uids), ct);
        return Ok(new BatchMoveResponse(result.Destination, false, result.Moved));
    }

    /// <summary>POST …/messages/{folder}/stop-ignoring {"uids"} — MODIFICA (da Posta eliminata): la conversazione torna in Posta in arrivo.</summary>
    [HttpPost("messages/{folder}/stop-ignoring")]
    [HttpPost("accounts/{accountId}/messages/{folder}/stop-ignoring")]
    public async Task<ActionResult<BatchMoveResponse>> StopIgnoring(string folder, [FromBody] ConversationCommandRequest request, CancellationToken ct)
    {
        var result = await Tools.StopIgnoringAsync(FolderName.FromRoute(folder), RequireUids(request.Uids), ct);
        return Ok(new BatchMoveResponse(result.Destination, false, result.Moved));
    }

    /// <summary>POST …/messages/{folder}/clean-up {"uids"} — MODIFICA: «Pulisci conversazione» sulle conversazioni delle mail.</summary>
    [HttpPost("messages/{folder}/clean-up")]
    [HttpPost("accounts/{accountId}/messages/{folder}/clean-up")]
    public async Task<ActionResult<CleanUpResponse>> CleanUpConversation(string folder, [FromBody] ConversationCommandRequest request,
        CancellationToken ct)
    {
        var result = await Tools.CleanUpAsync(FolderName.FromRoute(folder), RequireUids(request.Uids), ct);
        return Ok(new CleanUpResponse(result.Destination, result.Moved, result.Checked));
    }

    /// <summary>POST …/folders/{folder}/clean-up — MODIFICA: «Pulisci cartella», tutte le conversazioni della cartella.</summary>
    [HttpPost("folders/{folder}/clean-up")]
    [HttpPost("accounts/{accountId}/folders/{folder}/clean-up")]
    public async Task<ActionResult<CleanUpResponse>> CleanUpFolder(string folder, CancellationToken ct)
    {
        var result = await Tools.CleanUpAsync(FolderName.FromRoute(folder), null, ct);
        return Ok(new CleanUpResponse(result.Destination, result.Moved, result.Checked));
    }

    private static IReadOnlyCollection<uint> RequireUids(uint[]? uids)
    {
        if (uids is null || uids.Length == 0)
            throw new FieldValidationException("uids", "Indicare almeno una mail.").WithCode("indicareAlmenoUnaMail");
        if (uids.Length > MessagesController.MaxBatch)
            throw new FieldValidationException("uids", $"Al massimo {MessagesController.MaxBatch} mail per volta.").WithCode("alMassimoMailPerVolta", ("maxBatch", MessagesController.MaxBatch));
        return uids.Distinct().ToList();
    }
}
