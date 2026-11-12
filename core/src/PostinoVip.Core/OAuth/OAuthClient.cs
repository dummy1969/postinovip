using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace PostinoVip.Core.OAuth;

/// <summary>
/// Il fornitore ha rifiutato la richiesta (es. invalid_grant: token di rinnovo scaduto o revocato, serve un
/// nuovo accesso). Il messaggio è per l'utente; non contiene token.
/// </summary>
public sealed class OAuthException(string error, string message) : Exception(message)
{
    public string Error { get; } = error;
    public bool NeedsLogin => Error is "invalid_grant" or "interaction_required" or "consent_required" or "login_required";
}

/// <summary>Risposta del server dei token.</summary>
/// <summary><see cref="Scope"/>: i permessi concessi, separati da spazi (null se il fornitore non li indica).</summary>
public sealed record OAuthTokens(string AccessToken, DateTimeOffset ExpiresAt, string? RefreshToken, string? Email, string? Scope = null);

/// <summary>PKCE (RFC 7636): verificatore casuale e sfida S256.</summary>
public static class Pkce
{
    public static string NewVerifier() => Base64Url(RandomNumberGenerator.GetBytes(32));

    public static string Challenge(string verifier) => Base64Url(SHA256.HashData(Encoding.ASCII.GetBytes(verifier)));

    public static string Base64Url(byte[] bytes) => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}

/// <summary>Richieste al server dei token (codice -> token, rinnovo). I token non vanno mai nei log.</summary>
public static class OAuthClient
{
    public static readonly TimeSpan Timeout = TimeSpan.FromSeconds(15);

    private static readonly HttpClient Http = new() { Timeout = Timeout };

    /// <summary>URL della pagina di accesso del fornitore (browser di sistema, 3a).</summary>
    /// <param name="contacts">Anche i permessi dei contatti (C4d, solo per gli account con la sincronizzazione dei contatti).</param>
    /// <param name="calendar">Anche i permessi del calendario (G1, solo per gli account con il calendario sincronizzato).</param>
    public static string AuthorizationUrl(OAuthProvider p, string redirectUri, string state, string challenge, string? loginHint,
        bool contacts = false, bool calendar = false)
    {
        var query = new Dictionary<string, string>
        {
            ["client_id"] = p.ClientId,
            ["response_type"] = "code",
            ["redirect_uri"] = redirectUri,
            ["scope"] = string.Join(' ', p.ScopesFor(contacts, calendar)),
            ["state"] = state,
            ["code_challenge"] = challenge,
            ["code_challenge_method"] = "S256",
            ["prompt"] = "select_account",
        };
        if (!string.IsNullOrWhiteSpace(loginHint))
            query["login_hint"] = loginHint.Trim();
        return p.AuthorizationEndpoint + (p.AuthorizationEndpoint.Contains('?') ? "&" : "?")
               + string.Join('&', query.Select(kv => $"{Uri.EscapeDataString(kv.Key)}={Uri.EscapeDataString(kv.Value)}"));
    }

    public static Task<OAuthTokens> ExchangeCodeAsync(OAuthProvider p, string code, string verifier, string redirectUri,
        CancellationToken ct = default) =>
        RequestAsync(p, new Dictionary<string, string>
        {
            ["grant_type"] = "authorization_code",
            ["code"] = code,
            ["redirect_uri"] = redirectUri,
            ["code_verifier"] = verifier,
        }, ct);

    public static Task<OAuthTokens> RefreshAsync(OAuthProvider p, string refreshToken, CancellationToken ct = default)
    {
        var form = new Dictionary<string, string>
        {
            ["grant_type"] = "refresh_token",
            ["refresh_token"] = refreshToken,
        };
        if (p.RefreshWithScope)
            form["scope"] = string.Join(' ', p.Scopes);
        return RequestAsync(p, form, ct);
    }

    private static async Task<OAuthTokens> RequestAsync(OAuthProvider p, Dictionary<string, string> form, CancellationToken ct)
    {
        form["client_id"] = p.ClientId;
        if (!string.IsNullOrEmpty(p.ClientSecret))
            form["client_secret"] = p.ClientSecret;
        HttpResponseMessage response;
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, p.TokenEndpoint) { Content = new FormUrlEncodedContent(form) };
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            response = await Http.SendAsync(request, ct);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException && !ct.IsCancellationRequested)
        {
            throw new MailOfflineException($"Server di accesso di {p.DisplayName} non raggiungibile.", ex);
        }
        using (response)
        {
            var json = await response.Content.ReadAsStringAsync(ct);
            JsonElement root;
            try
            {
                root = JsonDocument.Parse(json).RootElement;
            }
            catch (JsonException)
            {
                throw new OAuthException("invalid_response", $"Risposta non valida dal server di accesso di {p.DisplayName} (HTTP {(int)response.StatusCode}).");
            }
            if (!response.IsSuccessStatusCode || !root.TryGetProperty("access_token", out var access))
            {
                var error = root.TryGetProperty("error", out var e) ? e.GetString() ?? "error" : "error";
                throw new OAuthException(error, error switch
                {
                    "invalid_grant" => $"Accesso a {p.DisplayName} scaduto o revocato: rifai «Accedi con {p.DisplayName}».",
                    "invalid_client" or "unauthorized_client" => $"PostinoVip non è registrato correttamente presso {p.DisplayName} (client ID).",
                    _ => $"Accesso a {p.DisplayName} non riuscito ({error}).",
                });
            }
            var expires = root.TryGetProperty("expires_in", out var exp) && exp.TryGetInt32(out var seconds) ? seconds : 3600;
            return new OAuthTokens(
                access.GetString()!,
                DateTimeOffset.UtcNow.AddSeconds(expires),
                root.TryGetProperty("refresh_token", out var refresh) ? refresh.GetString() : null,
                root.TryGetProperty("id_token", out var id) ? EmailFromIdToken(id.GetString()) : null,
                root.TryGetProperty("scope", out var scope) ? scope.GetString() : null);
        }
    }

    /// <summary>
    /// Indirizzo dall'id_token (JWT): email, altrimenti preferred_username (gli account personali Microsoft spesso non
    /// hanno email). Solo lettura del contenuto: il token arriva direttamente dal fornitore su HTTPS.
    /// </summary>
    public static string? EmailFromIdToken(string? jwt)
    {
        var parts = jwt?.Split('.');
        if (parts is not { Length: >= 2 })
            return null;
        try
        {
            var payload = parts[1].Replace('-', '+').Replace('_', '/');
            payload = payload.PadRight(payload.Length + (4 - payload.Length % 4) % 4, '=');
            var claims = JsonDocument.Parse(Convert.FromBase64String(payload)).RootElement;
            foreach (var name in new[] { "email", "preferred_username", "upn" })
                if (claims.TryGetProperty(name, out var v) && v.GetString() is { } value && value.Contains('@'))
                    return value;
        }
        catch (Exception ex) when (ex is FormatException or JsonException)
        {
        }
        return null;
    }
}
