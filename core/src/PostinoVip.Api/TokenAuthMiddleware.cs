using Microsoft.AspNetCore.Mvc;

namespace PostinoVip.Api;

/// <summary>
/// Rifiuta con 401 ogni richiesta senza "Authorization: Bearer &lt;token&gt;" valido.
/// Il core ascolta solo su loopback, ma qualunque programma dello stesso PC potrebbe raggiungerlo:
/// il token limita l'accesso a chi ha avviato il core (l'app).
/// </summary>
public sealed class TokenAuthMiddleware(RequestDelegate next, ApiToken token, IProblemDetailsService problemDetails)
{
    private const string Prefix = "Bearer ";

    public async Task InvokeAsync(HttpContext context)
    {
        var header = context.Request.Headers.Authorization.ToString();
        var candidate = header.StartsWith(Prefix, StringComparison.Ordinal) ? header[Prefix.Length..] : null;

        // Ritorno dal browser dopo l'accesso OAuth2 (3a): il browser non ha il token. La richiesta vale solo se porta
        // lo "state" casuale di un accesso appena avviato dall'app (controllato da OAuthLogins).
        if (token.Matches(candidate) || (HttpMethods.IsGet(context.Request.Method) && context.Request.Path == OAuthLogins.CallbackPath))
        {
            await next(context);
            return;
        }

        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await problemDetails.WriteAsync(new ProblemDetailsContext
        {
            HttpContext = context,
            ProblemDetails = new ProblemDetails
            {
                Status = StatusCodes.Status401Unauthorized,
                Title = "Non autorizzato",
                Detail = "Token mancante o non valido.",
            },
        });
    }
}
