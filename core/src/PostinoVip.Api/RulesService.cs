using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Events;
using PostinoVip.Core.Rules;

namespace PostinoVip.Api;

/// <summary>
/// Esegue il filtro della posta indesiderata (J1), le risposte automatiche e poi le regole (R1) di ogni account con la copia locale: all'avvio, quando la Posta in arrivo cambia
/// (IDLE o scaricamento POP3, evento mailbox-changed), quando il server torna raggiungibile e ogni
/// <see cref="Interval"/> per sicurezza. Gli avvisi ravvicinati si raccolgono (<see cref="Debounce"/>).
/// Rules:Enabled=false lo disattiva (test).
/// </summary>
public sealed class RulesService(MailAccountRegistry accounts, MailboxEventHub hub, RuleJobs jobs, ILoggerFactory loggers) : BackgroundService
{
    public static readonly TimeSpan Interval = TimeSpan.FromMinutes(5);
    public static readonly TimeSpan Debounce = TimeSpan.FromSeconds(1);
    public static readonly TimeSpan StartDelay = TimeSpan.FromSeconds(3);

    private readonly ILogger _logger = loggers.CreateLogger("PostinoVip.Rules");

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var workers = accounts.All
            .Where(a => a.Rules is not null && a.Configured)
            .ToDictionary(a => a.Id, a => new Worker(jobs.RunnerFor(a), jobs.AutoReplyFor(a), jobs.JunkFor(a), jobs.ConversationsFor(a), _logger, a.Id)); // stesso runner di "Esegui regole ora"
        if (workers.Count == 0)
            return;

        using var subscription = hub.Subscribe();
        var loops = workers.Values.Select(w => w.RunAsync(stoppingToken)).ToList();
        try
        {
            await foreach (var e in subscription.Reader.ReadAllAsync(stoppingToken))
            {
                if (!workers.TryGetValue(e.Account, out var worker))
                    continue;
                var inboxChanged = e.Type == "mailbox-changed" && string.Equals(e.Folder, RuleRunner.Inbox, StringComparison.OrdinalIgnoreCase);
                if (inboxChanged || e is { Type: "connection-status", Online: true } || e.Type == "cache-rebuilt")
                    worker.Wake();
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
        await Task.WhenAll(loops);
    }

    private sealed class Worker(RuleRunner runner, PostinoVip.Core.AutoReply.AutoReplyRunner? autoReply,
        PostinoVip.Core.Junk.JunkFilter? junk, PostinoVip.Core.Conversations.ConversationTools? ignore, ILogger logger, string account)
    {
        private readonly SemaphoreSlim _wake = new(0, 1);

        public void Wake()
        {
            try { _wake.Release(); }
            catch (SemaphoreFullException) { /* già richiesto */ }
        }

        public async Task RunAsync(CancellationToken ct)
        {
            try
            {
                await Task.Delay(StartDelay, ct);
                while (!ct.IsCancellationRequested)
                {
                    try
                    {
                        // Prima la posta indesiderata (niente risposte automatiche né regole sulle mail spostate lì),
                        // poi le risposte automatiche: una regola potrebbe spostare la mail fuori dalla Posta in arrivo.
                        if (junk is not null)
                            await junk.RunNewAsync(ct);
                        if (ignore is not null)
                            await ignore.RunNewAsync(ct); // conversazioni ignorate: niente risposte automatiche né regole
                        if (autoReply is not null)
                            await autoReply.RunNewAsync(ct);
                        await runner.RunNewAsync(ct);
                    }
                    catch (OperationCanceledException) when (ct.IsCancellationRequested)
                    {
                        return;
                    }
                    catch (MailOfflineException)
                    {
                        // Senza rete: si riprova al ritorno della connessione (evento) o al prossimo giro.
                    }
                    catch (Exception ex)
                    {
                        logger.LogWarning("[{Account}] regole non eseguite: {Type}: {Message}", account, ex.GetType().Name, ex.Message);
                    }
                    await _wake.WaitAsync(Interval, ct);
                    await Task.Delay(Debounce, ct); // più avvisi insieme (l'IDLE ne manda due per arrivo)
                }
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
            }
        }
    }
}
