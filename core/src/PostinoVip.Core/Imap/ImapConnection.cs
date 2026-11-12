using System.Net.Sockets;
using MailKit;
using MailKit.Net.Imap;

namespace PostinoVip.Core.Imap;

/// <summary>
/// Connessione IMAP persistente condivisa da lettura e scrittura (una sola, comandi in serie).
/// Le letture vengono ripetute una volta se la connessione cade; le scritture no.
/// Senza rete: collegamento entro <see cref="ConnectTimeout"/>, poi per <see cref="OfflineFor"/> le
/// richieste falliscono subito con MailOfflineException (chi può usa la copia locale).
/// </summary>
public sealed class ImapConnection : IAsyncDisposable
{
    // I server IMAP chiudono le connessioni inattive dopo almeno 30 minuti (RFC 3501);
    // oltre questa soglia si fa un NOOP prima di usarla.
    private static readonly TimeSpan PingAfter = TimeSpan.FromMinutes(2);

    /// <summary>Tempo massimo per collegarsi e autenticarsi: oltre, il server è considerato non raggiungibile.</summary>
    public static readonly TimeSpan ConnectTimeout = TimeSpan.FromSeconds(10);

    /// <summary>
    /// Tempo massimo di ogni lettura/scrittura (vale per singola lettura: un allegato grande che arriva
    /// non viene interrotto). Con la rete staccata a connessione aperta, entro questo tempo il comando
    /// fallisce, la connessione si chiude e il nuovo collegamento (al massimo <see cref="ConnectTimeout"/>)
    /// porta a "non connesso": in tutto circa 20 s, meno dei 30 s che l'app concede a una richiesta.
    /// </summary>
    public static readonly TimeSpan OperationTimeout = TimeSpan.FromSeconds(10);

    /// <summary>Dopo un collegamento non riuscito, per quanto non si ritenta a ogni richiesta.</summary>
    public static readonly TimeSpan OfflineFor = TimeSpan.FromMinutes(1);

    private readonly ReconnectingSession<ImapMailService> _session;

    /// <param name="onlineChanged">Chiamata quando il server diventa non raggiungibile (false) o torna raggiungibile (true).</param>
    public ImapConnection(ImapSettings settings, TimeProvider? time = null, Action<bool>? onlineChanged = null)
    {
        _session = new ReconnectingSession<ImapMailService>(
            connect: async ct =>
            {
                var s = new ImapMailService(settings, OperationTimeout);
                try
                {
                    await s.ConnectAsync(ct);
                    return s;
                }
                catch
                {
                    await s.DisposeAsync();
                    throw;
                }
            },
            isAlive: s => s.IsAlive,
            ping: (s, ct) => s.PingAsync(ct),
            isConnectionError: IsConnectionError,
            pingAfter: PingAfter,
            time: time,
            connectTimeout: ConnectTimeout,
            offlineFor: OfflineFor,
            onlineChanged: onlineChanged);
    }

    public int ConnectCount => _session.ConnectCount;

    /// <summary>false dopo un collegamento non riuscito, finché uno non riesce.</summary>
    public bool IsOnline => _session.IsOnline;

    public Task<T> ReadAsync<T>(Func<ImapMailService, Task<T>> action, CancellationToken ct = default) =>
        _session.RunAsync(action, retryOnConnectionError: true, ct);

    public Task<T> WriteAsync<T>(Func<ImapMailService, Task<T>> action, CancellationToken ct = default) =>
        _session.RunAsync(action, retryOnConnectionError: false, ct);

    /// <summary>Prova a collegarsi anche durante la pausa (controllo periodico): true se il server risponde.</summary>
    public Task<bool> ProbeAsync(CancellationToken ct = default) => _session.ProbeAsync(ct);

    /// <summary>
    /// Errori che indicano una connessione inutilizzabile (non un "NO" del server su un comando).
    /// TimeoutException: il server non ha risposto entro <see cref="OperationTimeout"/> (MailKit chiude la connessione).
    /// </summary>
    public static bool IsConnectionError(Exception ex) =>
        ex is IOException or SocketException or ImapProtocolException or ServiceNotConnectedException or MailOfflineException
            or TimeoutException;

    public ValueTask DisposeAsync() => _session.DisposeAsync();
}
