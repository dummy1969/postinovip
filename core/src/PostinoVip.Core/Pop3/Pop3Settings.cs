using PostinoVip.Core.Security;

namespace PostinoVip.Core.Pop3;

/// <summary>
/// Server POP3 di un account (4.2) e regole di Outlook per le mail scaricate (scelta 2a):
/// "Lascia una copia sul server" (attiva di default), "Rimuovi dal server dopo N giorni" (attiva, 14 giorni,
/// modificabile; 0 = mai) e "Rimuovi dal server quando eliminata da Posta eliminata" (spenta di default).
/// </summary>
public sealed class Pop3Settings
{
    public string Host { get; set; } = "";
    public int Port { get; set; } = 995;
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";

    /// <summary>Crittografia; assente = secondo la porta (110 STARTTLS, altrimenti SSL/TLS).</summary>
    public ConnectionSecurity? Security { get; set; }

    /// <summary>Impronta SHA-256 di un certificato non valido di cui l'utente ha scelto di fidarsi.</summary>
    public string? CertificateSha256 { get; set; }

    /// <summary>false: ogni mail viene tolta dal server subito dopo averla scaricata.</summary>
    public bool LeaveOnServer { get; set; } = true;

    /// <summary>Con <see cref="LeaveOnServer"/>: rimuovi dal server N giorni dopo averla scaricata; 0 = mai.</summary>
    public int RemoveAfterDays { get; set; } = 14;

    /// <summary>Con <see cref="LeaveOnServer"/>: rimuovi dal server quando la mail viene eliminata da Posta eliminata.</summary>
    public bool RemoveWhenDeleted { get; set; }

    /// <summary>Ogni quanti minuti controllare la posta nuova (scelta 3a: 10, per account 5/10/15/30/60).</summary>
    public int CheckMinutes { get; set; } = 10;

    /// <summary>
    /// Account con OAuth2: token di accesso al posto della password (impostato dal registro, non dalla configurazione).
    /// </summary>
    [System.Text.Json.Serialization.JsonIgnore]
    public Func<CancellationToken, Task<string>>? AccessToken { get; set; }

    public ConnectionSecurity EffectiveSecurity =>
        Security ?? (Port == 110 ? ConnectionSecurity.StartTls : ConnectionSecurity.SslOnConnect);
}
