using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Events;
using PostinoVip.Core.Outbox;

namespace PostinoVip.Api;

/// <summary>
/// Posta in uscita e bozze in attesa (3.8): ogni <see cref="Interval"/>, quando si mette qualcosa in coda e
/// quando un server torna raggiungibile, per ogni account invia le mail il cui momento è arrivato (copia in Posta
/// inviata se richiesta, bozza di partenza eliminata) e salva in Bozze quelle scritte senza connessione.
/// Senza connessione si riprova dopo; un altro errore resta sulla mail, niente nuovi tentativi da soli.
/// Funziona solo con il core acceso, cioè con l'app aperta (come Outlook).
/// </summary>
public sealed class OutboxService(MailAccountRegistry accounts, MailboxEventHub hub, OutboxSignal signal,
    ILogger<OutboxService> logger) : BackgroundService
{
    public static readonly TimeSpan Interval = TimeSpan.FromSeconds(30);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var watch = WatchConnectionAsync(stoppingToken);
        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                foreach (var account in accounts.All)
                {
                    if (account.Outbox is not null)
                        await RunPassAsync(account, hub, logger, DateTimeOffset.Now, stoppingToken);
                }
                await signal.WaitAsync(Interval, stoppingToken);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Arresto del core.
        }
        await watch;
    }

    /// <summary>Server di nuovo raggiungibile: si prova subito invece di aspettare il prossimo giro.</summary>
    private async Task WatchConnectionAsync(CancellationToken ct)
    {
        using var subscription = hub.Subscribe();
        try
        {
            await foreach (var e in subscription.Reader.ReadAllAsync(ct))
            {
                if (e is { Type: "connection-status", Online: true })
                    signal.Wake();
            }
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
        }
    }

    /// <summary>Un passaggio sulla coda di un account (pubblico per i test).</summary>
    public static async Task RunPassAsync(MailAccount account, MailboxEventHub hub, ILogger logger, DateTimeOffset now,
        CancellationToken ct)
    {
        var store = account.Outbox!;
        foreach (var item in store.List().Where(i => i.IsDue(now)))
        {
            var message = store.LoadMessage(item.Id);
            if (message is null)
            {
                store.Remove(item.Id);
                continue;
            }
            try
            {
                if (item.Kind == OutboxKind.Draft)
                {
                    var saved = await account.Writer.SaveDraftAsync(message, item.ReplaceDraftUid, ct);
                    store.MarkUploaded(item.Id, saved.Uid);
                    store.Remove(item.Id);
                    logger.LogInformation("[{Account}] bozza scritta senza connessione salvata in {Folder}", account.Id, saved.Folder);
                    continue;
                }

                message.Date = DateTimeOffset.Now; // ora dell'invio vero, non di quando è stata messa in coda
                await account.Sender.SendMimeAsync(message, ct);
                // Tolta subito: se dopo qualcosa non riesce la mail è comunque partita (mai inviarla due volte).
                store.Remove(item.Id);
                hub.Publish(MailboxEvent.OutboxChanged(account.Id, store.SendCount));
                logger.LogInformation("[{Account}] Posta in uscita: mail inviata", account.Id);
                Controllers.SendController.RecordRecipients(account, message);
                await AfterSendAsync(account, item, message, logger, ct);
            }
            catch (MailOfflineException)
            {
                return; // server non raggiungibile: si riprova al prossimo passaggio
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                store.Update(item with { Error = ex.Message });
                hub.Publish(MailboxEvent.OutboxChanged(account.Id, store.SendCount));
                logger.LogWarning("[{Account}] Posta in uscita: invio non riuscito: {Type}: {Message}", account.Id, ex.GetType().Name, ex.Message);
            }
        }
    }

    private static async Task AfterSendAsync(MailAccount account, OutboxItem item, MimeKit.MimeMessage message, ILogger logger,
        CancellationToken ct)
    {
        try
        {
            if (item.SaveCopy)
                await account.Writer.AppendToSentAsync(message, ct);
            if (item.DeleteDraftUid is { } uid)
                await account.Writer.DeleteDraftAsync(uid, ct);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning("[{Account}] mail inviata, ma copia o bozza non aggiornate: {Type}: {Message}", account.Id,
                ex.GetType().Name, ex.Message);
        }
    }
}
