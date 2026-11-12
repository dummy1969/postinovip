namespace PostinoVip.Core.Pop3;

/// <summary>
/// Controllo periodico della posta di un account POP3 (4.2, scelta 3a): subito all'avvio, poi ogni
/// <see cref="Pop3Settings.CheckMinutes"/> minuti e quando si chiede (<see cref="Wake"/>, es. Invia/ricevi).
/// Senza rete l'account risulta "non connesso" e si riprova ogni <see cref="OfflineRetry"/>.
/// Errori diversi dalla rete (password, certificato): nel log una volta, nuovo tentativo al giro dopo.
/// </summary>
public sealed class Pop3Worker(string account, Pop3Fetcher fetcher, Pop3Settings settings, Action<string>? log = null,
    Action<bool>? onlineChanged = null, Action<int>? onDownloaded = null)
{
    public static readonly TimeSpan OfflineRetry = TimeSpan.FromSeconds(30);

    private readonly SemaphoreSlim _wake = new(0, 1);
    private string? _lastError;

    public bool IsOnline { get; private set; } = true;

    /// <summary>Ultimo esito (diagnostica e verifica).</summary>
    public Pop3Result? LastResult { get; private set; }

    /// <summary>Controlla subito (le richieste durante un controllo valgono una sola volta in più).</summary>
    public void Wake()
    {
        try { _wake.Release(); }
        catch (SemaphoreFullException) { /* già richiesto */ }
    }

    public async Task RunAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            var wait = TimeSpan.FromMinutes(Math.Max(1, settings.CheckMinutes));
            try
            {
                var result = await fetcher.RunAsync(DateTimeOffset.UtcNow, ct);
                LastResult = result;
                SetOnline(true);
                _lastError = null;
                if (result.Downloaded > 0 || result.Removed > 0)
                    log?.Invoke($"[{account}] {result}");
                if (result.Downloaded > 0)
                    onDownloaded?.Invoke(result.Downloaded);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                return;
            }
            catch (MailOfflineException ex)
            {
                if (IsOnline)
                    log?.Invoke($"[{account}] POP3: {ex.Message}");
                SetOnline(false);
                wait = OfflineRetry;
            }
            catch (Exception ex)
            {
                // Rete caduta durante il controllo: come "non raggiungibile".
                if (ex is IOException or System.Net.Sockets.SocketException or TimeoutException or MailKit.ServiceNotConnectedException)
                {
                    SetOnline(false);
                    wait = OfflineRetry;
                }
                var message = $"{ex.GetType().Name}: {ex.Message}";
                if (message != _lastError)
                    log?.Invoke($"[{account}] POP3: controllo non riuscito ({message})");
                _lastError = message;
            }

            try
            {
                await _wake.WaitAsync(wait, ct);
            }
            catch (OperationCanceledException)
            {
                return;
            }
        }
    }

    private void SetOnline(bool online)
    {
        if (IsOnline == online)
            return;
        IsOnline = online;
        onlineChanged?.Invoke(online);
    }
}
