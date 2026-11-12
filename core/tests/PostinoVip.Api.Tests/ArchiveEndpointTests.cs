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

/// <summary>A1: cartella di archiviazione e Archivia su un account POP3 (tutto sul computer, nessuna rete).</summary>
public sealed class ArchiveEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-archive-api-" + Guid.NewGuid().ToString("N"));
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;
    private readonly LocalMailStore _store;

    public ArchiveEndpointTests(WebApplicationFactory<Program> factory)
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

    private Task<uint> AddAsync(string subject) =>
        _store.AddAsync("INBOX", new MemoryStream(Encoding.UTF8.GetBytes(
            $"From: anna@fornitore.it\r\nTo: me@example.com\r\nSubject: {subject}\r\nDate: Mon, 02 Nov 2026 10:00:00 +0100\r\n\r\ntesto\r\n")));

    private async Task<List<JsonElement>> MessagesAsync(string folder) =>
        (await _client.GetFromJsonAsync<JsonElement>($"/accounts/pop/folders/{Uri.EscapeDataString(folder)}/messages?limit=50"))
        .GetProperty("items").EnumerateArray().ToList();

    private async Task<string?> RoleAsync(string folder) =>
        (await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/folders")).EnumerateArray()
        .Single(f => f.GetProperty("fullName").GetString() == folder).GetProperty("specialUse").GetString();

    [Fact]
    public async Task SceltaDellaCartellaConPropostaERuolo()
    {
        var first = await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/archive");
        Assert.Equal(JsonValueKind.Null, first.GetProperty("folder").ValueKind);
        Assert.Equal(JsonValueKind.Null, first.GetProperty("suggested").ValueKind); // nessuna cartella adatta: si crea

        _store.CreateFolder("Archivio");
        Assert.Equal("Archivio", (await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/archive")).GetProperty("suggested").GetString());
        Assert.Null(await RoleAsync("Archivio")); // proposta, non ancora scelta

        foreach (var folder in new[] { "Non esiste", "INBOX", "Posta inviata", "Posta indesiderata" })
        {
            var bad = await _client.PutAsJsonAsync("/accounts/pop/archive", new { folder });
            Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
            Assert.Contains("\"folder\"", await bad.Content.ReadAsStringAsync());
        }

        var saved = await _client.PutAsJsonAsync("/accounts/pop/archive", new { folder = "Archivio" });
        Assert.Equal(HttpStatusCode.OK, saved.StatusCode);
        Assert.Equal("Archivio", (await saved.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("folder").GetString());
        Assert.Equal("archive", await RoleAsync("Archivio"));

        // La cartella di archiviazione non può diventare la posta indesiderata.
        var junk = await _client.PutAsJsonAsync("/accounts/pop/junk", new { folder = "Archivio" });
        Assert.Equal(HttpStatusCode.BadRequest, junk.StatusCode);

        var cleared = await _client.PutAsJsonAsync("/accounts/pop/archive", new { folder = (string?)null });
        Assert.Equal(HttpStatusCode.OK, cleared.StatusCode);
        Assert.Null(await RoleAsync("Archivio"));
    }

    [Fact]
    public async Task ArchiviaSpostaSenzaCambiareLoStatoLetto()
    {
        var read = await AddAsync("Letta");
        var unread = await AddAsync("Da leggere");
        await MessagesAsync("INBOX");
        Assert.Equal(HttpStatusCode.OK, (await _client.PutAsJsonAsync($"/accounts/pop/messages/INBOX/{read}/seen", new { seen = true })).StatusCode);

        var none = await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/archive", new { uids = new[] { read } });
        Assert.Equal(HttpStatusCode.Conflict, none.StatusCode); // cartella non ancora scelta: niente spostato
        Assert.Equal(2, (await MessagesAsync("INBOX")).Count);

        _store.CreateFolder("Archivio");
        await _client.PutAsJsonAsync("/accounts/pop/archive", new { folder = "Archivio" });
        Assert.Equal(HttpStatusCode.BadRequest,
            (await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/archive", new { uids = Array.Empty<uint>() })).StatusCode);

        var done = await _client.PostAsJsonAsync("/accounts/pop/messages/INBOX/archive", new { uids = new[] { read, unread } });
        Assert.Equal(HttpStatusCode.OK, done.StatusCode);
        var result = await done.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Archivio", result.GetProperty("movedTo").GetString());
        Assert.Equal(2, result.GetProperty("uids").GetArrayLength());

        Assert.Empty(await MessagesAsync("INBOX"));
        var archived = await MessagesAsync("Archivio");
        Assert.Equal(["Da leggere", "Letta"], archived.Select(m => m.GetProperty("subject").GetString()).Order());
        Assert.True(archived.Single(m => m.GetProperty("subject").GetString() == "Letta").GetProperty("seen").GetBoolean());
        Assert.False(archived.Single(m => m.GetProperty("subject").GetString() == "Da leggere").GetProperty("seen").GetBoolean());

        var again = await _client.PostAsJsonAsync("/accounts/pop/messages/Archivio/archive",
            new { uids = new[] { archived[0].GetProperty("uid").GetUInt32() } });
        Assert.Equal(HttpStatusCode.Conflict, again.StatusCode); // già nell'archivio
    }
}
