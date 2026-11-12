using System.Text;
using MimeKit;
using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Junk;
using PostinoVip.Core.Local;
using PostinoVip.Core.Models;
using PostinoVip.Core.Pop3;

namespace PostinoVip.Core.Tests;

/// <summary>Posta indesiderata (J1): classificazione come Outlook, elenchi, cartella, filtro e comandi.</summary>
public sealed class JunkTests : IDisposable
{
    private const string Me = "io@example.com";
    private const string Junk = "Posta indesiderata";
    private readonly string _dir = Directory.CreateTempSubdirectory("postinovip-junk-").FullName;

    public void Dispose()
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        Directory.Delete(_dir, recursive: true);
    }

    private static MimeMessage Mail(string from = "Anna <anna@fornitore.it>", string to = Me, string? extra = null) =>
        MimeMessage.Load(new MemoryStream(Encoding.UTF8.GetBytes(
            $"{extra}From: {from}\r\nTo: {to}\r\nSubject: Prova\r\nDate: Mon, 02 Nov 2026 10:00:00 +0100\r\n\r\ntesto\r\n")));

    private static JunkVerdict Classify(MimeMessage m, JunkSettings s, Func<string, bool>? contact = null) =>
        JunkClassifier.Classify(m, s, Me, contact);

    // --- Classificazione ------------------------------------------------------------------------------

    [Fact]
    public void BloccatiPerIndirizzoOPerDominioSenzaSottodomini()
    {
        var s = new JunkSettings { BlockedSenders = ["@spam.example", "tizio@altro.it"] };
        Assert.Equal(new(true, JunkReason.BlockedSender), Classify(Mail("X <Promo@SPAM.example>"), s));
        Assert.Equal(new(true, JunkReason.BlockedSender), Classify(Mail("tizio@altro.it"), s));
        Assert.False(Classify(Mail("caio@altro.it"), s).IsJunk);
        Assert.False(Classify(Mail("a@news.spam.example"), s).IsJunk); // sottodominio: non corrisponde
    }

    [Fact]
    public void GliAttendibiliPrevalgonoSuiBloccatiESulFiltro()
    {
        var spam = "X-Spam-Flag: YES\r\n";
        var s = new JunkSettings { Level = JunkLevel.SafeListsOnly, BlockedSenders = ["@fornitore.it"], SafeSenders = ["anna@fornitore.it"] };
        Assert.Equal(new(false, JunkReason.SafeSender), Classify(Mail(extra: spam), s));
        Assert.Equal(new(true, JunkReason.BlockedSender), Classify(Mail("bruno@fornitore.it"), s));
        Assert.Equal(new(false, JunkReason.Self), Classify(Mail(Me), s));
        Assert.Equal(new(true, JunkReason.NotInSafeLists), Classify(Mail("ugo@sconosciuto.it"), s));

        // Contatti: solo con «Considera attendibili anche i miei contatti».
        Func<string, bool> contacts = a => a == "ugo@sconosciuto.it";
        Assert.Equal(new(false, JunkReason.Contact), Classify(Mail("Ugo <UGO@sconosciuto.it>"), s, contacts));
        Assert.True(Classify(Mail("ugo@sconosciuto.it"), s with { TrustContacts = false }, contacts).IsJunk);
    }

    [Fact]
    public void DestinatariAttendibiliAncheConListPost()
    {
        var s = new JunkSettings { Level = JunkLevel.SafeListsOnly, SafeRecipients = ["lista@gruppo.org"] };
        Assert.Equal(new(false, JunkReason.SafeRecipient), Classify(Mail("x@y.it", "Lista <lista@gruppo.org>"), s));
        var viaList = Mail("x@y.it", extra: "List-Post: <mailto:Lista@gruppo.org>\r\n");
        Assert.Equal("lista@gruppo.org", JunkClassifier.ListAddress(viaList));
        Assert.Equal(new(false, JunkReason.SafeRecipient), Classify(viaList, s));
    }

    [Fact]
    public void LivelliSulGiudizioDelServer()
    {
        var flagged = Mail(extra: "X-Spam-Flag: YES\r\nX-Spam-Status: Yes, score=7.1 required=5.0 tests=A,B\r\n");
        var close = Mail(extra: "X-Spam-Flag: NO\r\nX-Spam-Status: No, score=3.2 required=5.0 tests=A\r\n");
        var clean = Mail(extra: "X-Spam-Status: No, score=0.4 required=5.0\r\n");
        var none = new JunkSettings();
        var low = new JunkSettings { Level = JunkLevel.Low };
        var high = new JunkSettings { Level = JunkLevel.High };

        Assert.False(Classify(flagged, none).IsJunk);
        Assert.Equal(new(true, JunkReason.ServerSpam), Classify(flagged, low));
        Assert.False(Classify(close, low).IsJunk);
        Assert.Equal(new(true, JunkReason.ServerScore), Classify(close, high));
        Assert.False(Classify(clean, high).IsJunk);
        Assert.Equal(new(true, JunkReason.ServerSpam), Classify(Mail(extra: "X-Spam: Yes\r\n"), low)); // rspamd
    }

    [Fact]
    public void SiLeggeSoloLaPrimaIntestazioneDelServer()
    {
        // In cima quella del server della casella; sotto una scritta dal mittente.
        var m = Mail(extra: "X-Spam-Flag: YES\r\nX-Spam-Status: Yes, score=9 required=5\r\nX-Spam-Flag: NO\r\nX-Spam-Status: No, score=-50 required=5\r\n");
        Assert.Equal(new ServerSpamMark(true, 9, 5), JunkClassifier.ServerMark(m));
        Assert.Equal(new ServerSpamMark(false, null, null), JunkClassifier.ServerMark(Mail()));
    }

    // --- Elenchi e cartella -----------------------------------------------------------------------------

    [Fact]
    public void VociRipuliteEControllate()
    {
        Assert.Equal("@esempio.it", JunkStore.CleanEntry(" Esempio.IT ", "x"));
        Assert.Equal("@esempio.it", JunkStore.CleanEntry("@esempio.it", "x"));
        Assert.Equal("anna@esempio.it", JunkStore.CleanEntry("Anna@Esempio.it", "x"));
        foreach (var bad in new[] { "", "esempio", "@-a.it", "a b@c.it", "Anna <anna@esempio.it>", "a@b" })
            Assert.Throws<FieldValidationException>(() => JunkStore.CleanEntry(bad, "x"));
        var tooMany = Enumerable.Range(0, JunkStore.MaxEntries + 1).Select(i => $"a{i}@b.it").ToList();
        Assert.Equal("blockedSenders", Assert.Throws<FieldValidationException>(() =>
            JunkStore.Validate(new JunkSettings { BlockedSenders = tooMany })).Field);
    }

    [Fact]
    public void AggiungereSpostaTraBloccatiEAttendibiliESalvaPrivato()
    {
        var store = new JunkStore(_dir);
        Assert.Equal(new JunkSettings().Level, store.Load().Level);
        store.Save(new JunkSettings { Level = JunkLevel.High, SafeSenders = ["Anna@Fornitore.it", "anna@fornitore.it"] });
        Assert.Equal(["anna@fornitore.it"], store.Load().SafeSenders);

        store.Add(JunkList.BlockedSenders, "anna@fornitore.it");
        var s = new JunkStore(_dir).Load();
        Assert.Equal((JunkLevel.High, 0, 1), (s.Level, s.SafeSenders.Count, s.BlockedSenders.Count));
        store.Add(JunkList.SafeSenders, "ANNA@fornitore.it");
        s = store.Load();
        Assert.Equal((1, 0), (s.SafeSenders.Count, s.BlockedSenders.Count));
        if (!OperatingSystem.IsWindows())
            Assert.Equal(CachePermissions.PrivateFile, File.GetUnixFileMode(store.SettingsPath));
    }

    [Fact]
    public void CartellaSceltaPoiQuellaDelServerPoiDalNome()
    {
        MailFolderInfo F(string name, string? role = null) => new(name, name, 0, role);
        var withServer = new[] { F("INBOX", "inbox"), F("Spam", "junk"), F("Indesiderata"), F("Archivio") };
        Assert.Equal("Spam", JunkFolders.Resolve(withServer, null));
        Assert.Equal("Archivio", JunkFolders.Resolve(withServer, "Archivio"));
        Assert.Equal("Spam", JunkFolders.Resolve(withServer, "Non esiste più"));
        Assert.Equal("Indesiderata", JunkFolders.Resolve([F("INBOX", "inbox"), F("Indesiderata")], null));
        Assert.Null(JunkFolders.Resolve([F("INBOX", "inbox"), F("Archivio")], null));

        var roles = JunkFolders.WithRole(withServer, "Archivio");
        Assert.Equal(["inbox", null, null, "junk"], roles.Select(f => f.SpecialUse));
    }

    [Fact]
    public void ParoleChiaveNeiDueModi()
    {
        Assert.Equal(["$Junk", "Junk"], MailKeywords.ToKeywords(MailFlags.Junk));
        Assert.Equal(["$NotJunk", "NonJunk"], MailKeywords.ToKeywords(MailFlags.NotJunk));
        Assert.Equal(MailFlags.Junk, MailKeywords.FromKeywords(["junk"]));
        Assert.Equal(MailFlags.NotJunk | MailFlags.Junk, MailKeywords.FromKeywords(["$NotJunk", "$junk"]));
    }

    // --- Filtro e comandi (account POP3 locale: niente server) ------------------------------------------

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

    private static Task<uint> AddAsync(LocalMailStore store, string from, string subject, string? extra = null, string folder = "INBOX") =>
        store.AddAsync(folder, new MemoryStream(Encoding.UTF8.GetBytes(
            $"{extra}From: {from}\r\nTo: {Me}\r\nSubject: {subject}\r\nDate: Mon, 02 Nov 2026 10:00:00 +0100\r\n\r\ntesto\r\n")));

    private static async Task<List<string>> Subjects(MailAccount account, string folder) =>
        (await account.Reader.GetHeadersAsync(folder, 0, 50)).Items.Select(m => m.Subject).Order().ToList();

    private static MailFlags FlagsOf(MailAccount account, string folder, string subject)
    {
        var cache = account.Bodies!.Cache;
        var f = cache.FindFolder(folder)!;
        var uid = account.Reader.GetHeadersAsync(folder, 0, 50).Result.Items.Single(m => m.Subject == subject).Uid;
        return cache.GetFlags(f.Id, uid)!.Value.Flags;
    }

    [Fact]
    public async Task FiltroSoloSulleMailNuoveConLivelloBassoEBloccati()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        await AddAsync(store, "x@spam.example", "Vecchia", "X-Spam-Flag: YES\r\n"); // già presente: non si tocca
        account.Junk!.Save(new JunkSettings { Level = JunkLevel.Low, BlockedSenders = ["@bloccato.it"], SafeSenders = ["amico@spam.example"] });
        var log = new List<string>();
        var filter = new JunkFilter(account, account.Junk!, log.Add);
        Assert.Equal(0, (await filter.RunNewAsync()).Checked); // prima volta: punto di partenza

        await AddAsync(store, "x@spam.example", "Spam", "X-Spam-Flag: YES\r\n");
        await AddAsync(store, "y@bloccato.it", "Bloccato");
        await AddAsync(store, "amico@spam.example", "Amico", "X-Spam-Flag: YES\r\n");
        await AddAsync(store, "z@normale.it", "Normale");
        var result = await filter.RunNewAsync();

        Assert.Equal((4, 2, 0), (result.Checked, result.Moved, result.Failed));
        Assert.Equal(["Amico", "Normale", "Vecchia"], await Subjects(account, "INBOX"));
        Assert.Equal(["Bloccato", "Spam"], await Subjects(account, Junk));
        Assert.True(FlagsOf(account, Junk, "Spam").HasFlag(MailFlags.Junk));
        Assert.False(FlagsOf(account, Junk, "Spam").HasFlag(MailFlags.Seen)); // resta da leggere
        Assert.Contains(log, l => l.Contains("BlockedSender") && l.Contains(Junk));
        Assert.DoesNotContain(log, l => l.Contains("bloccato.it") || l.Contains("Spam ")); // mai indirizzi o oggetti
        Assert.Equal(0, (await filter.RunNewAsync()).Checked);
    }

    [Fact]
    public async Task SenzaFiltroNeBloccatiIlPuntoDiPartenzaAvanza()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        var filter = new JunkFilter(account, account.Junk!);
        await filter.RunNewAsync();
        await AddAsync(store, "x@spam.example", "Arrivata prima", "X-Spam-Flag: YES\r\n");
        await filter.RunNewAsync();

        account.Junk!.Save(new JunkSettings { Level = JunkLevel.Low }); // vale da qui in avanti
        Assert.Equal(0, (await filter.RunNewAsync()).Checked);
        Assert.Equal(["Arrivata prima"], await Subjects(account, "INBOX"));
    }

    [Fact]
    public async Task BloccaMittenteSpostaEAggiungeAlleListe()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        account.Junk!.Add(JunkList.SafeSenders, "anna@fornitore.it");
        var a = await AddAsync(store, "Anna <anna@fornitore.it>", "Prima");
        var b = await AddAsync(store, "anna@fornitore.it", "Seconda");
        var mine = await AddAsync(store, Me, "Mia");
        var filter = new JunkFilter(account, account.Junk!);

        var result = await filter.BlockAsync("INBOX", [a, b, mine, 999]);

        Assert.Equal(["anna@fornitore.it"], result.Entries); // il proprio indirizzo non si blocca
        Assert.Equal((Junk, 3), (result.Folder, result.Moved.Count));
        Assert.Equal(["Mia", "Prima", "Seconda"], await Subjects(account, Junk));
        Assert.True(FlagsOf(account, Junk, "Prima").HasFlag(MailFlags.Junk));
        var s = account.Junk.Load();
        Assert.Equal(["anna@fornitore.it"], s.BlockedSenders);
        Assert.Empty(s.SafeSenders);

        var onlyMine = (await account.Reader.GetHeadersAsync(Junk, 0, 50)).Items.Single(m => m.Subject == "Mia").Uid;
        await Assert.ThrowsAsync<InvalidOperationException>(() => filter.BlockAsync(Junk, [onlyMine]));
    }

    [Fact]
    public async Task NonEPostaIndesiderataRiportaInArrivoSoloDallaCartella()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        var inbox = await AddAsync(store, "x@normale.it", "In arrivo");
        var junk = await AddAsync(store, "Bruno <bruno@normale.it>", "Finita lì", folder: Junk);
        var filter = new JunkFilter(account, account.Junk!);
        await account.Reader.GetHeadersAsync(Junk, 0, 1);

        await Assert.ThrowsAsync<InvalidOperationException>(() => filter.NotJunkAsync("INBOX", [inbox], true));
        var result = await filter.NotJunkAsync(Junk, [junk], trustSenders: true);

        Assert.Equal(["bruno@normale.it"], result.Entries);
        Assert.Equal(("INBOX", 1), (result.Folder, result.Moved.Count));
        Assert.Equal(["Finita lì", "In arrivo"], await Subjects(account, "INBOX"));
        var flags = FlagsOf(account, "INBOX", "Finita lì");
        Assert.True(flags.HasFlag(MailFlags.NotJunk) && !flags.HasFlag(MailFlags.Junk));
        Assert.Equal(["bruno@normale.it"], account.Junk!.Load().SafeSenders);
    }

    [Fact]
    public async Task NonBloccareMaiMittenteDominioOGruppo()
    {
        var (account, store, registry) = Pop3Account();
        await using var _ = registry;
        var plain = await AddAsync(store, "Anna <anna@fornitore.it>", "Diretta");
        var list = await AddAsync(store, "carlo@altro.it", "Dalla lista", "List-Post: <mailto:soci@club.org>\r\n");
        var filter = new JunkFilter(account, account.Junk!);

        Assert.Equal(["anna@fornitore.it"], (await filter.NeverBlockAsync("INBOX", [plain], NeverBlockKind.Sender)).Entries);
        Assert.Equal(["@fornitore.it"], (await filter.NeverBlockAsync("INBOX", [plain], NeverBlockKind.Domain)).Entries);
        Assert.Equal(["soci@club.org"], (await filter.NeverBlockAsync("INBOX", [list], NeverBlockKind.Group)).Entries);
        // Mail inviata solo a me: nessun gruppo.
        await Assert.ThrowsAsync<InvalidOperationException>(() => filter.NeverBlockAsync("INBOX", [plain], NeverBlockKind.Group));

        var s = account.Junk!.Load();
        Assert.Equal(["anna@fornitore.it", "@fornitore.it"], s.SafeSenders);
        Assert.Equal(["soci@club.org"], s.SafeRecipients);
        Assert.Equal(["Dalla lista", "Diretta"], await Subjects(account, "INBOX")); // la casella non cambia
    }
}
