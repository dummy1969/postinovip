using Microsoft.AspNetCore.Mvc;
using PostinoVip.Api.Contracts;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Eml;
using PostinoVip.Core.Outbox;

namespace PostinoVip.Api.Controllers;

[ApiController]
[Route("drafts")]
[Route("accounts/{accountId}/drafts")]
public sealed class DraftsController(MailAccountRegistry accounts, OutboxSignal outboxSignal, EmlStore eml,
    ILogger<DraftsController> logger)
    : MailControllerBase(accounts)
{
    /// <summary>
    /// POST [/accounts/{accountId}]/drafts — MODIFICA la casella (3.8): salva la bozza in Bozze (\Drafts) al posto di
    /// <c>replace</c>. Senza connessione resta sul computer (pending, localId) e va sul server al ritorno.
    /// Nessun invio: i destinatari possono mancare o essere ancora sbagliati.
    /// </summary>
    [HttpPost]
    [RequestSizeLimit(SendController.MaxRequestBytes)]
    public async Task<ActionResult<DraftResponse>> Save([FromBody] DraftRequest request, CancellationToken ct)
    {
        var account = CurrentAccount;
        var message = await ComposeBuilder.BuildAsync(account, AccountById, request, draft: true, ct, eml);
        var outbox = account.Outbox;

        // Bozza da sostituire: quella sul server, oppure quella ancora sul computer (forse già caricata).
        var replace = request.Replace;
        var replaceUid = replace?.Uid;
        var pending = replace?.LocalId is { } id && outbox is not null ? outbox.Get(id) : null;
        if (replace?.LocalId is { } localId && outbox is not null)
            replaceUid ??= pending?.ReplaceDraftUid ?? outbox.UploadedUid(localId);

        try
        {
            var saved = await account.Writer.SaveDraftAsync(message, replaceUid, ct);
            if (pending is not null)
                outbox!.Remove(pending.Id);
            return Ok(new DraftResponse(saved.Folder, saved.Uid, Pending: false, LocalId: null));
        }
        catch (MailOfflineException) when (outbox is not null)
        {
            var item = new OutboxItem(pending?.Id ?? OutboxStore.NewId(), OutboxKind.Draft, DateTimeOffset.Now,
                message.Subject ?? "", message.To.Mailboxes.Select(m => m.Address).ToList(), ReplaceDraftUid: replaceUid);
            outbox.Save(item, message);
            logger.LogInformation("[{Account}] bozza salvata sul computer (non connesso)", account.Id);
            outboxSignal.Wake();
            return Ok(new DraftResponse(null, null, Pending: true, LocalId: item.Id));
        }
    }
}
