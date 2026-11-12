using PostinoVip.Core.Security;

namespace PostinoVip.Core.Imap;

/// <summary>Parametri di connessione IMAP. Username e Password arrivano da user-secrets o variabili d'ambiente.</summary>
public sealed class ImapSettings
{
    public string Host { get; set; } = "";
    public int Port { get; set; } = 993;
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";

    /// <summary>Crittografia (4.1); assente = secondo la porta (143 STARTTLS, altrimenti TLS).</summary>
    public ConnectionSecurity? Security { get; set; }

    /// <summary>Impronta SHA-256 di un certificato non valido di cui l'utente ha scelto di fidarsi (4.1, 6a).</summary>
    public string? CertificateSha256 { get; set; }

    /// <summary>
    /// Account con OAuth2: token di accesso al posto della password (impostato dal registro, non dalla configurazione).
    /// </summary>
    [System.Text.Json.Serialization.JsonIgnore]
    public Func<CancellationToken, Task<string>>? AccessToken { get; set; }

    public ConnectionSecurity EffectiveSecurity => Security ?? ConnectionSecurityExtensions.DefaultForImap(Port);
}
