using System.Net.Sockets;
using MailKit;
using MailKit.Net.Imap;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using PostinoVip.Core;
using PostinoVip.Core.Security;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Api;

/// <summary>
/// Traduce le eccezioni del core in risposte ProblemDetails (RFC 9457).
/// Nei log e nelle risposte finiscono solo tipo e messaggio dell'eccezione, mai credenziali o contenuti.
/// </summary>
public sealed class MailExceptionHandler(IProblemDetailsService problemDetails, ILogger<MailExceptionHandler> logger)
    : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken ct)
    {
        // Indirizzo non valido: errore di validazione legato al campo, come quelli del model binding.
        if (exception is FieldValidationException invalid)
        {
            logger.LogInformation("{Method} {Path} -> 400: {Message}",
                context.Request.Method, context.Request.Path, invalid.Message);
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            return await problemDetails.TryWriteAsync(new ProblemDetailsContext
            {
                HttpContext = context,
                Exception = exception,
                ProblemDetails = new ValidationProblemDetails(
                    new Dictionary<string, string[]> { [invalid.Field] = [invalid.Message] })
                {
                    Status = StatusCodes.Status400BadRequest,
                    Title = "Richiesta non valida",
                },
            });
        }

        var (status, title, detail) = exception switch
        {
            MailNotFoundException e => (StatusCodes.Status404NotFound, "Non trovato", e.Message),
            MailOfflineException e => (StatusCodes.Status503ServiceUnavailable, "Non connesso", e.Message),
            // Il server ha smesso di rispondere a connessione aperta (rete staccata). Le letture vengono
            // ripetute e diventano MailOfflineException; una scrittura no: forse è già stata eseguita.
            TimeoutException => (StatusCodes.Status503ServiceUnavailable, "Non connesso",
                "Il server non risponde: l'operazione potrebbe non essere stata eseguita."),
            FormatException e => (StatusCodes.Status400BadRequest, "Richiesta non valida", e.Message),
            // Operazione non consentita in questo stato (es. eliminazione definitiva fuori da Posta eliminata).
            InvalidOperationException e => (StatusCodes.Status409Conflict, "Operazione non consentita", e.Message),
            NotSupportedException e => (StatusCodes.Status501NotImplemented, "Non supportato dal server", e.Message),
            // Il server di un account già salvato presenta un certificato diverso da quello di cui l'utente
            // si fida (rinnovato, o qualcuno in mezzo): niente connessione finché non lo riconferma.
            UntrustedCertificateException e => (StatusCodes.Status502BadGateway, "Certificato del server non valido",
                $"{e.Message} Aprire l'account in Impostazioni e ripetere \"Verifica connessione\"."),
            // OAuth2: token di rinnovo scaduto o revocato, client non registrato: serve rifare l'accesso.
            PostinoVip.Core.OAuth.OAuthException e => (StatusCodes.Status502BadGateway, "Accesso all'account non riuscito", e.Message),
            AuthenticationException => (StatusCodes.Status502BadGateway, "Autenticazione con il server mail fallita",
                "Controllare username e password."),
            ImapCommandException or SmtpCommandException or ProtocolException or SslHandshakeException
                or SocketException or IOException or ServiceNotConnectedException =>
                (StatusCodes.Status502BadGateway, "Errore del server mail", $"{exception.GetType().Name}: {exception.Message}"),
            ArgumentException e => (StatusCodes.Status500InternalServerError, "Configurazione non valida", e.Message),
            _ => (StatusCodes.Status500InternalServerError, "Errore interno", "Errore imprevisto, vedere il log del core."),
        };

        // Senza rete ogni richiesta che va al server finisce qui: non è un errore del core.
        if (status >= 500 && exception is not (MailOfflineException or TimeoutException))
            logger.LogError("{Method} {Path} -> {Status}: {Type}: {Message}",
                context.Request.Method, context.Request.Path, status, exception.GetType().Name, exception.Message);
        else
            logger.LogInformation("{Method} {Path} -> {Status}: {Message}",
                context.Request.Method, context.Request.Path, status, exception.Message);

        context.Response.StatusCode = status;
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = context,
            Exception = exception,
            ProblemDetails = new ProblemDetails { Status = status, Title = title, Detail = detail },
        });
    }
}
