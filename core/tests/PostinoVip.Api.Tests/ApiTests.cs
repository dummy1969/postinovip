using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.DependencyInjection.Extensions;
using PostinoVip.Core;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Models;

namespace PostinoVip.Api.Tests;

public class ApiTests : IClassFixture<WebApplicationFactory<Program>>, IDisposable
{
    private readonly FakeMailReader _reader = new();
    private readonly FakeMailSender _sender = new();
    private readonly FakeMailWriter _writer = new();
    private readonly HttpClient _client;

    public const string Token = "test-token-0123456789abcdef0123456789abcdef";

    private readonly WebApplicationFactory<Program> _factory;

    public ApiTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory.WithWebHostBuilder(b =>
        {
            // "Testing": gli user-secrets (credenziali reali) si caricano solo in Development.
            b.UseEnvironment("Testing");
            b.UseSetting("POSTINOVIP_TOKEN", Token);
            b.UseSetting("Smtp:Username", "me@example.com");
            b.UseSetting("Watch:Enabled", "false"); // gli user-secrets reali sono caricati: niente IDLE nei test
            // Un solo account ("main", formato Imap/Smtp) con i servizi finti.
            b.ConfigureServices(s => s.UseFakeAccounts(_ => (_reader, _writer, _sender)));
        });
        _client = _factory.CreateClient();
        _client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", Token);
    }

    // xUnit crea un'istanza per test: senza Dispose ogni host resterebbe aperto con i suoi
    // file watcher (appsettings, user-secrets) fino a esaurire il limite inotify di Linux (128).
    public void Dispose()
    {
        _client.Dispose();
        _factory.Dispose();
    }

    [Theory]
    [InlineData(null)]                    // nessun header
    [InlineData("Bearer sbagliato")]
    [InlineData("Basic " + Token)]        // schema diverso
    [InlineData(Token)]                   // senza "Bearer "
    public async Task SenzaTokenValido401(string? authorization)
    {
        var client = _factory.CreateClient();
        if (authorization is not null)
            client.DefaultRequestHeaders.TryAddWithoutValidation("Authorization", authorization);

        foreach (var url in new[] { "/folders", "/account", "/openapi/v1.json" })
        {
            var resp = await client.GetAsync(url);
            Assert.Equal(HttpStatusCode.Unauthorized, resp.StatusCode);
        }
        var send = await client.PostAsJsonAsync("/send", new { to = new[] { "a@example.com" }, subject = "S", body = "B" });
        Assert.Equal(HttpStatusCode.Unauthorized, send.StatusCode);
        Assert.Empty(_sender.Sent);
    }

    [Fact]
    public async Task ConTokenValidoOpenApiDisponibile()
    {
        Assert.Equal(HttpStatusCode.OK, (await _client.GetAsync("/openapi/v1.json")).StatusCode);
    }

    [Fact]
    public async Task GetFolders()
    {
        var json = await _client.GetFromJsonAsync<JsonElement>("/folders");

        Assert.Equal(2, json.GetArrayLength());
        Assert.Equal("INBOX", json[0].GetProperty("fullName").GetString());
    }

    [Fact]
    public async Task GetMessagesPassaOffsetLimitECartellaDecodificata()
    {
        var json = await _client.GetFromJsonAsync<JsonElement>("/folders/INBOX%2FSent/messages?offset=5&limit=2");

        Assert.Equal(("INBOX/Sent", 5, 2), _reader.LastHeadersCall);
        Assert.Equal(3, json.GetProperty("total").GetInt32());
        Assert.False(json.GetProperty("items")[0].GetProperty("seen").GetBoolean());
    }

    [Fact]
    public async Task RicercaPassaTestoCartellaEPagina()
    {
        var json = await _client.GetFromJsonAsync<JsonElement>("/search?q=fattura%20da%3Aanna&folder=INBOX&offset=10&limit=5");

        Assert.Equal(("fattura da:anna", "INBOX", 10, 5), _reader.LastSearchCall);
        var hit = json.GetProperty("items")[0];
        Assert.Equal("INBOX", hit.GetProperty("folder").GetString());
        Assert.Equal("la \u0002fattura\u0003 di ottobre", hit.GetProperty("snippet").GetString());
        Assert.True(hit.GetProperty("bodySearched").GetBoolean());

        await _client.GetFromJsonAsync<JsonElement>("/search?q=x");
        Assert.Equal(("x", null, 0, 50), _reader.LastSearchCall); // tutta la casella, prima pagina
    }

    [Fact]
    public async Task RicercaSulServer()
    {
        var json = await _client.GetFromJsonAsync<JsonElement>("/search/server?q=vecchia&folder=Archivio");

        Assert.Equal(("vecchia", "Archivio"), _reader.LastServerSearchCall);
        Assert.True(json.GetProperty("items")[0].GetProperty("fromServer").GetBoolean());
        Assert.Equal(HttpStatusCode.BadRequest, (await _client.GetAsync("/search/server?q=")).StatusCode);
    }

    [Theory]
    [InlineData("", "q")]
    [InlineData("q=%20", "q")]
    [InlineData("q=x&limit=0", "limit")]
    [InlineData("q=x&offset=-1", "offset")]
    public async Task RicercaParametriNonValidi400(string query, string field)
    {
        var response = await _client.GetAsync("/search?" + query);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(json.GetProperty("errors").TryGetProperty(field, out _));
    }

    [Theory]
    [InlineData("SenzaRete")]
    [InlineData("Muto")] // il server smette di rispondere a connessione aperta
    public async Task ServerNonRaggiungibile503NonConnesso(string folder)
    {
        var response = await _client.GetAsync($"/folders/{folder}/messages");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Non connesso", json.GetProperty("title").GetString());
        Assert.Matches("non raggiungibile|non risponde", json.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task GetMessagesFiltroDaLeggereEOrdine()
    {
        await _client.GetFromJsonAsync<JsonElement>("/folders/INBOX/messages?unread=true&order=asc");
        Assert.Equal((true, true), _reader.LastHeadersView);

        await _client.GetFromJsonAsync<JsonElement>("/folders/INBOX/messages");
        Assert.Equal((false, false), _reader.LastHeadersView); // predefiniti: tutti, dal più recente

        Assert.Equal(HttpStatusCode.BadRequest, (await _client.GetAsync("/folders/INBOX/messages?order=a-caso")).StatusCode);

        // Ordinamento per colonna (3.9).
        Assert.Equal(MessageSort.Date, _reader.LastHeadersSort);
        await _client.GetFromJsonAsync<JsonElement>("/folders/INBOX/messages?sort=from&order=asc");
        Assert.Equal(MessageSort.From, _reader.LastHeadersSort);
        await _client.GetFromJsonAsync<JsonElement>("/folders/INBOX/messages?sort=Size");
        Assert.Equal(MessageSort.Size, _reader.LastHeadersSort);
        Assert.Equal(HttpStatusCode.BadRequest, (await _client.GetAsync("/folders/INBOX/messages?sort=colore")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await _client.GetAsync("/folders/INBOX/messages?sort=2")).StatusCode);
    }

    [Theory]
    [InlineData("limit=0")]
    [InlineData("limit=201")]
    [InlineData("offset=-1")]
    public async Task GetMessagesParametriNonValidi400(string query)
    {
        var resp = await _client.GetAsync($"/folders/INBOX/messages?{query}");

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.Equal("application/problem+json", resp.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task GetMessage()
    {
        var json = await _client.GetFromJsonAsync<JsonElement>("/messages/INBOX/3");

        Assert.Equal("ciao", json.GetProperty("textBody").GetString());
    }

    [Fact]
    public async Task GetMessageInesistente404()
    {
        var resp = await _client.GetAsync("/messages/INBOX/999");

        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode);
        var problem = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Contains("999", problem.GetProperty("detail").GetString());
    }

    [Fact]
    public async Task GetAttachmentRestituisceByteEContentType()
    {
        var resp = await _client.GetAsync("/messages/INBOX/3/attachments/0");

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal("image/jpeg", resp.Content.Headers.ContentType?.MediaType);
        Assert.Equal("foto.jpg", resp.Content.Headers.ContentDisposition?.FileName);
        Assert.Equal(new byte[] { 0xFF, 0xD8, 0xFF }, await resp.Content.ReadAsByteArrayAsync());
    }

    [Theory]
    [InlineData("/messages/INBOX/3/attachments/5", HttpStatusCode.NotFound)]
    [InlineData("/messages/INBOX/3/attachments/-1", HttpStatusCode.NotFound)] // vincolo di route min(0)
    public async Task GetAttachmentInesistente(string url, HttpStatusCode expected)
    {
        Assert.Equal(expected, (await _client.GetAsync(url)).StatusCode);
    }


    [Fact]
    public async Task SendUsaMittenteConfiguratoEPiuDestinatari()
    {
        var resp = await _client.PostAsJsonAsync("/send",
            new { to = new[] { "a@example.com", " b@example.com ", "" }, cc = new[] { "c@example.com" }, subject = "S", body = "B" });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var sent = Assert.Single(_sender.Sent);
        Assert.Equal("me@example.com", sent.From);
        Assert.Equal(["a@example.com", "b@example.com"], sent.To); // spazi e voci vuote ripuliti
        Assert.Equal(["c@example.com"], sent.Cc);
    }

    [Theory]
    [InlineData("""{"subject":"S","body":"B"}""")]
    [InlineData("""{"to":[],"subject":"S","body":"B"}""")]
    public async Task SendSenzaDestinatario400SulCampoTo(string json)
    {
        var resp = await _client.PostAsync("/send", new StringContent(json, System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.True(await HasFieldError(resp, "to"));
        Assert.Empty(_sender.Sent);
    }

    [Theory]
    [InlineData("to")]
    [InlineData("cc")]
    public async Task SendIndirizzoNonValido400SulCampoGiusto(string field)
    {
        object body = field == "to"
            ? new { to = new[] { "mario" }, subject = "S", body = "B" }
            : new { to = new[] { "ok@example.com" }, cc = new[] { "mario" }, subject = "S", body = "B" };

        var resp = await _client.PostAsJsonAsync("/send", body);

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.True(await HasFieldError(resp, field));
        Assert.Empty(_sender.Sent);
    }

    [Fact]
    public async Task VersioneDelCoreDaDirectoryBuildProps()
    {
        var json = await _client.GetFromJsonAsync<JsonElement>("/version");

        Assert.Matches(@"^0\.0\.\d+$", json.GetProperty("version").GetString()); // senza "+hash"
        Assert.StartsWith(".NET", json.GetProperty("runtime").GetString());
        Assert.False(string.IsNullOrEmpty(json.GetProperty("os").GetString()));
    }

    [Fact]
    public async Task GetAccountIndirizzoEStatoMaiPassword()
    {
        var json = await _client.GetFromJsonAsync<JsonElement>("/account");

        Assert.Equal("me@example.com", json.GetProperty("address").GetString());
        Assert.False(json.GetProperty("configured").GetBoolean()); // nessuna password IMAP nei test
        Assert.Equal(["address", "configured"], json.EnumerateObject().Select(p => p.Name)); // niente password
    }

    [Fact]
    public async Task GetAccountConfiguratoConDatiCompleti()
    {
        using var factory = _factory.WithWebHostBuilder(b =>
        {
            b.UseSetting("Imap:Username", "me@example.com");
            b.UseSetting("Imap:Password", "segreta");
        });
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", Token);

        var json = await client.GetFromJsonAsync<JsonElement>("/account");

        Assert.True(json.GetProperty("configured").GetBoolean());
    }

    [Fact]
    public async Task AccountTestServerIrraggiungibileErroreLeggibileSenzaPassword()
    {
        // Porta 1 su loopback: connessione rifiutata subito, nessun traffico verso l'esterno.
        var resp = await _client.PostAsJsonAsync("/account/test", new
        {
            email = "me@example.com", password = "SEGRETA-123", imapHost = "127.0.0.1", imapPort = 1,
            smtpHost = "127.0.0.1", smtpPort = 1,
        });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var body = await resp.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(body).RootElement;
        Assert.False(json.GetProperty("imap").GetProperty("ok").GetBoolean());
        Assert.False(json.GetProperty("smtp").GetProperty("ok").GetBoolean());
        Assert.Contains("127.0.0.1:1", json.GetProperty("imap").GetProperty("error").GetString());
        Assert.DoesNotContain("SEGRETA-123", body);
    }

    [Fact]
    public async Task AccountTestAccettaCrittografiaEAutenticazione()
    {
        var resp = await _client.PostAsJsonAsync("/account/test", new
        {
            email = "me@example.com", password = "x", imapHost = "127.0.0.1", imapPort = 1, imapSecurity = "StartTls",
            smtpHost = "127.0.0.1", smtpPort = 1, smtpSecurity = "None", smtpRequireAuth = false,
            imapCertificateSha256 = new string('A', 64),
        });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var json = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Contains("127.0.0.1:1", json.GetProperty("smtp").GetProperty("error").GetString());
    }

    [Fact]
    public async Task AccountTestCrittografiaSconosciuta400()
    {
        var json = "{\"email\":\"a@b.it\",\"password\":\"x\",\"imapHost\":\"h\",\"smtpHost\":\"h\",\"imapSecurity\":\"Boh\"}";
        var resp = await _client.PostAsync("/account/test", new StringContent(json, System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
    }

    [Theory]
    [InlineData("{\"email\":\"\",\"password\":\"x\",\"imapHost\":\"h\",\"smtpHost\":\"h\"}")]
    [InlineData("{\"email\":\"a@b.it\",\"password\":\"x\",\"imapHost\":\"h\",\"imapPort\":0,\"smtpHost\":\"h\"}")]
    public async Task AccountTestDatiIncompleti400(string json)
    {
        var resp = await _client.PostAsync("/account/test", new StringContent(json, System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
    }

    [Theory]
    [InlineData("reply", DraftMode.Reply)]
    [InlineData("replyAll", DraftMode.ReplyAll)]
    [InlineData("forward", DraftMode.Forward)]
    public async Task GetDraftPassaModalitaEIndirizzoAccount(string mode, DraftMode expected)
    {
        var json = await _client.GetFromJsonAsync<JsonElement>($"/messages/INBOX/3/draft?mode={mode}");

        Assert.Equal((3u, expected, "me@example.com"), _reader.LastDraftCall);
        Assert.Equal("Re: Terza", json.GetProperty("subject").GetString());
        Assert.Equal("orig@example.com", json.GetProperty("inReplyTo").GetString());
    }

    [Theory]
    [InlineData("/messages/INBOX/3/draft")]
    [InlineData("/messages/INBOX/3/draft?mode=boh")]
    public async Task GetDraftModalitaMancanteONonValida400(string url)
    {
        Assert.Equal(HttpStatusCode.BadRequest, (await _client.GetAsync(url)).StatusCode);
    }

    [Fact]
    public async Task SendInoltraInReplyToEReferences()
    {
        var resp = await _client.PostAsJsonAsync("/send", new
        {
            to = new[] { "a@example.com" }, subject = "Re: x", body = "B",
            inReplyTo = "orig@example.com", references = new[] { "root@example.com", "orig@example.com" },
        });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var sent = Assert.Single(_sender.Sent);
        Assert.Equal("orig@example.com", sent.InReplyTo);
        Assert.Equal(["root@example.com", "orig@example.com"], sent.References);
    }

    [Fact]
    public async Task SendFormattatoConCitazioneRipresaDalCore()
    {
        var resp = await _client.PostAsJsonAsync("/send", new
        {
            to = new[] { "a@example.com" }, subject = "Re: Terza", body = "Ciao",
            htmlBody = "<p><b>Ciao</b></p><script>alert(1)</script>",
            quote = new { folder = "INBOX/Sub", uid = 3, mode = "replyAll" },
        });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal(("INBOX/Sub", 3u, DraftMode.ReplyAll), _reader.LastQuoteCall);
        var mime = Assert.Single(_sender.SentMime);
        Assert.Equal("Ciao\n\n> citato", mime.TextBody);
        Assert.Contains("<b>Ciao</b>", mime.HtmlBody);
        Assert.Contains("<p>citato</p>", mime.HtmlBody);
        Assert.DoesNotContain("script", mime.HtmlBody);
    }

    [Fact]
    public async Task SendCitazioneConModalitaNonValida400()
    {
        var resp = await _client.PostAsJsonAsync("/send", new
        {
            to = new[] { "a@example.com" }, subject = "S", body = "B",
            quote = new { folder = "INBOX", uid = 3, mode = "rispondi" },
        });

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        var problem = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(problem.GetProperty("errors").TryGetProperty("quote", out _));
        Assert.Empty(_sender.Sent);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task PutSeenImpostaIlFlag(bool seen)
    {
        var resp = await _client.PutAsJsonAsync("/messages/INBOX%2FSub/3/seen", new { seen });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal(seen, (await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("seen").GetBoolean());
        Assert.Equal(("INBOX/Sub", 3u, seen), Assert.Single(_writer.SeenCalls));
    }

    [Fact]
    public async Task PutFlagsContrassegnoCompletatoECategorie()
    {
        var resp = await _client.PutAsJsonAsync("/messages/INBOX/3/flags", new { followUp = "flagged", due = "2026-11-05", categories = new[] { 1, 4 } });
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var json = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(json.GetProperty("flagged").GetBoolean());
        Assert.False(json.GetProperty("completed").GetBoolean());
        Assert.Equal([1, 4], json.GetProperty("categories").EnumerateArray().Select(c => c.GetInt32()));
        Assert.Equal(JsonValueKind.Null, json.GetProperty("due").ValueKind); // senza cache la scadenza non si salva
        var call = Assert.Single(_writer.FlagCalls);
        Assert.Equal(MailFlags.Flagged | MailFlags.Category1 | MailFlags.Category4, call.Add);
        Assert.Equal(MailFlags.Completed | MailFlags.Category2 | MailFlags.Category3 | MailFlags.Category5 | MailFlags.Category6,
            call.Remove);

        resp = await _client.PutAsJsonAsync("/messages/INBOX/3/flags", new { followUp = "completed" });
        json = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.False(json.GetProperty("flagged").GetBoolean());
        Assert.True(json.GetProperty("completed").GetBoolean());
        Assert.Equal(2, json.GetProperty("categories").GetArrayLength()); // categorie non toccate
    }

    [Theory]
    [InlineData("{\"followUp\":\"forse\"}", "followUp")]
    [InlineData("{\"categories\":[7]}", "categories")]
    [InlineData("{\"followUp\":\"none\",\"due\":\"2026-11-05\"}", "due")]
    [InlineData("{}", "followUp")]
    public async Task PutFlagsNonValido400(string body, string field)
    {
        var resp = await _client.PutAsync("/messages/INBOX/3/flags", new StringContent(body, System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.True((await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("errors").TryGetProperty(field, out _));
        Assert.Empty(_writer.FlagCalls);
    }

    [Fact]
    public async Task PutSeenSenzaValore400()
    {
        var resp = await _client.PutAsJsonAsync("/messages/INBOX/3/seen", new { });

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.Empty(_writer.SeenCalls);
    }

    [Fact]
    public async Task PutSeenMessaggioInesistente404()
    {
        var resp = await _client.PutAsJsonAsync("/messages/INBOX/999/seen", new { seen = true });

        Assert.Equal(HttpStatusCode.NotFound, resp.StatusCode);
    }

    [Fact]
    public async Task PutSeenSenzaToken401()
    {
        var resp = await _factory.CreateClient().PutAsJsonAsync("/messages/INBOX/3/seen", new { seen = true });

        Assert.Equal(HttpStatusCode.Unauthorized, resp.StatusCode);
        Assert.Empty(_writer.SeenCalls);
    }

    [Fact]
    public async Task SendConAllegatiBase64EAllegatiInoltrati()
    {
        var resp = await _client.PostAsJsonAsync("/send", new
        {
            to = new[] { "a@example.com" }, subject = "Fwd: x", body = "B",
            attachments = new[] { new { fileName = "nota.txt", data = Convert.ToBase64String("ciao"u8.ToArray()) } },
            forwardAttachments = new { folder = "INBOX/Sub", uid = 3, indexes = new[] { 0, 2 } },
        });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal(("INBOX/Sub", 3u), (_reader.AttachmentBatchCalls.Single().Folder, _reader.AttachmentBatchCalls.Single().Uid));
        var sent = _sender.SentMime.Single();
        Assert.Equal(["nota.txt", "originale0.pdf", "originale2.pdf"],
            sent.Attachments.OfType<MimeKit.MimePart>().Select(p => p.FileName));
        Assert.Equal("text/plain", sent.Attachments.OfType<MimeKit.MimePart>().First().ContentType.MimeType);
    }

    [Fact]
    public async Task SendAllegatiOltre25Mb400SulCampoAttachments()
    {
        var big = Convert.ToBase64String(new byte[26 * 1024 * 1024]);
        var resp = await _client.PostAsJsonAsync("/send", new
        {
            to = new[] { "a@example.com" }, subject = "S", body = "B",
            attachments = new[] { new { fileName = "grande.bin", data = big } },
        });

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.True(await HasFieldError(resp, "attachments"));
        Assert.Empty(_sender.Sent);
    }

    [Fact]
    public async Task SendSenzaSaveCopyNonScriveNellaCasella()
    {
        var resp = await _client.PostAsJsonAsync("/send", new { to = new[] { "a@example.com" }, subject = "S", body = "B" });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Single(_sender.Sent);
        Assert.Empty(_writer.Appended);
        var json = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(JsonValueKind.Null, json.GetProperty("savedTo").ValueKind);
    }

    [Fact]
    public async Task SendConSaveCopySalvaLoStessoMessaggioInviato()
    {
        var resp = await _client.PostAsJsonAsync("/send",
            new { to = new[] { "a@example.com" }, subject = "S", body = "B", saveCopy = true });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var appended = Assert.Single(_writer.Appended);
        Assert.Same(_sender.SentMime.Single(), appended); // stesso oggetto: stesso Message-ID, data, intestazioni
        var json = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Posta inviata", json.GetProperty("savedTo").GetString());
    }

    [Fact]
    public async Task CopiaFallitaMaMailInviata200ConSaveError()
    {
        _writer.AppendFailure = new MailNotFoundException("Il server non dichiara una cartella \\Sent");

        var resp = await _client.PostAsJsonAsync("/send",
            new { to = new[] { "a@example.com" }, subject = "S", body = "B", saveCopy = true });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode); // la mail è partita
        Assert.Single(_sender.Sent);
        var json = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Contains("Sent", json.GetProperty("saveError").GetString());
        Assert.Equal(JsonValueKind.Null, json.GetProperty("savedTo").ValueKind);
    }

    [Fact]
    public async Task InvioFallitoNessunaCopia()
    {
        var resp = await _client.PostAsJsonAsync("/send", new { to = new[] { "mario" }, subject = "S", body = "B", saveCopy = true });

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.Empty(_writer.Appended);
    }

    [Fact]
    public async Task MoveSpostaNellaDestinazione()
    {
        var resp = await _client.PostAsJsonAsync("/messages/INBOX/3/move", new { destination = "Archivio" });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal(("INBOX", 3u, "Archivio"), Assert.Single(_writer.Moves));
        Assert.Equal("Archivio", (await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("movedTo").GetString());
    }

    [Theory]
    [InlineData("INBOX", HttpStatusCode.Conflict)]       // stessa cartella
    [InlineData("Inesistente", HttpStatusCode.NotFound)]
    [InlineData("", HttpStatusCode.BadRequest)]
    public async Task MoveNonValido(string destination, HttpStatusCode expected)
    {
        var resp = await _client.PostAsJsonAsync("/messages/INBOX/3/move", new { destination });

        Assert.Equal(expected, resp.StatusCode);
        Assert.Empty(_writer.Moves);
    }

    [Fact]
    public async Task InBloccoLettoSoloLeMailEsistenti()
    {
        var resp = await _client.PutAsJsonAsync("/messages/INBOX/seen", new { uids = new[] { 3, 5, 5, 42 }, seen = true });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var body = await resp.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal([3u, 5u], body.GetProperty("uids").EnumerateArray().Select(e => e.GetUInt32()));
        var batch = Assert.Single(_writer.SeenBatches);
        Assert.Equal(("INBOX", true), (batch.Folder, batch.Seen));
        Assert.Equal([3u, 5u], batch.Uids);
    }

    [Fact]
    public async Task InBloccoCategorieAggiunteETolteEContrassegno()
    {
        _writer.Flags[("INBOX", 3)] = MailKeywords.Category(2);

        var resp = await _client.PutAsJsonAsync("/messages/INBOX/flags",
            new { uids = new[] { 3, 4 }, followUp = "flagged", addCategories = new[] { 1 }, removeCategories = new[] { 2 } });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        var items = (await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("items").EnumerateArray().ToList();
        Assert.Equal(2, items.Count);
        foreach (var item in items)
        {
            Assert.True(item.GetProperty("flagged").GetBoolean());
            Assert.Equal([1], item.GetProperty("categories").EnumerateArray().Select(e => e.GetInt32()));
        }
    }

    [Theory]
    [InlineData("{\"uids\":[],\"seen\":true}", "seen", "uids")]
    [InlineData("{\"seen\":true}", "seen", "uids")]
    [InlineData("{\"uids\":[3]}", "seen", "seen")]
    [InlineData("{\"uids\":[3],\"addCategories\":[1],\"removeCategories\":[1]}", "flags", "removeCategories")]
    [InlineData("{\"uids\":[3],\"addCategories\":[9]}", "flags", "addCategories")]
    [InlineData("{\"uids\":[3]}", "flags", "followUp")]
    public async Task InBloccoRichiestaNonValida400(string body, string action, string field)
    {
        var resp = await _client.PutAsync($"/messages/INBOX/{action}", new StringContent(body, System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.True((await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("errors").TryGetProperty(field, out _));
        Assert.Empty(_writer.SeenBatches);
        Assert.Empty(_writer.FlagBatches);
    }

    [Fact]
    public async Task InBloccoTroppeMail400()
    {
        var uids = Enumerable.Range(1, PostinoVip.Api.Controllers.MessagesController.MaxBatch + 1).ToArray();
        var resp = await _client.PutAsJsonAsync("/messages/INBOX/seen", new { uids, seen = true });

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
    }

    [Fact]
    public async Task InBloccoSpostaEdElimina()
    {
        var move = await _client.PostAsJsonAsync("/messages/INBOX/move", new { uids = new[] { 3, 4 }, destination = "Archivio" });
        var trash = await _client.PostAsJsonAsync("/messages/INBOX/delete", new { uids = new[] { 5 } });
        var inTrash = await _client.PostAsJsonAsync("/messages/Posta%20eliminata/delete", new { uids = new[] { 6, 7 } });
        var permanentOutside = await _client.PostAsJsonAsync("/messages/INBOX/delete", new { uids = new[] { 6 }, permanent = true });
        var permanent = await _client.PostAsJsonAsync("/messages/Posta%20eliminata/delete", new { uids = new[] { 6, 7, 50 }, permanent = true });

        Assert.Equal("Archivio", (await move.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("movedTo").GetString());
        Assert.Equal(FakeMailWriter.Trash, (await trash.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("movedTo").GetString());
        Assert.Equal(HttpStatusCode.Conflict, inTrash.StatusCode); // già nel cestino: serve permanent
        Assert.Equal(HttpStatusCode.Conflict, permanentOutside.StatusCode);
        var body = await permanent.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("permanent").GetBoolean());
        Assert.Equal([6u, 7u], body.GetProperty("uids").EnumerateArray().Select(e => e.GetUInt32()));
        Assert.Equal(["INBOX 3,4 -> Archivio", $"INBOX 5 -> {FakeMailWriter.Trash}"],
            _writer.MoveBatches.Select(m => $"{m.From} {string.Join(',', m.Uids)} -> {m.To}"));
    }

    [Fact]
    public async Task ConversazioniPassaParametriERestituisceLeMailConLaCartella()
    {
        var resp = await _client.GetAsync("/folders/INBOX%2FSub/conversations?offset=20&limit=10&unread=true&order=asc");

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal(("INBOX/Sub", 20, 10, true, true), _reader.LastConversationsCall);
        var item = (await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("items")[0];
        Assert.Equal(42, item.GetProperty("id").GetInt64());
        Assert.Equal(2, item.GetProperty("count").GetInt32());
        Assert.Equal(1, item.GetProperty("unread").GetInt32());
        Assert.True(item.GetProperty("hasAttachments").GetBoolean());
        var sent = item.GetProperty("messages")[1];
        Assert.Equal("Posta inviata", sent.GetProperty("folder").GetString());
        Assert.Equal(2u, sent.GetProperty("message").GetProperty("uid").GetUInt32());
    }

    [Theory]
    [InlineData("limit=0")]
    [InlineData("limit=201")]
    [InlineData("offset=-1")]
    [InlineData("order=x")]
    public async Task ConversazioniParametriNonValidi400(string query)
    {
        var resp = await _client.GetAsync($"/folders/INBOX/conversations?{query}");

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.Null(_reader.LastConversationsCall);
    }

    [Fact]
    public async Task InBloccoCopiaSoloLeMailEsistenti()
    {
        var copy = await _client.PostAsJsonAsync("/messages/INBOX/copy", new { uids = new[] { 3, 4, 50 }, destination = "Archivio" });
        var same = await _client.PostAsJsonAsync("/messages/INBOX/copy", new { uids = new[] { 3 }, destination = "INBOX" });
        var noDest = await _client.PostAsJsonAsync("/messages/INBOX/copy", new { uids = new[] { 3 } });

        var body = await copy.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(HttpStatusCode.OK, copy.StatusCode);
        Assert.Equal("Archivio", body.GetProperty("copiedTo").GetString());
        Assert.Equal([3u, 4u], body.GetProperty("uids").EnumerateArray().Select(e => e.GetUInt32()));
        Assert.Equal(HttpStatusCode.Conflict, same.StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, noDest.StatusCode);
        Assert.Equal(["INBOX 3,4 -> Archivio"], _writer.CopyBatches.Select(m => $"{m.From} {string.Join(',', m.Uids)} -> {m.To}"));
        Assert.Empty(_writer.MoveBatches);
    }

    [Fact]
    public async Task SpostaCartellaDentroUnAltraEInCima()
    {
        var inside = await _client.PostAsJsonAsync("/folders/Clienti/move", new { parent = "INBOX" });
        var top = await _client.PostAsJsonAsync("/folders/INBOX%2FRossi/move", new { parent = (string?)null });

        Assert.Equal(HttpStatusCode.OK, inside.StatusCode);
        Assert.Equal("INBOX/Clienti", (await inside.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("fullName").GetString());
        Assert.Equal("Rossi", (await top.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("fullName").GetString());
        Assert.Equal([("Clienti", "INBOX/Clienti"), ("INBOX/Rossi", "Rossi")], _writer.MovedFolders);
    }

    [Fact]
    public async Task SpostaCartellaNomeUsato400TranneInPostaEliminata()
    {
        var used = await _client.PostAsJsonAsync("/folders/A%2FEsistente/move", new { parent = "INBOX" });
        var trash = await _client.PostAsJsonAsync("/folders/A%2FEsistente/move", new { parent = FakeMailWriter.Trash });

        Assert.Equal(HttpStatusCode.BadRequest, used.StatusCode);
        Assert.True((await used.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("errors").TryGetProperty("parent", out _));
        Assert.Equal($"{FakeMailWriter.Trash}/Esistente (2)",
            (await trash.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("fullName").GetString());
    }

    [Theory]
    [InlineData("INBOX", "Clienti", HttpStatusCode.Conflict)]             // cartella speciale
    [InlineData("Clienti", "Clienti%2FSub", HttpStatusCode.Conflict)]     // dentro sé stessa
    [InlineData("Inesistente", "INBOX", HttpStatusCode.NotFound)]
    [InlineData("Clienti", "Inesistente", HttpStatusCode.NotFound)]
    public async Task SpostaCartellaNonConsentita(string folder, string parent, HttpStatusCode expected)
    {
        var resp = await _client.PostAsJsonAsync($"/folders/{folder}/move", new { parent = Uri.UnescapeDataString(parent) });

        Assert.Equal(expected, resp.StatusCode);
        Assert.Empty(_writer.MovedFolders);
    }

    [Fact]
    public async Task NuovaCartellaInCimaEDentroUnaCartella()
    {
        var top = await _client.PostAsJsonAsync("/folders", new { name = " Clienti " });
        var inner = await _client.PostAsJsonAsync("/folders", new { parent = "INBOX", name = "Rossi" });

        Assert.Equal(HttpStatusCode.Created, top.StatusCode);
        Assert.Equal("Clienti", (await top.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("fullName").GetString());
        var body = await inner.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("INBOX/Rossi", body.GetProperty("fullName").GetString());
        Assert.Equal("/", body.GetProperty("separator").GetString());
        Assert.Equal([(null, "Clienti"), ("INBOX", "Rossi")], _writer.CreatedFolders);
    }

    [Theory]
    [InlineData("")]
    [InlineData("a/b")]
    [InlineData("Esistente")]
    public async Task NuovaCartellaConNomeNonValido400SulCampoName(string name)
    {
        var resp = await _client.PostAsJsonAsync("/folders", new { name });

        Assert.Equal(HttpStatusCode.BadRequest, resp.StatusCode);
        Assert.True((await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("errors").TryGetProperty("name", out _));
        Assert.Empty(_writer.CreatedFolders);
    }

    [Fact]
    public async Task RinominaCartella()
    {
        var resp = await _client.PostAsJsonAsync("/folders/INBOX%2FClienti/rename", new { name = "Fornitori" });

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal("INBOX/Fornitori", (await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("fullName").GetString());
        Assert.Equal(("INBOX/Clienti", "INBOX/Fornitori"), Assert.Single(_writer.RenamedFolders));
    }

    [Theory]
    [InlineData("INBOX", HttpStatusCode.Conflict)]
    [InlineData("Posta%20eliminata", HttpStatusCode.Conflict)]
    [InlineData("Inesistente", HttpStatusCode.NotFound)]
    public async Task CartellaSpecialeOInesistenteNonSiRinominaNeSiElimina(string folder, HttpStatusCode expected)
    {
        var rename = await _client.PostAsJsonAsync($"/folders/{folder}/rename", new { name = "Altro" });
        var delete = await _client.DeleteAsync($"/folders/{folder}");

        Assert.Equal(expected, rename.StatusCode);
        Assert.Equal(expected, delete.StatusCode);
        Assert.Empty(_writer.RenamedFolders);
        Assert.Empty(_writer.DeletedFolders);
    }

    [Fact]
    public async Task EliminaCartellaLaSpostaInPostaEliminataPoiDefinitiva()
    {
        var moved = await _client.DeleteAsync("/folders/Clienti");
        var body = await moved.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(HttpStatusCode.OK, moved.StatusCode);
        Assert.Equal("Posta eliminata/Clienti", body.GetProperty("movedTo").GetString());
        Assert.False(body.GetProperty("permanent").GetBoolean());

        var deleted = await _client.DeleteAsync("/folders/Posta%20eliminata%2FClienti");
        body = await deleted.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(HttpStatusCode.OK, deleted.StatusCode);
        Assert.True(body.GetProperty("permanent").GetBoolean());
        Assert.Equal(JsonValueKind.Null, body.GetProperty("movedTo").ValueKind);
        Assert.Equal([("Clienti", "Posta eliminata/Clienti"), ("Posta eliminata/Clienti", null)], _writer.DeletedFolders);
    }

    [Fact]
    public async Task DeleteSenzaPermanentSpostaInPostaEliminata()
    {
        var resp = await _client.DeleteAsync("/messages/INBOX/3");

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal(("INBOX", 3u, FakeMailWriter.Trash), Assert.Single(_writer.Moves));
        Assert.Empty(_writer.PermanentDeletes);
    }

    [Fact]
    public async Task DeletePermanenteInPostaEliminata()
    {
        var resp = await _client.DeleteAsync("/messages/Posta%20eliminata/3?permanent=true");

        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.True((await resp.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("permanent").GetBoolean());
        Assert.Equal((FakeMailWriter.Trash, 3u), Assert.Single(_writer.PermanentDeletes));
    }

    [Fact]
    public async Task DeletePermanenteFuoriDaPostaEliminata409()
    {
        var resp = await _client.DeleteAsync("/messages/INBOX/3?permanent=true");

        Assert.Equal(HttpStatusCode.Conflict, resp.StatusCode);
        Assert.Empty(_writer.PermanentDeletes);
        Assert.Empty(_writer.Moves);
    }

    [Fact]
    public async Task DeleteSempliceDaPostaEliminata409()
    {
        // Già nel cestino: serve la scelta esplicita permanent=true, non si "sposta" di nuovo.
        var resp = await _client.DeleteAsync("/messages/Posta%20eliminata/3");

        Assert.Equal(HttpStatusCode.Conflict, resp.StatusCode);
        Assert.Empty(_writer.PermanentDeletes);
    }

    [Fact]
    public async Task MoveEDeleteSenzaToken401()
    {
        var client = _factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.DeleteAsync("/messages/INBOX/3")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.PostAsJsonAsync("/messages/INBOX/3/move", new { destination = "Archivio" })).StatusCode);
        Assert.Empty(_writer.Moves);
    }

    [Fact]
    public async Task EventsSseInviaGliEventiPubblicati()
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "/events");
        using var resp = await _client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
        Assert.Equal("text/event-stream", resp.Content.Headers.ContentType?.MediaType);

        using var reader = new StreamReader(await resp.Content.ReadAsStreamAsync());
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        Assert.Equal(": connesso", await reader.ReadLineAsync(timeout.Token));

        var hub = _factory.Services.GetRequiredService<PostinoVip.Core.Events.MailboxEventHub>();
        hub.Publish(PostinoVip.Core.Events.MailboxEvent.Changed("main", "INBOX", 2066));

        string? line;
        do line = await reader.ReadLineAsync(timeout.Token);
        while (line is "");
        Assert.Equal("""data: {"type":"mailbox-changed","account":"main","folder":"INBOX","count":2066}""", line);
    }

    [Fact]
    public async Task EventsSiChiudeQuandoIlCoreSiArresta()
    {
        // Prima la richiesta restava aperta fino al tempo massimo di arresto (30 s): l'app si chiudeva lenta.
        using var request = new HttpRequestMessage(HttpMethod.Get, "/events");
        using var resp = await _client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
        using var reader = new StreamReader(await resp.Content.ReadAsStreamAsync());
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        Assert.Equal(": connesso", await reader.ReadLineAsync(timeout.Token));

        _factory.Services.GetRequiredService<IHostApplicationLifetime>().StopApplication();

        string? line;
        do line = await reader.ReadLineAsync(timeout.Token); // entro 5 s, non dopo il ping dei 30 s
        while (line is "");
        Assert.Null(line);
    }

    [Fact]
    public async Task EventsSenzaToken401()
    {
        var resp = await _factory.CreateClient().GetAsync("/events");

        Assert.Equal(HttpStatusCode.Unauthorized, resp.StatusCode);
    }

    [Fact]
    public void NeiTestIlControlloInTempoRealeEDisattivato()
    {
        // Gli user-secrets (credenziali reali) sono caricati anche nei test: nessun IDLE verso il server.
        var hosted = _factory.Services.GetServices<IHostedService>();
        Assert.DoesNotContain(hosted, s => s is InboxWatcherService);
    }

    /// <summary>ValidationProblemDetails: errors contiene una chiave uguale al campo (senza distinzione di maiuscole).</summary>
    private static async Task<bool> HasFieldError(HttpResponseMessage resp, string field)
    {
        var problem = await resp.Content.ReadFromJsonAsync<JsonElement>();
        return problem.TryGetProperty("errors", out var errors)
            && errors.EnumerateObject().Any(e => e.Name.Equals(field, StringComparison.OrdinalIgnoreCase));
    }
}
