using System.Text.Json.Serialization;
using MailKit.Security;

namespace PostinoVip.Core.Security;

/// <summary>
/// Crittografia della connessione con il server (4.1), come il menu "Crittografia" di Outlook.
/// SslOnConnect: TLS dall'inizio (993, 465). StartTls: collegamento in chiaro e passaggio obbligatorio a TLS
/// prima del login (143, 587, 25); se il server non offre STARTTLS la connessione fallisce, non prosegue in
/// chiaro. None: **nessuna cifratura**, password e mail viaggiano in chiaro (scelta esplicita dell'utente).
/// In JSON e nelle variabili d'ambiente con il nome: "SslOnConnect", "StartTls", "None".
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter<ConnectionSecurity>))]
public enum ConnectionSecurity
{
    SslOnConnect,
    StartTls,
    None,
}

public static class ConnectionSecurityExtensions
{
    public static SecureSocketOptions ToMailKit(this ConnectionSecurity security) => security switch
    {
        ConnectionSecurity.SslOnConnect => SecureSocketOptions.SslOnConnect,
        ConnectionSecurity.StartTls => SecureSocketOptions.StartTls, // mai StartTlsWhenAvailable
        ConnectionSecurity.None => SecureSocketOptions.None,
        _ => throw new ArgumentOutOfRangeException(nameof(security)),
    };

    /// <summary>Crittografia proposta per una porta di ricezione IMAP: 143 STARTTLS, il resto TLS.</summary>
    public static ConnectionSecurity DefaultForImap(int port) => port == 143 ? ConnectionSecurity.StartTls : ConnectionSecurity.SslOnConnect;

    /// <summary>Crittografia proposta per una porta di invio SMTP: 465 TLS, il resto STARTTLS.</summary>
    public static ConnectionSecurity DefaultForSmtp(int port) => port == 465 ? ConnectionSecurity.SslOnConnect : ConnectionSecurity.StartTls;
}
