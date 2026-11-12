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

/// <summary>C1: Ignora conversazione e Pulisci su un account POP3 (tutto sul computer, nessuna rete).</summary>
public sealed class ConversationToolsEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-conv-api-" + Guid.NewGuid().ToString("N"));
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;
    private readonly LocalMailStore _store;

    public ConversationToolsEndpointTests(WebApplicationFactory<Program> factory)
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

    private async Task<uint> AddAsync(string id, string body, string? parent = null)
    {
        var reply = parent is null ? "" : $"In-Reply-To: <{parent}@x>\r\nReferences: <{parent}@x>\r\n";
        var uid = await _store.AddAsync("INBOX", new MemoryStream(Encoding.UTF8.GetBytes(
            $"From: anna@fornitore.it\r\nTo: me@example.com\r\nSubject: {id}\r\nMessage-ID: <{id}@x>\r\n{reply}" +
            $"Date: Mon, 02 Nov 2026 10:00:00 +0100\r\n\r\n{body}\r\n")));
        await MessagesAsync("INBOX");
        await _client.PutAsJsonAsync($"/accounts/pop/messages/INBOX/{uid}/seen", new { seen = true });
        return uid;
    }

    private async Task<List<string?>> SubjectsAsync(string folder) =>
        (await MessagesAsync(folder)).Select(m => m.GetProperty("subject").GetString()).Order().ToList();

    private async Task<List<JsonElement>> MessagesAsync(string folder) =>
        (await _client.GetFromJsonAsync<JsonElement>($"/accounts/pop/folders/{Uri.EscapeDataString(folder)}/messages?limit=50"))
        .GetProperty("items").EnumerateArray().ToList();

    private async Task<bool> IgnoredAsync(string folder, uint uid) =>
        (await _client.GetFromJsonAsync<JsonElement>($"/accounts/pop/messages/{Uri.EscapeDataString(folder)}/{uid}/ignored"))
        .GetProperty("ignored").GetBoolean();

    [Fact]
    public async Task IgnoraEInterrompiIgnora()
    {
        var a = await AddAsync("a", "Domanda");
        await AddAsync("b", "Risposta", parent: "a");
        await AddAsync("c", "Altro");
        Assert.False(await IgnoredAsync("INBOX", a));
        Assert.Equal(HttpStatusCode.BadRequest,
            (await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/ignore", new { uids = Array.Empty<uint>() })).StatusCode);

        var done = await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/ignore", new { uids = new[] { a } });
        Assert.Equal(HttpStatusCode.OK, done.StatusCode);
        var result = await done.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Posta eliminata", result.GetProperty("movedTo").GetString());
        Assert.Equal(2, result.GetProperty("uids").GetArrayLength());
        Assert.Equal(["c"], await SubjectsAsync("INBOX"));
        var trashed = await MessagesAsync("Posta eliminata");
        var first = trashed[0].GetProperty("uid").GetUInt32();
        Assert.True(await IgnoredAsync("Posta eliminata", first));

        var c = (await MessagesAsync("INBOX"))[0].GetProperty("uid").GetUInt32();
        Assert.Equal(HttpStatusCode.Conflict,
            (await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/stop-ignoring", new { uids = new[] { c } })).StatusCode);
        var back = await _client.PostAsJsonAsync("/accounts/pop/messages/Posta%20eliminata/stop-ignoring", new { uids = new[] { first } });
        Assert.Equal(HttpStatusCode.OK, back.StatusCode);
        Assert.Equal(["a", "b", "c"], await SubjectsAsync("INBOX"));
    }

    [Fact]
    public async Task PulisciConversazioneECartella()
    {
        await AddAsync("a", "Prima domanda");
        var b = await AddAsync("b", "Risposta\r\n> Prima domanda", parent: "a");
        await AddAsync("x", "Altra domanda");
        await AddAsync("y", "Altra risposta\r\n> Altra domanda", parent: "x");

        var one = await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/clean-up", new { uids = new[] { b } });
        Assert.Equal(HttpStatusCode.OK, one.StatusCode);
        Assert.Equal(1, (await one.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("uids").GetArrayLength());
        Assert.Equal(["b", "x", "y"], await SubjectsAsync("INBOX"));

        var all = await _client.PostAsync("/accounts/pop/folders/INBOX/clean-up", null);
        Assert.Equal(HttpStatusCode.OK, all.StatusCode);
        var result = await all.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal((1, 3), (result.GetProperty("uids").GetArrayLength(), result.GetProperty("checked").GetInt32()));
        Assert.Equal(["b", "y"], await SubjectsAsync("INBOX"));
        Assert.Equal(HttpStatusCode.Conflict, (await _client.PostAsync("/accounts/pop/folders/Posta%20eliminata/clean-up", null)).StatusCode);
    }
}
