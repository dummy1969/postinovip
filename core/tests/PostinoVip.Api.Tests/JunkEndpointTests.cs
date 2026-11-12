using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using PostinoVip.Core.Account;
using PostinoVip.Core.Local;

namespace PostinoVip.Api.Tests;

/// <summary>J1: opzioni e comandi della posta indesiderata su un account POP3 (tutto sul computer, nessuna rete).</summary>
public sealed class JunkEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private const string Junk = "Posta indesiderata";
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-junk-api-" + Guid.NewGuid().ToString("N"));
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;
    private readonly LocalMailStore _store;

    public JunkEndpointTests(WebApplicationFactory<Program> factory)
    {
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
            b.UseSetting("Accounts:0:Id", "pop");
            b.UseSetting("Accounts:0:Type", "Pop3");
            b.UseSetting("Accounts:0:Pop3:Host", "pop.example.invalid");
            b.UseSetting("Accounts:0:Pop3:Username", "me@example.com");
            b.UseSetting("Accounts:0:Pop3:Password", "x");
            b.UseSetting("Accounts:0:Smtp:Host", "smtp.example.invalid");
        });
        _client = _factory.CreateClient();
        _client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ApiTests.Token);
        _store = new LocalMailStore(Path.Combine(MailAccountRegistry.CacheDirectory(_root, "pop"), "mail"));
        _store.EnsureDefaults();
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_root))
            Directory.Delete(_root, recursive: true);
    }

    private Task<uint> AddAsync(string from, string subject) =>
        _store.AddAsync("INBOX", new MemoryStream(Encoding.UTF8.GetBytes(
            $"From: {from}\r\nTo: me@example.com\r\nSubject: {subject}\r\nDate: Mon, 02 Nov 2026 10:00:00 +0100\r\n\r\ntesto\r\n")));

    private async Task<List<string?>> SubjectsAsync(string folder) =>
        (await _client.GetFromJsonAsync<JsonElement>($"/accounts/pop/folders/{Uri.EscapeDataString(folder)}/messages?limit=50"))
        .GetProperty("items").EnumerateArray().Select(m => m.GetProperty("subject").GetString()).Order().ToList();

    [Fact]
    public async Task OpzioniDiSerieESalvataggioControllato()
    {
        var options = await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/junk");
        Assert.Equal("None", options.GetProperty("level").GetString());
        Assert.Equal(Junk, options.GetProperty("junkFolder").GetString());
        Assert.True(options.GetProperty("trustContacts").GetBoolean());

        var saved = await _client.PutAsJsonAsync("/accounts/pop/junk", new { level = "High", blockedSenders = new[] { "Spam.Example" } });
        Assert.Equal(HttpStatusCode.OK, saved.StatusCode);
        var body = await saved.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("High", body.GetProperty("level").GetString());
        Assert.Equal("@spam.example", body.GetProperty("blockedSenders")[0].GetString());

        var badEntry = await _client.PutAsJsonAsync("/accounts/pop/junk", new { safeSenders = new[] { "non valido" } });
        Assert.Equal(HttpStatusCode.BadRequest, badEntry.StatusCode);
        Assert.Contains("safeSenders", await badEntry.Content.ReadAsStringAsync());
        foreach (var folder in new[] { "Non esiste", "INBOX" })
        {
            var bad = await _client.PutAsJsonAsync("/accounts/pop/junk", new { folder });
            Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
            Assert.Contains("\"folder\"", await bad.Content.ReadAsStringAsync());
        }
        Assert.Equal("High", (await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/junk")).GetProperty("level").GetString());
    }

    [Fact]
    public async Task CartellaSceltaHaIlRuoloNellElencoDelleCartelle()
    {
        _store.CreateFolder("Scarti");
        var saved = await _client.PutAsJsonAsync("/accounts/pop/junk", new { folder = "Scarti" });
        Assert.Equal(HttpStatusCode.OK, saved.StatusCode);
        Assert.Equal("Scarti", (await saved.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("junkFolder").GetString());

        var folders = await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/folders");
        string? Role(string name) => folders.EnumerateArray().Single(f => f.GetProperty("fullName").GetString() == name)
            .GetProperty("specialUse").GetString();
        Assert.Equal("junk", Role("Scarti"));
        Assert.Null(Role(Junk));
    }

    [Fact]
    public async Task BloccaENonEPostaIndesiderata()
    {
        var uid = await AddAsync("Anna <anna@fornitore.it>", "Offerta");
        await SubjectsAsync("INBOX");

        var blocked = await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/block", new { uids = new[] { uid } });
        Assert.Equal(HttpStatusCode.OK, blocked.StatusCode);
        var result = await blocked.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("anna@fornitore.it", result.GetProperty("entries")[0].GetString());
        Assert.Equal(Junk, result.GetProperty("folder").GetString());
        Assert.Equal(["Offerta"], await SubjectsAsync(Junk));

        var inJunk = (await _client.GetFromJsonAsync<JsonElement>($"/accounts/pop/folders/{Uri.EscapeDataString(Junk)}/messages"))
            .GetProperty("items")[0].GetProperty("uid").GetUInt32();
        var wrong = await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/not-junk", new { uids = new[] { inJunk } });
        Assert.Equal(HttpStatusCode.Conflict, wrong.StatusCode);
        var back = await _client.PostAsJsonAsync($"/accounts/pop/messages/{Uri.EscapeDataString(Junk)}/not-junk",
            new { uids = new[] { inJunk }, trustSenders = true });
        Assert.Equal(HttpStatusCode.OK, back.StatusCode);
        Assert.Equal(["Offerta"], await SubjectsAsync("INBOX"));

        var options = await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/junk");
        Assert.Equal(0, options.GetProperty("blockedSenders").GetArrayLength());
        Assert.Equal("anna@fornitore.it", options.GetProperty("safeSenders")[0].GetString());
    }

    [Fact]
    public async Task RichiesteNonValide()
    {
        var uid = await AddAsync("anna@fornitore.it", "Prova");
        await SubjectsAsync("INBOX");
        Assert.Equal(HttpStatusCode.BadRequest, (await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/block", new { })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,
            (await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/never-block", new { uids = new[] { uid } })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,
            (await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/block", new { uids = new[] { 999u } })).StatusCode);

        var ok = await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/never-block", new { uids = new[] { uid }, kind = "Domain" });
        Assert.Equal(HttpStatusCode.OK, ok.StatusCode);
        Assert.Equal("@fornitore.it", (await ok.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("entries")[0].GetString());
        Assert.Equal(["Prova"], await SubjectsAsync("INBOX"));
    }
}
