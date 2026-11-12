using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Configuration;
using PostinoVip.Core.Account;
using PostinoVip.Core.Contacts;
using PostinoVip.Core.Contacts.CardDav;
using PostinoVip.Core.Dav;
using PostinoVip.Core.Tests;

namespace PostinoVip.Api.Tests;

// Contatti C4b: sincronizzazione CardDAV nel core vero (servizio in background, stato, conferma, Invia/ricevi) con un
// server CardDAV finto. Nessun server di posta.
public class CardDavEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-carddav-api-" + Guid.NewGuid().ToString("N"));
    private readonly FakeCardDavServer _server = new();
    private readonly WebApplicationFactory<Program> _factory;

    public CardDavEndpointTests(WebApplicationFactory<Program> factory)
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
            b.UseSetting("Accounts:0:CardDav:Enabled", "true");
            b.UseSetting("Accounts:0:CardDav:Url", _server.Url);
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
    public async Task PrimaVoltaConConfermaPoiModificheDallApp()
    {
        _server.Put("a.vcf", FakeCardDavServer.Card("uid-a", "Anna", "Bianchi", "anna@example.com"));
        // un contatto già sul computer prima di attivare CardDAV
        new ContactStore(Path.Combine(MailAccountRegistry.CacheDirectory(_root, "a1"), "contacts"))
            .Create(new Contact("", "Carla", "Neri", null, [new ContactEmail("carla@example.com")], [], null, null));
        using var client = Client();

        JsonElement status = default;
        await WaitFor(async () =>
        {
            status = await client.GetFromJsonAsync<JsonElement>("/accounts/a1/contacts/sync");
            return status.GetProperty("state").GetString() == "ok";
        });
        Assert.True(status.GetProperty("enabled").GetBoolean());
        Assert.True(status.GetProperty("needsConfirmation").GetBoolean());
        Assert.Equal(1, status.GetProperty("pendingUpload").GetInt32());
        Assert.Equal("Contatti", status.GetProperty("addressBook").GetString());
        Assert.Equal(2, (await client.GetFromJsonAsync<JsonElement>("/accounts/a1/contacts")).GetProperty("items").GetArrayLength());
        Assert.Single(_server.Cards);

        Assert.Equal(HttpStatusCode.Accepted, (await client.PostAsync("/accounts/a1/contacts/sync/confirm", null)).StatusCode);
        await WaitFor(() => Task.FromResult(_server.Cards.Count == 2));

        // un contatto nuovo nell'app va subito sul server (4a)
        var created = await client.PostAsJsonAsync("/accounts/a1/contacts",
            new { givenName = "Dario", emails = new[] { new { address = "dario@example.com" } } });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        await WaitFor(() => Task.FromResult(_server.Cards.Count == 3));

        // un contatto nuovo sul server arriva con Invia/ricevi (F9)
        _server.Put("e.vcf", FakeCardDavServer.Card("uid-e", "Elena", "Blu", "elena@example.com"));
        Assert.Equal(HttpStatusCode.Accepted, (await client.PostAsync("/accounts/a1/receive", null)).StatusCode);
        await WaitFor(async () =>
            (await client.GetFromJsonAsync<JsonElement>("/accounts/a1/contacts")).GetProperty("items").GetArrayLength() == 4);
        Assert.False((await client.GetFromJsonAsync<JsonElement>("/accounts/a1/contacts/sync")).GetProperty("needsConfirmation").GetBoolean());
        Assert.True(File.Exists(Path.Combine(MailAccountRegistry.CacheDirectory(_root, "a1"), "carddav.json")));
    }

    [Fact]
    public async Task AccountSenzaCardDav()
    {
        using var client = Client();
        var status = await client.GetFromJsonAsync<JsonElement>("/accounts/a2/contacts/sync");
        Assert.False(status.GetProperty("enabled").GetBoolean());
        Assert.Equal("off", status.GetProperty("state").GetString());
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsync("/accounts/a2/contacts/sync", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsync("/accounts/a2/contacts/sync/confirm", null)).StatusCode);
    }

    [Fact]
    public async Task VerificaRubricaPrimaDiSalvare()
    {
        using var client = Client();
        async Task<JsonElement> Test(object body) =>
            await (await client.PostAsJsonAsync("/account/test-carddav", body)).Content.ReadFromJsonAsync<JsonElement>();

        var ok = await Test(new { email = _server.User, password = _server.Password, host = "ignorato.invalid", url = _server.Url });
        Assert.True(ok.GetProperty("ok").GetBoolean());
        Assert.Equal("Contatti", ok.GetProperty("addressBook").GetString());
        Assert.EndsWith(FakeCardDavServer.BookPath, ok.GetProperty("url").GetString());
        Assert.DoesNotContain(_server.Requests, r => r.StartsWith("PUT") || r.StartsWith("DELETE")); // sola lettura

        var wrong = await Test(new { email = _server.User, password = "sbagliata", host = "x", url = _server.Url });
        Assert.False(wrong.GetProperty("ok").GetBoolean());
        Assert.Contains("password", wrong.GetProperty("error").GetString());

        var http = await Test(new { email = "a@b.c", password = "x", host = "x", url = "http://dav.example.com/" });
        Assert.Contains("https", http.GetProperty("error").GetString());

        var missing = await client.PostAsJsonAsync("/account/test-carddav", new { email = "a@b.c", password = "", host = "x" });
        Assert.Equal(HttpStatusCode.BadRequest, missing.StatusCode);
    }

    [Fact]
    public void ImpostazioniEIndirizzoNonAmmesso()
    {
        IConfiguration Config(string url) => new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Accounts:0:Id"] = "a",
            ["Accounts:0:Imap:Host"] = "imap.example.com",
            ["Accounts:0:Imap:Username"] = "me@example.com",
            ["Accounts:0:Imap:Password"] = "x",
            ["Accounts:0:Smtp:Host"] = "smtp.example.com",
            ["Accounts:0:CardDav:Enabled"] = "true",
            ["Accounts:0:CardDav:Url"] = url,
        }).Build();
        var s = AccountsConfiguration.Read(Config("https://dav.example.com/"));
        Assert.True(s[0].CardDav.Enabled);
        Assert.Equal("https://dav.example.com/", s[0].CardDav.Url);
        // la password andrebbe in chiaro: il core non parte
        var ex = Assert.Throws<ArgumentException>(() => AccountsConfiguration.Read(Config("http://dav.example.com/")));
        Assert.Contains("https", ex.Message);
        Assert.Throws<ArgumentException>(() => AccountsConfiguration.Read(Config("non un indirizzo")));
    }
}
