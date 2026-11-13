using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace PostinoVip.Api.Tests;

/// <summary>E1: «Salva con nome» (GET …/raw) e file .eml aperti (POST /eml e seguenti), anche per rispondere e inoltrare.</summary>
public sealed class EmlEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly FakeMailReader _reader = new();
    private readonly FakeMailSender _sender = new();
    private readonly FakeMailWriter _writer = new();
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    /// <summary>Mail con testo, HTML, un allegato PDF e una mail allegata.</summary>
    private const string Eml =
        "From: Anna Bianchi <anna@example.com>\r\nTo: me@example.com, luca@example.com\r\nSubject: Verbale\r\n" +
        "Date: Mon, 9 Nov 2026 10:05:00 +0100\r\nMessage-ID: <verbale@example.com>\r\nMIME-Version: 1.0\r\n" +
        "Content-Type: multipart/mixed; boundary=\"b1\"\r\n\r\n" +
        "--b1\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nEcco il verbale.\r\n" +
        "--b1\r\nContent-Type: application/pdf; name=\"verbale.pdf\"\r\nContent-Disposition: attachment; filename=\"verbale.pdf\"\r\n" +
        "Content-Transfer-Encoding: base64\r\n\r\nJVBERi0xLjQK\r\n" +
        "--b1\r\nContent-Type: message/rfc822\r\nContent-Disposition: attachment\r\n\r\n" +
        "From: luca@example.com\r\nSubject: Dentro\r\n\r\nMail allegata\r\n" +
        "--b1--\r\n";

    public EmlEndpointTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", ApiTests.Token);
            b.UseSetting("Smtp:Username", "me@example.com");
            b.UseSetting("Watch:Enabled", "false");
            b.ConfigureServices(s => s.UseFakeAccounts(_ => (_reader, _writer, _sender)));
        });
        _client = _factory.CreateClient();
        _client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", ApiTests.Token);
    }

    public void Dispose() => _factory.Dispose();

    private async Task<(string Id, JsonElement Message)> Open(string text = Eml)
    {
        var resp = await _client.PostAsync("/eml", new ByteArrayContent(Encoding.UTF8.GetBytes(text))
        {
            Headers = { ContentType = new MediaTypeHeaderValue("message/rfc822") },
        });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var json = await resp.Content.ReadFromJsonAsync<JsonElement>();
        return (json.GetProperty("id").GetString()!, json.GetProperty("message"));
    }

    [Fact]
    public async Task SalvaConNomeDaiByteOriginaliSenzaToccareLaCasella()
    {
        var resp = await _client.GetAsync("/messages/INBOX%2FSub/3/raw");

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal("message/rfc822", resp.Content.Headers.ContentType!.MediaType);
        Assert.Equal(FakeMailReader.Raw, await resp.Content.ReadAsByteArrayAsync());
        Assert.Equal(("INBOX/Sub", 3u), _reader.RawCalls.Single());
        Assert.Empty(_writer.SeenCalls);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync("/messages/INBOX/9/raw")).StatusCode);
    }

    [Fact]
    public async Task ApreUnFileEmlConAllegatiEMailAllegata()
    {
        var (id, message) = await Open();

        Assert.Matches("^[0-9a-f]{32}$", id);
        Assert.Equal("Verbale", message.GetProperty("subject").GetString());
        Assert.Contains("Anna Bianchi", message.GetProperty("from").GetString());
        Assert.Equal("Ecco il verbale.", message.GetProperty("textBody").GetString()!.Trim());
        var attachments = message.GetProperty("attachments").EnumerateArray().ToList();
        Assert.Equal(2, attachments.Count);
        Assert.Equal("verbale.pdf", attachments[0].GetProperty("fileName").GetString());
        Assert.Equal("message/rfc822", attachments[1].GetProperty("contentType").GetString());

        // Allegato e mail allegata: quest'ultima si può riaprire come .eml.
        var pdf = await _client.GetAsync($"/eml/{id}/attachments/0");
        Assert.Equal("%PDF-1.4\n", Encoding.ASCII.GetString(await pdf.Content.ReadAsByteArrayAsync()));
        var inner = await (await _client.GetAsync($"/eml/{id}/attachments/1")).Content.ReadAsByteArrayAsync();
        var (_, nested) = await Open(Encoding.UTF8.GetString(inner));
        Assert.Equal("Dentro", nested.GetProperty("subject").GetString());

        Assert.Equal("Verbale", (await _client.GetFromJsonAsync<JsonElement>($"/eml/{id}")).GetProperty("subject").GetString());
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/eml/{id}/attachments/5")).StatusCode);
    }

    [Fact]
    public async Task UnFileCheNonEUnaMail400EUnoChiusoNonCePiu()
    {
        var resp = await _client.PostAsync("/eml", new ByteArrayContent("solo testo\r\n"u8.ToArray()));
        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        var problem = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(problem.GetProperty("errors").TryGetProperty("file", out _));

        var (id, _) = await Open();
        Assert.Equal(HttpStatusCode.NoContent, (await _client.DeleteAsync($"/eml/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/eml/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await _client.DeleteAsync($"/eml/{id}")).StatusCode);
    }

    [Fact]
    public async Task RispostaEInoltroDaUnFileEml()
    {
        var (id, _) = await Open();

        var draft = await _client.GetFromJsonAsync<JsonElement>($"/eml/{id}/draft?mode=replyAll");
        Assert.Equal("Re: Verbale", draft.GetProperty("subject").GetString());
        Assert.True(draft.GetProperty("plainText").GetBoolean()); // originale di solo testo: risposta in testo normale
        var to = draft.GetProperty("to").EnumerateArray().Select(e => e.GetString()).ToList();
        Assert.Contains(to, a => a!.Contains("anna@example.com"));
        Assert.DoesNotContain(to.Concat(draft.GetProperty("cc").EnumerateArray().Select(e => e.GetString())),
            a => a!.Contains("me@example.com")); // il proprio indirizzo escluso

        var resp = await _client.PostAsJsonAsync("/send", new
        {
            to = new[] { "carla@example.com" }, subject = "Fwd: Verbale", body = "Ti giro il verbale", htmlBody = "<p>Ti giro il verbale</p>",
            quote = new { eml = id, mode = "forward" },
            forwardAttachments = new { eml = id, indexes = new[] { 0 } },
        });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var sent = _sender.SentMime.Single();
        Assert.Equal(["verbale.pdf"], sent.Attachments.OfType<MimeKit.MimePart>().Select(p => p.FileName));
        Assert.Contains("Ecco il verbale.", sent.TextBody);
        Assert.Empty(_reader.AttachmentBatchCalls); // niente letto dalla casella

        // File non più aperto: 404, niente invio.
        await _client.DeleteAsync($"/eml/{id}");
        var gone = await _client.PostAsJsonAsync("/send", new
        {
            to = new[] { "carla@example.com" }, subject = "x", body = "y", quote = new { eml = id, mode = "reply" },
        });
        Assert.Equal(HttpStatusCode.NotFound, gone.StatusCode);
        Assert.Single(_sender.SentMime);
    }
}
