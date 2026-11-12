using System.Collections.Concurrent;
using System.Threading.Channels;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Events;

namespace PostinoVip.Core.Imap;

/// <summary>
/// Download in background della cache di un account su una connessione IMAP dedicata: i clic
/// nell'app (connessione dei comandi) non aspettano mai. Un passaggio di <see cref="BodyDownloader"/>
/// parte subito all'avvio, quando l'IDLE segnala un cambiamento dell'account e ogni
/// <see cref="Interval"/> (per le cartelle diverse da INBOX). Le richieste che arrivano durante un
/// passaggio si riducono a un solo passaggio successivo. Dopo un errore di connessione si ritenta con
/// attese crescenti, come il controllo di INBOX.
/// Cartelle che la lista ha lasciato incomplete («headers-pending») o alla prima sincronizzazione: completate le
/// intestazioni, l'evento «folder-synced» dice all'app di rileggere la lista.
/// </summary>
public sealed class CacheDownloadWorker(string account, ImapSettings settings, BodyDownloader downloader, MailboxEventHub hub,
    Action<string>? log = null)
{
    public static readonly TimeSpan Interval = TimeSpan.FromMinutes(15);

    // Le notifiche IDLE arrivano a coppie (lezione appresa): una breve attesa le raccoglie in un passaggio.
    private static readonly TimeSpan Coalesce = TimeSpan.FromSeconds(1);
    private static readonly TimeSpan MaxBackoff = TimeSpan.FromMinutes(5);

    private readonly ConcurrentDictionary<string, bool> _pending = new(StringComparer.Ordinal);

    public async Task RunAsync(CancellationToken ct)
    {
        downloader.HeadersSynced = (folder, added, incomplete) =>
        {
            if (_pending.TryRemove(folder, out _) | (added > 0 && incomplete))
                hub.Publish(MailboxEvent.FolderSynced(account, folder));
        };
        using var stop = CancellationTokenSource.CreateLinkedTokenSource(ct);
        var wake = Channel.CreateBounded<bool>(new BoundedChannelOptions(1) { FullMode = BoundedChannelFullMode.DropWrite });
        wake.Writer.TryWrite(true); // primo passaggio subito dopo l'avvio
        var listen = ListenAsync(wake.Writer, stop.Token);
        var tick = TickAsync(wake.Writer, stop.Token);

        await using var connection = new ImapConnection(settings);
        var backoff = TimeSpan.FromSeconds(5);
        try
        {
            while (await wake.Reader.WaitToReadAsync(ct))
            {
                await Task.Delay(Coalesce, ct);
                wake.Reader.TryRead(out _);
                try
                {
                    await connection.ReadAsync(async s =>
                    {
                        await downloader.RunPassAsync(s, ct);
                        return true;
                    }, ct);
                    backoff = TimeSpan.FromSeconds(5);
                }
                catch (OperationCanceledException) when (ct.IsCancellationRequested)
                {
                    break;
                }
                catch (ArgumentException ex)
                {
                    // Configurazione mancante (es. credenziali): ritentare non servirebbe.
                    log?.Invoke($"[{account}] cache: download in background disattivato: {ex.Message}");
                    return;
                }
                catch (Exception ex)
                {
                    log?.Invoke($"[{account}] cache: download in background interrotto ({ex.GetType().Name}: {ex.Message}); " +
                                $"nuovo tentativo tra {backoff.TotalSeconds:0} s");
                    await Task.Delay(backoff, ct);
                    backoff = TimeSpan.FromSeconds(Math.Min(backoff.TotalSeconds * 2, MaxBackoff.TotalSeconds));
                    wake.Writer.TryWrite(true);
                }
            }
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            // Arresto del core.
        }
        finally
        {
            await stop.CancelAsync();
            await Task.WhenAll(listen, tick);
        }
    }

    /// <summary>Un passaggio a ogni cambiamento segnalato dall'IDLE di questo account e dopo "Ricostruisci cache".</summary>
    private async Task ListenAsync(ChannelWriter<bool> wake, CancellationToken ct)
    {
        using var subscription = hub.Subscribe();
        try
        {
            await foreach (var e in subscription.Reader.ReadAllAsync(ct))
            {
                if (e.Account != account)
                    continue;
                if (e is { Type: "headers-pending", Folder: { } folder })
                    _pending[folder] = true;
                if (e.Type is "mailbox-changed" or "cache-rebuilt" or "headers-pending")
                    wake.TryWrite(true);
            }
        }
        catch (OperationCanceledException)
        {
        }
    }

    private static async Task TickAsync(ChannelWriter<bool> wake, CancellationToken ct)
    {
        using var timer = new PeriodicTimer(Interval);
        try
        {
            while (await timer.WaitForNextTickAsync(ct))
                wake.TryWrite(true);
        }
        catch (OperationCanceledException)
        {
        }
    }
}
