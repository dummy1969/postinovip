using PostinoVip.Core.Imap;
using PostinoVip.Core.Pop3;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Account;

/// <summary>Cache locale di un account (sezione Accounts:N:Cache).</summary>
public sealed class AccountCacheSettings
{
    /// <summary>Corpi conservati: mail arrivate negli ultimi N mesi; 0 = tutte; assente = 12.</summary>
    public int? BodyMonths { get; set; }
}

/// <summary>
/// Accesso con OAuth2 (Accounts:N:OAuth): fornitore ("microsoft") e token di rinnovo, che l'app tiene nel portachiavi
/// e passa all'avvio come la password. Con questo l'account non usa la password.
/// </summary>
public sealed class AccountOAuthSettings
{
    public string Provider { get; set; } = "";
    public string RefreshToken { get; set; } = "";

    public bool IsSet => !string.IsNullOrWhiteSpace(Provider) && !string.IsNullOrWhiteSpace(RefreshToken);

    /// <summary>Fonte dei token dell'account, impostata dal registro (non viene dalla configurazione).</summary>
    [System.Text.Json.Serialization.JsonIgnore]
    public OAuth.OAuthTokenSource? Tokens { get; set; }
}

/// <summary>
/// Sincronizzazione con un server DAV: rubrica con CardDAV (C4, scelta 2a) o calendari con CalDAV (K2a, scelta 2a);
/// spenta di serie, si accende per account. <see cref="Url"/> vuoto = scoperta da
/// <c>https://&lt;server di ricezione&gt;/.well-known/carddav</c> (o caldav); altrimenti l'indirizzo del server o
/// direttamente quello della raccolta. Credenziali dell'account (utente e password di ricezione).
/// </summary>
public sealed class AccountDavSettings
{
    public bool Enabled { get; set; }
    public string? Url { get; set; }
}

/// <summary>Tipo di account (4.2): IMAP (mail sul server) o POP3 (mail scaricate sul computer). Non cambia dopo la creazione.</summary>
[System.Text.Json.Serialization.JsonConverter(typeof(System.Text.Json.Serialization.JsonStringEnumConverter<MailAccountType>))]
public enum MailAccountType { Imap, Pop3 }

/// <summary>
/// Una casella configurata: identificativo stabile (scelto dall'app, usato nei percorsi
/// /accounts/{id}/...), nome mostrato e parametri IMAP/SMTP.
/// </summary>
public sealed class MailAccountSettings
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public MailAccountType Type { get; set; } = MailAccountType.Imap;
    public ImapSettings Imap { get; set; } = new();

    /// <summary>Server di ricezione degli account POP3 (Type = Pop3); Imap non si usa.</summary>
    public Pop3Settings Pop3 { get; set; } = new();
    public SmtpSettings Smtp { get; set; } = new();
    public AccountCacheSettings Cache { get; set; } = new();
    public AccountOAuthSettings OAuth { get; set; } = new();
    public AccountDavSettings CardDav { get; set; } = new();
    public AccountDavSettings CalDav { get; set; } = new();

    /// <summary>Indirizzo del mittente (username SMTP, ereditato da IMAP se non indicato).</summary>
    public string Address => Smtp.Username;

    public string DisplayName => string.IsNullOrWhiteSpace(Name) ? Address : Name;

    /// <summary>Tutti i dati necessari per collegarsi (la password non viene mai esposta).</summary>
    public bool IsConfigured =>
        (Type == MailAccountType.Pop3
            ? !string.IsNullOrWhiteSpace(Pop3.Host) && !string.IsNullOrWhiteSpace(Pop3.Username) && (OAuth.IsSet || !string.IsNullOrEmpty(Pop3.Password))
            : !string.IsNullOrWhiteSpace(Imap.Host) && !string.IsNullOrWhiteSpace(Imap.Username) && (OAuth.IsSet || !string.IsNullOrEmpty(Imap.Password)))
        && !string.IsNullOrWhiteSpace(Smtp.Host);

    public bool IsPop3 => Type == MailAccountType.Pop3;
}
