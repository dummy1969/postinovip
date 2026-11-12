using PostinoVip.Core.Imap;
using PostinoVip.Core.Security;

namespace PostinoVip.Core.Smtp;

/// <summary>Parametri di connessione SMTP.</summary>
public sealed class SmtpSettings
{
    public string Host { get; set; } = "";
    public int Port { get; set; } = 587;
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";

    /// <summary>Crittografia (4.1); assente = secondo la porta (465 TLS, altrimenti STARTTLS).</summary>
    public ConnectionSecurity? Security { get; set; }

    /// <summary>
    /// "Il server di invio richiede l'autenticazione" (4.1, 3a). False: nessun login (es. relay sulla 25 della
    /// rete aziendale); Username resta l'indirizzo del mittente.
    /// </summary>
    public bool RequireAuth { get; set; } = true;

    /// <summary>Impronta SHA-256 di un certificato non valido di cui l'utente ha scelto di fidarsi (4.1, 6a).</summary>
    public string? CertificateSha256 { get; set; }

    /// <summary>
    /// Account con OAuth2: token di accesso al posto della password (impostato dal registro, non dalla configurazione).
    /// </summary>
    [System.Text.Json.Serialization.JsonIgnore]
    public Func<CancellationToken, Task<string>>? AccessToken { get; set; }

    public ConnectionSecurity EffectiveSecurity => Security ?? ConnectionSecurityExtensions.DefaultForSmtp(Port);

    /// <summary>Usa le credenziali della casella se per l'SMTP non ne sono configurate di proprie.</summary>
    public void InheritCredentialsFrom(ImapSettings imap) => InheritCredentialsFrom(imap.Username, imap.Password);

    public void InheritCredentialsFrom(string username, string password)
    {
        if (string.IsNullOrWhiteSpace(Username)) Username = username;
        if (string.IsNullOrEmpty(Password)) Password = password;
    }
}
