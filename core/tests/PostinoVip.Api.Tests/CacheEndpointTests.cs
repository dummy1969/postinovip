using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Events;
using PostinoVip.Core.Models;

namespace PostinoVip.Api.Tests;

/// <summary>Endpoint della copia locale, con una cartella di cache temporanea (mai quella vera).</summary>
public class CacheEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-test-" + Guid.NewGuid().ToString("N"));
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;
    private AccountCache? _mainCache;

    public CacheEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", ApiTests.Token);
            b.UseSetting("Watch:Enabled", "false");
            b.UseSetting("Cache:Download:Enabled", "false");
            b.UseSetting("Cache:Directory", _root);
            b.UseSetting("Smtp:Username", "me@example.com");
            // Un account ("main") con la cache vera in _root e i servizi di posta finti.
            b.ConfigureServices(s =>
            {
                s.RemoveAll<MailAccountRegistry>();
                s.AddSingleton(sp => new MailAccountRegistry(sp.GetRequiredService<IReadOnlyList<MailAccountSettings>>()
                    .Select(a =>
                    {
                        _mainCache = new AccountCache(MailAccountRegistry.CacheDirectory(_root, a.Id));
                        return new MailAccount(a, new FakeMailReader(), new FakeMailWriter(), new FakeMailSender(),
                            new BodyCache(a.Id, _mainCache, BodyPolicy.Default));
                    })
                    .ToList()));
            });
        });
        _client = _factory.CreateClient();
        _client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ApiTests.Token);
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_root))
            Directory.Delete(_root, recursive: true);
    }

    private void Orphan(string id, string address)
    {
        CacheAccounts.WriteInfo(_root, new MailAccountSettings
        {
            Id = id,
            Name = "Vecchio",
            Imap = new() { Username = address },
            Smtp = new() { Username = address },
        });
        File.WriteAllBytes(Path.Combine(MailAccountRegistry.CacheDirectory(_root, id), "index.db"), new byte[2048]);
    }

    [Fact]
    public async Task ElencaEdEliminaIDatiDegliAccountRimossi()
    {
        Orphan("b2", "vecchio@example.com");

        var json = await _client.GetFromJsonAsync<JsonElement>("/cache/orphans");

        var orphan = json.EnumerateArray().Single();
        Assert.Equal(("b2", "vecchio@example.com", "Vecchio"),
            (orphan.GetProperty("id").GetString(), orphan.GetProperty("address").GetString(), orphan.GetProperty("name").GetString()));
        Assert.True(orphan.GetProperty("sizeBytes").GetInt64() >= 2048);

        Assert.Equal(HttpStatusCode.NoContent, (await _client.DeleteAsync("/cache/orphans/b2")).StatusCode);
        Assert.Empty((await _client.GetFromJsonAsync<JsonElement>("/cache/orphans")).EnumerateArray());
        Assert.Equal(HttpStatusCode.NotFound, (await _client.DeleteAsync("/cache/orphans/b2")).StatusCode);
    }

    [Fact]
    public async Task AccountConfiguratoNonSiEliminaComeRimosso()
    {
        await _client.GetAsync("/accounts"); // crea il registro (e la cache di "main")
        Directory.CreateDirectory(MailAccountRegistry.CacheDirectory(_root, "main"));

        Assert.Equal(HttpStatusCode.Conflict, (await _client.DeleteAsync("/cache/orphans/main")).StatusCode);
        Assert.True(Directory.Exists(MailAccountRegistry.CacheDirectory(_root, "main")));
    }

    [Fact]
    public async Task RicostruisciSvuotaLaCacheEAvvisaIlDownload()
    {
        await _client.GetAsync("/accounts");
        _mainCache!.SetFolderInfo([new MailFolderInfo("INBOX", "INBOX", 0, "inbox")]);
        using var events = _factory.Services.GetRequiredService<MailboxEventHub>().Subscribe();

        var response = await _client.PostAsync("/accounts/main/cache/rebuild", null);

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        Assert.Null(_mainCache.FindFolder("INBOX"));
        Assert.True(events.Reader.TryRead(out var e));
        Assert.Equal(MailboxEvent.CacheRebuilt("main"), e);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.PostAsync("/accounts/nessuno/cache/rebuild", null)).StatusCode);
    }
}
