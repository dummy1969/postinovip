using Microsoft.AspNetCore.Mvc;
using PostinoVip.Api.Contracts;
using PostinoVip.Core.Account;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Api.Controllers;

[ApiController]
[Route("account")]
public sealed class AccountController(MailAccountRegistry accounts,
    IReadOnlyDictionary<string, PostinoVip.Core.OAuth.OAuthProvider> oauthProviders) : ControllerBase
{
    /// <summary>GET /account — indirizzo e stato della configurazione del primo account, mai la password.</summary>
    [HttpGet]
    public ActionResult<AccountResponse> Get()
    {
        var first = accounts.Get(null);
        return Ok(new AccountResponse(first.Address, first.Configured));
    }

    /// <summary>
    /// POST /account/test — prova login IMAP e autenticazione SMTP con i dati ricevuti, senza
    /// leggere né inviare nulla e senza salvarli. La password non viene registrata nei log.
    /// Certificato non valido: errore con i dati del certificato (<c>certificate</c>), nessuna password inviata.
    /// </summary>
    [HttpPost("test")]
    public async Task<ActionResult<AccountTestResponse>> Test([FromBody] AccountTestRequest request, CancellationToken ct)
    {
        var imapSettings = new ImapSettings
        {
            Host = request.ImapHost.Trim(), Port = request.ImapPort, Username = request.Email.Trim(), Password = request.Password,
            Security = request.ImapSecurity, CertificateSha256 = request.ImapCertificateSha256,
        };
        var smtpSettings = new SmtpSettings
        {
            Host = request.SmtpHost.Trim(), Port = request.SmtpPort, Username = request.Email.Trim(), Password = request.Password,
            Security = request.SmtpSecurity, RequireAuth = request.SmtpRequireAuth, CertificateSha256 = request.SmtpCertificateSha256,
        };

        // Con OAuth2 un token di accesso al posto della password, lo stesso per i due server.
        if (!string.IsNullOrWhiteSpace(request.OAuthProvider))
        {
            if (!oauthProviders.TryGetValue(request.OAuthProvider, out var provider) || string.IsNullOrWhiteSpace(request.RefreshToken))
                return ValidationProblem(new ValidationProblemDetails(new Dictionary<string, string[]>
                {
                    ["oauthProvider"] = ["Fornitore o token di accesso mancanti."],
                }));
            var source = new PostinoVip.Core.OAuth.OAuthTokenSource(provider, request.RefreshToken);
            imapSettings.AccessToken = smtpSettings.AccessToken = source.GetAccessTokenAsync;
        }
        else if (string.IsNullOrEmpty(request.Password))
        {
            return ValidationProblem(new ValidationProblemDetails(new Dictionary<string, string[]> { ["password"] = ["Password obbligatoria."] }));
        }

        // In parallelo: sono due server (o due porte) indipendenti.
        var imapCheck = request.Type == MailAccountType.Pop3
            ? AccountTester.TestPop3Async(new PostinoVip.Core.Pop3.Pop3Settings
            {
                Host = imapSettings.Host, Port = request.ImapPort, Username = imapSettings.Username, Password = request.Password,
                Security = request.ImapSecurity, CertificateSha256 = request.ImapCertificateSha256, AccessToken = imapSettings.AccessToken,
            }, ct)
            : AccountTester.TestImapAsync(imapSettings, ct);
        var smtpCheck = AccountTester.TestSmtpAsync(smtpSettings, ct);
        return Ok(new AccountTestResponse(await imapCheck, await smtpCheck));
    }

    /// <summary>
    /// POST /account/test-carddav — «Verifica rubrica» (C4c, 1b): cerca la rubrica CardDAV con questi dati, in sola
    /// lettura (PROPFIND), senza salvarli né sincronizzare. 200 sempre, con Ok e il nome della rubrica o il motivo.
    /// </summary>
    [HttpPost("test-carddav")]
    public async Task<ActionResult<CardDavTestResponse>> TestCardDav([FromBody] CardDavTestRequest request, CancellationToken ct)
    {
        var (found, error) = await DiscoverAsync(request, PostinoVip.Core.Dav.DavKind.CardDav, ct);
        if (found is null)
            return error is null ? MissingPassword() : Ok(new CardDavTestResponse(false, error));
        return Ok(new CardDavTestResponse(true, null, found[0].Name ?? "Contatti", found[0].Url.AbsoluteUri));
    }

    /// <summary>
    /// POST /account/test-caldav — «Verifica calendario» (K2a): cerca i calendari CalDAV che accettano appuntamenti, in
    /// sola lettura, senza salvare né sincronizzare. 200 sempre, con Ok e i nomi dei calendari o il motivo.
    /// </summary>
    [HttpPost("test-caldav")]
    public async Task<ActionResult<CalDavTestResponse>> TestCalDav([FromBody] CardDavTestRequest request, CancellationToken ct)
    {
        var (found, error) = await DiscoverAsync(request, PostinoVip.Core.Dav.DavKind.CalDav, ct);
        if (found is null)
            return error is null ? MissingPassword() : Ok(new CalDavTestResponse(false, error));
        return Ok(new CalDavTestResponse(true, null, found.Select(f => f.Name ?? "Calendario").ToList()));
    }

    private ActionResult MissingPassword() =>
        ValidationProblem(new ValidationProblemDetails(new Dictionary<string, string[]> { ["password"] = ["Password obbligatoria."] }));

    /// <summary>Scoperta con i dati della richiesta; (null, null) = password mancante, (null, motivo) = non riuscita.</summary>
    private async Task<(List<PostinoVip.Core.Dav.DavCollectionInfo>? Found, string? Error)> DiscoverAsync(CardDavTestRequest request,
        PostinoVip.Core.Dav.DavKind kind, CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(request.OAuthProvider))
            return await DiscoverOAuthAsync(request, kind, ct);
        if (string.IsNullOrEmpty(request.Password))
            return (null, null);
        var host = request.Host.Trim();
        Uri start;
        try
        {
            start = PostinoVip.Core.Dav.DavClient.StartUrl(request.Url, host, kind);
            PostinoVip.Core.Dav.DavClient.EnsureAllowed(start, kind);
        }
        catch (UriFormatException)
        {
            return (null, $"Indirizzo del {kind.ServerLabel} non valido.");
        }
        catch (PostinoVip.Core.Dav.DavException ex)
        {
            return (null, ex.Message);
        }
        var pin = start.Host.Equals(host, StringComparison.OrdinalIgnoreCase) ? request.CertificateSha256 : null;
        using var client = new PostinoVip.Core.Dav.DavClient(new System.Net.NetworkCredential(request.Email.Trim(), request.Password),
            new PostinoVip.Core.Security.TrustedCertificate(start.Host, start.Port, pin), kind: kind);
        try
        {
            var found = await client.DiscoverAllAsync(start, ct);
            if (kind == PostinoVip.Core.Dav.DavKind.CardDav)
            {
                // nome della rubrica dalle sue proprietà (come prima del K2a)
                var info = await client.GetCollectionAsync(found[0].Url, ct);
                found[0] = found[0] with { Name = info.Name ?? found[0].Name };
            }
            return (found, null);
        }
        catch (Exception ex) when (ex is PostinoVip.Core.Dav.DavException or PostinoVip.Core.MailOfflineException)
        {
            return (null, ex.Message);
        }
    }

    /// <summary>
    /// «Verifica rubrica» di un account con OAuth2 (C4d): token dal token di rinnovo ricevuto, scoperta dal server del
    /// fornitore (o dall'indirizzo scritto), in sola lettura. Senza il permesso dei contatti si ferma prima.
    /// </summary>
    private async Task<(List<PostinoVip.Core.Dav.DavCollectionInfo>? Found, string? Error)> DiscoverOAuthAsync(CardDavTestRequest request,
        PostinoVip.Core.Dav.DavKind kind, CancellationToken ct)
    {
        if (!oauthProviders.TryGetValue(request.OAuthProvider!, out var provider) || string.IsNullOrWhiteSpace(request.RefreshToken))
            return (null, "Fornitore o token di accesso mancanti.");
        if (MailAccountRegistry.OAuthStart(provider, kind, request.Email) is not { } providerStart)
            return (null, $"Non ancora disponibile per gli account con accesso {provider.DisplayName}.");
        Uri start;
        try
        {
            start = string.IsNullOrWhiteSpace(request.Url) ? providerStart : PostinoVip.Core.Dav.DavClient.StartUrl(request.Url, request.Host.Trim(), kind);
            PostinoVip.Core.Dav.DavClient.EnsureAllowed(start, kind);
        }
        catch (UriFormatException)
        {
            return (null, $"Indirizzo del {kind.ServerLabel} non valido.");
        }
        catch (PostinoVip.Core.Dav.DavException ex)
        {
            return (null, ex.Message);
        }
        var tokens = new PostinoVip.Core.OAuth.OAuthTokenSource(provider, request.RefreshToken);
        using var client = MailAccountRegistry.BearerClient(request.Email.Trim(), tokens, start, kind: kind);
        try
        {
            var found = await client.DiscoverAllAsync(start, ct);
            if (kind == PostinoVip.Core.Dav.DavKind.CardDav)
            {
                var info = await client.GetCollectionAsync(found[0].Url, ct);
                found[0] = found[0] with { Name = info.Name ?? found[0].Name };
            }
            return (found, null);
        }
        catch (Exception ex) when (ex is PostinoVip.Core.Dav.DavException or PostinoVip.Core.MailOfflineException)
        {
            return (null, ex.Message);
        }
        catch (PostinoVip.Core.OAuth.OAuthException ex)
        {
            return (null, ex.Message);
        }
    }
}
