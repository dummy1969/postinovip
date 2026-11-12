using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using PostinoVip.Core.Dav;
using PostinoVip.Core.Tests;

namespace PostinoVip.Api.Tests;

// G1: un account Gmail (OAuth2) con la sincronizzazione del calendario nel core vero: token Bearer al server CalDAV finto,
// «Verifica calendario» con il token di rinnovo, accesso che chiede anche il permesso del calendario (scelta 2a).
public class GoogleCalDavEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private const string Granted = "openid email https://mail.google.com/ https://www.googleapis.com/auth/calendar";
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-gcaldav-api-" + Guid.NewGuid().ToString("N"));
    private readonly FakeOAuthServer _oauth = new() { Rotate = false, Scope = Granted };
    private readonly FakeCardDavServer _server = new(caldav: true) { AcceptBearer = t => t.StartsWith("AT", StringComparison.Ordinal) };
    private readonly WebApplicationFactory<Program> _factory;

    public GoogleCalDavEndpointTests(WebApplicationFactory<Program> factory)
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
            b.UseSetting("OAuth:Google:CalDavUrl", _server.Url + ".well-known/caldav");
            b.UseSetting("OAuth:Microsoft:ClientId", "id-microsoft");
            b.UseSetting("Accounts:0:Id", "gm");
            b.UseSetting("Accounts:0:Imap:Host", "imap.example.invalid");
            b.UseSetting("Accounts:0:Imap:Username", "io@gmail.com");
            b.UseSetting("Accounts:0:Smtp:Host", "smtp.example.invalid");
            b.UseSetting("Accounts:0:OAuth:Provider", "google");
            b.UseSetting("Accounts:0:OAuth:RefreshToken", "RT0");
            b.UseSetting("Accounts:0:CalDav:Enabled", "true");
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
    public async Task CalendarioDiGoogleSincronizzatoConIlToken()
    {
        _server.Put("s1.ics", FakeCardDavServer.Event("s1", "Dal server"));
        using var client = Client();
        JsonElement status = default;
        await WaitFor(async () =>
        {
            status = await client.GetFromJsonAsync<JsonElement>("/accounts/gm/calendars/sync");
            return status.GetProperty("state").GetString() == "ok";
        });
        var calendars = await client.GetFromJsonAsync<JsonElement>("/accounts/gm/calendars");
        Assert.Contains(calendars.GetProperty("items").EnumerateArray(), c => c.GetProperty("count").GetInt32() == 1);
        Assert.All(_server.Authorizations, a => Assert.StartsWith("Bearer AT", a));
    }

    [Fact]
    public async Task AccessoSenzaIlPermessoDelCalendario()
    {
        _oauth.Scope = "openid email https://mail.google.com/";
        using var client = Client();
        JsonElement status = default;
        await WaitFor(async () =>
        {
            status = await client.GetFromJsonAsync<JsonElement>("/accounts/gm/calendars/sync");
            return status.GetProperty("state").GetString() == "error";
        });
        Assert.Contains("non comprende il calendario", status.GetProperty("error").GetString());
        Assert.Empty(_server.Requests);
    }

    [Fact]
    public async Task VerificaCalendarioConIlTokenDiRinnovo()
    {
        using var client = Client();
        var ok = await (await client.PostAsJsonAsync("/account/test-caldav",
            new { email = "io@gmail.com", host = "imap.gmail.com", oauthProvider = "google", refreshToken = "RT5" })).Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(ok.GetProperty("ok").GetBoolean(), ok.ToString());
        Assert.Equal(["Calendario"], ok.GetProperty("calendars").EnumerateArray().Select(c => c.GetString()));
    }

    [Fact]
    public async Task AccessoConIlCalendarioSoloSeChiesto()
    {
        using var client = Client();
        async Task<string?> Scope(object body)
        {
            var start = await (await client.PostAsJsonAsync("/oauth/start", body)).Content.ReadFromJsonAsync<JsonElement>();
            return System.Web.HttpUtility.ParseQueryString(new Uri(start.GetProperty("authorizationUrl").GetString()!).Query)["scope"];
        }

        Assert.DoesNotContain("auth/calendar", await Scope(new { provider = "google", contacts = true }));
        Assert.EndsWith("https://www.googleapis.com/auth/carddav https://www.googleapis.com/auth/calendar",
            await Scope(new { provider = "google", contacts = true, calendar = true }));
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/oauth/start", new { provider = "microsoft", calendar = true })).StatusCode);
    }

    [Fact]
    public async Task CalendarioDiSolaLetturaNonSiModifica()
    {
        _server.Holidays = true;
        _server.Put("natale.ics", FakeCardDavServer.Event("natale", "Natale"), FakeCardDavServer.HolidaysPath);
        using var client = Client();
        JsonElement holidays = default;
        await WaitFor(async () =>
        {
            var list = await client.GetFromJsonAsync<JsonElement>("/accounts/gm/calendars");
            holidays = list.GetProperty("items").EnumerateArray().FirstOrDefault(c => c.GetProperty("name").GetString() == "Festività");
            return holidays.ValueKind == JsonValueKind.Object && holidays.GetProperty("count").GetInt32() == 1;
        });
        Assert.True(holidays.GetProperty("readOnly").GetBoolean());
        var id = holidays.GetProperty("id").GetString();
        var created = await client.PostAsJsonAsync($"/accounts/gm/calendars/{id}/events",
            new { summary = "x", start = "2026-11-11T10:00", end = "2026-11-11T11:00", timeZone = "Europe/Rome" });
        Assert.Equal(HttpStatusCode.Conflict, created.StatusCode);
        Assert.Contains("sola lettura", await created.Content.ReadAsStringAsync());
        var events = await client.GetFromJsonAsync<JsonElement>("/accounts/gm/calendars/events?from=2026-11-01T00:00:00Z&to=2026-12-01T00:00:00Z");
        var eventId = events.GetProperty("items").EnumerateArray().First(e => e.GetProperty("calendarId").GetString() == id).GetProperty("eventId").GetString();
        Assert.Equal(HttpStatusCode.Conflict, (await client.DeleteAsync($"/accounts/gm/calendars/{id}/events/{eventId}")).StatusCode);
    }
}
