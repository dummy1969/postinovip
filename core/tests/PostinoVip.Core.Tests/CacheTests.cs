using Microsoft.Data.Sqlite;
using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

public sealed class CacheTests : IDisposable
{
    /// <summary>Cartella del server in memoria: messaggi per UID, conta le richieste.</summary>
    private sealed class FakeFolder(string fullName = "INBOX", uint uidValidity = 1) : IFolderSource
    {
        public SortedDictionary<uint, HeaderRecord> Messages { get; } = [];
        public List<int> HeaderBatches { get; } = [];
        public int FlagFetches { get; private set; }

        public string FullName { get; } = fullName;
        public uint UidValidity { get; set; } = uidValidity;

        public void Add(params uint[] uids)
        {
            foreach (var u in uids)
                Messages[u] = Record(u);
        }

        public Task<IReadOnlyList<uint>> GetUidsAsync(CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<uint>>(Messages.Keys.ToList());

        public List<bool> PreviewRequests { get; } = [];

        public Task<IReadOnlyList<PreviewRecord>> FetchPreviewsAsync(IReadOnlyList<uint> uids, CancellationToken ct) =>
            throw new NotSupportedException();

        public Task<IReadOnlyList<HeaderRecord>> FetchHeadersAsync(IReadOnlyList<uint> uids, bool withPreview, CancellationToken ct)
        {
            HeaderBatches.Add(uids.Count);
            PreviewRequests.Add(withPreview);
            return Task.FromResult<IReadOnlyList<HeaderRecord>>(
                uids.Where(Messages.ContainsKey).Select(u => Messages[u]).ToList());
        }

        public Task<IReadOnlyList<(uint Uid, MailFlags Flags)>> FetchFlagsAsync(CancellationToken ct)
        {
            FlagFetches++;
            return Task.FromResult<IReadOnlyList<(uint, MailFlags)>>(Messages.Values.Select(m => (m.Uid, m.Flags)).ToList());
        }

        public Task ReadRawAsync(uint uid, Func<Stream, CancellationToken, Task> consume, CancellationToken ct) =>
            throw new NotSupportedException();

        public Task<IReadOnlyList<uint>> SearchAsync(MailSearchQuery query, CancellationToken ct) =>
            throw new NotSupportedException();

        public Task<IReadOnlyDictionary<uint, bool>> FetchHasAttachmentsAsync(IReadOnlyList<uint> uids, CancellationToken ct) =>
            throw new NotSupportedException();

        public List<uint> ReferenceFetches { get; } = [];

        public Task<IReadOnlyList<(uint Uid, string References)>> FetchReferencesAsync(IReadOnlyList<uint> uids, CancellationToken ct)
        {
            ReferenceFetches.AddRange(uids);
            return Task.FromResult<IReadOnlyList<(uint, string)>>(
                uids.Where(Messages.ContainsKey).Select(u => (u, Messages[u].References ?? "")).ToList());
        }

        public Task<IReadOnlyList<(uint Uid, MailImportance Importance)>> FetchImportanceAsync(IReadOnlyList<uint> uids, CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<(uint, MailImportance)>>(
                uids.Where(Messages.ContainsKey).Select(u => (u, Messages[u].Importance ?? MailImportance.Normal)).ToList());
    }

    private static HeaderRecord Record(uint uid, MailFlags flags = MailFlags.None) => new(
        uid, flags, $"Oggetto {uid}", "Anna Bianchi", "anna@example.com", "io@example.com", null,
        new DateTimeOffset(2026, 10, 30, 9, 15, 0, TimeSpan.FromHours(1)), null, 1234, $"<{uid}@example.com>", null);

    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-test-" + Guid.NewGuid().ToString("N"));
    private readonly AccountCache _cache;

    public CacheTests() => _cache = new AccountCache(Path.Combine(_dir, "accounts", "main"));

    public void Dispose()
    {
        SqliteConnection.ClearAllPools(); // chiude i file prima di cancellarli
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private (int Total, IReadOnlyList<HeaderRecord> Items) Page(string folder = "INBOX", int offset = 0, int limit = 50) =>
        _cache.GetPage(_cache.FindFolder(folder)!.Id, offset, limit);

    [Fact]
    public async Task PrimaSincronizzazioneSalvaTutteLeIntestazioniDalPiuRecente()
    {
        var server = new FakeFolder();
        server.Add(1, 2, 5, 9);

        var result = await FolderSynchronizer.SyncAsync(server, _cache);

        Assert.True(result.FirstSync);
        Assert.Equal(4, result.Added);
        Assert.Equal(0, server.FlagFetches); // niente da rileggere: la cache era vuota
        var (total, items) = Page();
        Assert.Equal(4, total);
        Assert.Equal([9u, 5u, 2u, 1u], items.Select(i => i.Uid));
        Assert.Equal(server.Messages[9], items[0]); // tutti i campi, date con fuso orario comprese
    }

    [Fact]
    public async Task SincronizzazioneLimitataSalvaLePiuRecentiELasciaIlRestoAlGiroDopo()
    {
        var server = new FakeFolder();
        server.Add(1, 2, 3, 4, 5);

        var first = await FolderSynchronizer.SyncAsync(server, _cache, maxNew: 2);

        Assert.True(first.FirstSync);
        Assert.Equal(2, first.Added);
        Assert.Equal(3, first.Pending);
        Assert.Equal([5u, 4u], Page().Items.Select(i => i.Uid));
        Assert.Null(_cache.FindFolder("INBOX")!.SyncedAt); // non ancora completa

        var rest = await FolderSynchronizer.SyncAsync(server, _cache, maxNew: 2);
        Assert.True(rest.FirstSync);
        Assert.Equal(2, rest.Added);
        Assert.Equal(1, rest.Pending);

        var last = await FolderSynchronizer.SyncAsync(server, _cache);
        Assert.Equal(1, last.Added);
        Assert.Equal(0, last.Pending);
        Assert.NotNull(_cache.FindFolder("INBOX")!.SyncedAt);
        Assert.Equal(5, Page().Total);
    }

    [Fact]
    public async Task AnteprimaSubitoSoloConPocheMailNuove()
    {
        var server = new FakeFolder();
        server.Add(Enumerable.Range(1, FolderSynchronizer.InlinePreviewLimit + 1).Select(i => (uint)i).ToArray());
        await FolderSynchronizer.SyncAsync(server, _cache); // prima sincronizzazione grande: niente anteprime
        Assert.All(server.PreviewRequests, Assert.False);

        server.PreviewRequests.Clear();
        server.Add(100, 101);
        await FolderSynchronizer.SyncAsync(server, _cache); // poche nuove: anteprima nello stesso FETCH
        Assert.Equal([true], server.PreviewRequests);
    }

    [Fact]
    public async Task ScadenzaSoloLocaleToltaQuandoSparisceIlContrassegno()
    {
        var server = new FakeFolder();
        server.Add(1, 2);
        await FolderSynchronizer.SyncAsync(server, _cache);
        var id = _cache.FindFolder("INBOX")!.Id;
        var due = new DateOnly(2026, 11, 5);

        var flagged = MailFlags.Flagged | MailFlags.Category2;
        Assert.Equal(due, _cache.SetFlags(id, 1, flagged, due));
        Assert.Equal(due, _cache.SetFlags(id, 1, flagged | MailFlags.Category3, null, keepDue: true)); // solo categorie: resta
        server.Messages[1] = server.Messages[1] with { Flags = flagged | MailFlags.Category3 };
        await FolderSynchronizer.SyncAsync(server, _cache);
        var header = MessageHeaderMapper.FromRecord(Page().Items.Single(i => i.Uid == 1));
        Assert.Equal((true, due), (header.Flagged, header.Due));
        Assert.Equal([2, 3], header.Categories!);

        // Contrassegno tolto da un altro programma: la scadenza non vale più, nemmeno se torna.
        server.Messages[1] = server.Messages[1] with { Flags = MailFlags.Completed };
        await FolderSynchronizer.SyncAsync(server, _cache);
        server.Messages[1] = server.Messages[1] with { Flags = MailFlags.Flagged };
        await FolderSynchronizer.SyncAsync(server, _cache);
        header = MessageHeaderMapper.FromRecord(Page().Items.Single(i => i.Uid == 1));
        Assert.Equal((true, (DateOnly?)null), (header.Flagged, header.Due));
    }

    [Fact]
    public void ParoleChiaveDelleCategorieEDelCompletato()
    {
        var flags = MessageHeaderMapper.ToMailFlags(MailKit.MessageFlags.Flagged, ["$catblu", "$Completed", "$Sconosciuta", "$CatRossa"]);

        Assert.Equal(MailFlags.Flagged | MailFlags.Completed | MailFlags.Category1 | MailFlags.Category5, flags);
        Assert.Equal(["$Completed", "$CatRossa", "$CatBlu"], MailKeywords.ToKeywords(flags));
    }

    [Fact]
    public async Task FiltroDaLeggereEOrdineDalPiuVecchio()
    {
        var server = new FakeFolder();
        server.Add(1, 2, 3, 4);
        server.Messages[2] = server.Messages[2] with { Flags = MailFlags.Seen };
        server.Messages[4] = server.Messages[4] with { Flags = MailFlags.Seen };
        await FolderSynchronizer.SyncAsync(server, _cache);
        var id = _cache.FindFolder("INBOX")!.Id;

        var unread = _cache.GetPage(id, 0, 10, unreadOnly: true);
        Assert.Equal(2, unread.Total);
        Assert.Equal([3u, 1u], unread.Items.Select(i => i.Uid));
        Assert.Equal([1u, 2u, 3u, 4u], _cache.GetPage(id, 0, 10, oldestFirst: true).Items.Select(i => i.Uid));
    }

    [Fact]
    public async Task OrdinePerMittenteOggettoDimensione()
    {
        var server = new FakeFolder();
        server.Add(1, 2, 3, 4);
        server.Messages[1] = server.Messages[1] with { FromName = "carla", Subject = "Zeta", Size = 300 };
        server.Messages[2] = server.Messages[2] with { FromName = null, FromAddress = "bruno@x.it", Subject = "alfa", Size = 10 };
        server.Messages[3] = server.Messages[3] with { FromName = "Anna", Subject = "Beta", Size = 5000 };
        server.Messages[4] = server.Messages[4] with { FromName = "Anna", Subject = null, Size = null };
        await FolderSynchronizer.SyncAsync(server, _cache);
        var id = _cache.FindFolder("INBOX")!.Id;
        IEnumerable<uint> Uids(MessageSort sort, bool asc) => _cache.GetPage(id, 0, 10, oldestFirst: asc, sort: sort).Items.Select(i => i.Uid);

        // A→Z senza distinzione di maiuscole; il nome manca: l'indirizzo; a parità dalla più recente (UID 4 prima di 3).
        Assert.Equal([4u, 3u, 2u, 1u], Uids(MessageSort.From, asc: true));
        Assert.Equal([1u, 2u, 4u, 3u], Uids(MessageSort.From, asc: false));
        Assert.Equal([4u, 2u, 3u, 1u], Uids(MessageSort.Subject, asc: true)); // senza oggetto in cima
        Assert.Equal([3u, 1u, 2u, 4u], Uids(MessageSort.Size, asc: false)); // dimensione non nota = 0
        Assert.Equal(5000, _cache.GetPage(id, 0, 1, sort: MessageSort.Size).Items.Single().Size);
    }

    [Fact]
    public async Task PaginaConOffsetELimit()
    {
        var server = new FakeFolder();
        server.Add(1, 2, 3, 4, 5);
        await FolderSynchronizer.SyncAsync(server, _cache);

        var (total, items) = Page(offset: 1, limit: 2);

        Assert.Equal(5, total);
        Assert.Equal([4u, 3u], items.Select(i => i.Uid));
    }

    [Fact]
    public async Task CartellaGrandeScaricataABlocchi()
    {
        var server = new FakeFolder();
        server.Add(Enumerable.Range(1, 1200).Select(i => (uint)i).ToArray());

        await FolderSynchronizer.SyncAsync(server, _cache);

        Assert.Equal([500, 500, 200], server.HeaderBatches);
        Assert.Equal(1200, Page().Total);
    }

    [Fact]
    public async Task SecondaSincronizzazioneScaricaSoloLeNuove()
    {
        var server = new FakeFolder();
        server.Add(1, 2);
        await FolderSynchronizer.SyncAsync(server, _cache);
        server.HeaderBatches.Clear();

        server.Add(3);
        var result = await FolderSynchronizer.SyncAsync(server, _cache);

        Assert.False(result.FirstSync);
        Assert.Equal(1, result.Added);
        Assert.Equal([1], server.HeaderBatches);
        Assert.Equal([3u, 2u, 1u], Page().Items.Select(i => i.Uid));
    }

    [Fact]
    public async Task NienteCambiamentiNienteScritture()
    {
        var server = new FakeFolder();
        server.Add(1, 2);
        await FolderSynchronizer.SyncAsync(server, _cache);

        var result = await FolderSynchronizer.SyncAsync(server, _cache);

        Assert.False(result.Changed);
        Assert.Empty(server.HeaderBatches.Skip(1));
    }

    [Fact]
    public async Task CancellatiSulServerSparisconoAncheInCache()
    {
        var server = new FakeFolder();
        server.Add(1, 2, 3);
        await FolderSynchronizer.SyncAsync(server, _cache);

        server.Messages.Remove(2);
        var result = await FolderSynchronizer.SyncAsync(server, _cache);

        Assert.Equal(1, result.Removed);
        Assert.Equal([3u, 1u], Page().Items.Select(i => i.Uid));
    }

    [Fact]
    public async Task FlagCambiatiAltroveAggiornati()
    {
        var server = new FakeFolder();
        server.Add(1, 2);
        await FolderSynchronizer.SyncAsync(server, _cache);

        server.Messages[1] = server.Messages[1] with { Flags = MailFlags.Seen | MailFlags.Flagged };
        var result = await FolderSynchronizer.SyncAsync(server, _cache);

        Assert.Equal(1, result.FlagsChanged); // solo quello cambiato davvero
        Assert.Equal(MailFlags.Seen | MailFlags.Flagged, Page().Items.Single(i => i.Uid == 1).Flags);
    }

    [Fact]
    public async Task UidValidityCambiatoAzzeraLaCartella()
    {
        var server = new FakeFolder();
        server.Add(1, 2);
        await FolderSynchronizer.SyncAsync(server, _cache);

        // Il server ha ricostruito la cartella: gli stessi UID ora indicano altri messaggi.
        server.UidValidity = 2;
        server.Messages.Clear();
        server.Add(1);
        server.Messages[1] = server.Messages[1] with { Subject = "Messaggio diverso" };
        var result = await FolderSynchronizer.SyncAsync(server, _cache);

        Assert.True(result.Reset);
        Assert.Equal("Messaggio diverso", Page().Items.Single().Subject);
        Assert.Equal(2u, _cache.FindFolder("INBOX")!.UidValidity);
    }

    [Fact]
    public async Task CartelleSeparate()
    {
        var inbox = new FakeFolder("INBOX");
        inbox.Add(1, 2);
        var sent = new FakeFolder("Posta inviata");
        sent.Add(1);
        await FolderSynchronizer.SyncAsync(inbox, _cache);
        await FolderSynchronizer.SyncAsync(sent, _cache);

        Assert.Equal(2, Page("INBOX").Total);
        Assert.Equal(1, Page("Posta inviata").Total);
    }

    /// <summary>"Clienti" con una sottocartella e "Clienti2", che ha lo stesso inizio ma non è una sottocartella.</summary>
    private async Task SyncClientiAsync()
    {
        var clienti = new FakeFolder("Clienti");
        clienti.Add(1, 2);
        var rossi = new FakeFolder("Clienti/Rossi");
        rossi.Add(1);
        var clienti2 = new FakeFolder("Clienti2");
        clienti2.Add(1);
        foreach (var f in new[] { clienti, rossi, clienti2 })
            await FolderSynchronizer.SyncAsync(f, _cache);
        _cache.SetFolderInfo([new("Clienti", "Clienti", 2), new("Clienti/Rossi", "Rossi", 1), new("Clienti2", "Clienti2", 1)]);
    }

    [Fact]
    public async Task CartellaRinominataConSottocartelleSenzaRiscaricareLeMail()
    {
        await SyncClientiAsync();
        var id = _cache.FindFolder("Clienti")!.Id;

        Assert.Equal(2, _cache.RenameFolderTree("Clienti", "Posta eliminata/Clienti", '/'));

        Assert.Null(_cache.FindFolder("Clienti"));
        Assert.Null(_cache.FindFolder("Clienti/Rossi"));
        Assert.Equal(id, _cache.FindFolder("Posta eliminata/Clienti")!.Id); // stessa cartella: mail e corpi restano
        Assert.Equal(2, Page("Posta eliminata/Clienti").Total);
        Assert.Equal(1, Page("Posta eliminata/Clienti/Rossi").Total);
        Assert.Equal(1, Page("Clienti2").Total); // stesso inizio del nome, ma non è una sottocartella
        var names = _cache.GetFolderList().ToDictionary(f => f.FullName, f => f.Name);
        Assert.Equal("Clienti", names["Posta eliminata/Clienti"]);
        Assert.Equal("Rossi", names["Posta eliminata/Clienti/Rossi"]);
    }

    [Fact]
    public async Task RinominaSopraUnaRigaGiaPresenteConIlNuovoNome()
    {
        await SyncClientiAsync();
        // Una sincronizzazione ha già visto la cartella con il nome nuovo (vuota): la rinomina la sostituisce.
        _cache.GetOrAddFolder("Archivio");

        _cache.RenameFolderTree("Clienti", "Archivio", '/');

        Assert.Equal(2, Page("Archivio").Total);
        Assert.Equal(1, Page("Archivio/Rossi").Total);
    }

    [Fact]
    public async Task CartellaEliminataDefinitivamenteTolteAncheLeSottocartelle()
    {
        await SyncClientiAsync();

        Assert.Equal(2, _cache.RemoveFolderTree("Clienti", '/'));

        Assert.Null(_cache.FindFolder("Clienti"));
        Assert.Null(_cache.FindFolder("Clienti/Rossi"));
        Assert.NotNull(_cache.FindFolder("Clienti2"));
        Assert.Equal(1L, Scalar("SELECT count(*) FROM messages")); // solo quella di Clienti2
        Assert.Equal(0, _cache.RenameFolderTree("Inesistente", "Altro", '/'));
    }

    [Fact]
    public async Task CartellaSparitaDalServerEliminataConISuoiMessaggi()
    {
        var old = new FakeFolder("Vecchia");
        old.Add(1, 2);
        await FolderSynchronizer.SyncAsync(old, _cache);
        await FolderSynchronizer.SyncAsync(new FakeFolder("INBOX"), _cache);

        Assert.Equal(1, _cache.RemoveFoldersNotIn(["INBOX"]));

        Assert.Null(_cache.FindFolder("Vecchia"));
        Assert.NotNull(_cache.FindFolder("INBOX"));
        // ON DELETE CASCADE: nessun messaggio rimasto senza cartella.
        Assert.Equal(0L, Scalar("SELECT count(*) FROM messages"));
    }

    [Fact]
    public async Task SchemaConNumeroDiVersione()
    {
        await FolderSynchronizer.SyncAsync(new FakeFolder(), _cache);

        Assert.Equal((long)AccountCache.SchemaVersion, Scalar("PRAGMA user_version"));
        Assert.Equal("wal", Scalar("PRAGMA journal_mode"));
    }

    [Fact]
    public async Task CacheDiUnaVersionePiuRecenteVieneRicreata()
    {
        var server = new FakeFolder();
        server.Add(1);
        await FolderSynchronizer.SyncAsync(server, _cache);
        Scalar($"PRAGMA user_version = {AccountCache.SchemaVersion + 1}");
        SqliteConnection.ClearAllPools();

        var reopened = new AccountCache(_cache.Directory);
        var result = await FolderSynchronizer.SyncAsync(server, reopened);

        Assert.True(result.FirstSync); // ricreata vuota e riempita di nuovo dal server
        Assert.NotNull(reopened.TakeInitializeNote());
        Assert.Null(reopened.TakeInitializeNote()); // segnalato una volta sola
        Assert.Equal(1, reopened.GetPage(reopened.FindFolder("INBOX")!.Id, 0, 10).Total);
    }

    [Fact]
    public async Task FilePrivati()
    {
        if (OperatingSystem.IsWindows())
            return;
        await FolderSynchronizer.SyncAsync(new FakeFolder(), _cache);

        Assert.Equal(CachePermissions.PrivateDirectory, File.GetUnixFileMode(_cache.Directory));
        Assert.Equal(CachePermissions.PrivateFile, File.GetUnixFileMode(_cache.Path));
        Assert.Equal(CachePermissions.PrivateFile, File.GetUnixFileMode(_cache.Path + "-wal"));
    }

    [Fact]
    public async Task RegistroRendePrivateAncheLeCartelleSuperiori()
    {
        if (OperatingSystem.IsWindows())
            return;
        var root = Path.Combine(_dir, "radice");
        Directory.CreateDirectory(root); // già esistente con i permessi predefiniti

        await using var registry = MailAccountRegistry.CreateImap([new MailAccountSettings { Id = "uno" }], root);

        Assert.Equal(CachePermissions.PrivateDirectory, File.GetUnixFileMode(root));
        Assert.Equal(CachePermissions.PrivateDirectory, File.GetUnixFileMode(Path.Combine(root, "accounts")));
    }

    [Fact]
    public void SqliteInclusaHaFts5ConRimozioneDegliAccenti()
    {
        // Requisito della ricerca (8c): la SQLite inclusa nel pacchetto, non quella di sistema.
        using var db = new SqliteConnection("Data Source=:memory:");
        db.Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            CREATE VIRTUAL TABLE t USING fts5(x, tokenize = 'unicode61 remove_diacritics 2');
            INSERT INTO t VALUES ('Perché la fattura è arrivata');
            SELECT count(*) FROM t WHERE t MATCH 'perche fatt*';
            """;
        Assert.Equal(1L, cmd.ExecuteScalar());
    }

    [Fact]
    public void RigaDellaCacheDiventaIntestazioneDellaLista()
    {
        var h = MessageHeaderMapper.FromRecord(Record(7, MailFlags.Seen));
        Assert.Equal("Anna Bianchi", h.From);
        Assert.Equal("Oggetto 7", h.Subject);
        Assert.True(h.Seen);

        var bare = MessageHeaderMapper.FromRecord(Record(8) with { Subject = null, FromName = null });
        Assert.Equal("anna@example.com", bare.From);
        Assert.Equal("(nessun oggetto)", bare.Subject);
        Assert.False(bare.Seen);

        Assert.Equal("(mittente sconosciuto)", MessageHeaderMapper.FromRecord(Record(9) with { FromName = null, FromAddress = null }).From);
    }

    private object? Scalar(string sql)
    {
        using var db = new SqliteConnection($"Data Source={_cache.Path}");
        db.Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = sql;
        return cmd.ExecuteScalar();
    }

    // ---------------------------------------------------------------------------------------------
    // Conversazioni (3.6)
    // ---------------------------------------------------------------------------------------------

    /// <summary>Mail con Message-ID "&lt;id@x&gt;", eventuale risposta a <paramref name="replyTo"/> e References.</summary>
    private static HeaderRecord Mail(uint uid, string id, string? replyTo = null, string? refs = "", int day = 1,
        MailFlags flags = MailFlags.Seen) =>
        Record(uid, flags) with
        {
            MessageId = $"<{id}@x>",
            InReplyTo = replyTo is null ? null : $"<{replyTo}@x>",
            References = refs,
            InternalDate = new DateTimeOffset(2026, 10, day, 12, 0, 0, TimeSpan.Zero),
        };

    private async Task Sync(string name, params HeaderRecord[] mails)
    {
        var folder = new FakeFolder(name);
        foreach (var m in mails)
            folder.Messages[m.Uid] = m;
        await FolderSynchronizer.SyncAsync(folder, _cache);
    }

    private void Roles(params (string Name, string? Role)[] folders) =>
        _cache.SetFolderInfo(folders.Select(f => new MailFolderInfo(f.Name, f.Name, null, f.Role)).ToList());

    /// <summary>Conversazioni della cartella come "cartella:uid cartella:uid | ..." (mail dalla più recente).</summary>
    private string Conversations(string folder, bool unreadOnly = false, bool oldestFirst = false, int offset = 0, int limit = 50)
    {
        var (_, items) = _cache.GetConversations(_cache.FindFolder(folder)!, offset, limit, unreadOnly, oldestFirst);
        return string.Join(" | ", items.Select(c => string.Join(" ", c.Messages.Select(m => $"{m.Folder}:{m.Header.Uid}"))));
    }

    [Fact]
    public async Task ConversazioniDaInReplyToEReferencesAncheTraCartelle()
    {
        Roles(("INBOX", "inbox"), ("Posta inviata", "sent"), ("Posta eliminata", "trash"));
        await Sync("INBOX",
            Mail(1, "a", day: 1),
            Mail(2, "c", replyTo: "b", refs: "<a@x> <b@x>", day: 3), // risponde alla mia risposta (in Posta inviata)
            Mail(3, "z", day: 2));                                   // un'altra conversazione
        await Sync("Posta inviata", Mail(10, "b", replyTo: "a", refs: "<a@x>", day: 2));
        await Sync("Posta eliminata", Mail(20, "d", replyTo: "c", refs: "<a@x> <b@x> <c@x>", day: 4));

        Assert.Equal("INBOX:2 Posta inviata:10 INBOX:1 | INBOX:3", Conversations("INBOX"));
        // Posta eliminata aperta: solo le sue mail; dalle altre cartelle Posta eliminata non si vede.
        Assert.Equal("Posta eliminata:20", Conversations("Posta eliminata"));
        // Le mail di una conversazione per data, qualunque sia la cartella.
        Assert.Equal("INBOX:2 Posta inviata:10 INBOX:1", Conversations("Posta inviata"));
    }

    [Fact]
    public async Task MailCheCitanoLaStessaMailMancanteStannoInsieme()
    {
        // "Re:" di due persone diverse alla stessa mail, che non abbiamo: solo References le lega.
        await Sync("INBOX",
            Mail(1, "r1", replyTo: "orig", refs: "<orig@x>"),
            Mail(2, "r2", replyTo: "orig", refs: "<orig@x>", day: 2),
            Mail(3, "altra", refs: null, day: 3)); // References non ancora nota: da sola

        Assert.Equal("INBOX:3 | INBOX:2 INBOX:1", Conversations("INBOX"));
    }

    [Fact]
    public async Task StessoMessageIdInDueCartelleStessaConversazione()
    {
        await Sync("INBOX", Mail(1, "uguale"));
        await Sync("Archivio", Mail(7, "uguale", day: 2));

        Assert.Equal("Archivio:7 INBOX:1", Conversations("INBOX"));
    }

    [Fact]
    public async Task ConversazioniPerPaginaFiltroEOrdine()
    {
        await Sync("INBOX",
            Mail(1, "a", day: 1),
            Mail(2, "b", replyTo: "a", refs: "<a@x>", day: 5, flags: MailFlags.None), // da leggere
            Mail(3, "c", day: 3),
            Mail(4, "d", day: 4));

        var (total, page) = _cache.GetConversations(_cache.FindFolder("INBOX")!, 1, 1);
        Assert.Equal(3, total);
        Assert.Equal([4u], page.Single().Messages.Select(m => m.Header.Uid));
        Assert.Equal("INBOX:2 INBOX:1", Conversations("INBOX", unreadOnly: true));
        Assert.Equal("INBOX:3 | INBOX:4 | INBOX:2 INBOX:1", Conversations("INBOX", oldestFirst: true));
        Assert.Equal(1, _cache.GetConversations(_cache.FindFolder("INBOX")!, 0, 50, unreadOnly: true).Total);
    }

    [Fact]
    public async Task ReferencesRiempiteDopoUnisconoLeConversazioni()
    {
        var inbox = new FakeFolder();
        inbox.Messages[1] = Mail(1, "a", refs: null);
        inbox.Messages[2] = Mail(2, "c", refs: null, day: 3); // senza In-Reply-To: solo References la lega
        await FolderSynchronizer.SyncAsync(inbox, _cache);
        Assert.Equal("INBOX:2 | INBOX:1", Conversations("INBOX"));

        var folder = _cache.FindFolder("INBOX")!;
        Assert.Equal([2u, 1u], _cache.GetMissingReferences(folder.Id));
        _cache.SetReferences(folder.Id, [(2, "<b@x> <a@x>"), (1, "")]);

        Assert.Empty(_cache.GetMissingReferences(folder.Id));
        Assert.Equal("INBOX:2 INBOX:1", Conversations("INBOX"));
    }

    [Fact]
    public async Task ConversazioneSiDivideQuandoSparisceLaMailCheLeLegava()
    {
        var inbox = new FakeFolder();
        inbox.Messages[1] = Mail(1, "a");
        inbox.Messages[2] = Mail(2, "b", replyTo: "a", refs: "", day: 2);
        inbox.Messages[3] = Mail(3, "c", replyTo: "b", refs: "", day: 3);
        await FolderSynchronizer.SyncAsync(inbox, _cache);
        Assert.Equal("INBOX:3 INBOX:2 INBOX:1", Conversations("INBOX"));

        inbox.Messages.Remove(2);
        await FolderSynchronizer.SyncAsync(inbox, _cache);

        Assert.Equal("INBOX:3 | INBOX:1", Conversations("INBOX"));
    }
}
