using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using PostinoVip.Core.Dav;
using PostinoVip.Core.Tests;

namespace PostinoVip.Api.Tests;

// C4d: un account Gmail (OAuth2) con la sincronizzazione dei contatti nel core vero: token Bearer al server CardDAV
// finto, «Verifica rubrica» con il token di rinnovo, accesso che chiede anche il permesso dei contatti (scelta 1a).
public class GoogleCardDavEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private const string Granted = "openid email https://mail.google.com/ https://www.googleapis.com/auth/carddav";
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-gcarddav-api-" + Guid.NewGuid().ToString("N"));
    private readonly FakeOAuthServer _oauth = new() { Rotate = false, Scope = Granted };
    private readonly FakeCardDavServer _server = new() { AcceptBearer = t => t.StartsWith("AT", StringComparison.Ordinal) };
    private readonly WebApplicationFactory<Program> _factory;

    public GoogleCardDavEndpointTests(WebApplicationFactory<Program> factory)
    {
        DavWorker.Debounce = TimeSpan.FromMilliseconds(10);
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", ApiTests.Token);
            b.UseSetting("Watch:Enabled", "false");
            b.UseSetting("Pop3:Enabled", "false");
            b.UseSetting("Rules:Enabled", "false");
            b.UseSetting("Outbox:Enabled", "false");
            b.UseSetting("Cache:Download:Enabled", "false");
            b.UseSetting("Cache:Directory", _root);
            b.UseSetting("OAuth:Google:ClientId", "id-google");
            b.UseSetting("OAuth:Google:ClientSecret", "segreto-desktop");
            b.UseSetting("OAuth:Google:TokenEndpoint", _oauth.TokenEndpoint);
            b.UseSetting("OAuth:Google:CardDavUrl", _server.Url + ".well-known/carddav");
            b.UseSetting("OAuth:Microsoft:ClientId", "id-microsoft");
            b.UseSetting("Accounts:0:Id", "gm");
            b.UseSetting("Accounts:0:Imap:Host", "imap.example.invalid");
            b.UseSetting("Accounts:0:Imap:Username", "io@gmail.com");
            b.UseSetting("Accounts:0:Smtp:Host", "smtp.example.invalid");
            b.UseSetting("Accounts:0:OAuth:Provider", "google");
            b.UseSetting("Accounts:0:OAuth:RefreshToken", "RT0");
            b.UseSetting("Accounts:0:CardDav:Enabled", "true");
        });
    }

    public void Dispose()
    {
        _factory.Dispose();
        _server.Dispose();
        _oauth.Dispose();
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_root))
            Directory.Delete(_root, recursive: true);
    }

    private HttpClient Client()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ApiTests.Token);
        return client;
    }

    private static async Task WaitFor(Func<Task<bool>> condition)
    {
        for (var i = 0; i < 200; i++)
        {
            if (await condition())
                return;
            await Task.Delay(25);
        }
        Assert.True(await condition());
    }

    [Fact]
    public async Task RubricaDiGoogleSincronizzataConIlToken()
    {
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com"));
        using var client = Client();
        JsonElement status = default;
        await WaitFor(async () =>
        {
            status = await client.GetFromJsonAsync<JsonElement>("/accounts/gm/contacts/sync");
            return status.GetProperty("state").GetString() == "ok";
        });
        Assert.Equal("Contatti", status.GetProperty("addressBook").GetString());
        Assert.Single((await client.GetFromJsonAsync<JsonElement>("/accounts/gm/contacts")).GetProperty("items").EnumerateArray());
        Assert.All(_server.Authorizations, a => Assert.StartsWith("Bearer AT", a));
    }

    [Fact]
    public async Task AccessoSenzaIlPermessoDeiContatti()
    {
        _oauth.Scope = "openid email https://mail.google.com/";
        using var client = Client();
        JsonElement status = default;
        await WaitFor(async () =>
        {
            status = await client.GetFromJsonAsync<JsonElement>("/accounts/gm/contacts/sync");
            return status.GetProperty("state").GetString() == "error";
        });
        Assert.Contains("non comprende i contatti", status.GetProperty("error").GetString());
        Assert.Empty(_server.Requests);
    }

    [Fact]
    public async Task VerificaRubricaConIlTokenDiRinnovo()
    {
        using var client = Client();
        async Task<JsonElement> Test(object body) =>
            await (await client.PostAsJsonAsync("/account/test-carddav", body)).Content.ReadFromJsonAsync<JsonElement>();

        var ok = await Test(new { email = "io@gmail.com", host = "imap.gmail.com", oauthProvider = "google", refreshToken = "RT5" });
        Assert.True(ok.GetProperty("ok").GetBoolean(), ok.ToString());
        Assert.Equal("Contatti", ok.GetProperty("addressBook").GetString());
        Assert.Contains(_oauth.Requests, r => r.GetValueOrDefault("refresh_token") == "RT5");

        var revoked = await Test(new { email = "io@gmail.com", host = "imap.gmail.com", oauthProvider = "google", refreshToken = "revoked" });
        Assert.False(revoked.GetProperty("ok").GetBoolean());
        Assert.Contains("scaduto o revocato", revoked.GetProperty("error").GetString());

        var microsoft = await Test(new { email = "io@outlook.it", host = "outlook.office365.com", oauthProvider = "microsoft", refreshToken = "x" });
        Assert.Contains("Non ancora disponibile", microsoft.GetProperty("error").GetString());

        var caldav = await (await client.PostAsJsonAsync("/account/test-caldav",
            new { email = "io@outlook.it", host = "outlook.office365.com", oauthProvider = "microsoft", refreshToken = "x" })).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Contains("Non ancora disponibile", caldav.GetProperty("error").GetString());
    }

    [Fact]
    public async Task AccessoConIContattiSoloSeChiesto()
    {
        using var client = Client();
        async Task<string?> Scope(object body)
        {
            var start = await (await client.PostAsJsonAsync("/oauth/start", body)).Content.ReadFromJsonAsync<JsonElement>();
            return System.Web.HttpUtility.ParseQueryString(new Uri(start.GetProperty("authorizationUrl").GetString()!).Query)["scope"];
        }

        Assert.DoesNotContain("carddav", await Scope(new { provider = "google" }));
        Assert.Contains("https://www.googleapis.com/auth/carddav", await Scope(new { provider = "google", contacts = true }));
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/oauth/start", new { provider = "microsoft", contacts = true })).StatusCode);
    }
}
