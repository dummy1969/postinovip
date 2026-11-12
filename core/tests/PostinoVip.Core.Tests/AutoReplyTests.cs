using System.Text;
using MimeKit;
using PostinoVip.Core.Account;
using PostinoVip.Core.AutoReply;
using PostinoVip.Core.Local;
using PostinoVip.Core.Models;
using PostinoVip.Core.Pop3;

namespace PostinoVip.Core.Tests;

/// <summary>Risposte automatiche: filtri RFC 3834, messaggio, impostazioni, invio sulle mail nuove (invio finto).</summary>
public sealed class AutoReplyTests : IDisposable
{
    private const string Me = "io@example.com";
    private readonly string _dir = Directory.CreateTempSubdirectory("postinovip-autoreply-").FullName;

    public void Dispose()
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        Directory.Delete(_dir, recursive: true);
    }

    private static string Raw(string from = "Anna <anna@cliente.it>", string to = Me, string subject = "Preventivo", string extra = "",
        string received = "Mon, 02 Nov 2026 10:00:00 +0100") =>
        $"Received: from mx by posta; {received}\r\nFrom: {from}\r\nTo: {to}\r\nSubject: {subject}\r\n" +
        $"Message-ID: <{Guid.NewGuid():N}@cliente.it>\r\nDate: Mon, 02 Nov 2026 10:00:00 +0100\r\n{extra}\r\nTesto\r\n";

    private static MimeMessage Mime(string raw) => MimeMessage.Load(new MemoryStream(Encoding.UTF8.GetBytes(raw)));

    // --- Filtri ------------------------------------------------------------------------------------

    [Theory]
    [InlineData("Auto-Submitted: auto-replied\r\n", "Anna <anna@cliente.it>", Me, "automatico")]
    [InlineData("Precedence: bulk\r\n", "Anna <anna@cliente.it>", Me, "massa")]
    [InlineData("List-Id: <soci.example.org>\r\n", "Anna <anna@cliente.it>", Me, "mailing list")]
    [InlineData("List-Unsubscribe: <mailto:x@y>\r\n", "News <news@shop.it>", Me, "mailing list")]
    [InlineData("X-Auto-Response-Suppress: OOF\r\n", "Anna <anna@cliente.it>", Me, "chiede")]
    [InlineData("Return-Path: <>\r\n", "Anna <anna@cliente.it>", Me, "vuoto")]
    [InlineData("", "MAILER-DAEMON@posta.it", Me, "sistema")]
    [InlineData("", "Shop <noreply@shop.it>", Me, "sistema")]
    [InlineData("", "Io <IO@example.com>", "altro@example.com", "da me")]
    [InlineData("", "Anna <anna@cliente.it>", "lista@example.com", "A o Cc")]
    public void NonRispondeQuandoLaRfc3834LoSconsiglia(string extra, string from, string to, string why)
    {
        Assert.Null(AutoReplyPolicy.Recipient(Mime(Raw(from, to, extra: extra)), Me, [], out var reason));
        Assert.Contains(why, reason);
    }

    [Fact]
    public void RispondeAlMittenteUnaVoltaSola()
    {
        Assert.Equal("anna@cliente.it", AutoReplyPolicy.Recipient(Mime(Raw()), Me, [], out _));
        Assert.Equal("anna@cliente.it", AutoReplyPolicy.Recipient(Mime(Raw(extra: "Auto-Submitted: no\r\n")), Me, [], out _));
        Assert.Equal("anna@cliente.it", AutoReplyPolicy.Recipient(Mime(Raw(to: $"altro@x.it, Io <{Me}>")), Me, [], out _));
        Assert.Null(AutoReplyPolicy.Recipient(Mime(Raw()), Me, ["ANNA@cliente.it"], out var reason));
        Assert.Contains("già", reason);
    }

    [Fact]
    public void LaRispostaECollegataEMarcataComeAutomatica()
    {
        var original = Mime(Raw());
        var settings = new AutoReplySettings { Enabled = true, Html = "<p>Sono <b>fuori sede</b></p>", Text = "Sono fuori sede" };

        var reply = AutoReplyPolicy.Build(original, Me, "anna@cliente.it", settings);

        Assert.Equal("Risposta automatica: Preventivo", reply.Subject);
        Assert.Equal("auto-replied", reply.Headers[HeaderId.AutoSubmitted]);
        Assert.Equal("All", reply.Headers["X-Auto-Response-Suppress"]);
        Assert.Equal(original.MessageId, reply.InReplyTo);
        Assert.Contains(original.MessageId, reply.References);
        Assert.Equal("anna@cliente.it", reply.To.Mailboxes.Single().Address);
        Assert.Equal(Me, reply.From.Mailboxes.Single().Address);
        Assert.Contains("fuori sede", reply.TextBody);
        Assert.Contains("<b>fuori sede</b>", reply.HtmlBody);
    }

    // --- Impostazioni ------------------------------------------------------------------------------

    [Fact]
    public void ControlliEGenerazioneSoloAdAttivazioneOCambioDiIntervallo()
    {
        var store = new AutoReplyStore(_dir);
        Assert.False(store.Load().Enabled);
        Assert.Equal("text", Assert.Throws<FieldValidationException>(() => store.Save(new AutoReplySettings { Enabled = true })).Field);
        var start = new DateTimeOffset(2026, 11, 10, 8, 0, 0, TimeSpan.Zero);
        Assert.Equal("end", Assert.Throws<FieldValidationException>(() =>
            store.Save(new AutoReplySettings { Enabled = true, Text = "x", Start = start, End = start })).Field);

        store.Save(new AutoReplySettings { Enabled = true, Text = "Fuori sede" });
        var first = store.LoadState().Generation;
        store.SaveState(store.LoadState() with { LastUid = 5, Replied = ["anna@cliente.it"] });

        store.Save(new AutoReplySettings { Enabled = true, Text = "Fuori sede fino a lunedì" }); // solo il testo
        Assert.Equal((first, 5u), (store.LoadState().Generation, store.LoadState().LastUid!.Value));
        Assert.Single(store.LoadState().Replied);

        store.Save(new AutoReplySettings { Enabled = false, Text = "x" });
        store.Save(new AutoReplySettings { Enabled = true, Text = "x" }); // riattivate: si ricomincia
        Assert.NotEqual(first, store.LoadState().Generation);
        Assert.Empty(store.LoadState().Replied);
        Assert.Null(store.LoadState().LastUid);
        if (!OperatingSystem.IsWindows())
            Assert.Equal(Cache.CachePermissions.PrivateFile, File.GetUnixFileMode(store.StatePath));
    }

    [Fact]
    public void AttiveSoloNellIntervallo()
    {
        var start = new DateTimeOffset(2026, 11, 10, 8, 0, 0, TimeSpan.Zero);
        var s = new AutoReplySettings { Enabled = true, Text = "x", Start = start, End = start.AddDays(3) };
        Assert.False(s.IsActive(start.AddMinutes(-1)));
        Assert.True(s.IsActive(start));
        Assert.False(s.IsActive(start.AddDays(3)));
        Assert.False((s with { Enabled = false }).IsActive(start.AddHours(1)));
        Assert.True(new AutoReplySettings { Enabled = true }.IsActive(DateTimeOffset.MinValue));
    }

    // --- Invio sulle mail nuove (account POP3 locale, invio finto) ---------------------------------

    private sealed class FakeSender : IMailSender
    {
        public List<MimeMessage> Sent { get; } = [];
        public bool Offline { get; set; }

        public Task<SendResult> SendAsync(OutgoingMessage msg, CancellationToken ct = default) => throw new NotSupportedException();

        public Task<string> SendMimeAsync(MimeMessage message, CancellationToken ct = default)
        {
            if (Offline)
                throw new MailOfflineException("non connesso");
            Sent.Add(message);
            return Task.FromResult("250 ok");
        }
    }

    private (MailAccount Account, LocalMailStore Store, FakeSender Sender, MailAccountRegistry Registry) Pop3Account()
    {
        var settings = new MailAccountSettings
        {
            Id = "pop", Type = MailAccountType.Pop3,
            Pop3 = new Pop3Settings { Host = "pop.example.invalid", Username = Me, Password = "x" },
            Smtp = new Smtp.SmtpSettings { Host = "smtp.example.invalid", Username = Me, Password = "x" },
        };
        var registry = MailAccountRegistry.CreateImap([settings], _dir);
        var real = registry.Get("pop");
        var sender = new FakeSender();
        var account = new MailAccount(settings, real.Reader, real.Writer, sender, real.Bodies, null, null, null, real.Rules, real.AutoReply);
        var store = new LocalMailStore(Path.Combine(MailAccountRegistry.CacheDirectory(_dir, "pop"), "mail"));
        store.EnsureDefaults();
        return (account, store, sender, registry);
    }

    private static Task<uint> AddAsync(LocalMailStore store, string raw) =>
        store.AddAsync("INBOX", new MemoryStream(Encoding.UTF8.GetBytes(raw)));

    [Fact]
    public async Task RispondeAlleMailNuoveUnaVoltaPerMittente()
    {
        var (account, store, sender, registry) = Pop3Account();
        await using var _ = registry;
        await AddAsync(store, Raw(subject: "Già presente"));
        account.AutoReply!.Save(new AutoReplySettings { Enabled = true, Html = "<p>Fuori sede</p>", Text = "Fuori sede" });
        var runner = new AutoReplyRunner(account, account.AutoReply!);
        await runner.RunNewAsync(); // punto di partenza: nessuna risposta alle mail già presenti
        Assert.Empty(sender.Sent);

        await AddAsync(store, Raw(subject: "Prima"));
        await AddAsync(store, Raw(subject: "Seconda")); // stesso mittente
        await AddAsync(store, Raw("Lista <soci@club.it>", extra: "List-Id: <soci.club.it>\r\n"));
        await AddAsync(store, Raw("Bruno <bruno@amici.it>", subject: "Ciao"));
        var result = await runner.RunNewAsync();

        Assert.Equal((4, 2, 2), (result.Checked, result.Sent, result.Skipped));
        Assert.Equal(["Risposta automatica: Prima", "Risposta automatica: Ciao"], sender.Sent.Select(m => m.Subject));
        Assert.Equal(0, (await runner.RunNewAsync()).Checked);

        // Spente e riattivate: si ricomincia, ma solo dalle mail nuove.
        account.AutoReply!.Save(new AutoReplySettings { Enabled = false, Text = "Fuori sede" });
        await AddAsync(store, Raw(subject: "Mentre erano spente"));
        Assert.Equal(0, (await runner.RunNewAsync()).Checked);
        account.AutoReply!.Save(new AutoReplySettings { Enabled = true, Text = "Fuori sede" });
        await runner.RunNewAsync();
        await AddAsync(store, Raw(subject: "Terza"));
        await runner.RunNewAsync();
        Assert.Equal("Risposta automatica: Terza", sender.Sent.Last().Subject);
        Assert.Equal(3, sender.Sent.Count);
    }

    [Fact]
    public async Task FuoriDallIntervalloNessunaRispostaESenzaReteSiRiprova()
    {
        var (account, store, sender, registry) = Pop3Account();
        await using var _ = registry;
        // Orari relativi all'ora vera (lezione appresa): le mail devono arrivare dopo l'attivazione, che usa l'ora vera.
        var now = DateTimeOffset.UtcNow;
        var start = now.AddHours(2);
        account.AutoReply!.Save(new AutoReplySettings { Enabled = true, Text = "x", Start = start, End = start.AddDays(5) });
        var runner = new AutoReplyRunner(account, account.AutoReply!);
        await runner.RunNewAsync();

        await AddAsync(store, Raw(subject: "Prima del periodo", received: now.AddHours(1).ToString("r")));
        await AddAsync(store, Raw("Bruno <bruno@amici.it>", subject: "Nel periodo", received: now.AddHours(3).ToString("r")));
        sender.Offline = true;
        await Assert.ThrowsAsync<MailOfflineException>(() => runner.RunNewAsync());
        Assert.Empty(sender.Sent);

        sender.Offline = false;
        var result = await runner.RunNewAsync(); // riprende: la prima di nuovo esaminata (era prima del periodo)
        Assert.Equal("Risposta automatica: Nel periodo", Assert.Single(sender.Sent).Subject);
        Assert.Equal(1, result.Sent);
    }

    [Fact]
    public async Task LaPrimaMailDopoLAttivazioneRiceveLaRisposta()
    {
        var (account, store, sender, registry) = Pop3Account();
        await using var _ = registry;
        await AddAsync(store, Raw(subject: "Vecchia")); // arrivata il 2/11: prima dell'attivazione
        account.AutoReply!.Save(new AutoReplySettings { Enabled = true, Text = "Fuori sede" });
        var runner = new AutoReplyRunner(account, account.AutoReply!);

        // Nessun giro tra l'attivazione e l'arrivo: il primo giro parte proprio per questa mail.
        var now = DateTimeOffset.UtcNow.AddMinutes(1).ToString("ddd, dd MMM yyyy HH:mm:ss +0000", System.Globalization.CultureInfo.InvariantCulture);
        await AddAsync(store, Raw("Bruno <bruno@amici.it>", subject: "Appena arrivata", received: now));
        var result = await runner.RunNewAsync();

        Assert.Equal("Risposta automatica: Appena arrivata", Assert.Single(sender.Sent).Subject);
        Assert.Equal((1, 1), (result.Checked, result.Sent));
        Assert.Equal(0, (await runner.RunNewAsync()).Checked);
    }
}
