using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using PostinoVip.Core.OAuth;
using PostinoVip.Core.Tests;

namespace PostinoVip.Api.Tests;

/// <summary>Flusso di accesso OAuth2 (O1) attraverso gli endpoint, con il fornitore finto.</summary>
public class OAuthEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly FakeOAuthServer _oauth = new();
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public OAuthEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", ApiTests.Token);
            b.UseSetting("Watch:Enabled", "false");
            b.UseSetting("Cache:Enabled", "false");
            b.UseSetting("Imap:Host", "imap.example.invalid");
            b.UseSetting("Smtp:Host", "smtp.example.invalid");
            b.UseSetting("OAuth:Microsoft:ClientId", "client-di-prova");
            b.UseSetting("OAuth:Microsoft:TokenEndpoint", _oauth.TokenEndpoint);
            b.UseSetting("OAuth:Microsoft:AuthorizationEndpoint", "https://login.example/authorize");
        });
        _client = _factory.CreateClient();
        _client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ApiTests.Token);
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
        _oauth.Dispose();
    }

    [Fact]
    public async Task AccessoCompletoConPkceETokenConsegnatoUnaVolta()
    {
        var providers = await _client.GetFromJsonAsync<JsonElement>("/oauth/providers");
        Assert.Contains(providers.EnumerateArray(), p => p.GetProperty("id").GetString() == "microsoft" && p.GetProperty("configured").GetBoolean());

        var start = await (await _client.PostAsJsonAsync("/oauth/start", new { provider = "microsoft", loginHint = "io@outlook.it" }))
            .Content.ReadFromJsonAsync<JsonElement>();
        var id = start.GetProperty("id").GetString()!;
        var url = new Uri(start.GetProperty("authorizationUrl").GetString()!);
        var q = System.Web.HttpUtility.ParseQueryString(url.Query);
        Assert.StartsWith("http://localhost:", q["redirect_uri"]);
        Assert.EndsWith("/oauth/callback", q["redirect_uri"]);
        Assert.Equal("pending", (await _client.GetFromJsonAsync<JsonElement>($"/oauth/flows/{id}")).GetProperty("status").GetString());

        // Il browser torna senza token: vale lo state.
        using var browser = _factory.CreateClient();
        var page = await browser.GetAsync($"/oauth/callback?code=good-code&state={Uri.EscapeDataString(q["state"]!)}");
        Assert.Equal(HttpStatusCode.OK, page.StatusCode);
        Assert.Contains("Accesso riuscito", await page.Content.ReadAsStringAsync());

        var exchange = _oauth.Requests.Single();
        Assert.Equal(q["code_challenge"], Pkce.Challenge(exchange["code_verifier"])); // PKCE: il verificatore giusto
        Assert.Equal(q["redirect_uri"], exchange["redirect_uri"]);

        var done = await _client.GetFromJsonAsync<JsonElement>($"/oauth/flows/{id}");
        Assert.Equal(("done", "RT1", "io@outlook.it"), (done.GetProperty("status").GetString(), done.GetProperty("refreshToken").GetString(),
            done.GetProperty("email").GetString()));
        Assert.Equal("outlook.office365.com", done.GetProperty("servers").GetProperty("imapHost").GetString());
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/oauth/flows/{id}")).StatusCode); // consegnato una volta

        // Lo stesso state non vale due volte.
        var again = await browser.GetAsync($"/oauth/callback?code=good-code&state={Uri.EscapeDataString(q["state"]!)}");
        Assert.Equal(HttpStatusCode.BadRequest, again.StatusCode);
    }

    [Fact]
    public async Task StateSbagliatoAnnullatoETokenObbligatorioAltrove()
    {
        using var browser = _factory.CreateClient();
        Assert.Equal(HttpStatusCode.BadRequest, (await browser.GetAsync("/oauth/callback?code=good-code&state=inventato")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await browser.GetAsync("/oauth/providers")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await browser.PostAsJsonAsync("/oauth/start", new { provider = "microsoft" })).StatusCode);
        Assert.Empty(_oauth.Requests);

        var start = await (await _client.PostAsJsonAsync("/oauth/start", new { provider = "microsoft" })).Content.ReadFromJsonAsync<JsonElement>();
        var state = System.Web.HttpUtility.ParseQueryString(new Uri(start.GetProperty("authorizationUrl").GetString()!).Query)["state"]!;
        var denied = await browser.GetAsync($"/oauth/callback?error=access_denied&state={Uri.EscapeDataString(state)}");
        Assert.Contains("annullato", await denied.Content.ReadAsStringAsync());
        var status = await _client.GetFromJsonAsync<JsonElement>($"/oauth/flows/{start.GetProperty("id").GetString()}");
        Assert.Equal(("error", "Accesso annullato."), (status.GetProperty("status").GetString(), status.GetProperty("error").GetString()));

        Assert.Equal(HttpStatusCode.BadRequest, (await _client.PostAsJsonAsync("/oauth/start", new { provider = "boh" })).StatusCode);
    }

    [Fact]
    public async Task ProvaDellAccountConTokenDiRinnovo()
    {
        var resp = await _client.PostAsJsonAsync("/account/test", new
        {
            email = "io@outlook.it", password = "", oauthProvider = "microsoft", refreshToken = "revoked",
            imapHost = "127.0.0.1", imapPort = 1, smtpHost = "127.0.0.1", smtpPort = 1,
        });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var json = await resp.Content.ReadFromJsonAsync<JsonElement>();
        // Il server è irraggiungibile (porta 1): l'errore è di collegamento, prima ancora di chiedere il token.
        Assert.False(json.GetProperty("imap").GetProperty("ok").GetBoolean());

        var noPassword = await _client.PostAsJsonAsync("/account/test", new
        {
            email = "io@outlook.it", password = "", imapHost = "h", imapPort = 993, smtpHost = "h", smtpPort = 587,
        });
        Assert.Equal(HttpStatusCode.BadRequest, noPassword.StatusCode);
    }
}

/// <summary>Senza client ID: il pulsante non va mostrato e l'accesso non parte.</summary>
/// <summary>Accesso scaduto (2a, 05/11/2026): GET /accounts con needsLogin e Google tra i fornitori.</summary>
public class OAuthNeedsLoginTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly FakeOAuthServer _oauth = new();
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public OAuthNeedsLoginTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", ApiTests.Token);
            b.UseSetting("Watch:Enabled", "false");
            b.UseSetting("Cache:Enabled", "false");
            b.UseSetting("OAuth:Google:ClientId", "id-google");
            b.UseSetting("OAuth:Google:ClientSecret", "segreto-desktop");
            b.UseSetting("OAuth:Google:TokenEndpoint", _oauth.TokenEndpoint);
            b.UseSetting("Accounts:0:Id", "gm");
            b.UseSetting("Accounts:0:Imap:Host", "imap.example.invalid");
            b.UseSetting("Accounts:0:Imap:Username", "io@gmail.com");
            b.UseSetting("Accounts:0:Smtp:Host", "smtp.example.invalid");
            b.UseSetting("Accounts:0:OAuth:Provider", "google");
            b.UseSetting("Accounts:0:OAuth:RefreshToken", "revoked");
        });
        _client = _factory.CreateClient();
        _client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ApiTests.Token);
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
        _oauth.Dispose();
    }

    [Fact]
    public async Task TokenRifiutatoNeedsLoginInAccounts()
    {
        var providers = await _client.GetFromJsonAsync<JsonElement>("/oauth/providers");
        Assert.Contains(providers.EnumerateArray(), p => p.GetProperty("id").GetString() == "google" && p.GetProperty("configured").GetBoolean());

        var before = await _client.GetFromJsonAsync<JsonElement>("/accounts");
        Assert.False(before[0].GetProperty("needsLogin").GetBoolean());

        var registry = (PostinoVip.Core.Account.MailAccountRegistry)_factory.Services.GetService(typeof(PostinoVip.Core.Account.MailAccountRegistry))!;
        var settings = registry.Get("gm").Settings;
        await Assert.ThrowsAsync<OAuthException>(() => settings.Imap.AccessToken!(default));

        var after = await _client.GetFromJsonAsync<JsonElement>("/accounts");
        Assert.True(after[0].GetProperty("needsLogin").GetBoolean());
        var hub = (PostinoVip.Core.Events.MailboxEventHub)_factory.Services.GetService(typeof(PostinoVip.Core.Events.MailboxEventHub))!;
        using var sub = hub.Subscribe();
        Assert.True(sub.Reader.TryRead(out var e)); // ripetuto a chi si iscrive dopo
        Assert.Equal(("login-status", "gm", true), (e!.Type, e.Account, e.NeedsLogin));
    }
}

public class OAuthWithoutClientIdTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public OAuthWithoutClientIdTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", ApiTests.Token);
            b.UseSetting("Watch:Enabled", "false");
            b.UseSetting("Cache:Enabled", "false");
            b.UseSetting("Imap:Host", "imap.example.invalid");
            b.UseSetting("Smtp:Host", "smtp.example.invalid");
        });
        _client = _factory.CreateClient();
        _client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ApiTests.Token);
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
    }

    [Fact]
    public async Task NessunClientIdNessunAccesso()
    {
        var providers = await _client.GetFromJsonAsync<JsonElement>("/oauth/providers");
        Assert.False(providers.EnumerateArray().Single(p => p.GetProperty("id").GetString() == "microsoft").GetProperty("configured").GetBoolean());
        var start = await _client.PostAsJsonAsync("/oauth/start", new { provider = "microsoft" });
        Assert.Equal(HttpStatusCode.Conflict, start.StatusCode);
        Assert.Contains("client ID", await start.Content.ReadAsStringAsync());
    }
}
