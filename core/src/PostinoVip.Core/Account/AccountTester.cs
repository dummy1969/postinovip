using System.Net.Sockets;
using MailKit;
using MailKit.Security;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Security;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Account;

/// <summary>
/// Esito della prova di una connessione: Error null se tutto è andato bene. Certificate: il certificato non
/// valido che ha fatto rifiutare la connessione, da mostrare all'utente ("Fidarsi di questo certificato?").
/// </summary>
public sealed record ConnectionCheck(bool Ok, string? Error, CertificateInfo? Certificate = null)
{
    public static readonly ConnectionCheck Success = new(true, null);
    public static ConnectionCheck Failure(string error) => new(false, error);

    /// <summary>Codice e valori di <see cref="Error"/> per l'app (L6); null = solo il testo.</summary>
    public string? ErrorCode { get; init; }
    public IReadOnlyDictionary<string, string>? ErrorArgs { get; init; }
}

/// <summary>
/// Prova i dati di un account prima di salvarli: login IMAP e autenticazione SMTP, senza leggere
/// né inviare nulla. I messaggi d'errore sono pensati per l'utente e non contengono la password.
/// </summary>
public static class AccountTester
{
    public static readonly TimeSpan Timeout = TimeSpan.FromSeconds(20);

    public static async Task<ConnectionCheck> TestImapAsync(ImapSettings settings, CancellationToken ct = default)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(Timeout);
        try
        {
            await using var session = new ImapMailService(settings);
            await session.ConnectAsync(timeout.Token);
            return ConnectionCheck.Success;
        }
        catch (Exception ex) when (ex is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            return Fail(ex, settings.Host, settings.Port);
        }
    }

    /// <summary>Prova del server POP3 (4.2): collegamento, login e conteggio, senza scaricare né togliere nulla.</summary>
    public static async Task<ConnectionCheck> TestPop3Async(Pop3.Pop3Settings settings, CancellationToken ct = default)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(Timeout);
        try
        {
            using var client = new MailKit.Net.Pop3.Pop3Client { Timeout = (int)Timeout.TotalMilliseconds };
            await Pop3.Pop3Fetcher.ConnectAsync(client, settings, timeout.Token);
            if (!client.Capabilities.HasFlag(MailKit.Net.Pop3.Pop3Capabilities.UIDL))
                return ConnectionCheck.Failure($"Il server POP3 {settings.Host}:{settings.Port} non supporta UIDL: necessario per non scaricare due volte le mail.")
                    with { ErrorCode = "pop3NoUidl", ErrorArgs = Address(settings.Host, settings.Port) };
            await client.DisconnectAsync(quit: true, timeout.Token); // nessun DELE: non cambia nulla
            return ConnectionCheck.Success;
        }
        catch (Exception ex) when (ex is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            return Fail(ex, settings.Host, settings.Port);
        }
    }

    public static async Task<ConnectionCheck> TestSmtpAsync(SmtpSettings settings, CancellationToken ct = default)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(Timeout);
        try
        {
            await new SmtpMailService(settings).TestAsync(timeout.Token);
            return ConnectionCheck.Success;
        }
        catch (Exception ex) when (ex is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            return Fail(ex, settings.Host, settings.Port);
        }
    }

    private static ConnectionCheck Fail(Exception ex, string host, int port)
    {
        var (code, args) = CodeOf(ex, host, port);
        return new(false, Describe(ex, host, port), Untrusted(ex)?.Certificate) { ErrorCode = code, ErrorArgs = args };
    }

    private static Dictionary<string, string> Address(string host, int port) => new() { ["address"] = $"{host}:{port}" };

    /// <summary>Codice per l'app dello stesso caso di <see cref="Describe"/> (L6).</summary>
    public static (string? Code, IReadOnlyDictionary<string, string>? Args) CodeOf(Exception ex, string host, int port) => ex switch
    {
        ArgumentException or OAuth.OAuthException => (CoreError.CodeOf(ex), CoreError.CodeOf(ex) is null ? null : CoreError.ArgsOf(ex)),
        UntrustedCertificateException e => ("testCertificateInvalid",
            new Dictionary<string, string>(Address(host, port)) { ["host"] = host, ["problems"] = string.Join(",", e.Certificate.ProblemCodes) }),
        NotSupportedException => ("testNoStartTls", Address(host, port)),
        AuthenticationException => ("testAuthRejected", null),
        SslHandshakeException => ("testTlsFailed", Address(host, port)),
        SocketException => ("testUnreachable", Address(host, port)),
        MailOfflineException { InnerException: { } inner } => CodeOf(inner, host, port),
        OperationCanceledException or TimeoutException =>
            ("testNoAnswer", new Dictionary<string, string>(Address(host, port)) { ["seconds"] = $"{Timeout.TotalSeconds:0}" }),
        ProtocolException or IOException => ("testUnexpectedAnswer", Address(host, port)),
        _ => (null, null),
    };

    private static UntrustedCertificateException? Untrusted(Exception ex) => ex switch
    {
        UntrustedCertificateException u => u,
        MailOfflineException { InnerException: UntrustedCertificateException u } => u,
        _ => null,
    };

    public static string Describe(Exception ex, string host, int port) => ex switch
    {
        ArgumentException e => e.Message, // dati mancanti
        OAuth.OAuthException e => e.Message,
        UntrustedCertificateException e => $"Il certificato del server {host}:{port} non è valido: {string.Join(", ", e.Certificate.Problems)}.",
        // MailKit con STARTTLS obbligatorio e un server che non lo offre.
        NotSupportedException => $"Il server {host}:{port} non offre STARTTLS: scegliere un'altra crittografia o un'altra porta.",
        AuthenticationException => "Autenticazione rifiutata: controllare indirizzo e password.",
        SslHandshakeException => $"Connessione cifrata non riuscita con {host}:{port}: la porta usa davvero questa crittografia?",
        SocketException => $"Server {host}:{port} non raggiungibile.",
        // SmtpMailService traduce già rete assente e nessuna risposta: si guarda la causa.
        MailOfflineException { InnerException: { } inner } => Describe(inner, host, port),
        OperationCanceledException or TimeoutException =>
            $"Nessuna risposta da {host}:{port} entro {Timeout.TotalSeconds:0} s: server, porta o crittografia errati?",
        ProtocolException or IOException => $"Risposta inattesa da {host}:{port}: porta o protocollo errati?",
        _ => $"{ex.GetType().Name}: {ex.Message}",
    };
}
