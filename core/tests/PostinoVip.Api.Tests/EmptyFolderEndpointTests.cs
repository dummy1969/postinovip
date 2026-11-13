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

/// <summary>«Svuota cartella» (12/11/2026) su un account POP3: writer locale vero, nessuna rete.</summary>
public sealed class EmptyFolderEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private const string Junk = "Posta indesiderata";
    private const string Trash = "Posta eliminata";
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-empty-api-" + Guid.NewGuid().ToString("N"));
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;
    private readonly LocalMailStore _store;

    public EmptyFolderEndpointTests(WebApplicationFactory<Program> factory)
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

    private Task<uint> AddAsync(string folder, string subject, string from = "anna@example.com") =>
        _store.AddAsync(folder, new MemoryStream(Encoding.UTF8.GetBytes(
            $"From: {from}\r\nTo: me@example.com\r\nSubject: {subject}\r\nDate: Mon, 02 Nov 2026 10:00:00 +0100\r\n\r\ntesto\r\n")));

    private async Task<List<string?>> SubjectsAsync(string folder) =>
        (await _client.GetFromJsonAsync<JsonElement>($"/accounts/pop/folders/{Uri.EscapeDataString(folder)}/messages?limit=50"))
        .GetProperty("items").EnumerateArray().Select(m => m.GetProperty("subject").GetString()).Order().ToList();

    private Task<HttpResponseMessage> EmptyAsync(string folder) =>
        _client.PostAsync($"/accounts/pop/folders/{Uri.EscapeDataString(folder)}/empty", null);

    private async Task<List<string>> FolderNamesAsync() =>
        (await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/folders"))
        .EnumerateArray().Select(f => f.GetProperty("fullName").GetString()!).ToList();

    [Fact]
    public async Task SvuotaSoloPostaEliminataEIndesiderata()
    {
        await AddAsync("INBOX", "resta");
        await AddAsync(Junk, "spam 1");
        await AddAsync(Junk, "spam 2");
        await AddAsync(Trash, "vecchia 1");
        _store.CreateFolder($"{Trash}/Vecchia");
        _store.CreateFolder($"{Trash}/Vecchia/Più vecchia");
        await AddAsync($"{Trash}/Vecchia/Più vecchia", "vecchia 2");
        _store.CreateFolder("Clienti");
        await AddAsync("Clienti", "cliente");

        // Altre cartelle: 409, niente toccato.
        foreach (var other in new[] { "INBOX", "Clienti", $"{Trash}/Vecchia" })
            Assert.Equal(HttpStatusCode.Conflict, (await EmptyAsync(other)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await EmptyAsync("Non esiste")).StatusCode);

        // Posta indesiderata: solo le mail.
        var junk = await EmptyAsync(Junk);
        Assert.Equal(HttpStatusCode.OK, junk.StatusCode);
        var j = await junk.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(2, j.GetProperty("messages").GetInt32());
        Assert.Equal(0, j.GetProperty("removedFolders").GetArrayLength());
        Assert.Empty(await SubjectsAsync(Junk));

        // Posta eliminata: mail e sottocartelle (anche annidate).
        var trash = await EmptyAsync(Trash);
        Assert.Equal(HttpStatusCode.OK, trash.StatusCode);
        var t = await trash.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(1, t.GetProperty("messages").GetInt32());
        Assert.Equal([$"{Trash}/Vecchia/Più vecchia", $"{Trash}/Vecchia"],
            t.GetProperty("removedFolders").EnumerateArray().Select(e => e.GetString()).ToList());
        Assert.Empty(await SubjectsAsync(Trash));
        var names = await FolderNamesAsync();
        Assert.DoesNotContain(names, n => n.StartsWith($"{Trash}/", StringComparison.Ordinal));
        Assert.Contains(Trash, names);

        // Le altre cartelle intatte.
        Assert.Equal(["resta"], await SubjectsAsync("INBOX"));
        Assert.Equal(["cliente"], await SubjectsAsync("Clienti"));
    }

    [Fact]
    public async Task CartellaVuotaZeroMail()
    {
        var empty = await EmptyAsync(Junk);
        Assert.Equal(HttpStatusCode.OK, empty.StatusCode);
        Assert.Equal(0, (await empty.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("messages").GetInt32());
    }
}
