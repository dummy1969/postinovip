using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.DependencyInjection;
using PostinoVip.Core.Account;
using PostinoVip.Core.Events;
using PostinoVip.Core.Local;

namespace PostinoVip.Api.Tests;

/// <summary>RulesService (R1): all'avvio fissa il punto di partenza, poi applica le regole alle mail nuove a ogni evento.</summary>
public class RulesServiceTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-rules-api-" + Guid.NewGuid().ToString("N"));
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;
    private readonly LocalMailStore _store;

    public RulesServiceTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", ApiTests.Token);
            b.UseSetting("Watch:Enabled", "false");
            b.UseSetting("Pop3:Enabled", "false");
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
        _store = new LocalMailStore(Path.Combine(MailAccountRegistry.CacheDirectory(_root, "pop"), "mail"));
        _store.EnsureDefaults();
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

    private Task<uint> AddAsync(string subject) => _store.AddAsync("INBOX", new MemoryStream(Encoding.UTF8.GetBytes(
        $"From: Anna <anna@fornitore.it>\r\nTo: me@example.com\r\nSubject: {subject}\r\nDate: Mon, 02 Nov 2026 10:00:00 +0100\r\n\r\nx\r\n")));

    private async Task<int> CountAsync(string folder) =>
        (await _client.GetFromJsonAsync<JsonElement>($"/accounts/pop/folders/{Uri.EscapeDataString(folder)}/messages?limit=50"))
        .GetProperty("total").GetInt32();

    [Fact]
    public async Task EventoDellaPostaInArrivoApplicaLeRegole()
    {
        await AddAsync("Vecchia"); // c'era già prima del servizio: non si tocca
        var put = await _client.PutAsJsonAsync("/accounts/pop/rules", new[]
        {
            new { name = "Via", conditions = new { from = new[] { "fornitore.it" } }, actions = new { delete = true } },
        });
        put.EnsureSuccessStatusCode();
        var progress = Path.Combine(MailAccountRegistry.CacheDirectory(_root, "pop"), "rules-state.json");
        for (var i = 0; i < 100 && !File.Exists(progress); i++)
            await Task.Delay(100); // primo giro dopo l'avvio: punto di partenza

        await AddAsync("Nuova");
        _factory.Services.GetRequiredService<MailboxEventHub>().Publish(MailboxEvent.Changed("pop", "INBOX", 2));
        for (var i = 0; i < 100 && await CountAsync("Posta eliminata") == 0; i++)
            await Task.Delay(100);

        Assert.Equal(1, await CountAsync("Posta eliminata"));
        Assert.Equal(1, await CountAsync("INBOX")); // la vecchia resta
    }
}
