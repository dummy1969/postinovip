using MailKit.Net.Smtp;
using MailKit.Security;
using PostinoVip.Core.Models;
using PostinoVip.Core.Security;

namespace PostinoVip.Core.Smtp;

/// <summary>
/// Invio SMTP con la crittografia scelta per l'account (4.1). StartTls (mai StartTlsWhenAvailable): se il
/// server non offre TLS la connessione fallisce invece di proseguire in chiaro. Autenticazione facoltativa
/// (<see cref="SmtpSettings.RequireAuth"/>).
/// </summary>
public sealed class SmtpMailService : IMailSender
{
    private readonly SmtpSettings _settings;

    public SmtpMailService(SmtpSettings settings)
    {
        if (string.IsNullOrWhiteSpace(settings.Host))
            throw new ArgumentException("Host SMTP non configurato.", nameof(settings));
        if (string.IsNullOrWhiteSpace(settings.Username)
            || settings.RequireAuth && string.IsNullOrEmpty(settings.Password) && settings.AccessToken is null)
            throw new ArgumentException("Credenziali SMTP mancanti.", nameof(settings));

        _settings = settings;
    }

    /// <summary>
    /// Nome con cui il core si presenta al server (EHLO): un indirizzo letterale (RFC 5321) invece del nome del PC,
    /// che MailKit userebbe e che il server scrive nella riga Received: di ogni mail inviata (scelta 3a del
    /// 09/11/2026, come il Message-ID con il dominio del mittente).
    /// </summary>
    public const string HeloName = "[127.0.0.1]";

    /// <summary>Connessione + autenticazione, poi chiusura: verifica i dati senza inviare nulla.</summary>
    public async Task TestAsync(CancellationToken ct = default)
    {
        using var client = new SmtpClient();
        await ConnectAsync(client, ct);
        await client.DisconnectAsync(quit: true, ct);
    }

    /// <summary>Invia il messaggio; la risposta del server è del tipo "2.0.0 Ok: queued as ...".</summary>
    public async Task<SendResult> SendAsync(OutgoingMessage msg, CancellationToken ct = default)
    {
        var message = MimeMessageBuilder.Build(msg);
        return new SendResult(await SendMimeAsync(message, ct), message);
    }

    public async Task<string> SendMimeAsync(MimeKit.MimeMessage message, CancellationToken ct = default)
    {
        using var client = new SmtpClient();
        await ConnectAsync(client, ct);
        var response = await client.SendAsync(message, ct);
        await client.DisconnectAsync(quit: true, ct);
        return response;
    }

    /// <summary>Tempo massimo per collegarsi e autenticarsi (l'invio vero e proprio non ha questo limite).</summary>
    public static readonly TimeSpan ConnectTimeout = TimeSpan.FromSeconds(15);

    /// <summary>
    /// Collegamento (con la crittografia scelta) e autenticazione entro <see cref="ConnectTimeout"/>. Server non raggiungibile
    /// (rete assente, nessuna risposta) -> MailOfflineException: niente invio, la mail resta all'utente.
    /// </summary>
    private async Task ConnectAsync(SmtpClient client, CancellationToken ct)
    {
        using var limit = CancellationTokenSource.CreateLinkedTokenSource(ct);
        limit.CancelAfter(ConnectTimeout);
        var trust = new TrustedCertificate(_settings.Host, _settings.Port, _settings.CertificateSha256);
        client.ServerCertificateValidationCallback = trust.Validate;
        client.LocalDomain = HeloName;
        try
        {
            try
            {
                await client.ConnectAsync(_settings.Host, _settings.Port, _settings.EffectiveSecurity.ToMailKit(), limit.Token);
            }
            catch (SslHandshakeException ex) when (trust.Rejected is { } rejected && !limit.IsCancellationRequested)
            {
                throw new UntrustedCertificateException(rejected, ex);
            }
            if (_settings.RequireAuth)
                await OAuth.MailAuth.AuthenticateAsync(client, _settings.Username, _settings.Password, _settings.AccessToken, limit.Token);
        }
        catch (Exception ex) when (limit.IsCancellationRequested && !ct.IsCancellationRequested)
        {
            // Qualunque errore dopo lo scadere del tempo (anche SslHandshakeException: vedi ReconnectingSession).
            throw new MailOfflineException(
                $"Server di invio non raggiungibile (nessuna risposta in {ConnectTimeout.TotalSeconds:0} s): mail non inviata.", ex);
        }
        catch (Exception ex) when (ex is System.Net.Sockets.SocketException or IOException && !ct.IsCancellationRequested
                                   && ex is not MailKit.Security.SslHandshakeException)
        {
            throw new MailOfflineException($"Server di invio non raggiungibile ({ex.GetType().Name}: {ex.Message}): mail non inviata.", ex);
        }
    }
}
