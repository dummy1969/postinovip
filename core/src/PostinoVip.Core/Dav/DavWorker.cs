namespace PostinoVip.Core.Dav;

/// <summary>Stato della sincronizzazione per l'app (GET …/contacts/sync, …/calendars/sync); AddressBook = nome della raccolta.</summary>
/// <param name="State">"waiting" (non ancora partita), "syncing", "ok", "offline", "error", "unavailable" (non possibile per questo account).</param>
public sealed record DavStatus(bool Enabled, string State, DateTimeOffset? LastSync, string? Error, bool NeedsConfirmation,
    int PendingUpload, string? AddressBook)
{
    /// <summary>Codice e valori di <see cref="Error"/> per l'app (L6): la striscia «nuovo accesso» lo riconosce dal codice.</summary>
    public string? ErrorCode { get; init; }
    public IReadOnlyDictionary<string, string>? ErrorArgs { get; init; }
}

/// <summary>
/// Sincronizzazione DAV di un account (rubrica: C4b; calendari: K2a; scelta 4a): all'avvio, ogni <see cref="Interval"/>, subito dopo una
/// modifica nell'app (attesa di <see cref="Debounce"/> per raccogliere modifiche ravvicinate) e con
/// Invia/ricevi (<see cref="Wake"/>). Senza rete nuovo tentativo ogni <see cref="OfflineRetry"/>; altri errori
/// (password, certificato, risposta inattesa) nel log una volta e nuovo tentativo al giro dopo.
/// </summary>
public sealed class DavWorker
{
    public static readonly TimeSpan Interval = TimeSpan.FromMinutes(15);
    public static readonly TimeSpan OfflineRetry = TimeSpan.FromMinutes(1);
    public static TimeSpan Debounce { get; set; } = TimeSpan.FromSeconds(2);

    private readonly string _account;
    private readonly Func<IDavSyncJob>? _create;
    private readonly string _label;
    private readonly Action<string>? _log;
    private readonly Action<DavResult>? _done;
    private readonly SemaphoreSlim _wake = new(0, 1);
    private readonly SemaphoreSlim _running = new(1, 1);
    private volatile bool _confirmRequested;
    private string? _lastError;

    /// <param name="create">Crea la sincronizzazione (client con le credenziali attuali); null = non possibile per l'account.</param>
    /// <param name="unavailable">Motivo per cui non è possibile (con <paramref name="create"/> null).</param>
    /// <param name="done">Dopo ogni giro riuscito (l'Api ne fa l'evento contacts-changed se la rubrica è cambiata).</param>
    public DavWorker(string account, Contacts.ContactStore contacts, Func<IDavSyncJob>? create, string? unavailable = null,
        Action<string>? log = null, Action<DavResult>? done = null)
        : this(account, wake => contacts.LocalChanged += wake, create, unavailable, log, done, "CardDAV")
    {
    }

    /// <param name="subscribe">Registra l'azione da chiamare quando l'app cambia un elemento (sincronizzazione subito, 4a).</param>
    /// <param name="label">«CardDAV» o «CalDAV», per il log.</param>
    public DavWorker(string account, Action<Action>? subscribe, Func<IDavSyncJob>? create, string? unavailable,
        Action<string>? log, Action<DavResult>? done, string label)
    {
        _account = account;
        _label = label;
        _create = create;
        _log = log;
        _done = done;
        Status = create is null
            ? new DavStatus(true, "unavailable", null, unavailable, false, 0, null)
            : new DavStatus(true, "waiting", null, null, false, 0, null);
        if (create is not null)
            subscribe?.Invoke(Wake);
    }

    public DavStatus Status { get; private set; }

    /// <summary>Sincronizza subito (le richieste durante un giro valgono una sola volta in più).</summary>
    public void Wake()
    {
        try { _wake.Release(); }
        catch (SemaphoreFullException) { /* già richiesto */ }
    }

    /// <summary>L'utente conferma il caricamento degli elementi solo sul computer (2a): vale dal prossimo giro, che parte subito.</summary>
    public void Confirm()
    {
        _confirmRequested = true;
        Wake();
    }

    /// <summary>Un giro, aspettando quello in corso (anche per i test e la verifica).</summary>
    public async Task<DavResult?> RunOnceAsync(CancellationToken ct)
    {
        if (_create is null)
            return null;
        await _running.WaitAsync(ct);
        try
        {
            Status = Status with { State = "syncing" };
            var confirm = _confirmRequested;
            using var sync = _create();
            var result = await sync.RunAsync(DateTimeOffset.UtcNow, confirm, ct);
            if (confirm)
                _confirmRequested = false;
            Status = new DavStatus(true, "ok", DateTimeOffset.UtcNow, null, result.NeedsConfirmation, result.PendingUpload, result.CollectionName);
            _lastError = null;
            if (result.AnyChange || result.Conflicts > 0)
                _log?.Invoke($"[{_account}] {result.Describe(_label)}");
            _done?.Invoke(result);
            return result;
        }
        finally
        {
            _running.Release();
        }
    }

    public async Task RunAsync(CancellationToken ct)
    {
        if (_create is null)
            return;
        while (!ct.IsCancellationRequested)
        {
            var wait = Interval;
            try
            {
                await RunOnceAsync(ct);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                return;
            }
            catch (MailOfflineException ex)
            {
                if (Status.State != "offline")
                    _log?.Invoke($"[{_account}] {_label}: {ex.Message}");
                Status = Status with { State = "offline", Error = ex.Message, ErrorCode = CoreError.CodeOf(ex), ErrorArgs = CoreError.ArgsOf(ex) };
                wait = OfflineRetry;
            }
            catch (Exception ex)
            {
                var message = ex is DavException ? ex.Message : $"{ex.GetType().Name}: {ex.Message}";
                if (message != _lastError)
                    _log?.Invoke($"[{_account}] {_label}: sincronizzazione non riuscita ({message})");
                _lastError = message;
                Status = Status with { State = "error", Error = message, ErrorCode = CoreError.CodeOf(ex), ErrorArgs = CoreError.ArgsOf(ex) };
            }

            try
            {
                if (await _wake.WaitAsync(wait, ct))
                    await Task.Delay(Debounce, ct); // più modifiche di seguito = un solo giro
            }
            catch (OperationCanceledException)
            {
                return;
            }
        }
    }
}
