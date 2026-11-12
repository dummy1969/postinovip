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

/// <summary>
/// Account POP3 (4.2b) attraverso gli endpoint di sempre, con il registro vero e una cartella temporanea:
/// tutto avviene sul computer (il controllo POP3 è spento, nessuna rete).
/// </summary>
public class Pop3EndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-pop3-api-" + Guid.NewGuid().ToString("N"));
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;
    private readonly LocalMailStore _store;

    public Pop3EndpointTests(WebApplicationFactory<Program> factory)
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

    private async Task AddAsync(string folder, string subject) =>
        await _store.AddAsync(folder, new MemoryStream(Encoding.UTF8.GetBytes(
            $"From: a@example.com\r\nTo: me@example.com\r\nSubject: {subject}\r\nDate: Mon, 02 Nov 2026 10:00:00 +0100\r\n\r\ntesto {subject}\r\n")));

    private async Task<JsonElement> ListAsync(string folder) =>
        await _client.GetFromJsonAsync<JsonElement>($"/accounts/pop/folders/{Uri.EscapeDataString(folder)}/messages?limit=50");

    private static JsonElement BySubject(JsonElement page, string subject) =>
        page.GetProperty("items").EnumerateArray().Single(m => m.GetProperty("subject").GetString() == subject);

    [Fact]
    public async Task CartelleLettoContrassegnoSpostaRinominaEdEliminaSulComputer()
    {
        await AddAsync("INBOX", "Fattura");
        await AddAsync("INBOX", "Saluti");

        var folders = await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/folders");
        Assert.Contains(folders.EnumerateArray(), f => f.GetProperty("fullName").GetString() == "INBOX" && f.GetProperty("unread").GetInt32() == 2);
        var fattura = BySubject(await ListAsync("INBOX"), "Fattura").GetProperty("uid").GetUInt32();

        Assert.Equal(HttpStatusCode.OK, (await _client.PutAsJsonAsync($"/accounts/pop/messages/INBOX/{fattura}/seen", new { seen = true })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.PutAsJsonAsync($"/accounts/pop/messages/INBOX/{fattura}/flags",
            new { followUp = "flagged", due = "2026-11-06", categories = new[] { 3 } })).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await _client.PostAsJsonAsync("/accounts/pop/folders", new { name = "Clienti" })).StatusCode);
        var move = await _client.PostAsJsonAsync($"/accounts/pop/messages/INBOX/{fattura}/move", new { destination = "Clienti" });
        Assert.Equal(HttpStatusCode.OK, move.StatusCode);

        // Rinomina: le mail restano con i loro flag (l'indice cambia solo il nome).
        var rename = await _client.PostAsJsonAsync("/accounts/pop/folders/Clienti/rename", new { name = "Fornitori" });
        Assert.Equal(HttpStatusCode.OK, rename.StatusCode);
        var moved = BySubject(await ListAsync("Fornitori"), "Fattura");
        Assert.True(moved.GetProperty("seen").GetBoolean());
        Assert.True(moved.GetProperty("flagged").GetBoolean());
        Assert.Equal("2026-11-06", moved.GetProperty("due").GetString());
        Assert.Equal(3, moved.GetProperty("categories")[0].GetInt32());
        Assert.Equal(1, (await ListAsync("INBOX")).GetProperty("total").GetInt32());

        // Cartella eliminata -> Posta eliminata, poi definitivamente.
        var deleted = await _client.DeleteFromJsonAsync<JsonElement>("/accounts/pop/folders/Fornitori");
        Assert.Equal("Posta eliminata/Fornitori", deleted.GetProperty("movedTo").GetString());
        Assert.True(BySubject(await ListAsync("Posta eliminata/Fornitori"), "Fattura").GetProperty("flagged").GetBoolean());
        var permanent = await _client.DeleteFromJsonAsync<JsonElement>($"/accounts/pop/folders/{Uri.EscapeDataString("Posta eliminata/Fornitori")}");
        Assert.True(permanent.GetProperty("permanent").GetBoolean());

        // Elimina mail -> Posta eliminata; definitiva solo lì; speciali intoccabili; niente ricostruzione.
        var saluti = BySubject(await ListAsync("INBOX"), "Saluti").GetProperty("uid").GetUInt32();
        Assert.Equal(HttpStatusCode.OK, (await _client.DeleteAsync($"/accounts/pop/messages/INBOX/{saluti}")).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await _client.DeleteAsync($"/accounts/pop/messages/INBOX/{saluti}?permanent=true")).StatusCode);
        var inTrash = BySubject(await ListAsync("Posta eliminata"), "Saluti").GetProperty("uid").GetUInt32();
        var batch = await _client.PostAsJsonAsync("/accounts/pop/messages/Posta%20eliminata/delete", new { uids = new[] { inTrash }, permanent = true });
        Assert.Equal(HttpStatusCode.OK, batch.StatusCode);
        Assert.Equal(0, (await ListAsync("Posta eliminata")).GetProperty("total").GetInt32());
        Assert.Equal(HttpStatusCode.Conflict, (await _client.DeleteAsync("/accounts/pop/folders/INBOX")).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await _client.PostAsync("/accounts/pop/cache/rebuild", null)).StatusCode);
    }

    [Fact]
    public async Task BozzaSalvataSulComputer()
    {
        var resp = await _client.PostAsJsonAsync("/accounts/pop/drafts", new
        {
            to = new[] { "x@example.com" }, cc = Array.Empty<string>(), subject = "Bozza POP3", body = "testo",
        });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var saved = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Bozze", saved.GetProperty("folder").GetString());
        Assert.False(saved.GetProperty("pending").GetBoolean());
        Assert.Equal("Bozza POP3", BySubject(await ListAsync("Bozze"), "Bozza POP3").GetProperty("subject").GetString());
    }

    [Fact]
    public async Task TipoNellElencoEInviaRiceviAccettato()
    {
        var accounts = await _client.GetFromJsonAsync<JsonElement>("/accounts");
        Assert.Equal("Pop3", accounts[0].GetProperty("type").GetString());

        var receive = await _client.PostAsync("/accounts/pop/receive", null);
        Assert.Equal(HttpStatusCode.Accepted, receive.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.PostAsync("/accounts/manca/receive", null)).StatusCode);
    }

    [Fact]
    public async Task DatiDiUnAccountPop3RimossoSegnatiComeUnicaCopia()
    {
        // Dopo la rimozione dall'app: la cartella resta, con le mail POP3 dentro.
        var orphans = PostinoVip.Core.Cache.CacheAccounts.ListOrphans(_root, []);
        Assert.False(Assert.Single(orphans).LocalOnly); // casella vuota: niente da perdere
        await _store.AddAsync("INBOX", new MemoryStream("Subject: x\r\n\r\ny"u8.ToArray()));
        Assert.True(Assert.Single(PostinoVip.Core.Cache.CacheAccounts.ListOrphans(_root, [])).LocalOnly);
        Assert.Empty(PostinoVip.Core.Cache.CacheAccounts.ListOrphans(_root, ["pop"]));
    }

    [Fact]
    public async Task RegoleSalvateERiletteConControlli()
    {
        Assert.Empty((await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/rules")).EnumerateArray());

        var put = await _client.PutAsJsonAsync("/accounts/pop/rules", new[]
        {
            new
            {
                name = " Fatture ", enabled = true,
                conditions = new { from = new[] { "fornitore.it" }, subjectContains = new[] { "fattura" } },
                exceptions = (object?)null,
                actions = new { moveTo = "Fatture", markRead = true, stopProcessing = true },
            },
        });
        Assert.Equal(HttpStatusCode.OK, put.StatusCode);

        var rules = await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/rules");
        var rule = Assert.Single(rules.EnumerateArray());
        Assert.Equal("Fatture", rule.GetProperty("name").GetString());
        Assert.Matches("^[0-9a-f]{8}$", rule.GetProperty("id").GetString());
        Assert.Equal("fornitore.it", rule.GetProperty("conditions").GetProperty("from")[0].GetString());
        Assert.Equal("Fatture", rule.GetProperty("actions").GetProperty("moveTo").GetString());

        var noAction = await _client.PutAsJsonAsync("/accounts/pop/rules", new[] { new { name = "Vuota", actions = new { } } });
        Assert.Equal(HttpStatusCode.BadRequest, noAction.StatusCode);
        var problem = await noAction.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Contains("azione", problem.GetProperty("errors").GetProperty("rules")[0].GetString());
        Assert.Single((await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/rules")).EnumerateArray()); // invariate
    }

    [Fact]
    public async Task EseguiRegoleOraConAvanzamentoEInterruzione()
    {
        await AddAsync("INBOX", "Fattura uno");
        await AddAsync("INBOX", "Saluti");
        await _client.PostAsJsonAsync("/accounts/pop/folders", new { name = "Fatture" });
        var saved = await (await _client.PutAsJsonAsync("/accounts/pop/rules", new[]
        {
            new { name = "Fatture", enabled = false, conditions = new { subjectContains = new[] { "fattura" } }, actions = new { moveTo = "Fatture" } },
        })).Content.ReadFromJsonAsync<JsonElement>();
        var ruleId = saved[0].GetProperty("id").GetString();

        Assert.Equal(HttpStatusCode.BadRequest,
            (await _client.PostAsJsonAsync("/accounts/pop/rules/run", new { ruleIds = Array.Empty<string>() })).StatusCode);
        var start = await _client.PostAsJsonAsync("/accounts/pop/rules/run",
            new { ruleIds = new[] { ruleId }, folder = "INBOX", includeSubfolders = true, filter = "All" });
        Assert.Equal(HttpStatusCode.Accepted, start.StatusCode);
        var id = (await start.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetString();

        JsonElement status = default;
        for (var i = 0; i < 100; i++)
        {
            status = await _client.GetFromJsonAsync<JsonElement>($"/accounts/pop/rules/run/{id}");
            if (status.GetProperty("done").GetBoolean())
                break;
            await Task.Delay(50);
        }
        Assert.True(status.GetProperty("done").GetBoolean());
        Assert.Equal((2, 2, 1), (status.GetProperty("checked").GetInt32(), status.GetProperty("total").GetInt32(),
            status.GetProperty("applied").GetInt32()));
        Assert.Equal(1, (await ListAsync("Fatture")).GetProperty("total").GetInt32());
        Assert.Equal(HttpStatusCode.Accepted, (await _client.DeleteAsync($"/accounts/pop/rules/run/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync("/accounts/pop/rules/run/0000000000000000")).StatusCode);
    }

    [Fact]
    public async Task RisposteAutomaticheSalvateConStatoEControlli()
    {
        var empty = await _client.GetFromJsonAsync<JsonElement>("/accounts/pop/autoreply");
        Assert.False(empty.GetProperty("enabled").GetBoolean());
        Assert.False(empty.GetProperty("active").GetBoolean());

        var bad = await _client.PutAsJsonAsync("/accounts/pop/autoreply", new { enabled = true, html = "", text = " " });
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);

        var future = DateTimeOffset.UtcNow.AddDays(1);
        var saved = await (await _client.PutAsJsonAsync("/accounts/pop/autoreply",
            new { enabled = true, start = future, end = future.AddDays(2), html = "<p>Fuori sede</p>", text = "Fuori sede", document = "[]" }))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(saved.GetProperty("enabled").GetBoolean());
        Assert.False(saved.GetProperty("active").GetBoolean()); // programmate: non ancora
        Assert.Equal("[]", saved.GetProperty("document").GetString());

        var now = await (await _client.PutAsJsonAsync("/accounts/pop/autoreply", new { enabled = true, html = "", text = "Fuori sede" }))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(now.GetProperty("active").GetBoolean());
    }
}
