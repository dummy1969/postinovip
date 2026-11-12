using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using PostinoVip.Core.Account;
using PostinoVip.Core.Calendars;
using PostinoVip.Core.Dav;
using PostinoVip.Core.Tests;

namespace PostinoVip.Api.Tests;

// Calendario K2a: calendari e sincronizzazione CalDAV nel core vero (servizio in background, stato, conferma,
// Invia/ricevi, «Verifica calendario») con un server CalDAV finto. Nessun server di posta.
public class CalendarsEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-caldav-api-" + Guid.NewGuid().ToString("N"));
    private readonly FakeCardDavServer _server = new(caldav: true) { SecondCalendar = true };
    private readonly WebApplicationFactory<Program> _factory;

    public CalendarsEndpointTests(WebApplicationFactory<Program> factory)
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
            for (var i = 0; i < 2; i++)
            {
                b.UseSetting($"Accounts:{i}:Id", $"a{i + 1}");
                b.UseSetting($"Accounts:{i}:Imap:Host", "imap.example.invalid");
                b.UseSetting($"Accounts:{i}:Imap:Username", i == 0 ? _server.User : "me2@example.com");
                b.UseSetting($"Accounts:{i}:Imap:Password", i == 0 ? _server.Password : "x");
                b.UseSetting($"Accounts:{i}:Smtp:Host", "smtp.example.invalid");
            }
            b.UseSetting("Accounts:0:CalDav:Enabled", "true");
            b.UseSetting("Accounts:0:CalDav:Url", _server.Url);
        });
    }

    public void Dispose()
    {
        _factory.Dispose();
        _server.Dispose();
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
    public async Task CalendariPrimaVoltaConConfermaEInviaRicevi()
    {
        _server.Put("s1.ics", FakeCardDavServer.Event("s1", "Dal server"));
        // un appuntamento già sul computer prima di attivare CalDAV
        var set = new CalendarSet(Path.Combine(MailAccountRegistry.CacheDirectory(_root, "a1"), "calendars"));
        set.Store(set.Default.Id).SaveLocal(null, FakeCardDavServer.Event("solo", "Solo qui"));
        using var client = Client();

        JsonElement status = default;
        await WaitFor(async () =>
        {
            status = await client.GetFromJsonAsync<JsonElement>("/accounts/a1/calendars/sync");
            return status.GetProperty("state").GetString() == "ok";
        });
        Assert.True(status.GetProperty("enabled").GetBoolean());
        Assert.True(status.GetProperty("needsConfirmation").GetBoolean());
        Assert.Equal(1, status.GetProperty("pendingUpload").GetInt32());
        Assert.Equal("2 calendari", status.GetProperty("addressBook").GetString());

        var list = (await client.GetFromJsonAsync<JsonElement>("/accounts/a1/calendars")).GetProperty("items").EnumerateArray().ToList();
        Assert.Equal(["Calendario", "Lavoro"], list.Select(c => c.GetProperty("name").GetString()));
        Assert.All(list, c => Assert.True(c.GetProperty("synced").GetBoolean()));
        Assert.Equal(2, list[0].GetProperty("count").GetInt32()); // s1 + solo
        Assert.False(_server.Cards.ContainsKey("solo.ics"));

        Assert.Equal(HttpStatusCode.Accepted, (await client.PostAsync("/accounts/a1/calendars/sync/confirm", null)).StatusCode);
        await WaitFor(() => Task.FromResult(_server.Cards.ContainsKey("solo.ics")));

        _server.Put("w1.ics", FakeCardDavServer.Event("w1", "Lavoro"), FakeCardDavServer.SecondCalendarPath);
        Assert.Equal(HttpStatusCode.Accepted, (await client.PostAsync("/accounts/a1/receive", null)).StatusCode);
        await WaitFor(async () =>
            (await client.GetFromJsonAsync<JsonElement>("/accounts/a1/calendars")).GetProperty("items")[1].GetProperty("count").GetInt32() == 1);

        var accounts = await client.GetFromJsonAsync<JsonElement>("/accounts");
        Assert.True(accounts[0].GetProperty("calDav").GetBoolean());
        Assert.False(accounts[1].GetProperty("calDav").GetBoolean());
    }

    [Fact]
    public async Task AccountSenzaCalDavEVerificaCalendario()
    {
        using var client = Client();
        var status = await client.GetFromJsonAsync<JsonElement>("/accounts/a2/calendars/sync");
        Assert.Equal("off", status.GetProperty("state").GetString());
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsync("/accounts/a2/calendars/sync", null)).StatusCode);
        var list = (await client.GetFromJsonAsync<JsonElement>("/accounts/a2/calendars")).GetProperty("items");
        Assert.Equal("Calendario", Assert.Single(list.EnumerateArray()).GetProperty("name").GetString()); // solo sul computer
        Assert.False(list[0].GetProperty("synced").GetBoolean());

        async Task<JsonElement> Test(object body) =>
            await (await client.PostAsJsonAsync("/account/test-caldav", body)).Content.ReadFromJsonAsync<JsonElement>();
        var ok = await Test(new { email = _server.User, password = _server.Password, host = "x", url = _server.Url });
        Assert.True(ok.GetProperty("ok").GetBoolean());
        Assert.Equal(["Calendario", "Lavoro"], ok.GetProperty("calendars").EnumerateArray().Select(c => c.GetString()));
        Assert.DoesNotContain(_server.Requests, r => r.StartsWith("PUT") || r.StartsWith("DELETE"));
        var wrong = await Test(new { email = _server.User, password = "no", host = "x", url = _server.Url });
        Assert.Contains("server del calendario", wrong.GetProperty("error").GetString());
    }

    private static object Riunione(string summary = "Riunione") => new
    {
        summary,
        location = "Sala 1",
        start = "2026-11-10T09:00",
        end = "2026-11-10T10:00",
        timeZone = "Europe/Rome",
        reminderMinutes = 15,
        recurrence = new { frequency = "weekly", days = new[] { "TU" }, count = 3 },
    };

    [Fact]
    public async Task AppuntamentiCreaPeriodoDettaglioModificaElimina()
    {
        using var client = Client();
        var cal = (await client.GetFromJsonAsync<JsonElement>("/accounts/a2/calendars")).GetProperty("items")[0].GetProperty("id").GetString();
        var created = await client.PostAsJsonAsync($"/accounts/a2/calendars/{cal}/events", Riunione());
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var detail = await created.Content.ReadFromJsonAsync<JsonElement>();
        var id = detail.GetProperty("id").GetString();
        Assert.Equal("2026-11-10T09:00", detail.GetProperty("start").GetString());
        Assert.Equal("weekly", detail.GetProperty("recurrence").GetProperty("frequency").GetString());

        var page = await client.GetFromJsonAsync<JsonElement>(
            "/accounts/a2/calendars/events?from=2026-11-01T00:00:00Z&to=2026-12-01T00:00:00Z");
        var items = page.GetProperty("items").EnumerateArray().ToList();
        Assert.Equal(["2026-11-10T08:00:00Z", "2026-11-17T08:00:00Z", "2026-11-24T08:00:00Z"], items.Select(o => o.GetProperty("start").GetString()));
        Assert.All(items, o => Assert.Equal(id, o.GetProperty("eventId").GetString()));
        Assert.False(page.GetProperty("truncated").GetBoolean());

        var put = await client.PutAsJsonAsync($"/accounts/a2/calendars/{cal}/events/{id}", new
        {
            summary = "Riunione spostata", start = "2026-11-10T11:00", end = "2026-11-10T12:00", timeZone = "Europe/Rome",
            reminderMinutes = 15, keepRecurrence = true,
        });
        put.EnsureSuccessStatusCode();
        var got = await client.GetFromJsonAsync<JsonElement>($"/accounts/a2/calendars/{cal}/events/{id}");
        Assert.Equal("Riunione spostata", got.GetProperty("summary").GetString());
        Assert.Equal(JsonValueKind.Null, got.GetProperty("location").ValueKind);
        Assert.Equal(3, got.GetProperty("recurrence").GetProperty("count").GetInt32());

        var bad = await client.PostAsJsonAsync($"/accounts/a2/calendars/{cal}/events", new { summary = "x", start = "2026-11-10T10:00", end = "2026-11-10T09:00" });
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
        Assert.Contains("end", await bad.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/accounts/a2/calendars/{cal}/events/0123456789abcdef")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/accounts/a2/calendars/events?from=2026-11-01T00:00:00Z&to=2026-11-02T00:00:00Z&calendars=ffff")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("/accounts/a2/calendars/events?from=ieri&to=oggi")).StatusCode);

        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/accounts/a2/calendars/{cal}/events/{id}")).StatusCode);
        Assert.Empty((await client.GetFromJsonAsync<JsonElement>("/accounts/a2/calendars/events?from=2026-11-01T00:00:00Z&to=2026-12-01T00:00:00Z"))
            .GetProperty("items").EnumerateArray());
    }

    [Fact]
    public async Task AppuntamentoCreatoNellAppVaSulServerEPoiSiElimina()
    {
        using var client = Client();
        await WaitFor(async () => (await client.GetFromJsonAsync<JsonElement>("/accounts/a1/calendars/sync")).GetProperty("state").GetString() == "ok");
        var cal = (await client.GetFromJsonAsync<JsonElement>("/accounts/a1/calendars")).GetProperty("items")[0].GetProperty("id").GetString();
        var created = await (await client.PostAsJsonAsync($"/accounts/a1/calendars/{cal}/events", Riunione("Dall'app"))).Content.ReadFromJsonAsync<JsonElement>();
        var uid = created.GetProperty("uid").GetString();
        await WaitFor(() => Task.FromResult(_server.Cards.ContainsKey(uid + ".ics")));
        Assert.Contains("SUMMARY:Dall'app", _server.Cards[uid + ".ics"]);
        await client.DeleteAsync($"/accounts/a1/calendars/{cal}/events/{created.GetProperty("id").GetString()}");
        await WaitFor(() => Task.FromResult(!_server.Cards.ContainsKey(uid + ".ics")));
    }

    [Fact]
    public async Task SoloQuestaOccorrenzaDallApi()
    {
        using var client = Client();
        var cal = (await client.GetFromJsonAsync<JsonElement>("/accounts/a2/calendars")).GetProperty("items")[0].GetProperty("id").GetString();
        var id = (await (await client.PostAsJsonAsync($"/accounts/a2/calendars/{cal}/events", Riunione())).Content.ReadFromJsonAsync<JsonElement>())
            .GetProperty("id").GetString();
        const string range = "/accounts/a2/calendars/events?from=2026-11-01T00:00:00Z&to=2026-12-01T00:00:00Z";
        var second = (await client.GetFromJsonAsync<JsonElement>(range)).GetProperty("items")[1].GetProperty("recurrenceId").GetString()!;
        var q = "?recurrenceId=" + Uri.EscapeDataString(second);

        var got = await client.GetFromJsonAsync<JsonElement>($"/accounts/a2/calendars/{cal}/events/{id}/occurrence{q}");
        Assert.Equal("2026-11-17T09:00", got.GetProperty("start").GetString());
        var put = await client.PutAsJsonAsync($"/accounts/a2/calendars/{cal}/events/{id}/occurrence{q}",
            new { summary = "Solo questa", start = "2026-11-17T15:00", end = "2026-11-17T16:00", timeZone = "Europe/Rome" });
        put.EnsureSuccessStatusCode();
        var items = (await client.GetFromJsonAsync<JsonElement>(range)).GetProperty("items").EnumerateArray().ToList();
        Assert.Equal(["Riunione", "Solo questa", "Riunione"], items.Select(o => o.GetProperty("summary").GetString()));

        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/accounts/a2/calendars/{cal}/events/{id}/occurrence{q}")).StatusCode);
        Assert.Equal(2, (await client.GetFromJsonAsync<JsonElement>(range)).GetProperty("items").GetArrayLength());
        Assert.Equal(HttpStatusCode.BadRequest, (await client.DeleteAsync($"/accounts/a2/calendars/{cal}/events/{id}/occurrence")).StatusCode);
    }
}
