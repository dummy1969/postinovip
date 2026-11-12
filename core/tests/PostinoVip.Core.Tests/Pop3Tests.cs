using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Local;
using PostinoVip.Core.Pop3;
using PostinoVip.Core.Security;

namespace PostinoVip.Core.Tests;

/// <summary>Account POP3 (4.2a): casella locale, indice, scaricamento e regole di rimozione dal server.</summary>
public sealed class Pop3Tests : IDisposable
{
    private readonly string _dir = Directory.CreateTempSubdirectory("postinovip-pop3-").FullName;

    public void Dispose() => Directory.Delete(_dir, recursive: true);

    private static string Mail(string subject, string body, string? date = null, string id = "") =>
        $"Received: from mx.example.com by posta.example.com; {date ?? "Mon, 02 Nov 2026 10:00:00 +0100"}\r\n" +
        "From: Mario Rossi <mario@example.com>\r\nTo: me@example.com\r\n" +
        $"Subject: {subject}\r\nDate: Sun, 01 Nov 2026 09:00:00 +0100\r\nMessage-ID: <{subject.Replace(' ', '-')}{id}@example.com>\r\n" +
        $"Content-Type: text/plain; charset=utf-8\r\n\r\n{body}\r\n";

    private LocalMailStore Store() => new(Path.Combine(_dir, "mail"));

    private (LocalMailStore Store, AccountCache Cache, LocalMailReader Reader, LocalMailWriter Writer) Local()
    {
        var store = Store();
        var cache = new AccountCache(_dir);
        var reader = new LocalMailReader("p", store, cache);
        return (store, cache, reader, new LocalMailWriter(store, cache, reader));
    }

    private static async Task<uint> AddAsync(LocalMailStore store, string folder, string message) =>
        await store.AddAsync(folder, new MemoryStream(System.Text.Encoding.UTF8.GetBytes(message)));

    // --- Casella locale ----------------------------------------------------------------------------

    [Theory]
    [InlineData("Clienti")]
    [InlineData("Posta in arrivo")]
    [InlineData("Fatture 2026: àèìòù")]
    [InlineData("CON")]
    [InlineData("nul.txt")]
    [InlineData("finisce con punto.")]
    [InlineData("finisce con spazio ")]
    [InlineData(".nascosta")]
    [InlineData("a%b*c?d<e>f|g\"h\\i:j")]
    [InlineData("emoji 📨")]
    public void NomiDelleCartelleSuDiscoReversibiliEValidiOvunque(string name)
    {
        var encoded = LocalMailStore.EncodeSegment(name);

        Assert.Equal(name, LocalMailStore.DecodeSegment(encoded));
        Assert.DoesNotContain(encoded, c => "/\\:*?\"<>|".Contains(c));
        Assert.False(encoded.EndsWith(' ') || encoded.EndsWith('.') || encoded.StartsWith('.'));
        Assert.NotEqual("CON", encoded.Split('.')[0].ToUpperInvariant());
    }

    [Fact]
    public async Task CartellePredefiniteUidCrescentiESpostamento()
    {
        var store = Store();
        store.EnsureDefaults();

        var folders = await store.GetFoldersAsync();
        Assert.Equal(["Bozze", "INBOX", "Posta eliminata", "Posta indesiderata", "Posta inviata"], folders.Select(f => f.FullName).Order());
        Assert.Equal("inbox", folders.Single(f => f.FullName == "INBOX").SpecialUse);
        Assert.Equal("trash", folders.Single(f => f.FullName == "Posta eliminata").SpecialUse);

        var a = await AddAsync(store, "INBOX", Mail("Uno", "a"));
        var b = await AddAsync(store, "INBOX", Mail("Due", "b"));
        Assert.Equal((1u, 2u), (a, b));
        var moved = await store.MoveAsync("INBOX", a, "Posta eliminata");
        Assert.Equal([2u], store.GetUids("INBOX"));
        Assert.Equal([moved], store.GetUids("Posta eliminata"));
        Assert.Equal(3u, await AddAsync(store, "INBOX", Mail("Tre", "c"))); // UID mai riusati

        store.CreateFolder("Clienti");
        store.CreateFolder("Clienti/Rossi: 2026");
        Assert.Contains((await store.GetFoldersAsync()), f => f.FullName == "Clienti/Rossi: 2026" && f.Name == "Rossi: 2026");
        Assert.Throws<MailNotFoundException>(() => store.CreateFolder("Manca/Figlia"));
    }

    [Fact]
    public async Task FolderJsonRovinatoNuovoUidValidityEUidOltreQuelliPresenti()
    {
        var store = Store();
        store.EnsureDefaults();
        await AddAsync(store, "INBOX", Mail("Uno", "a"));
        await AddAsync(store, "INBOX", Mail("Due", "b"));
        var before = store.GetFolder("INBOX").UidValidity;

        File.WriteAllText(Path.Combine(store.DirectoryFor("INBOX"), LocalMailStore.MetaFile), "{rovinato");
        store.EnsureDefaults();

        var after = store.GetFolder("INBOX");
        Assert.NotEqual(before, after.UidValidity);
        Assert.Equal("inbox", after.Role); // ruolo rimesso per le cartelle predefinite
        Assert.Equal(3u, await AddAsync(store, "INBOX", Mail("Tre", "c")));
    }

    [Fact]
    public async Task FilePrivatiSuLinux()
    {
        if (OperatingSystem.IsWindows())
            return;
        var store = Store();
        store.EnsureDefaults();
        var uid = await AddAsync(store, "INBOX", Mail("Uno", "a"));

        Assert.Equal(CachePermissions.PrivateFile, File.GetUnixFileMode(store.PathFor("INBOX", uid)));
        Assert.Equal(CachePermissions.PrivateDirectory, File.GetUnixFileMode(store.DirectoryFor("INBOX")));
        Assert.Equal(CachePermissions.PrivateDirectory, File.GetUnixFileMode(store.Root));
    }

    // --- Lettura e indice --------------------------------------------------------------------------

    [Fact]
    public async Task ListaLetturaRicercaELettoDallIndice()
    {
        var (store, _, reader, writer) = Local();
        store.EnsureDefaults();
        await AddAsync(store, "INBOX", Mail("Preventivo caldaia", "Il preventivo per la caldaia a condensazione"));
        await AddAsync(store, "INBOX", Mail("Saluti", "Ciao", "Tue, 03 Nov 2026 08:00:00 +0100"));

        var page = await reader.GetHeadersAsync("INBOX", 0, 50);
        Assert.Equal(2, page.Total);
        Assert.Equal("Saluti", page.Items[0].Subject); // ordinate per arrivo (Received), la più recente in cima
        Assert.All(page.Items, m => Assert.False(m.Seen));
        Assert.Equal("Il preventivo per la caldaia a condensazione", page.Items[1].Preview);

        var folders = await reader.GetFoldersAsync();
        Assert.Equal((2, 2), (folders.Single(f => f.FullName == "INBOX").Count, folders.Single(f => f.FullName == "INBOX").Unread));

        var hits = await reader.SearchAsync("condensazione", null, 0, 10);
        Assert.Equal("Preventivo caldaia", Assert.Single(hits.Items).Subject);

        await writer.SetSeenAsync("INBOX", page.Items[1].Uid, true);
        var detail = await reader.GetMessageAsync("INBOX", page.Items[1].Uid);
        Assert.Equal("Preventivo caldaia", detail.Subject);
        Assert.True((await reader.GetHeadersAsync("INBOX", 0, 50, unreadOnly: true)).Items.All(m => m.Subject == "Saluti"));
        Assert.Empty((await reader.SearchServerAsync("caldaia", null, 0, 10)).Items);
    }

    [Fact]
    public async Task IndicePersoSiRifaDaiFile()
    {
        var (store, _, reader, writer) = Local();
        store.EnsureDefaults();
        var uid = await AddAsync(store, "INBOX", Mail("Importante", "da non perdere"));
        await reader.GetHeadersAsync("INBOX", 0, 50);
        await writer.UpdateFlagsAsync("INBOX", uid, MailFlags.Flagged, MailFlags.None);

        // Database perso (rovinato e messo da parte, o cancellato): le mail sono nei file.
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); // altrimenti il pool tiene aperto il file cancellato
        foreach (var f in Directory.GetFiles(_dir, "index.db*"))
            File.Delete(f);
        var fresh = new LocalMailReader("p", store, new AccountCache(_dir));

        var page = await fresh.GetHeadersAsync("INBOX", 0, 50);
        Assert.Equal("Importante", Assert.Single(page.Items).Subject);
        Assert.False(page.Items[0].Flagged); // si perdono al più i flag (scelta 4a)
        Assert.Single((await fresh.SearchAsync("perdere", null, 0, 10)).Items);
    }

    [Fact]
    public async Task CopiaInPostaInviataGiaLetta()
    {
        var (store, _, reader, writer) = Local();
        var message = MimeKit.MimeMessage.Load(new MemoryStream(System.Text.Encoding.UTF8.GetBytes(Mail("Inviata", "testo"))));

        Assert.Equal("Posta inviata", await writer.AppendToSentAsync(message));

        var sent = await reader.GetHeadersAsync("Posta inviata", 0, 10);
        Assert.True(Assert.Single(sent.Items).Seen);
    }

    // --- Operazioni sul computer (4.2b) -------------------------------------------------------------

    private async Task<(LocalMailStore Store, AccountCache Cache, LocalMailReader Reader, LocalMailWriter Writer, uint A, uint B)>
        TwoMailsAsync(Action<IReadOnlyList<string>>? removed = null)
    {
        var store = Store();
        var cache = new AccountCache(_dir);
        var reader = new LocalMailReader("p", store, cache);
        var writer = new LocalMailWriter(store, cache, reader, removed);
        store.EnsureDefaults();
        var a = await store.AddAsync("INBOX", new MemoryStream(System.Text.Encoding.ASCII.GetBytes(
            "X-UIDL: srv-1\r\n" + Mail("Prima", "uno"))), ct: default);
        var b = await AddAsync(store, "INBOX", Mail("Seconda", "due"));
        await reader.GetHeadersAsync("INBOX", 0, 50);
        return (store, cache, reader, writer, a, b);
    }

    [Fact]
    public async Task SpostaECopiaConservanoLettoContrassegnoCategorieEScadenza()
    {
        var (store, cache, reader, writer, a, b) = await TwoMailsAsync();
        store.CreateFolder("Clienti");
        await writer.SetSeenAsync("INBOX", a, true);
        await writer.UpdateFlagsAsync("INBOX", a, MailFlags.Flagged | MailKeywords.Category(2), MailFlags.None);
        cache.SetFlags(cache.FindFolder("INBOX")!.Id, a, MailFlags.Seen | MailFlags.Flagged | MailKeywords.Category(2), new DateOnly(2026, 11, 6));

        var moved = await writer.MoveAsync("INBOX", [a, 999], "Clienti");
        var copied = await writer.CopyAsync("INBOX", [b], "Clienti");

        Assert.Equal("Clienti", moved.Destination);
        Assert.Equal([a], moved.Uids);
        Assert.Equal([b], copied.Uids);
        Assert.Equal([b], store.GetUids("INBOX"));
        var clienti = await reader.GetHeadersAsync("Clienti", 0, 10);
        var prima = clienti.Items.Single(m => m.Subject == "Prima");
        Assert.True(prima.Seen && prima.Flagged);
        Assert.Equal([2], Assert.IsType<int[]>(prima.Categories));
        Assert.Equal(new DateOnly(2026, 11, 6), prima.Due);
        Assert.False(clienti.Items.Single(m => m.Subject == "Seconda").Seen);
        Assert.Equal(1, (await reader.GetHeadersAsync("INBOX", 0, 10)).Total);
        await Assert.ThrowsAsync<InvalidOperationException>(() => writer.MoveAsync("INBOX", [b], "inbox"));
        await Assert.ThrowsAsync<MailNotFoundException>(() => writer.MoveAsync("INBOX", b, "Manca"));
        await Assert.ThrowsAsync<MailNotFoundException>(() => writer.MoveAsync("INBOX", 999, "Clienti"));
    }

    [Fact]
    public async Task EliminaPoiDefinitivaSoloInPostaEliminataConRichiestaDiRimozione()
    {
        var requested = new List<string>();
        var (store, _, reader, writer, a, b) = await TwoMailsAsync(requested.AddRange);

        await Assert.ThrowsAsync<InvalidOperationException>(() => writer.DeletePermanentlyAsync("INBOX", [a]));
        var trashed = await writer.MoveToTrashAsync("INBOX", [a, b]);
        Assert.Equal("Posta eliminata", trashed.Destination);
        await Assert.ThrowsAsync<InvalidOperationException>(() => writer.MoveToTrashAsync("Posta eliminata", [1u]));

        var inTrash = store.GetUids("Posta eliminata");
        var deleted = await writer.DeletePermanentlyAsync("Posta eliminata", inTrash);

        Assert.Equal(inTrash, deleted.Uids);
        Assert.Empty(store.GetUids("Posta eliminata"));
        Assert.Equal(0, (await reader.GetHeadersAsync("Posta eliminata", 0, 10)).Total);
        Assert.Equal(["srv-1"], requested); // solo la mail scaricata con POP3 (X-UIDL)
    }

    [Fact]
    public async Task CartelleCreaRinominaSpostaEliminaComeIImap()
    {
        var (store, _, reader, writer, a, _) = await TwoMailsAsync();

        var clienti = await writer.CreateFolderAsync(null, "  Clienti ");
        Assert.Equal(("Clienti", '/'), (clienti.FullName, clienti.Separator));
        await writer.CreateFolderAsync("Clienti", "Rossi");
        await writer.MoveAsync("INBOX", [a], "Clienti/Rossi");
        Assert.Equal("name", (await Assert.ThrowsAsync<FieldValidationException>(() => writer.CreateFolderAsync(null, "clienti"))).Field);
        Assert.Equal("name", (await Assert.ThrowsAsync<FieldValidationException>(() => writer.CreateFolderAsync(null, "inbox"))).Field);
        Assert.Equal("name", (await Assert.ThrowsAsync<FieldValidationException>(() => writer.CreateFolderAsync(null, "a/b"))).Field);

        Assert.Equal("Clienti/Bianchi", (await writer.RenameFolderAsync("Clienti/Rossi", "Bianchi")).FullName);
        Assert.Equal("CLIENTI", (await writer.RenameFolderAsync("Clienti", "CLIENTI")).FullName); // solo maiuscole
        Assert.Single(store.GetUids("CLIENTI/Bianchi")); // le mail seguono la cartella
        await Assert.ThrowsAsync<InvalidOperationException>(() => writer.RenameFolderAsync("Posta inviata", "Inviata"));
        await Assert.ThrowsAsync<InvalidOperationException>(() => writer.DeleteFolderAsync("INBOX"));

        await writer.CreateFolderAsync(null, "Archivio");
        Assert.Equal("Archivio/CLIENTI", (await writer.MoveFolderAsync("CLIENTI", "Archivio")).FullName);
        await Assert.ThrowsAsync<InvalidOperationException>(() => writer.MoveFolderAsync("Archivio", "Archivio/CLIENTI"));
        Assert.Equal("Archivio/CLIENTI", (await writer.MoveFolderAsync("Archivio/CLIENTI", "Archivio")).FullName); // già lì

        var first = await writer.DeleteFolderAsync("Archivio");
        Assert.Equal(("Posta eliminata/Archivio", false), (first.MovedTo, first.Permanent));
        await writer.CreateFolderAsync(null, "Archivio");
        Assert.Equal("Posta eliminata/Archivio (2)", (await writer.DeleteFolderAsync("Archivio")).MovedTo);
        Assert.Single(store.GetUids("Posta eliminata/Archivio/CLIENTI/Bianchi"));

        var permanent = await writer.DeleteFolderAsync("Posta eliminata/Archivio");
        Assert.True(permanent.Permanent);
        Assert.False(store.FolderExists("Posta eliminata/Archivio/CLIENTI"));
        Assert.DoesNotContain(await reader.GetFoldersAsync(), f => f.FullName.StartsWith("Posta eliminata/Archivio/"));
    }

    [Fact]
    public async Task BozzaSalvataSostituisceLaPrecedenteEPoiSiElimina()
    {
        var (store, _, reader, writer) = Local();
        var draft = MimeKit.MimeMessage.Load(new MemoryStream(System.Text.Encoding.UTF8.GetBytes(Mail("Bozza", "prima versione"))));

        var first = await writer.SaveDraftAsync(draft, null);
        var second = await writer.SaveDraftAsync(draft, first.Uid);

        Assert.Equal("Bozze", second.Folder);
        Assert.Equal([second.Uid!.Value], store.GetUids("Bozze"));
        Assert.True(Assert.Single((await reader.GetHeadersAsync("Bozze", 0, 10)).Items).Seen);
        await writer.DeleteDraftAsync(second.Uid.Value);
        Assert.Empty(store.GetUids("Bozze"));
        await writer.DeleteDraftAsync(12345); // non trovata: niente
    }

    // --- Scaricamento POP3 -------------------------------------------------------------------------

    private static async Task<FakeMailServer> Pop3ServerAsync(params (string Uidl, string Message)[] messages)
    {
        var server = new FakeMailServer(FakeMailServer.Protocol.Pop3, implicitTls: true, offerStartTls: false);
        server.Pop3Mailbox.AddRange(messages);
        await Task.CompletedTask;
        return server;
    }

    private static Pop3Settings Settings(FakeMailServer server, Action<Pop3Settings>? change = null)
    {
        var s = new Pop3Settings
        {
            Host = "127.0.0.1", Port = server.Port, Username = "me@example.com", Password = "x",
            Security = ConnectionSecurity.SslOnConnect, CertificateSha256 = TrustedCertificate.Fingerprint(server.Certificate),
        };
        change?.Invoke(s);
        return s;
    }

    [Fact]
    public async Task ScaricaUnaVoltaSolaELasciaLaCopia()
    {
        await using var server = await Pop3ServerAsync(("u-1", Mail("Prima", "uno")), ("u-2", Mail("Seconda", "..due")));
        var (store, _, reader, _) = Local();
        var state = new Pop3State(Path.Combine(_dir, "pop3.json"));
        var fetcher = new Pop3Fetcher(Settings(server), store, state);
        var now = DateTimeOffset.UtcNow;

        var first = await fetcher.RunAsync(now);
        Assert.Equal((2, 2, 0), (first.OnServer, first.Downloaded, first.Removed));
        Assert.Equal(2, server.Pop3Mailbox.Count); // copia lasciata sul server

        var second = await fetcher.RunAsync(now.AddMinutes(10));
        Assert.Equal(0, second.Downloaded);

        server.Pop3Mailbox.Add(("u-3", Mail("Terza", "tre")));
        Assert.Equal(1, (await fetcher.RunAsync(now.AddMinutes(20))).Downloaded);

        var page = await reader.GetHeadersAsync("INBOX", 0, 50);
        Assert.Equal(3, page.Total);
        var raw = await File.ReadAllTextAsync(store.PathFor("INBOX", store.GetUids("INBOX")[0]));
        Assert.StartsWith("X-UIDL: u-1\r\n", raw);
        Assert.Contains("..due", (await reader.GetMessageAsync("INBOX", store.GetUids("INBOX")[1])).TextBody); // punto iniziale ripristinato
        Assert.DoesNotContain(server.Commands, c => c.StartsWith("DELE"));
    }

    [Fact]
    public async Task RimuoveDalServerDopoNGiorni()
    {
        await using var server = await Pop3ServerAsync(("u-1", Mail("Prima", "uno")), ("u-2", Mail("Seconda", "due")));
        var store = Store();
        var state = new Pop3State(Path.Combine(_dir, "pop3.json"));
        var fetcher = new Pop3Fetcher(Settings(server, s => s.RemoveAfterDays = 14), store, state);
        var now = DateTimeOffset.UtcNow;

        await fetcher.RunAsync(now);
        Assert.Equal(0, (await fetcher.RunAsync(now.AddDays(13))).Removed);
        var late = await fetcher.RunAsync(now.AddDays(14).AddMinutes(1));

        Assert.Equal(2, late.Removed);
        Assert.Empty(server.Pop3Mailbox); // tolte al QUIT
        Assert.Empty(state.Entries); // dimenticate
        Assert.Equal(2, store.GetUids("INBOX").Count); // sul computer restano
    }

    [Fact]
    public async Task SenzaCopiaSulServerToltaSubitoDopoLoScaricamento()
    {
        await using var server = await Pop3ServerAsync(("u-1", Mail("Prima", "uno")));
        var store = Store();
        var fetcher = new Pop3Fetcher(Settings(server, s => s.LeaveOnServer = false), store, new Pop3State(Path.Combine(_dir, "pop3.json")));

        var result = await fetcher.RunAsync(DateTimeOffset.UtcNow);

        Assert.Equal((1, 1), (result.Downloaded, result.Removed));
        Assert.Empty(server.Pop3Mailbox);
        Assert.Single(store.GetUids("INBOX"));
    }

    [Fact]
    public async Task RimozioneRichiestaSoloConLOpzioneAttiva()
    {
        var entry = new Pop3Entry(DateTimeOffset.UtcNow, Remove: true);
        var now = DateTimeOffset.UtcNow;
        Assert.False(Pop3Fetcher.ShouldRemove(entry, new Pop3Settings { RemoveAfterDays = 0 }, now));
        Assert.True(Pop3Fetcher.ShouldRemove(entry, new Pop3Settings { RemoveAfterDays = 0, RemoveWhenDeleted = true }, now));
        Assert.False(Pop3Fetcher.ShouldRemove(entry with { Remove = false, Downloaded = now.AddDays(-400) },
            new Pop3Settings { RemoveAfterDays = 0 }, now)); // 0 = mai
        await Task.CompletedTask;
    }

    [Fact]
    public async Task EliminataDaPostaEliminataToltaDalServerAllaProssimaConnessione()
    {
        await using var server = await Pop3ServerAsync(("u-1", Mail("Prima", "uno")), ("u-2", Mail("Seconda", "due")));
        var store = Store();
        var state = new Pop3State(Path.Combine(_dir, "pop3.json"));
        var settings = Settings(server, s => { s.RemoveAfterDays = 0; s.RemoveWhenDeleted = true; });
        var fetcher = new Pop3Fetcher(settings, store, state);
        await fetcher.RunAsync(DateTimeOffset.UtcNow);

        // Come fa il writer dopo l'eliminazione definitiva (UIDL letto da X-UIDL).
        var cache = new AccountCache(_dir);
        var reader = new LocalMailReader("p", store, cache);
        var writer = new LocalMailWriter(store, cache, reader, uidls => { foreach (var u in uidls) state.RequestRemoval(u); });
        var first = store.GetUids("INBOX")[0];
        await writer.MoveToTrashAsync("INBOX", [first]);
        await writer.DeletePermanentlyAsync("Posta eliminata", store.GetUids("Posta eliminata"));
        var result = await fetcher.RunAsync(DateTimeOffset.UtcNow);

        Assert.Equal(1, result.Removed);
        Assert.Equal("u-2", Assert.Single(server.Pop3Mailbox).Uidl);
    }

    [Fact]
    public async Task StatoPersoRiscaricaDoppioniMaiPerdite()
    {
        await using var server = await Pop3ServerAsync(("u-1", Mail("Prima", "uno")));
        var store = Store();
        var statePath = Path.Combine(_dir, "pop3.json");
        await new Pop3Fetcher(Settings(server), store, new Pop3State(statePath)).RunAsync(DateTimeOffset.UtcNow);

        File.Delete(statePath);
        var again = await new Pop3Fetcher(Settings(server, s => s.RemoveAfterDays = 1), store, new Pop3State(statePath))
            .RunAsync(DateTimeOffset.UtcNow.AddDays(30));

        Assert.Equal((1, 0), (again.Downloaded, again.Removed)); // riscaricata come nuova: non tolta subito
        Assert.Equal(2, store.GetUids("INBOX").Count);
        Assert.Single(server.Pop3Mailbox);
    }

    [Fact]
    public async Task ServerSenzaUidlRifiutato()
    {
        await using var server = await Pop3ServerAsync(("u-1", Mail("Prima", "uno")));
        server.Pop3OffersUidl = false;

        await Assert.ThrowsAsync<NotSupportedException>(() =>
            new Pop3Fetcher(Settings(server), Store(), new Pop3State(Path.Combine(_dir, "pop3.json"))).RunAsync(DateTimeOffset.UtcNow));
        var check = await AccountTester.TestPop3Async(Settings(server));
        Assert.Contains("UIDL", check.Error);
    }

    [Fact]
    public async Task ProvaDellAccountPop3NonScaricaNeToglie()
    {
        await using var server = await Pop3ServerAsync(("u-1", Mail("Prima", "uno")));

        var untrusted = await AccountTester.TestPop3Async(Settings(server, s => s.CertificateSha256 = null));
        var ok = await AccountTester.TestPop3Async(Settings(server));

        Assert.Equal(TrustedCertificate.Fingerprint(server.Certificate), untrusted.Certificate?.Sha256);
        Assert.True(ok.Ok, ok.Error);
        Assert.DoesNotContain(server.Commands, c => c.StartsWith("RETR") || c.StartsWith("DELE"));
        Assert.Single(server.Pop3Mailbox);
    }

    [Fact]
    public async Task Pop3StartTlsSulla110()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Pop3, implicitTls: false, offerStartTls: true);
        server.Pop3Mailbox.Add(("u-1", Mail("Prima", "uno")));
        var settings = Settings(server, s => { s.Security = null; s.Port = server.Port; });
        Assert.Equal(ConnectionSecurity.SslOnConnect, settings.EffectiveSecurity); // porta qualsiasi: TLS
        Assert.Equal(ConnectionSecurity.StartTls, new Pop3Settings { Port = 110 }.EffectiveSecurity);
        settings.Security = ConnectionSecurity.StartTls;

        var result = await new Pop3Fetcher(settings, Store(), new Pop3State(Path.Combine(_dir, "pop3.json"))).RunAsync(DateTimeOffset.UtcNow);

        Assert.Equal(1, result.Downloaded);
        Assert.Contains(server.Commands, c => c == "STLS");
        Assert.Contains(server.EncryptedCommands, c => c.StartsWith("PASS"));
    }

    [Fact]
    public async Task RegistroCreaAccountPop3ConCasellaLocale()
    {
        var settings = new MailAccountSettings
        {
            Id = "pop", Type = MailAccountType.Pop3,
            Pop3 = new Pop3Settings { Host = "pop.example.com", Username = "me@example.com", Password = "x" },
            Smtp = new Smtp.SmtpSettings { Host = "smtp.example.com", Username = "me@example.com", Password = "x" },
        };
        await using var registry = MailAccountRegistry.CreateImap([settings], _dir);
        var account = registry.Get("pop");

        Assert.True(account.IsPop3 && account.Configured && account.Online);
        Assert.NotNull(account.Pop3);
        Assert.Null(account.Connection);
        Assert.False(account.Bodies!.Policy.Keeps("inbox", null, DateTimeOffset.UtcNow)); // niente copie dei corpi
        var folders = await account.Reader.GetFoldersAsync();
        Assert.Contains(folders, f => f.FullName == "INBOX" && f.SpecialUse == "inbox");
        Assert.True(Directory.Exists(Path.Combine(_dir, "accounts", "pop", "mail")));

        Assert.Throws<ArgumentException>(() => MailAccountRegistry.CreateImap([settings], cacheRoot: null));
    }
}
