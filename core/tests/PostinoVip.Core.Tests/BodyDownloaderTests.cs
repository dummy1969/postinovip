using System.Text;
using MailKit.Net.Imap;
using Microsoft.Data.Sqlite;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

public sealed class BodyDownloaderTests : IDisposable
{
    private sealed class FakeFolder(string fullName, string? role) : IFolderSource
    {
        public SortedDictionary<uint, (HeaderRecord Header, byte[] Content)> Messages { get; } = [];
        public List<uint> Downloads { get; } = [];
        public string? Role { get; } = role;
        public Exception? FailWith { get; set; }

        /// <summary>Simula un'eliminazione sul server tra la sincronizzazione e il download.</summary>
        public HashSet<uint> VanishOnDownload { get; } = [];

        public string FullName { get; } = fullName;
        public uint UidValidity => 1;

        public void Add(uint uid, DateTimeOffset arrived)
        {
            var header = new HeaderRecord(uid, MailFlags.None, $"Oggetto {uid}", null, "anna@example.com", null, null,
                arrived, arrived, 100, null, null);
            Messages[uid] = (header, Encoding.UTF8.GetBytes($"Subject: {FullName} {uid}\r\n\r\nCorpo {uid}\r\n"));
        }

        public Task<IReadOnlyList<uint>> GetUidsAsync(CancellationToken ct) =>
            FailWith is null ? Task.FromResult<IReadOnlyList<uint>>(Messages.Keys.ToList()) : throw FailWith;

        /// <summary>Anteprime chieste al server (riempimento in background).</summary>
        public List<uint> PreviewFetches { get; } = [];

        public Task<IReadOnlyList<PreviewRecord>> FetchPreviewsAsync(IReadOnlyList<uint> uids, CancellationToken ct)
        {
            PreviewFetches.AddRange(uids);
            return Task.FromResult<IReadOnlyList<PreviewRecord>>(
                uids.Select(u => new PreviewRecord(u, $"Anteprima {u}", WithAttachments.Contains(u))).ToList());
        }

        public Task<IReadOnlyList<HeaderRecord>> FetchHeadersAsync(IReadOnlyList<uint> uids, bool withPreview, CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<HeaderRecord>>(uids.Where(Messages.ContainsKey).Select(u => Messages[u].Header).ToList());

        public Task<IReadOnlyList<(uint Uid, MailFlags Flags)>> FetchFlagsAsync(CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<(uint, MailFlags)>>(Messages.Values.Select(m => (m.Header.Uid, m.Header.Flags)).ToList());

        /// <summary>Come il server: ogni termine come sottostringa del messaggio intero, senza maiuscole.</summary>
        public Task<IReadOnlyList<uint>> SearchAsync(MailSearchQuery query, CancellationToken ct)
        {
            Searches++;
            return Task.FromResult<IReadOnlyList<uint>>(Messages
                .Where(m => query.Terms.All(t => Encoding.UTF8.GetString(m.Value.Content).Contains(t.Text, StringComparison.OrdinalIgnoreCase)))
                .Select(m => m.Key).ToList());
        }

        public int Searches { get; private set; }

        /// <summary>Messaggi con allegati (per il filtro allegati:) e strutture richieste.</summary>
        public HashSet<uint> WithAttachments { get; } = [];
        public List<uint> StructureFetches { get; } = [];

        /// <summary>References del server per UID (assente = intestazione assente) e richieste fatte.</summary>
        public Dictionary<uint, string> References { get; } = [];
        public List<uint> ReferenceFetches { get; } = [];

        public Task<IReadOnlyList<(uint Uid, string References)>> FetchReferencesAsync(IReadOnlyList<uint> uids, CancellationToken ct)
        {
            ReferenceFetches.AddRange(uids);
            return Task.FromResult<IReadOnlyList<(uint, string)>>(
                uids.Where(Messages.ContainsKey).Select(u => (u, References.GetValueOrDefault(u, ""))).ToList());
        }

        public Dictionary<uint, MailImportance> Importance { get; } = [];
        public List<uint> ImportanceFetches { get; } = [];

        public Task<IReadOnlyList<(uint Uid, MailImportance Importance)>> FetchImportanceAsync(IReadOnlyList<uint> uids, CancellationToken ct)
        {
            ImportanceFetches.AddRange(uids);
            return Task.FromResult<IReadOnlyList<(uint, MailImportance)>>(
                uids.Where(Messages.ContainsKey).Select(u => (u, Importance.GetValueOrDefault(u))).ToList());
        }

        public Task<IReadOnlyDictionary<uint, bool>> FetchHasAttachmentsAsync(IReadOnlyList<uint> uids, CancellationToken ct)
        {
            StructureFetches.AddRange(uids);
            return Task.FromResult<IReadOnlyDictionary<uint, bool>>(uids.ToDictionary(u => u, WithAttachments.Contains));
        }

        public async Task ReadRawAsync(uint uid, Func<Stream, CancellationToken, Task> consume, CancellationToken ct)
        {
            if (VanishOnDownload.Contains(uid))
                throw new MailNotFoundException($"Messaggio {uid} non trovato.");
            Downloads.Add(uid);
            await consume(new MemoryStream(Messages[uid].Content), ct);
        }
    }

    private sealed class FakeMailbox : IMailboxSource
    {
        public List<FakeFolder> Folders { get; } = [];
        public List<string> Examined { get; } = [];

        public FakeFolder Add(string name, string? role = null)
        {
            var f = new FakeFolder(name, role);
            Folders.Add(f);
            return f;
        }

        public Task<IReadOnlyList<MailFolderInfo>> GetFoldersAsync(CancellationToken ct = default) =>
            Task.FromResult<IReadOnlyList<MailFolderInfo>>(Folders.Select(f => new MailFolderInfo(f.FullName, f.FullName, f.Messages.Count, f.Role)).ToList());

        public Task<T> ExamineAsync<T>(string folderName, Func<IFolderSource, Task<T>> action, CancellationToken ct = default)
        {
            Examined.Add(folderName);
            return action(Folders.Single(f => f.FullName == folderName));
        }
    }

    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-test-" + Guid.NewGuid().ToString("N"));
    private readonly AccountCache _cache;
    private readonly BodyDownloader _downloader;
    private readonly List<string> _log = [];
    private readonly FakeMailbox _server = new();

    private static DateTimeOffset Recent => DateTimeOffset.UtcNow.AddDays(-3);
    private static DateTimeOffset Old => DateTimeOffset.UtcNow.AddMonths(-13);

    public BodyDownloaderTests()
    {
        _cache = new AccountCache(Path.Combine(_dir, "accounts", "main"));
        _downloader = new BodyDownloader("main", _cache, BodyPolicy.Default, _log.Add);
    }

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private string? Sha(string folder, uint uid) => _cache.GetBodyRow(_cache.FindFolder(folder)!.Id, uid)?.Sha256;

    [Fact]
    public async Task CartellaGrandeSincronizzataABlocchiEAvvisataUnaVolta()
    {
        var inbox = _server.Add("INBOX", "inbox");
        var count = FolderSynchronizer.BatchSize * 2 + 10;
        for (uint u = 1; u <= count; u++)
            inbox.Add(u, Old); // vecchie: nessun corpo da scaricare
        var synced = new List<(string Folder, int Added, bool Incomplete)>();
        _downloader.HeadersSynced = (f, a, i) => synced.Add((f, a, i));

        await _downloader.RunPassAsync(_server);

        Assert.Equal(3, _log.Count(l => l.Contains("(in background) INBOX"))); // 200 (cartella vuota), 500, 310
        Assert.Equal([("INBOX", count, true)], synced);
        Assert.NotNull(_cache.FindFolder("INBOX")!.SyncedAt);

        synced.Clear();
        await _downloader.RunPassAsync(_server); // niente di nuovo: cartella già completa
        Assert.Equal([("INBOX", 0, false)], synced);
    }

    [Fact]
    public async Task InboxPerPrimaPoiLeAltreDalPiuRecente()
    {
        var sent = _server.Add("Posta inviata", "sent");
        sent.Add(1, Recent);
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(10, Recent);
        inbox.Add(11, Recent);

        await _downloader.RunPassAsync(_server);

        Assert.Equal(["INBOX", "Posta inviata"], _server.Examined);
        Assert.Equal([11u, 10u], inbox.Downloads);
        Assert.Equal([1u], sent.Downloads);
        var bytes = _cache.Bodies.TryRead(Sha("INBOX", 10)!);
        Assert.Equal(inbox.Messages[10].Content, bytes);
    }

    [Fact]
    public async Task SoloEntroIlLimiteECestinoSoloIntestazioni()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Old);
        inbox.Add(2, Recent);
        var trash = _server.Add("Posta eliminata", "trash");
        trash.Add(5, Recent);

        await _downloader.RunPassAsync(_server);

        Assert.Equal([2u], inbox.Downloads);
        Assert.Empty(trash.Downloads);
        Assert.Null(Sha("INBOX", 1));
        Assert.NotNull(_cache.FindFolder("Posta eliminata")); // intestazioni sincronizzate comunque
        Assert.Equal(1, _cache.GetPage(_cache.FindFolder("Posta eliminata")!.Id, 0, 10).Total);
    }

    [Fact]
    public async Task SecondoPassaggioScaricaSoloLeNuove()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent);
        await _downloader.RunPassAsync(_server);

        inbox.Add(2, Recent);
        await _downloader.RunPassAsync(_server);

        Assert.Equal([1u, 2u], inbox.Downloads);
    }

    [Fact]
    public async Task CorpoGiaApertoDallUtenteNonRiscaricato()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent);
        inbox.Add(2, Recent);
        // Sincronizzazione e apertura del messaggio 2 dalla connessione dei comandi.
        await FolderSynchronizer.SyncAsync(inbox, _cache);
        var folder = _cache.FindFolder("INBOX")!;
        _cache.SetBody(folder.Id, 2, await _cache.Bodies.SaveAsync(new MemoryStream(inbox.Messages[2].Content)));

        await _downloader.RunPassAsync(_server);

        Assert.Equal([1u], inbox.Downloads);
    }

    [Fact]
    public async Task MessaggioSparitoDuranteIlDownloadSaltato()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent);
        inbox.Add(2, Recent);
        inbox.VanishOnDownload.Add(2);

        var results = await _downloader.RunPassAsync(_server);

        Assert.Equal([1u], inbox.Downloads);
        Assert.Equal(1, results.Single().Gone);
        Assert.Null(Sha("INBOX", 2));
    }

    [Fact]
    public async Task ErroreDiUnaCartellaNonFermaLeAltre()
    {
        _server.Add("Rotta").FailWith = new InvalidOperationException("cartella non selezionabile");
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent);
        var other = _server.Add("Archivio");
        other.Add(3, Recent);

        await _downloader.RunPassAsync(_server);

        Assert.Equal([1u], inbox.Downloads);
        Assert.Equal([3u], other.Downloads);
        Assert.Contains(_log, l => l.Contains("Rotta saltata"));

        await _downloader.RunPassAsync(_server);
        Assert.Single(_log, l => l.Contains("Rotta saltata")); // segnalata una volta sola
    }

    [Fact]
    public async Task ErroreDiConnessionePropagato()
    {
        _server.Add("INBOX", "inbox").FailWith = new ImapProtocolException("connessione chiusa");

        await Assert.ThrowsAsync<ImapProtocolException>(() => _downloader.RunPassAsync(_server));
    }

    [Fact]
    public async Task CorpiScaricatiEGiaInCacheFinisconoNellaRicerca()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent);
        inbox.Add(2, Recent);
        // Il 2 era già salvato prima della ricerca (8b): file presente, testo non indicizzato.
        await FolderSynchronizer.SyncAsync(inbox, _cache);
        var folder = _cache.FindFolder("INBOX")!;
        _cache.SetBody(folder.Id, 2, await _cache.Bodies.SaveAsync(new MemoryStream(inbox.Messages[2].Content)));

        var results = await _downloader.RunPassAsync(_server);

        Assert.Equal([1u], inbox.Downloads);
        Assert.Equal(2, results.Single().Indexed);
        var hits = _cache.Search(MailSearchQuery.Parse("corpo"), null, 0, 10).Items;
        Assert.Equal([2u, 1u], hits.Select(h => h.Uid));
        Assert.All(hits, h => Assert.True(h.BodyIndexed));
        Assert.Empty(await _downloader.RunPassAsync(_server)); // niente da rifare
    }

    [Fact]
    public async Task FileSparitoPrimaDellIndicizzazioneVieneScollegato()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent);
        await FolderSynchronizer.SyncAsync(inbox, _cache);
        var folder = _cache.FindFolder("INBOX")!;
        _cache.SetBody(folder.Id, 1, new string('d', 64)); // file inesistente

        await _downloader.RunPassAsync(_server);

        Assert.Empty(inbox.Downloads); // al giro dopo verrà riscaricato
        Assert.Null(_cache.GetBodyRow(folder.Id, 1)!.Sha256);
        await _downloader.RunPassAsync(_server);
        Assert.Equal([1u], inbox.Downloads);
    }

    // ---------------------------------------------------------------------------------------------
    // Ricerca sul server
    // ---------------------------------------------------------------------------------------------

    [Fact]
    public async Task RicercaSulServerSoloPerLeMailSenzaCorpoNellIndice()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent); // corpo scaricato e indicizzato: la ricerca locale lo ha già visto tutto
        inbox.Add(2, Old);    // fuori dal limite: solo intestazioni in locale
        var trash = _server.Add("Posta eliminata", "trash");
        trash.Add(5, Recent); // cestino: solo intestazioni
        await _downloader.RunPassAsync(_server);

        var (rows, skipped) = await ServerSearch.RunAsync(_server, _cache, MailSearchQuery.Parse("corpo"), null);

        Assert.Equal([("INBOX", 2u), ("Posta eliminata", 5u)], rows.Select(r => (r.Folder, r.Uid)).OrderBy(r => r.Item1));
        Assert.Empty(skipped);
        Assert.Equal(5u, rows[0].Uid); // dal più recente
    }

    [Fact]
    public async Task RicercaSulServerInUnaCartellaSincronizzaPrimaLeIntestazioni()
    {
        var inbox = _server.Add("INBOX", "inbox");
        var other = _server.Add("Archivio");
        other.Add(3, Old);
        inbox.Add(9, Old); // mai sincronizzata: dopo la ricerca ha intestazione e risultato

        var (rows, _) = await ServerSearch.RunAsync(_server, _cache, MailSearchQuery.Parse("corpo 9"), "INBOX");

        Assert.Equal([9u], rows.Select(r => r.Uid));
        Assert.Equal("Oggetto 9", rows.Single().Subject);
        Assert.Equal(0, other.Searches);
    }

    [Fact]
    public async Task AllegatiSulServerStrutturaSoloPerLeMailSenzaCorpoESalvata()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent); // corpo in cache: allegati già noti in locale
        inbox.Add(2, Old);
        inbox.Add(3, Old);
        inbox.WithAttachments.Add(2);
        // Senza il passaggio in background: struttura chiesta dalla ricerca, solo per le mail senza corpo.
        await FolderSynchronizer.SyncAsync(inbox, _cache);
        var folder = _cache.FindFolder("INBOX")!;
        _cache.SetBody(folder.Id, 1, await _cache.Bodies.SaveAsync(new MemoryStream(inbox.Messages[1].Content)),
            new SearchText("corpo", []));

        var (rows, _) = await ServerSearch.RunAsync(_server, _cache, MailSearchQuery.Parse("allegati:sì"), null);

        Assert.Equal([2u], rows.Select(r => r.Uid));
        Assert.Equal([2u, 3u], inbox.StructureFetches.Order()); // non l'1
        inbox.StructureFetches.Clear();
        await ServerSearch.RunAsync(_server, _cache, MailSearchQuery.Parse("allegati:no"), null);
        Assert.Empty(inbox.StructureFetches); // già salvata
        // Anche la ricerca locale ora sa che il 2 ha allegati e il 3 no.
        Assert.Contains(2u, _cache.Search(MailSearchQuery.Parse("allegati:sì"), null, 0, 10).Items.Select(i => i.Uid));
        Assert.Contains(3u, _cache.Search(MailSearchQuery.Parse("allegati:no"), null, 0, 10).Items.Select(i => i.Uid));
    }

    // ---------------------------------------------------------------------------------------------
    // Anteprime (3.2)
    // ---------------------------------------------------------------------------------------------

    [Fact]
    public async Task AnteprimeDalCorpoInCacheODalServerPerLeAltre()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent); // scaricata: anteprima dal suo testo, senza rete
        inbox.Add(2, Old);    // fuori dal limite: anteprima dal server
        inbox.WithAttachments.Add(2);

        await _downloader.RunPassAsync(_server);

        var page = _cache.GetPage(_cache.FindFolder("INBOX")!.Id, 0, 10).Items.ToDictionary(i => i.Uid);
        Assert.Equal("Corpo 1", page[1].Preview);
        Assert.Equal("Anteprima 2", page[2].Preview);
        Assert.True(page[2].HasAttachments);
        Assert.Equal([2u], inbox.PreviewFetches);

        inbox.PreviewFetches.Clear();
        await _downloader.RunPassAsync(_server);
        Assert.Empty(inbox.PreviewFetches); // già tutte note
    }

    [Fact]
    public async Task CorpiIndicizzatiPrimaDellAnteprimaLaRicavanoDallIndice()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent);
        await FolderSynchronizer.SyncAsync(inbox, _cache);
        var folder = _cache.FindFolder("INBOX")!;
        // Come una cache dell'8c: corpo indicizzato, anteprima mai scritta.
        _cache.SetBody(folder.Id, 1, await _cache.Bodies.SaveAsync(new MemoryStream(inbox.Messages[1].Content)),
            new SearchText("Testo   salvato\r\nnell'indice", []));
        using (var db = new SqliteConnection($"Data Source={_cache.Path}"))
        {
            db.Open();
            using var cmd = db.CreateCommand();
            cmd.CommandText = "UPDATE messages SET preview = NULL";
            cmd.ExecuteNonQuery();
        }

        await _downloader.RunPassAsync(_server);

        Assert.Equal("Testo salvato nell'indice", _cache.GetPage(folder.Id, 0, 10).Items.Single().Preview);
        Assert.Empty(inbox.PreviewFetches); // senza chiedere nulla al server
    }

    [Fact]
    public async Task RicercaSulServerSaltaLeCartelleNonApribili()
    {
        _server.Add("Rotta").FailWith = new InvalidOperationException("NO Insufficient rights");
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(2, Old);

        var (rows, skipped) = await ServerSearch.RunAsync(_server, _cache, MailSearchQuery.Parse("corpo"), null);

        Assert.Equal([2u], rows.Select(r => r.Uid));
        Assert.Equal(["Rotta"], skipped);
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            ServerSearch.RunAsync(_server, _cache, MailSearchQuery.Parse("corpo"), "Rotta")); // cartella chiesta: errore
    }

    [Fact]
    public async Task BloccoPerCartellaUnaSincronizzazioneAllaVolta()
    {
        var first = await _cache.LockFolderAsync("INBOX");
        var second = _cache.LockFolderAsync("INBOX");
        var other = _cache.LockFolderAsync("Archivio");

        Assert.False(second.IsCompleted);
        Assert.True(other.IsCompleted); // cartelle diverse non si bloccano
        first.Dispose();
        first.Dispose(); // doppio rilascio innocuo
        (await second).Dispose();
        (await other).Dispose();
    }

    [Fact]
    public async Task PassaggioRiempieReferencesUnaVoltaERicalcolaLeConversazioni()
    {
        var inbox = _server.Add("INBOX", "inbox");
        var sent = _server.Add("Posta inviata", "sent");
        inbox.Add(1, Recent);
        sent.Add(5, Recent.AddHours(1));
        // Intestazioni come salvate prima dello schema 7: References non ancora nota (null).
        inbox.Messages[1] = (inbox.Messages[1].Header with { MessageId = "domanda@x" }, inbox.Messages[1].Content);
        sent.Messages[5] = (sent.Messages[5].Header with { MessageId = "risposta@x" }, sent.Messages[5].Content);
        sent.References[5] = "domanda@x";

        await _downloader.RunPassAsync(_server);
        await _downloader.RunPassAsync(_server);

        Assert.Equal([1u], inbox.ReferenceFetches); // una volta sola: poi è nota
        Assert.Equal([5u], sent.ReferenceFetches);
        var (_, conversations) = _cache.GetConversations(_cache.FindFolder("INBOX")!, 0, 10);
        Assert.Equal(["Posta inviata:5", "INBOX:1"], conversations.Single().Messages.Select(m => $"{m.Folder}:{m.Header.Uid}"));
        Assert.Contains(_log, l => l.Contains("conversazioni ricalcolate"));
    }

    [Fact]
    public async Task PassaggioLeggeLImportanzaUnaVoltaSola()
    {
        var inbox = _server.Add("INBOX", "inbox");
        inbox.Add(1, Recent);
        inbox.Add(2, Recent.AddHours(1));
        inbox.Importance[2] = MailImportance.High; // intestazioni salvate prima dell'importanza (null)

        await _downloader.RunPassAsync(_server);
        await _downloader.RunPassAsync(_server);

        Assert.Equal([2u, 1u], inbox.ImportanceFetches); // dal più recente, una volta sola
        var page = _cache.GetPage(_cache.FindFolder("INBOX")!.Id, 0, 10).Items.ToDictionary(r => r.Uid, r => r.Importance);
        Assert.Equal(MailImportance.High, page[2]);
        Assert.Equal(MailImportance.Normal, page[1]);
        Assert.Contains(_log, l => l.Contains("2 importanze lette"));
    }
}
