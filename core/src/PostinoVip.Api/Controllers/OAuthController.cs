using System.Net;
using Microsoft.AspNetCore.Mvc;

namespace PostinoVip.Api.Controllers;

/// <summary>Corpo di POST /oauth/start.</summary>
public sealed class OAuthStartRequest
{
    public string Provider { get; set; } = "";

    /// <summary>Indirizzo già scritto dall'utente, proposto nella pagina di accesso.</summary>
    public string? LoginHint { get; set; }

    /// <summary>Anche il permesso dei contatti (C4d, 1a: solo per un account con la sincronizzazione dei contatti).</summary>
    public bool Contacts { get; set; }

    /// <summary>Anche il permesso del calendario (G1, 2a: solo per un account con il calendario sincronizzato).</summary>
    public bool Calendar { get; set; }
}

public sealed record OAuthStartResponse(string Id, string AuthorizationUrl);

/// <summary>
/// Accesso con OAuth2 (O1): l'app chiede di iniziare, apre nel browser di sistema l'indirizzo ricevuto, poi legge lo
/// stato finché l'accesso non finisce. Il browser torna su /oauth/callback (senza token: vale lo "state").
/// </summary>
[ApiController]
[Route("oauth")]
public sealed class OAuthController(OAuthLogins logins) : ControllerBase
{
    /// <summary>GET /oauth/providers — i fornitori e se hanno il client ID (senza, l'app non mostra il pulsante).</summary>
    [HttpGet("providers")]
    public IActionResult Providers() =>
        Ok(logins.Providers.Values.Select(p => new { id = p.Id, name = p.DisplayName, configured = p.IsConfigured }));

    [HttpPost("start")]
    public ActionResult<OAuthStartResponse> Start([FromBody] OAuthStartRequest request)
    {
        // Ritorno su "localhost" (come chiede Microsoft per le app desktop) alla porta del core.
        var redirect = $"http://localhost:{HttpContext.Connection.LocalPort}{OAuthLogins.CallbackPath}";
        var (id, url) = logins.Start(request.Provider, redirect, request.LoginHint, request.Contacts, request.Calendar);
        return Ok(new OAuthStartResponse(id, url));
    }

    [HttpGet("flows/{id}")]
    public ActionResult<OAuthFlowStatus> Status(string id) => logins.Status(id) is { } s ? Ok(s) : NotFound();

    [HttpDelete("flows/{id}")]
    public IActionResult Cancel(string id) => logins.Cancel(id) ? NoContent() : NotFound();

    /// <summary>GET /oauth/callback — pagina mostrata nel browser alla fine dell'accesso.</summary>
    [HttpGet("callback")]
    public async Task<ContentResult> Callback([FromQuery] string? state, [FromQuery] string? code, [FromQuery] string? error,
        [FromQuery(Name = "error_description")] string? errorDescription, CancellationToken ct)
    {
        var (ok, message) = await logins.CompleteAsync(state, code, error, errorDescription, ct);
        var html = $"""
            <!doctype html><html lang="{PostinoVip.Core.Texts.CoreTexts.Language}"><head><meta charset="utf-8"><title>PostinoVip</title>
            <style>body{"{"}font-family:system-ui,sans-serif;margin:3rem;color:#1b1e2e{"}"}h1{"{"}font-size:1.4rem{"}"}</style></head>
            <body><h1>{PostinoVip.Core.Texts.CoreTexts.Get(ok ? "oauthPageOk" : "oauthPageFailed")}</h1><p>{WebUtility.HtmlEncode(message)}</p></body></html>
            """;
        return new ContentResult { Content = html, ContentType = "text/html; charset=utf-8", StatusCode = ok ? 200 : 400 };
    }
}
