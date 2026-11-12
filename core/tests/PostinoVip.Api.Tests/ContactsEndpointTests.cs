using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using PostinoVip.Core.Account;

namespace PostinoVip.Api.Tests;

// Contatti (C1): rubrica per account, importazione/esportazione, suggerimenti di tutti gli account. Nessun server.
public class ContactsEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-contacts-api-" + Guid.NewGuid().ToString("N"));
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public ContactsEndpointTests(WebApplicationFactory<Program> factory)
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
            for (var i = 0; i < 2; i++)
            {
                b.UseSetting($"Accounts:{i}:Id", $"a{i + 1}");
                b.UseSetting($"Accounts:{i}:Imap:Host", "imap.example.invalid");
                b.UseSetting($"Accounts:{i}:Imap:Username", $"me{i + 1}@example.com");
                b.UseSetting($"Accounts:{i}:Imap:Password", "x");
                b.UseSetting($"Accounts:{i}:Smtp:Host", "smtp.example.invalid");
            }
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

    private static object Mario => new
    {
        givenName = "Mario",
        familyName = "Rossi",
        emails = new[] { new { address = "mario@example.com", label = "work" } },
        phones = new[] { new { number = "333 1", label = "mobile" } },
        company = "ACME",
    };

    [Fact]
    public async Task CreaLeggiModificaElimina()
    {
        var created = await _client.PostAsJsonAsync("/accounts/a1/contacts", Mario);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var c = await created.Content.ReadFromJsonAsync<JsonElement>();
        var id = c.GetProperty("id").GetString()!;
        Assert.Equal("Mario Rossi", c.GetProperty("name").GetString());
        Assert.False(c.TryGetProperty("vCardUid", out _)); // dati interni del vCard: non passano
        Assert.True(File.Exists(Path.Combine(MailAccountRegistry.CacheDirectory(_root, "a1"), "contacts", id + ".vcf")));

        var list = await _client.GetFromJsonAsync<JsonElement>("/accounts/a1/contacts");
        Assert.Equal(id, Assert.Single(list.GetProperty("items").EnumerateArray()).GetProperty("id").GetString());
        Assert.Empty((await _client.GetFromJsonAsync<JsonElement>("/accounts/a2/contacts")).GetProperty("items").EnumerateArray());

        var put = await _client.PutAsJsonAsync($"/accounts/a1/contacts/{id}", new { displayName = "Il Mario", emails = new[] { new { address = "m2@example.com" } } });
        put.EnsureSuccessStatusCode();
        var updated = await _client.GetFromJsonAsync<JsonElement>($"/accounts/a1/contacts/{id}");
        Assert.Equal("Il Mario", updated.GetProperty("name").GetString());
        Assert.Equal("m2@example.com", Assert.Single(updated.GetProperty("emails").EnumerateArray()).GetProperty("address").GetString());

        Assert.Equal(HttpStatusCode.NoContent, (await _client.DeleteAsync($"/accounts/a1/contacts/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/accounts/a1/contacts/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.DeleteAsync($"/accounts/a1/contacts/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync("/accounts/nessuno/contacts")).StatusCode);
    }

    [Fact]
    public async Task ErroriPerCampo()
    {
        var bad = await _client.PostAsJsonAsync("/accounts/a1/contacts", new { givenName = "X", emails = new[] { new { address = "non valido" } } });
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
        Assert.Contains("emails", await bad.Content.ReadAsStringAsync());
        var empty = await _client.PostAsJsonAsync("/accounts/a1/contacts", new { notes = "solo note" });
        Assert.Equal(HttpStatusCode.BadRequest, empty.StatusCode);
        var format = await _client.PostAsJsonAsync("/accounts/a1/contacts/import", new { format = "xls", data = "" });
        Assert.Contains("format", await format.Content.ReadAsStringAsync());
        var data = await _client.PostAsJsonAsync("/accounts/a1/contacts/import", new { format = "vcf", data = "!!!" });
        Assert.Equal(HttpStatusCode.BadRequest, data.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await _client.GetAsync("/addresses/suggest?q=a&limit=0")).StatusCode);
    }

    [Fact]
    public async Task ImportaEsportaESuggerisce()
    {
        const string vcf = "BEGIN:VCARD\r\nVERSION:3.0\r\nN:Bianchi;Anna;;;\r\nEMAIL:anna@example.org\r\nEND:VCARD\r\n"
            + "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Bruno\r\nEMAIL:bruno@example.org\r\nEND:VCARD\r\n";
        var import = await _client.PostAsJsonAsync("/accounts/a1/contacts/import",
            new { format = "vcf", data = Convert.ToBase64String(Encoding.UTF8.GetBytes(vcf)) });
        var result = await import.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(2, result.GetProperty("imported").GetInt32());
        var again = await (await _client.PostAsJsonAsync("/accounts/a1/contacts/import",
            new { format = "vcf", data = Convert.ToBase64String(Encoding.UTF8.GetBytes(vcf)) })).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal((0, 2), (again.GetProperty("imported").GetInt32(), again.GetProperty("duplicates").GetInt32()));
        await _client.PostAsJsonAsync("/accounts/a2/contacts", Mario);

        var csv = await _client.GetAsync("/accounts/a1/contacts/export?format=csv");
        Assert.Equal("text/csv", csv.Content.Headers.ContentType!.MediaType);
        Assert.Equal("Contatti.csv", csv.Content.Headers.ContentDisposition!.FileName);
        Assert.Contains("anna@example.org", Encoding.UTF8.GetString(await csv.Content.ReadAsByteArrayAsync()));
        var vcard = await _client.GetAsync("/accounts/a1/contacts/export");
        Assert.Equal("text/vcard", vcard.Content.Headers.ContentType!.MediaType);
        Assert.Equal(2, (await vcard.Content.ReadAsStringAsync()).Split("BEGIN:VCARD").Length - 1);

        // Suggerimenti da tutti gli account.
        var b = await _client.GetFromJsonAsync<JsonElement>("/addresses/suggest?q=b");
        Assert.Equal(["anna@example.org", "bruno@example.org"],
            b.GetProperty("items").EnumerateArray().Select(i => i.GetProperty("address").GetString()).Order());
        var m = Assert.Single((await _client.GetFromJsonAsync<JsonElement>("/addresses/suggest?q=mario")).GetProperty("items").EnumerateArray());
        Assert.Equal(("a2", "contact"), (m.GetProperty("accountId").GetString(), m.GetProperty("source").GetString()));
        Assert.Equal(HttpStatusCode.NoContent, (await _client.DeleteAsync("/addresses/recent?address=x@example.org")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await _client.DeleteAsync("/addresses/recent")).StatusCode);
    }

    [Fact]
    public async Task ContattiDiUnAccountRimossoContati()
    {
        var dir = Path.Combine(MailAccountRegistry.CacheDirectory(_root, "vecchio"), "contacts");
        Directory.CreateDirectory(dir);
        File.WriteAllText(Path.Combine(dir, "00aa.vcf"), "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:X\r\nEND:VCARD\r\n");
        var orphans = await _client.GetFromJsonAsync<JsonElement>("/cache/orphans");
        var o = Assert.Single(orphans.EnumerateArray(), x => x.GetProperty("id").GetString() == "vecchio");
        Assert.Equal(1, o.GetProperty("contacts").GetInt32());
    }
}
