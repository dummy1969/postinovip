using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using MimeKit;
using PostinoVip.Core.Cache;

namespace PostinoVip.Api.Tests;

/// <summary>R1: POST …/receipt invia (o no) la conferma di lettura e segna $MDNSent; richiesta con «readReceipt» all'invio.</summary>
public sealed class ReadReceiptEndpointTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly FakeMailReader _reader = new();
    private readonly FakeMailSender _sender = new();
    private readonly FakeMailWriter _writer = new();
    private readonly WebApplicationFactory<Program> _factory;
    private readonly HttpClient _client;

    public ReadReceiptEndpointTests(WebApplicationFactory<Program> factory)
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

    [Fact]
    public async Task InviaLaConfermaESegnaMdnSent()
    {
        var resp = await _client.PostAsJsonAsync("/messages/INBOX/3/receipt", new { send = true });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.True((await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("sent").GetBoolean());
        var receipt = _sender.SentMime.Single();
        Assert.Equal("anna@example.com", receipt.To.Mailboxes.Single().Address);
        Assert.Equal("me@example.com", receipt.From.Mailboxes.Single().Address);
        Assert.Equal("Letto: Riunione", receipt.Subject);
        var report = Assert.IsType<MultipartReport>(receipt.Body);
        var mdn = report.OfType<MessageDispositionNotification>().Single();
        Assert.Equal("manual-action/MDN-sent-manually; displayed", mdn.Fields["Disposition"]);
        Assert.Equal(("INBOX", 3u, MailFlags.MdnSent, MailFlags.None), _writer.FlagCalls.Single());

        var auto = await _client.PostAsJsonAsync("/messages/INBOX/3/receipt", new { send = true, automatic = true });
        Assert.Equal(HttpStatusCode.OK, auto.StatusCode); // senza copia locale non si sa se è già trattata
        Assert.StartsWith("automatic-action/", _sender.SentMime[1].BodyParts.OfType<MessageDispositionNotification>().Single().Fields["Disposition"]);
    }

    [Fact]
    public async Task NonInviareSegnaSoltantoMdnSent()
    {
        var resp = await _client.PostAsJsonAsync("/messages/INBOX/3/receipt", new { send = false });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.False((await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("sent").GetBoolean());
        Assert.Empty(_sender.SentMime);
        Assert.Equal(MailFlags.MdnSent, _writer.FlagCalls.Single().Add);
    }

    [Fact]
    public async Task SenzaRichiestaOSenzaSend()
    {
        var none = await _client.PostAsJsonAsync("/messages/INBOX/4/receipt", new { send = true });
        Assert.Equal(HttpStatusCode.Conflict, none.StatusCode);
        var missing = await _client.PostAsJsonAsync("/messages/INBOX/3/receipt", new { });
        Assert.Equal(HttpStatusCode.BadRequest, missing.StatusCode);
        Assert.Empty(_sender.SentMime);
        Assert.Empty(_writer.FlagCalls);
    }

    [Fact]
    public async Task RichiestaAllInvioEDettaglioConLIndirizzo()
    {
        var resp = await _client.PostAsJsonAsync("/send", new { to = new[] { "a@example.com" }, subject = "S", body = "B", readReceipt = true });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal("me@example.com", _sender.SentMime.Single().Headers[HeaderId.DispositionNotificationTo]);

        await _client.PostAsJsonAsync("/send", new { to = new[] { "a@example.com" }, subject = "S", body = "B" });
        Assert.False(_sender.SentMime[1].Headers.Contains(HeaderId.DispositionNotificationTo));
    }
}
