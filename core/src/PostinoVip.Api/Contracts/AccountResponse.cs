using System.ComponentModel.DataAnnotations;
using PostinoVip.Core.Account;
using PostinoVip.Core.Security;

namespace PostinoVip.Api.Contracts;

/// <summary>
/// Indirizzo dell'account configurato (mittente delle mail inviate) e se il core ha tutti i dati
/// per collegarsi. Mai la password.
/// </summary>
public sealed record AccountResponse(string Address, bool Configured);

/// <summary>
/// Una voce di GET /accounts. Name: nome scelto dall'utente, altrimenti l'indirizzo.
/// Online: false se il server non è raggiungibile (l'app mostra la copia locale).
/// Type: IMAP o POP3 (4.2): per POP3 l'app non offre "Cerca anche sul server" né "Ricostruisci cache".
/// NeedsLogin (OAuth2, 2a): il fornitore ha rifiutato il token di rinnovo, serve «Accedi di nuovo».
/// CardDav (C4c): la rubrica si sincronizza con un server CardDAV (Invia/ricevi la sincronizza anche).
/// CalDav (K2a): i calendari si sincronizzano con un server CalDAV.
/// </summary>
public sealed record AccountInfo(string Id, string Name, string Address, bool Configured, bool Online = true,
    MailAccountType Type = MailAccountType.Imap, bool NeedsLogin = false, bool CardDav = false, bool CalDav = false);

/// <summary>Corpo di POST /account/test: dati da provare prima di salvarli.</summary>
public sealed class AccountTestRequest
{
    [Required(AllowEmptyStrings = false)] public string Email { get; set; } = "";
    /// <summary>Obbligatoria senza OAuth2 (controllo nel controller).</summary>
    public string Password { get; set; } = "";

    /// <summary>Accesso con OAuth2 (O1): fornitore e token di rinnovo ottenuti con /oauth/start, al posto della password.</summary>
    public string? OAuthProvider { get; set; }
    public string? RefreshToken { get; set; }
    [Required(AllowEmptyStrings = false)] public string ImapHost { get; set; } = "";
    [Range(1, 65535)] public int ImapPort { get; set; } = 993;
    [Required(AllowEmptyStrings = false)] public string SmtpHost { get; set; } = "";
    [Range(1, 65535)] public int SmtpPort { get; set; } = 587;

    /// <summary>
    /// Tipo di account (4.2): con Pop3 i campi imap* descrivono il server di ricezione POP3 (stessa riga
    /// "posta in arrivo" della schermata dell'account).
    /// </summary>
    public MailAccountType Type { get; set; } = MailAccountType.Imap;

    /// <summary>Crittografia (4.1); assente = secondo la porta.</summary>
    public ConnectionSecurity? ImapSecurity { get; set; }
    public ConnectionSecurity? SmtpSecurity { get; set; }

    /// <summary>"Il server di invio richiede l'autenticazione" (assente = sì).</summary>
    public bool SmtpRequireAuth { get; set; } = true;

    /// <summary>Certificati non validi di cui l'utente ha scelto di fidarsi (impronta SHA-256).</summary>
    public string? ImapCertificateSha256 { get; set; }
    public string? SmtpCertificateSha256 { get; set; }
}

public sealed record AccountTestResponse(ConnectionCheck Imap, ConnectionCheck Smtp);

/// <summary>
/// Corpo di POST /account/test-carddav (C4c, «Verifica rubrica»): credenziali e server di ricezione dell'account,
/// indirizzo CardDAV facoltativo (vuoto = scoperta dal server di ricezione), certificato accettato per quel server.
/// </summary>
public sealed class CardDavTestRequest
{
    [Required(AllowEmptyStrings = false)] public string Email { get; set; } = "";
    public string Password { get; set; } = "";
    [Required(AllowEmptyStrings = false)] public string Host { get; set; } = "";
    public string? Url { get; set; }
    public string? CertificateSha256 { get; set; }

    /// <summary>Account con OAuth2 (C4d, Google): fornitore e token di rinnovo al posto della password.</summary>
    public string? OAuthProvider { get; set; }
    public string? RefreshToken { get; set; }
}

/// <summary>Esito della prova: rubrica trovata (nome e indirizzo) oppure il motivo, leggibile.</summary>
public sealed record CardDavTestResponse(bool Ok, string? Error, string? AddressBook = null, string? Url = null);

/// <summary>Esito di «Verifica calendario»: i calendari del server che accettano appuntamenti, oppure il motivo.</summary>
public sealed record CalDavTestResponse(bool Ok, string? Error, IReadOnlyList<string>? Calendars = null);
