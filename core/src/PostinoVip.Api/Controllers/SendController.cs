using Microsoft.AspNetCore.Mvc;
using MimeKit;
using PostinoVip.Api.Contracts;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Eml;
using PostinoVip.Core.Events;
using PostinoVip.Core.Outbox;

namespace PostinoVip.Api.Controllers;

[ApiController]
[Route("send")]
[Route("accounts/{accountId}/send")]
public sealed class SendController(MailAccountRegistry accounts, MailboxEventHub hub, OutboxSignal outboxSignal,
    EmlStore eml, ILogger<SendController> logger) : MailControllerBase(accounts)
{
    /// <summary>
    /// 25 MB di allegati diventano circa 33 MB in base64: il limite predefinito di Kestrel (~28,6 MB)
    /// non basterebbe. Alzato solo qui; il limite vero sugli allegati lo applica MimeMessageBuilder.
    /// </summary>
    public const long MaxRequestBytes = 40_000_000;

    /// <summary>
    /// POST [/accounts/{accountId}]/send — invia davvero la mail dall'account indicato; con saveCopy salva anche
    /// una copia nella sua Posta inviata. Con sendAfter nel futuro, o se il server di invio non è raggiungibile,
    /// la mail va nella Posta in uscita del computer e parte da sola dopo (3.8).
    /// </summary>
    [HttpPost]
    [RequestSizeLimit(MaxRequestBytes)]
    public async Task<ActionResult<SendResponse>> Send([FromBody] SendRequest request, CancellationToken ct)
    {
        var account = CurrentAccount;
        var message = await ComposeBuilder.BuildAsync(account, AccountById, request, draft: false, ct, eml);

        if (request.SendAfter is { } after && after > DateTimeOffset.Now)
        {
            if (account.Outbox is null)
                throw new NotSupportedException("Ritarda recapito richiede la cache locale (Cache:Enabled=false).").WithCode("ritardaRecapitoRichiedeLaCache");
            return Ok(await QueueAsync(account, message, request, after, offline: false, ct));
        }

        string serverResponse;
        try
        {
            serverResponse = await account.Sender.SendMimeAsync(message, ct);
        }
        catch (MailOfflineException) when (account.Outbox is not null)
        {
            // Senza connessione (3.8): nella Posta in uscita, parte da sola quando il server risponde.
            return Ok(await QueueAsync(account, message, request, null, offline: true, ct));
        }

        RecordRecipients(account, message);
        await DeleteDraftAsync(account, request.DeleteDraft, ct);
        if (!request.SaveCopy)
            return Ok(new SendResponse(serverResponse));

        // La mail è già partita: un errore nella copia non deve trasformare l'esito in un fallimento,
        // altrimenti l'utente potrebbe reinviarla. Si segnala a parte.
        try
        {
            var folder = await account.Writer.AppendToSentAsync(message, ct);
            logger.LogInformation("[{Account}] APPEND copia inviata in {Folder}", account.Id, folder);
            return Ok(new SendResponse(serverResponse, SavedTo: folder));
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning("[{Account}] Copia in Posta inviata non salvata: {Type}: {Message}", account.Id, ex.GetType().Name, ex.Message);
            return Ok(new SendResponse(serverResponse, SaveError: ex.Message));
        }
    }

    private async Task<SendResponse> QueueAsync(MailAccount account, MimeMessage message, SendRequest request,
        DateTimeOffset? after, bool offline, CancellationToken ct)
    {
        var outbox = account.Outbox!;
        var item = new OutboxItem(OutboxStore.NewId(), OutboxKind.Send, DateTimeOffset.Now, message.Subject ?? "",
            message.To.Mailboxes.Select(m => m.Address).ToList(), after, request.SaveCopy);

        // La bozza che si stava scrivendo: tolta subito se si può (non si rischia di inviarla due volte),
        // altrimenti dopo l'invio.
        var draft = request.DeleteDraft;
        if (draft?.LocalId is { } localId)
        {
            outbox.Remove(localId);
            draft = new DraftRef { Uid = draft.Uid ?? outbox.UploadedUid(localId) };
        }
        if (draft?.Uid is { } uid)
        {
            try
            {
                if (offline)
                    throw new MailOfflineException("non connesso").WithCode("notConnected");
                await account.Writer.DeleteDraftAsync(uid, ct);
            }
            catch (MailOfflineException)
            {
                item = item with { DeleteDraftUid = uid };
            }
        }

        outbox.Save(item, message);
        logger.LogInformation("[{Account}] mail nella Posta in uscita ({Reason})", account.Id, offline ? "non connesso" : "invio differito");
        hub.Publish(MailboxEvent.OutboxChanged(account.Id, outbox.SendCount));
        outboxSignal.Wake();
        return new SendResponse(null, Queued: true, OutboxId: item.Id, SendAfter: after, OfflineQueued: offline);
    }

    /// <summary>
    /// Dopo un invio riuscito (anche dalla Posta in uscita): i destinatari diventano indirizzi usati di recente
    /// (contatti, 7a). Un errore qui non cambia l'esito dell'invio: la mail è già partita.
    /// </summary>
    internal static void RecordRecipients(MailAccount account, MimeMessage message)
    {
        try
        {
            account.Recent?.RecordSent(message);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
        }
    }

    /// <summary>Dopo l'invio: la bozza da cui veniva la mail sparisce (non è un errore se non riesce).</summary>
    private async Task DeleteDraftAsync(MailAccount account, DraftRef? draft, CancellationToken ct)
    {
        if (draft is null)
            return;
        var uid = draft.Uid;
        if (draft.LocalId is { } localId && account.Outbox is { } outbox)
        {
            outbox.Remove(localId);
            uid ??= outbox.UploadedUid(localId);
        }
        if (uid is not { } u)
            return;
        try
        {
            await account.Writer.DeleteDraftAsync(u, ct);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning("[{Account}] bozza inviata non eliminata: {Type}: {Message}", account.Id, ex.GetType().Name, ex.Message);
        }
    }
}
