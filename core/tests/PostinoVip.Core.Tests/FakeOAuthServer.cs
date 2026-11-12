using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace PostinoVip.Core.Tests;

/// <summary>
/// Server dei token OAuth2 finto su 127.0.0.1 (solo HTTP, solo per i test). Codice "good-code" -> token; rinnovo:
/// ogni volta un token di accesso nuovo e (con <see cref="Rotate"/>) un token di rinnovo nuovo; "revoked" -> invalid_grant.
/// Registra le richieste ricevute (per controllare PKCE e parametri).
/// </summary>
public sealed class FakeOAuthServer : IDisposable
{
    private readonly HttpListener _listener = new();
    private readonly CancellationTokenSource _stop = new();
    private int _issued;

    public FakeOAuthServer()
    {
        var port = FreePort();
        Url = $"http://127.0.0.1:{port}/";
        _listener.Prefixes.Add(Url);
        _listener.Start();
        _ = Task.Run(LoopAsync);
    }

    public string Url { get; }
    public string TokenEndpoint => Url + "token";
    public ConcurrentQueue<Dictionary<string, string>> Requests { get; } = new();
    public bool Rotate { get; set; } = true;

    /// <summary>Token di rinnovo rifiutati con invalid_grant (oltre a "revoked"): si può cambiare durante la prova.</summary>
    public string? Revoked { get; set; }
    public string Email { get; set; } = "io@outlook.it";

    /// <summary>Campo "scope" delle risposte (permessi concessi); null = assente, come prima del C4d.</summary>
    public string? Scope { get; set; }

    public static string IdToken(string email)
    {
        static string B64(string s) => Convert.ToBase64String(Encoding.UTF8.GetBytes(s)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        return $"{B64("{\"alg\":\"none\"}")}.{B64(JsonSerializer.Serialize(new { preferred_username = email }))}.";
    }

    private async Task LoopAsync()
    {
        while (!_stop.IsCancellationRequested)
        {
            HttpListenerContext ctx;
            try { ctx = await _listener.GetContextAsync(); }
            catch { return; }
            using var reader = new StreamReader(ctx.Request.InputStream);
            var form = (await reader.ReadToEndAsync()).Split('&', StringSplitOptions.RemoveEmptyEntries)
                .Select(p => p.Split('=', 2)).ToDictionary(p => WebUtility.UrlDecode(p[0]), p => WebUtility.UrlDecode(p.Length > 1 ? p[1] : ""));
            Requests.Enqueue(form);
            object body;
            var status = 200;
            var n = Interlocked.Increment(ref _issued);
            switch (form.GetValueOrDefault("grant_type"))
            {
                case "authorization_code" when form.GetValueOrDefault("code") == "good-code":
                    body = new { access_token = $"AT{n}", expires_in = 3600, refresh_token = "RT1", id_token = IdToken(Email), scope = Scope };
                    break;
                case "refresh_token" when form.GetValueOrDefault("refresh_token") is { } rt && rt != "revoked" && rt != Revoked:
                    body = Rotate
                        ? new { access_token = $"AT{n}", expires_in = 3600, refresh_token = $"RT{n}", scope = Scope }
                        : new { access_token = $"AT{n}", expires_in = 3600, refresh_token = rt, scope = Scope };
                    break;
                default:
                    status = 400;
                    body = new { error = "invalid_grant", error_description = "scaduto" };
                    break;
            }
            var bytes = JsonSerializer.SerializeToUtf8Bytes(body);
            ctx.Response.StatusCode = status;
            ctx.Response.ContentType = "application/json";
            await ctx.Response.OutputStream.WriteAsync(bytes);
            ctx.Response.Close();
        }
    }

    private static int FreePort()
    {
        var l = new TcpListener(IPAddress.Loopback, 0);
        l.Start();
        var port = ((IPEndPoint)l.LocalEndpoint).Port;
        l.Stop();
        return port;
    }

    public void Dispose()
    {
        _stop.Cancel();
        _listener.Close();
    }
}
