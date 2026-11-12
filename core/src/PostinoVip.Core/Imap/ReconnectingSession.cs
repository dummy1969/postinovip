namespace PostinoVip.Core.Imap;

/// <summary>
/// Una sessione di rete riusata tra le richieste, un comando alla volta (ImapClient non supporta
/// comandi concorrenti). Se la sessione è caduta viene ricreata; dopo un periodo di inattività
/// viene controllata con un "ping" prima dell'uso (i server chiudono le connessioni inattive).
/// Senza rete: il collegamento ha un tempo massimo (<c>connectTimeout</c>); se non riesce la sessione
/// diventa "non connessa" e per <c>offlineFor</c> ogni richiesta fallisce subito con
/// <see cref="MailOfflineException"/>, senza riprovare a ogni clic. <see cref="ProbeAsync"/> riprova
/// comunque (controllo periodico per tornare connessi).
/// Generica e senza dipendenze da MailKit, così la logica è testabile con una sessione finta.
/// </summary>
public sealed class ReconnectingSession<TSession> : IAsyncDisposable where TSession : class, IAsyncDisposable
{
    private readonly Func<CancellationToken, Task<TSession>> _connect;
    private readonly Func<TSession, bool> _isAlive;
    private readonly Func<TSession, CancellationToken, Task> _ping;
    private readonly Func<Exception, bool> _isConnectionError;
    private readonly TimeProvider _time;
    private readonly TimeSpan _pingAfter;
    private readonly TimeSpan? _connectTimeout;
    private readonly TimeSpan _offlineFor;
    private readonly Action<bool>? _onlineChanged;
    private readonly SemaphoreSlim _gate = new(1, 1);

    private TSession? _session;
    private DateTimeOffset _lastUse;
    private DateTimeOffset _offlineUntil;
    private MailOfflineException? _offline;

    /// <param name="connectTimeout">Tempo massimo per collegarsi (null = quello della libreria).</param>
    /// <param name="offlineFor">Dopo un collegamento non riuscito: per quanto non si ritenta.</param>
    /// <param name="onlineChanged">Chiamata quando lo stato passa da connesso a non connesso e viceversa.</param>
    public ReconnectingSession(
        Func<CancellationToken, Task<TSession>> connect,
        Func<TSession, bool> isAlive,
        Func<TSession, CancellationToken, Task> ping,
        Func<Exception, bool> isConnectionError,
        TimeSpan pingAfter,
        TimeProvider? time = null,
        TimeSpan? connectTimeout = null,
        TimeSpan? offlineFor = null,
        Action<bool>? onlineChanged = null)
    {
        _connect = connect;
        _isAlive = isAlive;
        _ping = ping;
        _isConnectionError = isConnectionError;
        _pingAfter = pingAfter;
        _time = time ?? TimeProvider.System;
        _connectTimeout = connectTimeout;
        _offlineFor = offlineFor ?? TimeSpan.Zero;
        _onlineChanged = onlineChanged;
    }

    /// <summary>Numero di connessioni aperte finora (diagnostica e test).</summary>
    public int ConnectCount { get; private set; }

    /// <summary>false dopo un collegamento non riuscito, finché uno non riesce (all'inizio true: non si sa ancora).</summary>
    public bool IsOnline => _offline is null;

    /// <param name="retryOnConnectionError">
    /// true solo per operazioni ripetibili senza effetti (letture). Una scrittura interrotta a metà
    /// non va ripetuta alla cieca: potrebbe essere già stata eseguita dal server.
    /// </param>
    /// <exception cref="MailOfflineException">Server non raggiungibile (anche senza ritentare, durante la pausa).</exception>
    public async Task<T> RunAsync<T>(Func<TSession, Task<T>> action, bool retryOnConnectionError, CancellationToken ct = default)
    {
        await _gate.WaitAsync(ct);
        try
        {
            var session = await EnsureSessionAsync(force: false, ct);
            try
            {
                return await Execute(session, action);
            }
            catch (Exception ex) when (_isConnectionError(ex))
            {
                await DropAsync();
                if (!retryOnConnectionError)
                    throw;
                return await Execute(await EnsureSessionAsync(force: false, ct), action);
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>
    /// Prova a collegarsi anche durante la pausa dopo un errore (e controlla una sessione esistente).
    /// </summary>
    /// <returns>true se il server ora risponde.</returns>
    public async Task<bool> ProbeAsync(CancellationToken ct = default)
    {
        await _gate.WaitAsync(ct);
        try
        {
            await EnsureSessionAsync(force: true, ct);
            return true;
        }
        catch (MailOfflineException)
        {
            return false;
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task<T> Execute<T>(TSession session, Func<TSession, Task<T>> action)
    {
        var result = await action(session);
        _lastUse = _time.GetUtcNow();
        return result;
    }

    private async Task<TSession> EnsureSessionAsync(bool force, CancellationToken ct)
    {
        if (_session is not null && _isAlive(_session))
        {
            if (!force && _time.GetUtcNow() - _lastUse < _pingAfter)
                return _session;
            try
            {
                await _ping(_session, ct);
                _lastUse = _time.GetUtcNow();
                return _session;
            }
            catch (Exception ex) when (_isConnectionError(ex))
            {
                // Connessione chiusa dal server durante l'inattività: si riapre sotto.
            }
        }

        await DropAsync();
        if (!force && _offline is not null && _time.GetUtcNow() < _offlineUntil)
            throw _offline;

        try
        {
            _session = await ConnectWithTimeoutAsync(ct);
        }
        catch (Exception ex) when (IsOffline(ex, ct))
        {
            var wasOnline = _offline is null;
            _offline = new MailOfflineException($"Server non raggiungibile ({Describe(ex)}).", ex);
            _offlineUntil = _time.GetUtcNow() + _offlineFor;
            if (wasOnline)
                _onlineChanged?.Invoke(false);
            throw _offline;
        }

        ConnectCount++;
        _lastUse = _time.GetUtcNow();
        if (_offline is not null)
        {
            _offline = null;
            _onlineChanged?.Invoke(true);
        }
        return _session;
    }

    private async Task<TSession> ConnectWithTimeoutAsync(CancellationToken ct)
    {
        if (_connectTimeout is not { } timeout)
            return await _connect(ct);
        using var limit = CancellationTokenSource.CreateLinkedTokenSource(ct);
        limit.CancelAfter(timeout);
        try
        {
            return await _connect(limit.Token);
        }
        catch (Exception ex) when (limit.IsCancellationRequested && !ct.IsCancellationRequested)
        {
            // Scaduto il tempo massimo: qualunque errore ne è la conseguenza. MailKit, se l'annullamento
            // arriva durante la cifratura, lo segnala come SslHandshakeException invece che come
            // OperationCanceledException (misurato con un server che non risponde).
            throw new TimeoutException($"nessuna risposta in {timeout.TotalSeconds:0} s", ex);
        }
    }

    /// <summary>Rete o server assenti; non: credenziali sbagliate, configurazione, richiesta annullata.</summary>
    private bool IsOffline(Exception ex, CancellationToken ct) =>
        !ct.IsCancellationRequested && (ex is TimeoutException || _isConnectionError(ex));

    private static string Describe(Exception ex) => ex is TimeoutException ? ex.Message : $"{ex.GetType().Name}: {ex.Message}";

    private async Task DropAsync()
    {
        var old = _session;
        _session = null;
        if (old is null)
            return;
        try
        {
            await old.DisposeAsync();
        }
        catch
        {
            // Una sessione già rotta può fallire anche in chiusura: non interessa.
        }
    }

    public async ValueTask DisposeAsync()
    {
        await _gate.WaitAsync();
        try
        {
            await DropAsync();
        }
        finally
        {
            _gate.Release();
            _gate.Dispose();
        }
    }
}
