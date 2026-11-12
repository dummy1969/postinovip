using System.Text;
using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Local;
using PostinoVip.Core.Pop3;
using PostinoVip.Core.Rules;

namespace PostinoVip.Core.Tests;

/// <summary>Regole (R1): valutazione come Outlook, controlli dei dati, esecuzione sulle mail nuove.</summary>
public sealed class RuleTests : IDisposable
{
    private const string Me = "io@example.com";
    private readonly string _dir = Directory.CreateTempSubdirectory("postinovip-rules-").FullName;

    public void Dispose()
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        Directory.Delete(_dir, recursive: true);
    }

    private static RuleMessage Msg(string from = "Anna <anna@fornitore.it>", string[]? to = null, string[]? cc = null,
        string subject = "Fattura ottobre", string body = "In allegato la fattura", bool attachments = false, long? size = 10_000) =>
        new(from, to ?? [Me], cc ?? [], subject, body, attachments, size);

    private static MailRule Rule(string name, RuleConditions? when = null, RuleActions? then = null, RuleConditions? unless = null,
        bool enabled = true) =>
        new() { Id = "", Name = name, Enabled = enabled, Conditions = when ?? new(), Exceptions = unless, Actions = then ?? new() { MarkRead = true } };

    // --- Valutazione --------------------------------------------------------------------------------

    [Fact]
    public void CondizioniInAndParoleInOrSenzaMaiuscole()
    {
        var rule = Rule("r", new() { From = ["@FORNITORE.it", "altro.it"], SubjectContains = ["fattura"] });

        Assert.True(RuleMatcher.Matches(rule, Msg(), Me));
        Assert.False(RuleMatcher.Matches(rule, Msg(subject: "Saluti"), Me)); // una condizione falsa basta
        Assert.False(RuleMatcher.Matches(rule, Msg(from: "Bruno <b@cliente.it>"), Me));
        Assert.True(RuleMatcher.Matches(Rule("vuota"), Msg(), Me)); // senza condizioni: tutte le mail
        Assert.False(RuleMatcher.Matches(Rule("spenta", enabled: false), Msg(), Me));
    }

    [Theory]
    [InlineData(new[] { Me }, new string[0], true, true, false)]
    [InlineData(new[] { "Io <IO@example.com>" }, new string[0], true, true, false)]
    [InlineData(new[] { Me, "altro@example.com" }, new string[0], false, true, false)]
    [InlineData(new[] { "lista@example.com" }, new[] { Me }, false, false, true)]
    public void DestinatariIoSoloIoInAInCc(string[] to, string[] cc, bool onlyMe, bool inTo, bool inCc)
    {
        var m = Msg(to: to, cc: cc);
        Assert.Equal(onlyMe, RuleMatcher.Matches(Rule("a", new() { SentOnlyToMe = true }), m, Me));
        Assert.Equal(inTo, RuleMatcher.Matches(Rule("b", new() { MeInTo = true }), m, Me));
        Assert.Equal(inCc, RuleMatcher.Matches(Rule("c", new() { MeInCc = true }), m, Me));
        Assert.True(RuleMatcher.Matches(Rule("d", new() { ToOrCc = ["example.com"] }), m, Me));
    }

    [Fact]
    public void TestoAllegatiDimensioneEdEccezioni()
    {
        Assert.True(RuleMatcher.Matches(Rule("t", new() { SubjectOrBodyContains = ["allegato"] }), Msg(), Me));
        Assert.True(RuleMatcher.Matches(Rule("t", new() { SubjectOrBodyContains = ["OTTOBRE"] }), Msg(), Me));
        Assert.False(RuleMatcher.Matches(Rule("a", new() { HasAttachments = true }), Msg(), Me));
        Assert.True(RuleMatcher.Matches(Rule("a", new() { HasAttachments = true }), Msg(attachments: true), Me));
        Assert.True(RuleMatcher.Matches(Rule("s", new() { SizeGreaterThanKb = 9 }), Msg(size: 10_000), Me));
        Assert.False(RuleMatcher.Matches(Rule("s", new() { SizeGreaterThanKb = 10 }), Msg(size: 10_000), Me));
        Assert.False(RuleMatcher.Matches(Rule("s", new() { SizeGreaterThanKb = 1 }), Msg(size: null), Me));

        // "tranne se": basta un'eccezione vera.
        var except = Rule("e", new() { From = ["fornitore"] }, unless: new() { SubjectContains = ["urgente", "ottobre"] });
        Assert.False(RuleMatcher.Matches(except, Msg(), Me));
        Assert.True(RuleMatcher.Matches(except, Msg(subject: "Fattura novembre"), Me));
    }

    [Fact]
    public void PianoDelleAzioniComeOutlook()
    {
        var rules = new[]
        {
            Rule("letta", then: new() { MarkRead = true, Category = 2 }),
            Rule("fatture", then: new() { MoveTo = "Fatture", Flag = true }),
            Rule("archivio", then: new() { MoveTo = "Archivio", Category = 2 }),
            Rule("stop", then: new() { CopyTo = "Copie", StopProcessing = true }),
            Rule("mai", then: new() { Delete = true }),
        };

        var plan = RuleMatcher.Plan(rules, Msg(), Me);

        Assert.Equal(["letta", "fatture", "archivio", "stop"], plan.Rules);
        Assert.True(plan.MarkRead && plan.Flag && !plan.Delete);
        Assert.Equal([2], plan.Categories);
        Assert.Equal("Fatture", plan.MoveTo); // la prima sposta
        Assert.Equal(["Archivio", "Copie"], plan.CopyTo); // le altre copiano

        var deleting = RuleMatcher.Plan([Rule("sposta", then: new() { MoveTo = "Fatture" }), Rule("via", then: new() { Delete = true })], Msg(), Me);
        Assert.True(deleting.Delete);
        Assert.Null(deleting.MoveTo);
        Assert.Equal(["Fatture"], deleting.CopyTo);
        Assert.True(RuleMatcher.Plan([Rule("no", new() { SubjectContains = ["xyz"] })], Msg(), Me).IsEmpty);
    }

    // --- Controlli dei dati ------------------------------------------------------------------------

    [Fact]
    public void ControlliEPuliziaDelleRegole()
    {
        Assert.Throws<FieldValidationException>(() => RuleStore.Validate([Rule("  ")]));
        Assert.Throws<FieldValidationException>(() => RuleStore.Validate([Rule("x", then: new())]));
        Assert.Throws<FieldValidationException>(() => RuleStore.Validate([Rule("x", then: new() { Delete = true, MoveTo = "A" })]));
        Assert.Throws<FieldValidationException>(() => RuleStore.Validate([Rule("x", then: new() { Category = 7 })]));
        Assert.Throws<FieldValidationException>(() => RuleStore.Validate([Rule("x", new() { SizeGreaterThanKb = 0 })]));
        Assert.Equal("rules", Assert.Throws<FieldValidationException>(() => RuleStore.Validate([Rule("")])).Field);

        var clean = RuleStore.Validate([
            Rule(" Fatture ", new() { From = [" a ", "", "A", "b"] }, unless: new() { SubjectContains = [" "] }) with { Id = "ab12" },
            Rule("Due") with { Id = "ab12" },
        ]);
        Assert.Equal("Fatture", clean[0].Name);
        Assert.Equal(["a", "b"], clean[0].Conditions.From!);
        Assert.Null(clean[0].Exceptions); // eccezioni vuote tolte
        Assert.Equal("ab12", clean[0].Id);
        Assert.NotEqual("ab12", clean[1].Id); // id ripetuto: nuovo
        Assert.Matches("^[0-9a-f]{8}$", clean[1].Id);
    }

    [Fact]
    public void SalvateERilette()
    {
        var store = new RuleStore(_dir);
        Assert.Empty(store.Load());

        store.Save([Rule("Fatture", new() { From = ["fornitore.it"] }, new() { MoveTo = "Fatture", StopProcessing = true })]);

        var back = Assert.Single(new RuleStore(_dir).Load());
        Assert.Equal(("Fatture", "Fatture", true), (back.Name, back.Actions.MoveTo, back.Actions.StopProcessing));
        Assert.Equal(["fornitore.it"], back.Conditions.From!);
        if (!OperatingSystem.IsWindows())
            Assert.Equal(CachePermissions.PrivateFile, File.GetUnixFileMode(store.RulesPath));
    }

    // --- Esecuzione sulle mail nuove (account POP3 locale: niente server) ---------------------------

    private (MailAccount Account, LocalMailStore Store, MailAccountRegistry Registry) Pop3Account()
    {
        var settings = new MailAccountSettings
        {
            Id = "pop", Type = MailAccountType.Pop3,
            Pop3 = new Pop3Settings { Host = "pop.example.invalid", Username = Me, Password = "x" },
            Smtp = new Smtp.SmtpSettings { Host = "smtp.example.invalid", Username = Me, Password = "x" },
        };
        var registry = MailAccountRegistry.CreateImap([settings], _dir);
        var store = new LocalMailStore(Path.Combine(MailAccountRegistry.CacheDirectory(_dir, "pop"), "mail"));
        store.EnsureDefaults();
        return (registry.Get("pop"), store, registry);
    }

    private static Task<uint> AddAsync(LocalMailStore store, string from, string subject, string body = "testo") =>
        store.AddAsync("INBOX", new MemoryStream(Encoding.UTF8.GetBytes(
            $"From: {from}\r\nTo: {Me}\r\nSubject: {subject}\r\nDate: Mon, 02 Nov 2026 10:00:00 +0100\r\n\r\n{body}\r\n")));

    [Fact]
    public async Task SoloLeMailNuoveEUnaVoltaSola()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        store.CreateFolder("Fatture");
        await AddAsync(store, "Anna <anna@fornitore.it>", "Fattura vecchia"); // già presente: non si tocca
        account.Rules!.Save([
            Rule("Fatture", new() { From = ["fornitore.it"] }, new() { MoveTo = "Fatture", MarkRead = true, Category = 3 }),
            Rule("Promo", new() { SubjectOrBodyContains = ["offerta"] }, new() { Delete = true }),
        ]);
        var runner = new RuleRunner(account, account.Rules!);

        var first = await runner.RunNewAsync(); // prima volta: punto di partenza
        Assert.Equal(0, first.Checked);

        await AddAsync(store, "Anna <anna@fornitore.it>", "Fattura novembre");
        await AddAsync(store, "Shop <news@shop.example>", "Novità", "Una grande OFFERTA per te");
        await AddAsync(store, "Bruno <bruno@amici.it>", "Ciao");
        var second = await runner.RunNewAsync();

        Assert.Equal((3, 2, 0), (second.Checked, second.Applied, second.Failed));
        var inbox = await account.Reader.GetHeadersAsync("INBOX", 0, 50);
        Assert.Equal(["Ciao", "Fattura vecchia"], inbox.Items.Select(m => m.Subject).Order());
        var fatture = await account.Reader.GetHeadersAsync("Fatture", 0, 50);
        var moved = Assert.Single(fatture.Items);
        Assert.Equal("Fattura novembre", moved.Subject);
        Assert.True(moved.Seen);
        Assert.Equal([3], moved.Categories!);
        Assert.Equal("Novità", Assert.Single((await account.Reader.GetHeadersAsync("Posta eliminata", 0, 50)).Items).Subject);

        Assert.Equal(0, (await runner.RunNewAsync()).Checked); // niente di nuovo: niente da rifare
    }

    [Fact]
    public async Task AzioneNonRiuscitaNelLogEMailNonRipetuta()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        account.Rules!.Save([Rule("Manca", then: new() { MoveTo = "Cartella inesistente", Flag = true })]);
        var log = new List<string>();
        var runner = new RuleRunner(account, account.Rules!, log.Add);
        await runner.RunNewAsync();

        await AddAsync(store, "Anna <anna@fornitore.it>", "Fattura");
        var result = await runner.RunNewAsync();

        Assert.Equal((1, 1, 1), (result.Checked, result.Applied, result.Failed));
        var mail = Assert.Single((await account.Reader.GetHeadersAsync("INBOX", 0, 50)).Items);
        Assert.True(mail.Flagged); // le altre azioni sono state fatte
        Assert.Contains(log, l => l.Contains("sposta in Cartella inesistente") && l.Contains("non riuscito"));
        Assert.DoesNotContain(log, l => l.Contains("Fattura") || l.Contains("anna@")); // mai contenuti nel log
        Assert.Equal(0, (await runner.RunNewAsync()).Checked);
    }

    [Fact]
    public async Task SenzaRegoleAttiveIlPuntoDiPartenzaAvanza()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        var runner = new RuleRunner(account, account.Rules!);
        await runner.RunNewAsync();
        await AddAsync(store, "Anna <anna@fornitore.it>", "Arrivata senza regole");
        await runner.RunNewAsync();

        // La regola creata dopo non si applica alle mail arrivate prima (come in Outlook senza "Esegui ora").
        account.Rules!.Save([Rule("Tutte", then: new() { Flag = true })]);
        Assert.Equal(0, (await runner.RunNewAsync()).Checked);
        Assert.False(Assert.Single((await account.Reader.GetHeadersAsync("INBOX", 0, 50)).Items).Flagged);
    }

    // --- Esegui regole ora (R3) ---------------------------------------------------------------------

    [Fact]
    public async Task EseguiOraSulleMailGiaPresentiConFiltroEAvanzamento()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        store.CreateFolder("Fatture");
        var letta = await AddAsync(store, "Anna <anna@fornitore.it>", "Fattura letta");
        await AddAsync(store, "Anna <anna@fornitore.it>", "Fattura da leggere");
        await AddAsync(store, "Bruno <bruno@amici.it>", "Ciao");
        await account.Reader.GetHeadersAsync("INBOX", 0, 50);
        await account.Writer.SetSeenAsync("INBOX", letta, true);
        // Disattivata: "Esegui regole ora" la applica lo stesso, se scelta (come Outlook).
        var rule = Rule("Fatture", new() { From = ["fornitore.it"] }, new() { MoveTo = "Fatture", Flag = true }, enabled: false);
        var steps = new List<(int, int)>();
        var runner = new RuleRunner(account, account.Rules!);

        var result = await runner.RunOnFoldersAsync([rule], ["INBOX"], RuleRunFilter.Unread, (d, t) => steps.Add((d, t)));

        Assert.Equal((2, 1, 0), (result.Checked, result.Applied, result.Failed)); // solo le da leggere
        Assert.Equal([(0, 2), (1, 2), (2, 2)], steps);
        Assert.Equal("Fattura da leggere", Assert.Single((await account.Reader.GetHeadersAsync("Fatture", 0, 50)).Items).Subject);

        var all = await runner.RunOnFoldersAsync([rule], ["INBOX"], RuleRunFilter.All);
        Assert.Equal((2, 1), (all.Checked, all.Applied)); // ora anche quella letta
        Assert.Equal(2, (await account.Reader.GetHeadersAsync("Fatture", 0, 50)).Total);
        Assert.Equal("Ciao", Assert.Single((await account.Reader.GetHeadersAsync("INBOX", 0, 50)).Items).Subject);
    }

    [Fact]
    public async Task EseguiOraUnaMailSpostataInUnaCartellaSuccessivaNonSiRivaluta()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        store.CreateFolder("INBOX/Sotto");
        await AddAsync(store, "Anna <anna@fornitore.it>", "Uno");
        await AddAsync(store, "Anna <anna@fornitore.it>", "Due");
        // Ogni volta che la vede, la sposta e la copia: se rivalutata nella sottocartella, le copie raddoppierebbero.
        var rule = Rule("Giro", then: new() { MoveTo = "INBOX/Sotto", CopyTo = "Posta inviata" });
        var runner = new RuleRunner(account, account.Rules!);

        var result = await runner.RunOnFoldersAsync([rule], ["INBOX", "INBOX/Sotto"], RuleRunFilter.All);

        Assert.Equal(2, result.Checked);
        Assert.Equal(2, (await account.Reader.GetHeadersAsync("INBOX/Sotto", 0, 50)).Total);
        Assert.Equal(2, (await account.Reader.GetHeadersAsync("Posta inviata", 0, 50)).Total);
    }

    [Fact]
    public async Task EseguiOraInterrottoLasciaFattoCioCheEFatto()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        for (var i = 0; i < 5; i++)
            await AddAsync(store, "Anna <anna@fornitore.it>", $"Mail {i}");
        using var stop = new CancellationTokenSource();
        var runner = new RuleRunner(account, account.Rules!);

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => runner.RunOnFoldersAsync(
            [Rule("Via", then: new() { Delete = true })], ["INBOX"], RuleRunFilter.All, (done, _) => { if (done == 2) stop.Cancel(); }, stop.Token));

        Assert.Equal(2, (await account.Reader.GetHeadersAsync("Posta eliminata", 0, 50)).Total);
        Assert.Equal(3, (await account.Reader.GetHeadersAsync("INBOX", 0, 50)).Total);
        // Dopo l'interruzione il runner resta utilizzabile (il lock è stato rilasciato).
        Assert.Equal(3, (await runner.RunOnFoldersAsync([Rule("Niente", new() { SubjectContains = ["xyz"] })], ["INBOX"], RuleRunFilter.All)).Checked);
    }
}
