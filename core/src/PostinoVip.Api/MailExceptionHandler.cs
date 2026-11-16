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
            var validation = new ValidationProblemDetails(new Dictionary<string, string[]> { [invalid.Field] = [invalid.Message] })
            {
                Status = StatusCodes.Status400BadRequest,
                Title = "Richiesta non valida",
            };
            validation.Extensions["kind"] = "invalidRequest";
            // Codice dell'errore del campo (L6): l'app traduce il testo; senza codice resta quello italiano.
            if (CoreError.CodeOf(invalid) is { } fieldCode)
                validation.Extensions["fieldCodes"] = new Dictionary<string, object>
                {
                    [invalid.Field.ToLowerInvariant()] = new { code = fieldCode, args = CoreError.ArgsOf(invalid) },
                };
            return await problemDetails.TryWriteAsync(new ProblemDetailsContext
            {
                HttpContext = context,
                Exception = exception,
                ProblemDetails = validation,
            });
        }

        // Tipo (kind) e codice (code) per l'app (L6, scelta 2a): il tipo dà il titolo, il codice il dettaglio. Il codice viene
        // dall'eccezione (CoreError.WithCode) o, per i dettagli scritti qui, è fisso; senza codice l'app mostra il testo.
        string? code = CoreError.CodeOf(exception);
        var args = CoreError.ArgsOf(exception);
        var (status, kind, title, detail) = exception switch
        {
            MailNotFoundException e => (StatusCodes.Status404NotFound, "notFound", "Non trovato", e.Message),
            MailOfflineException e => (StatusCodes.Status503ServiceUnavailable, "offline", "Non connesso", e.Message),
            // Il server ha smesso di rispondere a connessione aperta (rete staccata). Le letture vengono
            // ripetute e diventano MailOfflineException; una scrittura no: forse è già stata eseguita.
            TimeoutException => (StatusCodes.Status503ServiceUnavailable, "offline", "Non connesso",
                Fixed(ref code, "timeout", "Il server non risponde: l'operazione potrebbe non essere stata eseguita.")),
            FormatException e => (StatusCodes.Status400BadRequest, "invalidRequest", "Richiesta non valida", e.Message),
            // Connessione caduta: MailKit la segnala con una InvalidOperationException, che sotto diventerebbe un 409
            // «Operazione non consentita» (successo il 12/11/2026): va prima.
            ServiceNotConnectedException => (StatusCodes.Status502BadGateway, "server", "Errore del server mail",
                $"{exception.GetType().Name}: {exception.Message}"),
            // Operazione non consentita in questo stato (es. eliminazione definitiva fuori da Posta eliminata).
            InvalidOperationException e => (StatusCodes.Status409Conflict, "conflict", "Operazione non consentita", e.Message),
            NotSupportedException e => (StatusCodes.Status501NotImplemented, "notSupported", "Non supportato dal server", e.Message),
            // Il server di un account già salvato presenta un certificato diverso da quello di cui l'utente
            // si fida (rinnovato, o qualcuno in mezzo): niente connessione finché non lo riconferma.
            UntrustedCertificateException e => (StatusCodes.Status502BadGateway, "certificate", "Certificato del server non valido",
                CertificateChanged(e, ref code, ref args)),
            // OAuth2: token di rinnovo scaduto o revocato, client non registrato: serve rifare l'accesso.
            PostinoVip.Core.OAuth.OAuthException e => (StatusCodes.Status502BadGateway, "oauth", "Accesso all'account non riuscito", e.Message),
            AuthenticationException => (StatusCodes.Status502BadGateway, "auth", "Autenticazione con il server mail fallita",
                Fixed(ref code, "authCheckCredentials", "Controllare username e password.")),
            ImapCommandException or SmtpCommandException or ProtocolException or SslHandshakeException
                or SocketException or IOException =>
                (StatusCodes.Status502BadGateway, "server", "Errore del server mail", $"{exception.GetType().Name}: {exception.Message}"),
            ArgumentException e => (StatusCodes.Status500InternalServerError, "config", "Configurazione non valida", e.Message),
            _ => (StatusCodes.Status500InternalServerError, "internal", "Errore interno",
                Fixed(ref code, "internalUnexpected", "Errore imprevisto, vedere il log del core.")),
        };

        // Senza rete ogni richiesta che va al server finisce qui: non è un errore del core.
        if (status >= 500 && exception is not (MailOfflineException or TimeoutException))
            logger.LogError("{Method} {Path} -> {Status}: {Type}: {Message}",
                context.Request.Method, context.Request.Path, status, exception.GetType().Name, exception.Message);
        else
            logger.LogInformation("{Method} {Path} -> {Status}: {Message}",
                context.Request.Method, context.Request.Path, status, exception.Message);

        context.Response.StatusCode = status;
        var problem = new ProblemDetails { Status = status, Title = title, Detail = detail };
        problem.Extensions["kind"] = kind;
        if (code is not null)
        {
            problem.Extensions["code"] = code;
            problem.Extensions["args"] = args;
        }
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = context,
            Exception = exception,
            ProblemDetails = problem,
        });
    }

    /// <summary>Dettaglio scritto qui: il suo codice, se l'eccezione non ne porta già uno.</summary>
    private static string Fixed(ref string? code, string fixedCode, string text)
    {
        code ??= fixedCode;
        return text;
    }

    /// <summary>Certificato cambiato su un account già salvato: problemi come codici (separati da virgola) per l'app.</summary>
    private static string CertificateChanged(UntrustedCertificateException e, ref string? code,
        ref IReadOnlyDictionary<string, string> args)
    {
        code = "certificateChanged";
        args = new Dictionary<string, string>
        {
            ["address"] = $"{e.Certificate.Host}:{e.Certificate.Port}",
            ["host"] = e.Certificate.Host,
            ["problems"] = string.Join(",", e.Certificate.ProblemCodes),
        };
        return $"{e.Message} Aprire l'account in Impostazioni e ripetere \"Verifica connessione\".";
    }
}
