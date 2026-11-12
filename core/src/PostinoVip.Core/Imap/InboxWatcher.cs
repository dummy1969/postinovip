using PostinoVip.Core.Events;

namespace PostinoVip.Core.Imap;

/// <summary>
/// Controllo di INBOX in tempo reale su una connessione dedicata (durante IDLE una connessione
/// non può eseguire altri comandi). Si riconnette con attese crescenti; pubblica nel
/// MailboxEventHub i cambiamenti e lo stato (attivo / non attivo). Uno per account.
/// </summary>
public sealed class InboxWatcher(string account, ImapSettings settings, MailboxEventHub hub, Action<string>? log = null)
{
    public static readonly TimeSpan IdleRenew = TimeSpan.FromMinutes(9);
    public static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(60);
    private static readonly TimeSpan MaxBackoff = TimeSpan.FromMinutes(5);

    public async Task RunAsync(CancellationToken ct)
    {
        var backoff = TimeSpan.FromSeconds(5);
        while (!ct.IsCancellationRequested)
        {
            try
            {
                await using var session = new ImapMailService(settings);
                await session.ConnectAsync(ct);
                hub.Publish(MailboxEvent.Status(account, true));
                log?.Invoke($"[{account}] Controllo INBOX attivo (IDLE).");
                backoff = TimeSpan.FromSeconds(5);

                await session.WatchInboxAsync(count => hub.Publish(MailboxEvent.Changed(account, "INBOX", count)),
                    IdleRenew, PollInterval, ct);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                break;
            }
            catch (ArgumentException ex)
            {
                // Configurazione mancante (es. credenziali): ritentare non servirebbe.
                hub.Publish(MailboxEvent.Status(account, false));
                log?.Invoke($"[{account}] Controllo INBOX disattivato: {ex.Message}");
                return;
            }
            catch (Exception ex)
            {
                hub.Publish(MailboxEvent.Status(account, false));
                log?.Invoke($"[{account}] Controllo INBOX interrotto ({ex.GetType().Name}: {ex.Message}); nuovo tentativo tra {backoff.TotalSeconds:0} s.");
            }

            try
            {
                await Task.Delay(backoff, ct);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            backoff = TimeSpan.FromSeconds(Math.Min(backoff.TotalSeconds * 2, MaxBackoff.TotalSeconds));
        }
        hub.Publish(MailboxEvent.Status(account, false));
    }
}
