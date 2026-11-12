using PostinoVip.Core.Security;

namespace PostinoVip.Core.OAuth;

/// <summary>
/// Configurazione di un fornitore (sezione OAuth:{Id}, da un file escluso da git: il client ID identifica chi
/// distribuisce PostinoVip). Gli indirizzi si possono cambiare (test con un fornitore finto).
/// </summary>
public sealed class OAuthProviderSettings
{
    public string ClientId { get; set; } = "";

    /// <summary>Solo Google (client "desktop": non è un vero segreto, ma lo chiede).</summary>
    public string? ClientSecret { get; set; }

    public string? AuthorizationEndpoint { get; set; }
    public string? TokenEndpoint { get; set; }

    /// <summary>
    /// Solo Google (C4d): permessi per i contatti con CardDAV, separati da spazi, al posto di quello predefinito
    /// (la documentazione CardDAV di Google non lo nomina: si può cambiare senza ricompilare).
    /// </summary>
    public string? ContactsScope { get; set; }

    /// <summary>Solo per i test: indirizzo da cui parte la scoperta CardDAV al posto di quello del fornitore.</summary>
    public string? CardDavUrl { get; set; }

    /// <summary>Solo Google (G1): permessi per il calendario con CalDAV, separati da spazi, al posto di quello predefinito.</summary>
    public string? CalendarScope { get; set; }

    /// <summary>Solo per i test: indirizzo da cui parte la scoperta CalDAV ({email} = indirizzo dell'account).</summary>
    public string? CalDavUrl { get; set; }
}

/// <summary>Server di posta di un fornitore, per compilare da soli l'account dopo l'accesso.</summary>
public sealed record OAuthServers(string ImapHost, int ImapPort, ConnectionSecurity ImapSecurity, string SmtpHost, int SmtpPort,
    ConnectionSecurity SmtpSecurity, string Pop3Host, int Pop3Port);

/// <summary>
/// Un fornitore OAuth2 per la posta (IMAP/POP/SMTP con XOAUTH2). <paramref name="RefreshWithScope"/>: gli scope vanno
/// ripetuti nella richiesta di rinnovo (Microsoft sì; Google non li elenca tra i parametri del rinnovo).
/// </summary>
public sealed record OAuthProvider(
    string Id,
    string DisplayName,
    string AuthorizationEndpoint,
    string TokenEndpoint,
    IReadOnlyList<string> Scopes,
    string ClientId,
    string? ClientSecret,
    OAuthServers Servers,
    bool RefreshWithScope = true,
    IReadOnlyList<string>? ContactsScopes = null,
    string? CardDavUrl = null,
    IReadOnlyList<string>? CalendarScopes = null,
    string? CalDavUrl = null)
{
    public bool IsConfigured => !string.IsNullOrWhiteSpace(ClientId);

    /// <summary>
    /// Permessi in più chiesti solo per un account con la sincronizzazione dei contatti (C4d, scelta 1a); vuoto =
    /// CardDAV non disponibile con questo fornitore.
    /// </summary>
    public IReadOnlyList<string> ContactsScopesOrEmpty => ContactsScopes ?? [];

    public bool SupportsCardDav => CardDavUrl is not null && ContactsScopesOrEmpty.Count > 0;

    /// <summary>Permessi in più per il calendario (G1, come i contatti: solo per un account con il calendario sincronizzato).</summary>
    public IReadOnlyList<string> CalendarScopesOrEmpty => CalendarScopes ?? [];

    public bool SupportsCalDav => CalDavUrl is not null && CalendarScopesOrEmpty.Count > 0;

    /// <summary>Indirizzo da cui parte la scoperta CalDAV per l'account (Google: il principal dell'indirizzo).</summary>
    public string? CalDavUrlFor(string email) => CalDavUrl?.Replace("{email}", email.Trim(), StringComparison.Ordinal);

    /// <summary>Gli scope dell'accesso: quelli della posta, più quelli dei contatti e del calendario se chiesti.</summary>
    public IReadOnlyList<string> ScopesFor(bool contacts, bool calendar = false) =>
        [.. Scopes, .. contacts ? ContactsScopesOrEmpty : [], .. calendar ? CalendarScopesOrEmpty : []];

    /// <summary>
    /// I permessi concessi (dal campo "scope" della risposta del fornitore) comprendono i contatti? null = non si sa
    /// ancora (nessun token chiesto).
    /// </summary>
    public bool? GrantsContacts(string? granted) => Grants(ContactsScopesOrEmpty, granted);

    public bool? GrantsCalendar(string? granted) => Grants(CalendarScopesOrEmpty, granted);

    private static bool? Grants(IReadOnlyList<string> needed, string? granted) => granted is null ? null
        : needed.Count > 0 && needed.All(s => granted.Split(' ', StringSplitOptions.RemoveEmptyEntries).Contains(s));
}

/// <summary>I fornitori conosciuti (1a: prima Microsoft, poi Google).</summary>
public static class OAuthProviders
{
    public const string Microsoft = "microsoft";
    public const string Google = "google";

    /// <summary>
    /// Microsoft 365 e Outlook.com (tenant "common": account aziendali e personali). Scope da Microsoft Learn
    /// (IMAP/POP/SMTP con OAuth); offline_access per il token di rinnovo; openid/email/profile per l'indirizzo.
    /// </summary>
    public static OAuthProvider MicrosoftFrom(OAuthProviderSettings? s) => new(
        Microsoft,
        "Microsoft",
        s?.AuthorizationEndpoint ?? "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
        s?.TokenEndpoint ?? "https://login.microsoftonline.com/common/oauth2/v2.0/token",
        ["offline_access", "openid", "email", "profile",
         "https://outlook.office.com/IMAP.AccessAsUser.All", "https://outlook.office.com/POP.AccessAsUser.All",
         "https://outlook.office.com/SMTP.Send"],
        s?.ClientId ?? "",
        s?.ClientSecret,
        new OAuthServers("outlook.office365.com", 993, ConnectionSecurity.SslOnConnect, "smtp.office365.com", 587,
            ConnectionSecurity.StartTls, "outlook.office365.com", 995));

    /// <summary>
    /// Permesso CardDAV di Google (C4d): **non verificato** sulla documentazione di Google (la pagina CardDAV dice solo
    /// che serve OAuth2); da verificare con la prova vera. Si cambia con OAuth:Google:ContactsScope.
    /// </summary>
    public const string GoogleCardDavScope = "https://www.googleapis.com/auth/carddav";

    /// <summary>Scoperta CardDAV di Google (developers.google.com/people/carddav, letto il 06/11/2026).</summary>
    public const string GoogleCardDavUrl = "https://www.googleapis.com/.well-known/carddav";

    /// <summary>
    /// Permesso del calendario di Google (G1, scelta 1a): la guida CalDAV non dice quale serve; da verificare con la prova
    /// vera. Si cambia con OAuth:Google:CalendarScope.
    /// </summary>
    public const string GoogleCalendarScope = "https://www.googleapis.com/auth/calendar";

    /// <summary>
    /// Principal CalDAV di Google (developers.google.com/calendar/caldav/v2/guide, letta il 09/11/2026: nessun
    /// .well-known; l'id del calendario principale è l'indirizzo dell'utente).
    /// </summary>
    public const string GoogleCalDavUrl = "https://apidata.googleusercontent.com/caldav/v2/{email}/user";

    /// <summary>
    /// Gmail (verificato il 05/11/2026): scope https://mail.google.com/ per IMAP, POP e SMTP con XOAUTH2 (pagina
    /// "OAuth 2.0 Mechanism" di Google), openid/email per l'indirizzo; app desktop con PKCE e client_secret (che per
    /// Google "non è trattato come segreto"); il token di rinnovo arriva sempre per le app installate.
    /// Server: pop.gmail.com 995 SSL e smtp.gmail.com 587 STARTTLS dalla guida di Gmail (answer 7104828);
    /// imap.gmail.com 993 TLS verificato collegandosi (saluto "Gimap ready", AUTH=XOAUTH2).
    /// </summary>
    public static OAuthProvider GoogleFrom(OAuthProviderSettings? s) => new(
        Google,
        "Google",
        s?.AuthorizationEndpoint ?? "https://accounts.google.com/o/oauth2/v2/auth",
        s?.TokenEndpoint ?? "https://oauth2.googleapis.com/token",
        ["openid", "email", "https://mail.google.com/"],
        s?.ClientId ?? "",
        s?.ClientSecret,
        new OAuthServers("imap.gmail.com", 993, ConnectionSecurity.SslOnConnect, "smtp.gmail.com", 587,
            ConnectionSecurity.StartTls, "pop.gmail.com", 995),
        RefreshWithScope: false,
        ContactsScopes: string.IsNullOrWhiteSpace(s?.ContactsScope)
            ? [GoogleCardDavScope]
            : s.ContactsScope.Split(' ', StringSplitOptions.RemoveEmptyEntries),
        CardDavUrl: s?.CardDavUrl ?? GoogleCardDavUrl,
        CalendarScopes: string.IsNullOrWhiteSpace(s?.CalendarScope)
            ? [GoogleCalendarScope]
            : s.CalendarScope.Split(' ', StringSplitOptions.RemoveEmptyEntries),
        CalDavUrl: s?.CalDavUrl ?? GoogleCalDavUrl);

    /// <summary>Dalla configurazione (sezione OAuth:Microsoft…); id -> fornitore.</summary>
    public static IReadOnlyDictionary<string, OAuthProvider> From(IReadOnlyDictionary<string, OAuthProviderSettings> settings) =>
        new Dictionary<string, OAuthProvider>(StringComparer.OrdinalIgnoreCase)
        {
            [Microsoft] = MicrosoftFrom(settings.GetValueOrDefault(Microsoft) ?? settings.GetValueOrDefault("Microsoft")),
            [Google] = GoogleFrom(settings.GetValueOrDefault(Google) ?? settings.GetValueOrDefault("Google")),
        };
}
