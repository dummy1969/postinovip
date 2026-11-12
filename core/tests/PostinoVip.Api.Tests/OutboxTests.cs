using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Events;
using PostinoVip.Core.Outbox;

namespace PostinoVip.Api.Tests;

/// <summary>Bozze e Posta in uscita (3.8) con servizi finti e una coda in una cartella temporanea.</summary>
public class OutboxTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly FakeMailReader _reader = new();
    private readonly FakeMailSender _sender = new();
    private readonly FakeMailWriter _writer = new();
    private readonly string _root = Directory.CreateTempSubdirectory("postinovip-outbox-test").FullName;
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public OutboxTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", ApiTests.Token);
            b.UseSetting("Smtp:Username", "me@example.com");
            b.UseSetting("Watch:Enabled", "false");
            b.UseSetting("Outbox:Enabled", "false"); // i passaggi li fa il test, quando vuole
            b.ConfigureServices(s => s.UseFakeAccounts(_ => (_reader, _writer, _sender), _root));
        });
        _client = _factory.CreateClient();
        _client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", ApiTests.Token);
    }

    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
        Directory.Delete(_root, recursive: true);
        GC.SuppressFinalize(this);
    }

    private MailAccount Account => _factory.Services.GetRequiredService<MailAccountRegistry>().Get(null);

    private Task RunPassAsync(DateTimeOffset? now = null) => OutboxService.RunPassAsync(Account,
        _factory.Services.GetRequiredService<MailboxEventHub>(), NullLogger.Instance, now ?? DateTimeOffset.Now, default);

    [Fact]
    public async Task BozzaSenzaDestinatariSalvataInBozzeESostituita()
    {
        var resp = await _client.PostAsJsonAsync("/drafts", new { to = Array.Empty<string>(), subject = "Bozza", body = "", htmlBody = "<p>x</p>" });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var first = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.False(first.GetProperty("pending").GetBoolean());
        var uid = first.GetProperty("uid").GetUInt32();

        resp = await _client.PostAsJsonAsync("/drafts", new { to = new[] { "mario" }, subject = "Bozza", body = "", replace = new { uid } });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal(2, _writer.Drafts.Count);
        Assert.Equal(uid, _writer.Drafts[1].Replaced); // la precedente sostituita
        Assert.Equal("mario", _writer.Drafts[1].Message.To.Mailboxes.Single().Address); // indirizzo ancora da correggere: tenuto
        Assert.Contains("id=\"postinovip-body\"", _writer.Drafts[0].Message.HtmlBody);
        Assert.Empty(_sender.Sent); // nessun invio
    }

    [Fact]
    public async Task CcnInviatoSalvatoNellaCopiaENellaBozza()
    {
        var resp = await _client.PostAsJsonAsync("/send", new
        {
            to = Array.Empty<string>(), bcc = new[] { "nascosto@example.com" }, subject = "Solo Ccn", body = "B", saveCopy = true,
        });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode); // basta un destinatario in Ccn
        var sent = Assert.Single(_sender.SentMime);
        Assert.Equal("nascosto@example.com", sent.Bcc.Mailboxes.Single().Address);
        Assert.Equal("nascosto@example.com", Assert.Single(_writer.Appended).Bcc.Mailboxes.Single().Address); // copia in Posta inviata
        Assert.Equal("nascosto@example.com", Assert.Single(Account.Recent!.Items()).Address);

        var bad = await _client.PostAsJsonAsync("/send", new { to = new[] { "a@example.com" }, bcc = new[] { "rotto" }, subject = "S", body = "B" });
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
        Assert.Contains("bcc", await bad.Content.ReadAsStringAsync());

        await _client.PostAsJsonAsync("/drafts", new { to = Array.Empty<string>(), bcc = new[] { "b@example.com" }, subject = "Bozza", body = "" });
        Assert.Equal("b@example.com", Assert.Single(_writer.Drafts).Message.Bcc.Mailboxes.Single().Address);
    }

    [Fact]
    public async Task BozzaSenzaConnessioneSulComputerPoiSulServer()
    {
        _writer.DraftFailure = new MailOfflineException("non connesso");
        var resp = await _client.PostAsJsonAsync("/drafts", new { to = Array.Empty<string>(), subject = "Offline", body = "", replace = new { uid = 7 } });
        var saved = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(saved.GetProperty("pending").GetBoolean());
        var localId = saved.GetProperty("localId").GetString()!;

        // Secondo salvataggio senza connessione: stesso elemento sul computer, non un altro.
        await _client.PostAsJsonAsync("/drafts", new { to = Array.Empty<string>(), subject = "Offline 2", body = "", replace = new { localId } });
        var pending = Assert.Single(Account.Outbox!.List());
        Assert.Equal(OutboxKind.Draft, pending.Kind);
        Assert.Equal("Offline 2", pending.Subject);
        Assert.Equal(7u, pending.ReplaceDraftUid);

        _writer.DraftFailure = null;
        await RunPassAsync();
        var (message, replaced) = Assert.Single(_writer.Drafts);
        Assert.Equal("Offline 2", message.Subject);
        Assert.Equal(7u, replaced);
        Assert.Empty(Account.Outbox!.List());

        // L'app scrive ancora con l'id locale: si sostituisce la bozza ormai sul server.
        await _client.PostAsJsonAsync("/drafts", new { to = Array.Empty<string>(), subject = "Offline 3", body = "", replace = new { localId } });
        Assert.Equal(100u, _writer.Drafts[1].Replaced);
    }

    [Fact]
    public async Task InvioEliminaLaBozza()
    {
        var resp = await _client.PostAsJsonAsync("/send", new
        {
            to = new[] { "a@example.com" }, subject = "S", body = "B", deleteDraft = new { uid = 42 },
        });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Single(_sender.Sent);
        Assert.Equal([42u], _writer.DeletedDrafts);
        Assert.Equal("a@example.com", Assert.Single(Account.Recent!.Items()).Address); // indirizzo usato di recente (C1)
    }

    [Fact]
    public async Task SenzaConnessioneInPostaInUscitaPoiInviata()
    {
        _sender.Failure = new MailOfflineException("non connesso");
        _writer.DraftFailure = new MailOfflineException("non connesso");
        var resp = await _client.PostAsJsonAsync("/send", new
        {
            to = new[] { "a@example.com" }, subject = "Fuori linea", body = "B", saveCopy = true, deleteDraft = new { uid = 42 },
        });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var body = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("queued").GetBoolean());
        Assert.True(body.GetProperty("offlineQueued").GetBoolean());
        Assert.Empty(Account.Recent!.Items()); // non ancora inviata

        var list = await _client.GetFromJsonAsync<JsonElement>("/outbox");
        Assert.Equal("Fuori linea", list[0].GetProperty("subject").GetString());

        await RunPassAsync(); // ancora senza connessione: resta
        Assert.Single(Account.Outbox!.List());

        _sender.Failure = null;
        _writer.DraftFailure = null;
        await RunPassAsync();
        Assert.Empty(Account.Outbox!.List());
        Assert.Equal("Fuori linea", Assert.Single(_sender.SentMime).Subject);
        Assert.Equal("a@example.com", Assert.Single(Account.Recent!.Items()).Address); // partita dalla coda
        Assert.Single(_writer.Appended); // copia in Posta inviata
        Assert.Equal([42u], _writer.DeletedDrafts); // bozza tolta dopo l'invio
    }

    [Fact]
    public async Task RitardaRecapitoPartePoiInviaOraEToDrafts()
    {
        var later = DateTimeOffset.Now.AddHours(2);
        var resp = await _client.PostAsJsonAsync("/send", new { to = new[] { "a@example.com" }, subject = "Dopo", body = "B", sendAfter = later });
        var body = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("queued").GetBoolean());
        var id = body.GetProperty("outboxId").GetString()!;

        await RunPassAsync();
        Assert.Empty(_sender.Sent); // non è ancora l'ora
        await RunPassAsync(later.AddMinutes(1));
        Assert.Single(_sender.Sent);
        Assert.Empty(Account.Outbox!.List());

        // Un'altra: "Invia ora" toglie l'attesa; un'altra ancora torna in Bozze.
        var second = (await (await _client.PostAsJsonAsync("/send", new { to = new[] { "a@example.com" }, subject = "Ora", body = "B", sendAfter = later }))
            .Content.ReadFromJsonAsync<JsonElement>()).GetProperty("outboxId").GetString();
        Assert.Equal(HttpStatusCode.Accepted, (await _client.PostAsync($"/outbox/{second}/send", null)).StatusCode);
        await RunPassAsync();
        Assert.Equal(2, _sender.Sent.Count);

        var third = (await (await _client.PostAsJsonAsync("/send", new { to = new[] { "a@example.com" }, subject = "Torna", body = "B", sendAfter = later }))
            .Content.ReadFromJsonAsync<JsonElement>()).GetProperty("outboxId").GetString();
        resp = await _client.PostAsync($"/outbox/{third}/to-drafts", null);
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal("Torna", Assert.Single(_writer.Drafts).Message.Subject);
        Assert.Empty(Account.Outbox!.List());
        Assert.Equal(HttpStatusCode.NotFound, (await _client.DeleteAsync($"/outbox/{id}")).StatusCode); // già inviata
    }

    [Fact]
    public async Task ErroreDiversoDallaConnessioneRestaSullaMail()
    {
        _sender.Failure = new MailKit.Net.Smtp.SmtpCommandException(MailKit.Net.Smtp.SmtpErrorCode.RecipientNotAccepted,
            MailKit.Net.Smtp.SmtpStatusCode.MailboxUnavailable, "550 destinatario sconosciuto");
        await _client.PostAsJsonAsync("/send", new { to = new[] { "a@example.com" }, subject = "Rifiutata", body = "B", sendAfter = DateTimeOffset.Now.AddSeconds(1) });
        await RunPassAsync(DateTimeOffset.Now.AddMinutes(1));
        var item = Assert.Single(Account.Outbox!.List());
        Assert.Contains("550", item.Error);
        _sender.Failure = null;
        await RunPassAsync(DateTimeOffset.Now.AddMinutes(2));
        Assert.Empty(_sender.Sent); // niente nuovi tentativi da soli
        Assert.Equal(HttpStatusCode.NoContent, (await _client.DeleteAsync($"/outbox/{item.Id}")).StatusCode);
        Assert.Empty(Account.Outbox!.List());
    }

    [Fact]
    public async Task RiaperturaDellaBozza()
    {
        var compose = await _client.GetFromJsonAsync<JsonElement>("/messages/Bozze/3/compose");
        Assert.Equal("<p>ciao</p>", compose.GetProperty("html").GetString());
        Assert.Equal("<p>citato</p>", compose.GetProperty("quoteHtml").GetString());
    }
}
