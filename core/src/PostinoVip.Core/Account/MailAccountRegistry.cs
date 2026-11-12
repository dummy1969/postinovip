using System.Text.RegularExpressions;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Models;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Account;

/// <summary>
/// Le caselle gestite dal core, nell'ordine di configurazione. Possiede le connessioni IMAP
/// e le chiude all'arresto.
/// </summary>
public sealed partial class MailAccountRegistry : IAsyncDisposable
{
    private readonly IReadOnlyList<MailAccount> _accounts;
    private readonly IReadOnlyList<IAsyncDisposable> _owned;

    public MailAccountRegistry(IReadOnlyList<MailAccount> accounts, IReadOnlyList<IAsyncDisposable>? owned = null)
    {
        Validate(accounts.Select(a => a.Settings).ToList());
        _accounts = accounts;
        _owned = owned ?? [];
    }

    public IReadOnlyList<MailAccount> All => _accounts;

    /// <summary>
    /// L'account con questo id; con null il primo (percorsi senza /accounts/{id}, usati dall'app
    /// finché gestiva un solo account).
    /// </summary>
    public MailAccount Get(string? id) =>
        id is null
            ? _accounts[0]
            : _accounts.FirstOrDefault(a => a.Id == id) ?? throw new MailNotFoundException($"Account '{id}' non trovato.");

    /// <summary>
    /// Servizi reali: una connessione IMAP persistente per account; SMTP solo al momento dell'invio.
    /// Con <paramref name="cacheRoot"/> lista e messaggi passano dalla cache locale, un database e i file
    /// dei corpi per account in <c>{cacheRoot}/accounts/{id}/</c>; null = senza cache.
    /// </summary>
    /// <param name="onlineChanged">Il server di un account è diventato non raggiungibile (false) o di nuovo raggiungibile.</param>
    /// <param name="pop3Downloaded">
    /// Mail nuove scaricate da un account POP3 (account, quante): l'Api ne fa l'evento mailbox-changed, come
    /// l'IDLE degli account IMAP.
    /// </param>
    /// <param name="oauthProviders">Fornitori OAuth2 (id -> configurazione) per gli account con <see cref="MailAccountSettings.OAuth"/>.</param>
    /// <param name="refreshTokenChanged">Il fornitore ha dato un nuovo token di rinnovo (account, token): l'app lo salva (4a).</param>
    /// <param name="needsLoginChanged">Il fornitore ha rifiutato (true) o di nuovo accettato (false) il token di rinnovo (2a).</param>
    /// <param name="contactsSynced">Giro di sincronizzazione CardDAV riuscito (account, esito): l'Api avvisa l'app se la rubrica è cambiata.</param>
    /// <param name="calendarsSynced">Giro di sincronizzazione CalDAV riuscito (account, esito): l'Api avvisa l'app se i calendari sono cambiati.</param>
    /// <param name="headersPending">La lista di una cartella (account, cartella) ha lasciato intestazioni nuove al download in background.</param>
    public static MailAccountRegistry CreateImap(IReadOnlyList<MailAccountSettings> settings, string? cacheRoot = null,
        Action<string>? log = null, Action<string, bool>? onlineChanged = null, Action<string, int>? pop3Downloaded = null,
        IReadOnlyDictionary<string, OAuth.OAuthProvider>? oauthProviders = null, Action<string, string>? refreshTokenChanged = null,
        Action<string, bool>? needsLoginChanged = null, Action<string, Dav.DavResult>? contactsSynced = null,
        Action<string, Dav.DavResult>? calendarsSynced = null, Action<string, string>? headersPending = null)
    {
        Validate(settings); // prima di usare i dati (es. l'indirizzo CardDAV)
        foreach (var s in settings.Where(s => s.OAuth.IsSet))
            AttachOAuth(s, oauthProviders, refreshTokenChanged, needsLoginChanged);

        if (cacheRoot is not null)
        {
            // Private anche le cartelle superiori (le cartelle degli account si creano al primo uso).
            CachePermissions.CreatePrivateDirectory(cacheRoot);
            CachePermissions.CreatePrivateDirectory(Path.Combine(cacheRoot, "accounts"));
        }

        var connections = new List<IAsyncDisposable>();
        var accounts = new List<MailAccount>();
        foreach (var s in settings)
        {
            // Nessun collegamento qui: ImapConnection si collega al primo comando.
            var id = s.Id;
            if (cacheRoot is not null)
                CacheAccounts.WriteInfo(cacheRoot, s); // di chi sono i dati, anche dopo la rimozione dell'account
            if (s.IsPop3)
            {
                accounts.Add(CreatePop3(s, cacheRoot ?? throw new ArgumentException(
                    $"Account '{s.Id}': un account POP3 richiede la copia locale (Cache:Enabled=false non è possibile)."), log, onlineChanged,
                    pop3Downloaded, contactsSynced, calendarsSynced));
                continue;
            }
            var connection = new ImapConnection(s.Imap, onlineChanged: online =>
            {
                log?.Invoke(online ? $"[{id}] server di nuovo raggiungibile" : $"[{id}] server non raggiungibile: uso la copia locale");
                onlineChanged?.Invoke(id, online);
            });
            connections.Add(connection);
            IMailReader reader = new ImapMailReader(connection);
            BodyCache? bodies = null;
            AccountCache? cache = null;
            if (cacheRoot is not null)
            {
                cache = new AccountCache(CacheDirectory(cacheRoot, s.Id));
                bodies = new BodyCache(s.Id, cache, BodyPolicy.FromMonths(s.Cache.BodyMonths), log);
                reader = new CachedMailReader(s.Id, connection, reader, cache, bodies, log,
                    headersPending is null ? null : folder => headersPending(id, folder));
            }
            var outbox = cacheRoot is null ? null : new Outbox.OutboxStore(Path.Combine(CacheDirectory(cacheRoot, s.Id), "outbox"));
            var rules = cacheRoot is null ? null : new Rules.RuleStore(CacheDirectory(cacheRoot, s.Id));
            var contacts = cacheRoot is null ? null : ContactsOf(cacheRoot, s.Id);
            var calendars = cacheRoot is null ? null : CalendarsOf(cacheRoot, s.Id);
            accounts.Add(new MailAccount(s, reader, new ImapMailWriter(connection),
                new DeferredMailSender(() => new SmtpMailService(s.Smtp)), bodies, connection, outbox, rules: rules,
                autoReply: cacheRoot is null ? null : new AutoReply.AutoReplyStore(CacheDirectory(cacheRoot, s.Id)),
                contacts: contacts, recent: cacheRoot is null ? null : RecentOf(cacheRoot, s.Id, cache),
                cardDav: contacts is null ? null : CardDavOf(s, cacheRoot!, contacts, log, contactsSynced),
                calendars: calendars, calDav: calendars is null ? null : CalDavOf(s, calendars, log, calendarsSynced),
                junk: cacheRoot is null ? null : new Junk.JunkStore(CacheDirectory(cacheRoot, s.Id)),
                archive: cacheRoot is null ? null : new Archive.ArchiveStore(CacheDirectory(cacheRoot, s.Id)),
                ignore: cacheRoot is null ? null : new Conversations.IgnoreStore(CacheDirectory(cacheRoot, s.Id))));
        }
        return new MailAccountRegistry(accounts, connections);
    }

    /// <summary>
    /// Account con OAuth2: un solo token di accesso per IMAP, SMTP e POP3 dell'account, rinnovato quando serve.
    /// Fornitore sconosciuto o senza client ID -> ArgumentException (il core non parte, come per gli altri dati sbagliati).
    /// </summary>
    private static void AttachOAuth(MailAccountSettings s, IReadOnlyDictionary<string, OAuth.OAuthProvider>? providers,
        Action<string, string>? changed, Action<string, bool>? needsLoginChanged)
    {
        if (providers is null || !providers.TryGetValue(s.OAuth.Provider, out var provider))
            throw new ArgumentException($"Account '{s.Id}': fornitore OAuth '{s.OAuth.Provider}' sconosciuto.");
        if (!provider.IsConfigured)
            throw new ArgumentException($"Account '{s.Id}': manca il client ID di {provider.DisplayName} (sezione OAuth:{provider.Id}).");
        var id = s.Id;
        var source = new OAuth.OAuthTokenSource(provider, s.OAuth.RefreshToken, rotated => changed?.Invoke(id, rotated),
            needsLoginChanged: value => needsLoginChanged?.Invoke(id, value));
        s.OAuth.Tokens = source;
        s.Imap.AccessToken = s.Smtp.AccessToken = s.Pop3.AccessToken = source.GetAccessTokenAsync;
    }

    /// <summary>
    /// Account POP3 (4.2): mail nella casella locale <c>{cache}/accounts/{id}/mail/</c> (i file sono la fonte
    /// della verità), indice nello stesso database della copia IMAP, controllo periodico del server POP3,
    /// invio con SMTP come per IMAP. I corpi non si copiano nella cache dei corpi: si leggono dai file.
    /// </summary>
    private static MailAccount CreatePop3(MailAccountSettings s, string cacheRoot, Action<string>? log, Action<string, bool>? onlineChanged,
        Action<string, int>? downloaded, Action<string, Dav.DavResult>? contactsSynced, Action<string, Dav.DavResult>? calendarsSynced)
    {
        var id = s.Id;
        var directory = CacheDirectory(cacheRoot, id);
        var cache = new AccountCache(directory);
        var store = new Local.LocalMailStore(Path.Combine(directory, "mail"));
        var reader = new Local.LocalMailReader(id, store, cache, log);
        var state = new Pop3.Pop3State(Path.Combine(directory, "pop3.json"));
        // "Rimuovi dal server quando eliminata da Posta eliminata": la mail si toglie alla prossima connessione.
        Action<IReadOnlyList<string>>? removed = s.Pop3.LeaveOnServer && s.Pop3.RemoveWhenDeleted
            ? uidls =>
            {
                foreach (var u in uidls)
                    state.RequestRemoval(u);
            }
            : null;
        var writer = new Local.LocalMailWriter(store, cache, reader, removed);
        var bodies = new BodyCache(id, cache, BodyPolicy.None, log);
        var worker = new Pop3.Pop3Worker(id, new Pop3.Pop3Fetcher(s.Pop3, store, state,
            (done, total) => log?.Invoke($"[{id}] POP3: {done}/{total} mail scaricate")), s.Pop3, log,
            online =>
            {
                log?.Invoke(online ? $"[{id}] server POP3 di nuovo raggiungibile" : $"[{id}] server POP3 non raggiungibile");
                onlineChanged?.Invoke(id, online);
            },
            count => downloaded?.Invoke(id, count));
        var outbox = new Outbox.OutboxStore(Path.Combine(directory, "outbox"));
        var contacts = ContactsOf(cacheRoot, id);
        var calendars = CalendarsOf(cacheRoot, id);
        return new MailAccount(s, reader, writer, new DeferredMailSender(() => new SmtpMailService(s.Smtp)), bodies,
            connection: null, outbox, worker, new Rules.RuleStore(directory), new AutoReply.AutoReplyStore(directory),
            contacts, RecentOf(cacheRoot, id, cache), CardDavOf(s, cacheRoot, contacts, log, contactsSynced),
            calendars, CalDavOf(s, calendars, log, calendarsSynced), new Junk.JunkStore(directory), new Archive.ArchiveStore(directory),
            new Conversations.IgnoreStore(directory));
    }

    /// <summary>
    /// Sincronizzazione CardDAV (C4b), solo se attiva per l'account (2a). Server: quello indicato o la scoperta dal
    /// server di ricezione; credenziali di ricezione; certificato accettato dall'utente valido solo per lo stesso server.
    /// Con OAuth2 (C4d) solo per Google, con il token dell'account e il permesso dei contatti.
    /// </summary>
    private static Dav.DavWorker? CardDavOf(MailAccountSettings s, string cacheRoot, Contacts.ContactStore contacts,
        Action<string>? log, Action<string, Dav.DavResult>? synced)
    {
        if (!s.CardDav.Enabled)
            return null;
        var id = s.Id;
        var (start, unavailable, client) = DavAccess(s, Dav.DavKind.CardDav, s.CardDav, "dei contatti");
        var stateStore = new Dav.DavStateStore(Path.Combine(CacheDirectory(cacheRoot, id), "carddav.json"));
        Func<Dav.IDavSyncJob>? create = unavailable is not null ? null : () => new Contacts.CardDav.CardDavSync(
            client(), contacts, stateStore, start, start.AbsoluteUri, log is null ? null : m => log($"[{id}] {m}"));
        return new Dav.DavWorker(id, contacts, create, unavailable, log, r => synced?.Invoke(id, r));
    }

    /// <summary>
    /// Sincronizzazione CalDAV dei calendari (K2a), solo se attiva per l'account (2a): come la rubrica, con lo stesso
    /// server, le stesse credenziali e lo stesso certificato accettato.
    /// </summary>
    private static Dav.DavWorker? CalDavOf(MailAccountSettings s, Calendars.CalendarSet calendars, Action<string>? log,
        Action<string, Dav.DavResult>? synced)
    {
        if (!s.CalDav.Enabled)
            return null;
        var id = s.Id;
        var (start, unavailable, client) = DavAccess(s, Dav.DavKind.CalDav, s.CalDav, "del calendario");
        Func<Dav.IDavSyncJob>? create = unavailable is not null ? null : () => new Calendars.CalDavSyncJob(
            client(), calendars, start, log is null ? null : m => log($"[{id}] {m}"));
        return new Dav.DavWorker(id, wake => calendars.LocalChanged += wake, create, unavailable, log, r => synced?.Invoke(id, r), "CalDAV");
    }

    /// <summary>
    /// Indirizzo di partenza, motivo per cui non si può (password mancante; OAuth2: CalDAV e Microsoft non ancora) e
    /// fabbrica del client DAV: con la password, le credenziali di ricezione e il certificato accettato dall'utente (valido
    /// solo per lo stesso server); con OAuth2 (C4d, Google) il token di accesso dell'account.
    /// </summary>
    private static (Uri Start, string? Unavailable, Func<Dav.DavClient> Client) DavAccess(MailAccountSettings s, Dav.DavKind kind,
        AccountDavSettings dav, string what)
    {
        var (host, user, password, pin) = s.IsPop3
            ? (s.Pop3.Host, s.Pop3.Username, s.Pop3.Password, s.Pop3.CertificateSha256)
            : (s.Imap.Host, s.Imap.Username, s.Imap.Password, s.Imap.CertificateSha256);
        if (s.OAuth.IsSet && s.OAuth.Tokens is { } tokens)
        {
            var provider = tokens.Provider;
            if (OAuthStart(provider, kind, user) is not { } providerStart)
                return (Dav.DavClient.StartUrl(dav.Url, host, kind),
                    $"La sincronizzazione {what} non è ancora disponibile per gli account con accesso {provider.DisplayName}.", null!);
            var oauthStart = string.IsNullOrWhiteSpace(dav.Url) ? providerStart : Dav.DavClient.StartUrl(dav.Url, host, kind);
            return (oauthStart, null, () => BearerClient(user, tokens, oauthStart, kind: kind));
        }
        var unavailable = s.OAuth.IsSet
            ? $"La sincronizzazione {what} non è ancora disponibile per questo account."
            : string.IsNullOrEmpty(password) ? "Manca la password dell'account." : null;
        var start = Dav.DavClient.StartUrl(dav.Url, host, kind);
        return (start, unavailable, () => new Dav.DavClient(new System.Net.NetworkCredential(user, password),
            new Security.TrustedCertificate(start.Host, start.Port, start.Host.Equals(host, StringComparison.OrdinalIgnoreCase) ? pin : null),
            kind: kind));
    }

    /// <summary>Indirizzo da cui parte la scoperta con OAuth2 (C4d contatti, G1 calendario); null = non disponibile.</summary>
    public static Uri? OAuthStart(OAuth.OAuthProvider provider, Dav.DavKind kind, string user) =>
        kind == Dav.DavKind.CardDav
            ? provider.SupportsCardDav ? new Uri(provider.CardDavUrl!) : null
            : provider.SupportsCalDav ? new Uri(provider.CalDavUrlFor(user)!) : null;

    /// <summary>
    /// Client CardDAV o CalDAV con il token OAuth2 (C4d, G1). Se il fornitore dice che l'accesso non comprende i contatti (o
    /// il calendario), si ferma prima di mandare il token al server: serve «Accedi di nuovo» con quel permesso.
    /// </summary>
    public static Dav.DavClient BearerClient(string user, OAuth.OAuthTokenSource tokens, Uri start, HttpMessageHandler? handler = null,
        Dav.DavKind? kind = null)
    {
        var provider = tokens.Provider;
        var calendar = kind == Dav.DavKind.CalDav;
        return new Dav.DavClient(user, async ct =>
        {
            var token = await tokens.GetAccessTokenAsync(ct);
            if ((calendar ? provider.GrantsCalendar(tokens.GrantedScopes) : provider.GrantsContacts(tokens.GrantedScopes)) == false)
            {
                var what = calendar ? "il calendario" : "i contatti";
                var access = calendar ? "al calendario" : "ai contatti";
                throw new Dav.DavException($"L'accesso con {provider.DisplayName} non comprende {what}: nella schermata dell'account " +
                    $"usa «Accedi di nuovo» e permetti l'accesso {access}.", 403);
            }
            return token;
        }, start.Host, provider.DisplayName, tokens.Invalidate, handler, kind ?? Dav.DavKind.CardDav);
    }

    /// <summary>
    /// Calendari dell'account: <c>{cache}/accounts/{id}/calendars/</c> (fuori da database e corpi: restano con
    /// «Ricostruisci cache»). Uno per account, condiviso tra le richieste dell'app e il lavoratore CalDAV.
    /// </summary>
    private static Calendars.CalendarSet CalendarsOf(string cacheRoot, string id) =>
        new(Path.Combine(CacheDirectory(cacheRoot, id), "calendars"));

    /// <summary>Rubrica dell'account: <c>{cache}/accounts/{id}/contacts/</c> (fuori da database e corpi: resta con «Ricostruisci cache»).</summary>
    private static Contacts.ContactStore ContactsOf(string cacheRoot, string id) =>
        new(Path.Combine(CacheDirectory(cacheRoot, id), "contacts"));

    private static Contacts.RecentAddresses RecentOf(string cacheRoot, string id, AccountCache? cache) =>
        new(Path.Combine(CacheDirectory(cacheRoot, id), "recent-addresses.json"), cache);

    /// <summary>Cartella della cache di un account (l'id è già validato: niente "/" o "..").</summary>
    public static string CacheDirectory(string cacheRoot, string accountId) => Path.Combine(cacheRoot, "accounts", accountId);

    /// <summary>
    /// Almeno un account; id non vuoti, senza caratteri speciali (finiscono negli URL) e unici;
    /// limite della cache non negativo.
    /// </summary>
    /// <summary>Id accettabile (anche come nome di cartella): lettere, cifre, '-' e '_', massimo 64.</summary>
    public static bool IsValidId(string id) => IdPattern().IsMatch(id);

    public static void Validate(IReadOnlyList<MailAccountSettings> settings)
    {
        if (settings.Count == 0)
            throw new ArgumentException("Nessun account configurato.");
        foreach (var s in settings)
        {
            if (!IdPattern().IsMatch(s.Id))
                throw new ArgumentException($"Id account non valido: '{s.Id}' (ammessi lettere, cifre, '-' e '_', massimo 64).");
        }
        foreach (var s in settings)
        {
            if (s.Cache.BodyMonths is < 0)
                throw new ArgumentException($"Account '{s.Id}': limite della cache non valido ({s.Cache.BodyMonths} mesi; 0 = tutte).");
            foreach (var (dav, kind, name) in new[] { (s.CardDav, Dav.DavKind.CardDav, "CardDAV"), (s.CalDav, Dav.DavKind.CalDav, "CalDAV") })
            {
                if (!dav.Enabled || string.IsNullOrWhiteSpace(dav.Url))
                    continue;
                if (!Uri.TryCreate(dav.Url.Trim(), UriKind.Absolute, out var url))
                    throw new ArgumentException($"Account '{s.Id}': indirizzo {name} non valido.");
                try
                {
                    Dav.DavClient.EnsureAllowed(url, kind);
                }
                catch (Dav.DavException ex)
                {
                    throw new ArgumentException($"Account '{s.Id}': {ex.Message}");
                }
            }
        }
        var duplicate = settings.GroupBy(s => s.Id).FirstOrDefault(g => g.Count() > 1);
        if (duplicate is not null)
            throw new ArgumentException($"Id account ripetuto: '{duplicate.Key}'.");
    }

    public async ValueTask DisposeAsync()
    {
        foreach (var o in _owned)
            await o.DisposeAsync();
    }

    [GeneratedRegex("^[A-Za-z0-9_-]{1,64}$")]
    private static partial Regex IdPattern();

    /// <summary>
    /// Crea il servizio SMTP solo al primo invio: SmtpMailService controlla i dati nel costruttore e
    /// un account non ancora configurato non deve impedire la creazione degli altri.
    /// </summary>
    private sealed class DeferredMailSender(Func<IMailSender> create) : IMailSender
    {
        // PublicationOnly: un errore di configurazione non resta memorizzato.
        private readonly Lazy<IMailSender> _sender = new(create, LazyThreadSafetyMode.PublicationOnly);

        public Task<SendResult> SendAsync(OutgoingMessage msg, CancellationToken ct = default) => _sender.Value.SendAsync(msg, ct);

        public Task<string> SendMimeAsync(MimeKit.MimeMessage message, CancellationToken ct = default) =>
            _sender.Value.SendMimeAsync(message, ct);
    }
}
