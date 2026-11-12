using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace PostinoVip.Api.Tests;

/// <summary>Due caselle ("uno" e "due") configurate con l'elenco Accounts, ognuna con i suoi servizi finti.</summary>
public class MultiAccountTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly Dictionary<string, (FakeMailReader Reader, FakeMailWriter Writer, FakeMailSender Sender)> _fakes = new()
    {
        ["uno"] = (new(), new(), new()),
        ["due"] = (new(), new(), new()),
    };

    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public MultiAccountTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", ApiTests.Token);
            b.UseSetting("Watch:Enabled", "false");
            b.UseSetting("Accounts:0:Id", "uno");
            b.UseSetting("Accounts:0:Imap:Host", "imap.uno.example");
            b.UseSetting("Accounts:0:Imap:Username", "uno@example.com");
            b.UseSetting("Accounts:0:Imap:Password", "segreta-uno");
            b.UseSetting("Accounts:0:Smtp:Host", "smtp.uno.example");
            b.UseSetting("Accounts:1:Id", "due");
            b.UseSetting("Accounts:1:Name", "Lavoro");
            b.UseSetting("Accounts:1:Imap:Username", "due@example.com"); // incompleto: non configurato
            b.ConfigureServices(s => s.UseFakeAccounts(id => _fakes[id]));
        });
        _client = _factory.CreateClient();
        _client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ApiTests.Token);
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
    }

    [Fact]
    public async Task ElencoAccountInOrdineSenzaPassword()
    {
        var body = await _client.GetStringAsync("/accounts");
        var json = JsonDocument.Parse(body).RootElement;

        Assert.Equal(2, json.GetArrayLength());
        Assert.Equal(("uno", "uno@example.com", "uno@example.com", true),
            (json[0].GetProperty("id").GetString(), json[0].GetProperty("name").GetString(),
             json[0].GetProperty("address").GetString(), json[0].GetProperty("configured").GetBoolean()));
        Assert.Equal(("due", "Lavoro", "due@example.com", false),
            (json[1].GetProperty("id").GetString(), json[1].GetProperty("name").GetString(),
             json[1].GetProperty("address").GetString(), json[1].GetProperty("configured").GetBoolean()));
        Assert.DoesNotContain("segreta", body);
        Assert.True(json[0].GetProperty("online").GetBoolean()); // nessun collegamento fallito
    }

    [Fact]
    public async Task PercorsiConAccountUsanoLaSuaCasella()
    {
        await _client.GetStringAsync("/accounts/due/folders/Archivio/messages?limit=5");

        Assert.Equal(("Archivio", 0, 5), _fakes["due"].Reader.LastHeadersCall);
        Assert.Null(_fakes["uno"].Reader.LastHeadersCall);
    }

    [Fact]
    public async Task PercorsiSenzaAccountUsanoIlPrimo()
    {
        await _client.GetStringAsync("/folders/INBOX/messages");
        var account = await _client.GetFromJsonAsync<JsonElement>("/account");

        Assert.NotNull(_fakes["uno"].Reader.LastHeadersCall);
        Assert.Null(_fakes["due"].Reader.LastHeadersCall);
        Assert.Equal("uno@example.com", account.GetProperty("address").GetString());
    }

    [Fact]
    public async Task AccountInesistente404()
    {
        var resp = await _client.GetAsync("/accounts/tre/folders");

        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode);
        Assert.Contains("Account 'tre' non trovato", await resp.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task InvioDaAccountIndicatoConCopiaNellaSuaPostaInviata()
    {
        var resp = await _client.PostAsJsonAsync("/accounts/due/send",
            new { to = new[] { "dest@example.com" }, subject = "S", body = "B", saveCopy = true });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal("due@example.com", _fakes["due"].Sender.Sent.Single().From);
        Assert.Single(_fakes["due"].Writer.Appended);
        Assert.Empty(_fakes["uno"].Sender.Sent);
        Assert.Empty(_fakes["uno"].Writer.Appended);
    }

    [Fact]
    public async Task InoltroConMittenteCambiatoAllegatiDallaCasellaOriginale()
    {
        var resp = await _client.PostAsJsonAsync("/accounts/uno/send", new
        {
            to = new[] { "dest@example.com" }, subject = "I: x", body = "B",
            forwardAttachments = new { account = "due", folder = "INBOX", uid = 3, indexes = new[] { 1 } },
        });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Single(_fakes["due"].Reader.AttachmentBatchCalls); // letti dalla casella "due"
        Assert.Empty(_fakes["uno"].Reader.AttachmentBatchCalls);
        var sent = _fakes["uno"].Sender.Sent.Single(); // inviati da "uno"
        Assert.Equal("uno@example.com", sent.From);
        Assert.NotNull(sent.Attachments);
        Assert.Equal("originale1.pdf", Assert.Single(sent.Attachments).FileName);
    }

    [Fact]
    public async Task InoltroDaAccountInesistente404SenzaInvio()
    {
        var resp = await _client.PostAsJsonAsync("/accounts/uno/send", new
        {
            to = new[] { "dest@example.com" }, subject = "I: x", body = "B",
            forwardAttachments = new { account = "tre", folder = "INBOX", uid = 3, indexes = new[] { 0 } },
        });

        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode);
        Assert.Empty(_fakes["uno"].Sender.Sent);
    }

    [Fact]
    public async Task ScrittureEBozzeSullAccountIndicato()
    {
        var seen = await _client.PutAsJsonAsync("/accounts/due/messages/INBOX/3/seen", new { seen = true });
        await _client.GetStringAsync("/accounts/due/messages/INBOX/3/draft?mode=replyAll");

        Assert.Equal(HttpStatusCode.OK, seen.StatusCode);
        Assert.Single(_fakes["due"].Writer.SeenCalls);
        Assert.Empty(_fakes["uno"].Writer.SeenCalls);
        Assert.Equal("due@example.com", _fakes["due"].Reader.LastDraftCall?.Own); // escluso da "rispondi a tutti"
    }

    [Fact]
    public async Task PercorsiConAccountRichiedonoIlToken()
    {
        var resp = await _factory.CreateClient().GetAsync("/accounts/uno/folders");

        Assert.Equal(HttpStatusCode.Unauthorized, resp.StatusCode);
    }
}
