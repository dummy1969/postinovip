using System.Text;
using Microsoft.Data.Sqlite;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

public sealed class BodyCacheTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-test-" + Guid.NewGuid().ToString("N"));
    private readonly AccountCache _cache;
    private readonly BodyCache _bodies;
    private readonly List<string> _log = [];

    /// <summary>Messaggi "sul server" per (cartella, UID) e numero di download.</summary>
    private readonly Dictionary<(string, uint), byte[]> _server = [];
    private int _downloads;

    public BodyCacheTests()
    {
        _cache = new AccountCache(Path.Combine(_dir, "accounts", "main"));
        _bodies = new BodyCache("main", _cache, BodyPolicy.Default, _log.Add);
    }

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private static byte[] Eml(string subject) => Encoding.UTF8.GetBytes(
        $"From: Anna <anna@example.com>\r\nTo: io@example.com\r\nSubject: {subject}\r\nMessage-ID: <{Guid.NewGuid():N}@example.com>\r\n" +
        "Date: Fri, 30 Oct 2026 09:15:00 +0100\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nCorpo del messaggio\r\n");

    /// <summary>Messaggio sul server e (con <paramref name="inCache"/>) la sua intestazione nella cache.</summary>
    private long Add(uint uid, DateTimeOffset arrived, string folder = "INBOX", string? role = null, bool inCache = true,
        byte[]? content = null)
    {
        _server[(folder, uid)] = content ?? Eml($"Oggetto {uid}");
        _cache.SetFolderInfo([new MailFolderInfo(folder, folder, null, role)]);
        var f = _cache.FindFolder(folder)!;
        if (inCache)
        {
            _cache.UpsertHeaders(f.Id, [new HeaderRecord(uid, MailFlags.None, $"Oggetto {uid}", null, "anna@example.com",
                null, null, arrived, arrived, 100, null, null)]);
        }
        return f.Id;
    }

    private Task<MimeKit.MimeMessage> Open(uint uid, string folder = "INBOX") =>
        _bodies.LoadAsync(folder, uid, async (consume, ct) =>
        {
            _downloads++;
            await consume(new MemoryStream(_server[(folder, uid)]), ct);
        });

    private static DateTimeOffset Recent => DateTimeOffset.UtcNow.AddDays(-3);
    private static DateTimeOffset Old => DateTimeOffset.UtcNow.AddMonths(-13);

    private string StoredSha(long folderId, uint uid) => _cache.GetBodyRow(folderId, uid)!.Sha256!;

    private Task<byte[]> Raw(uint uid, string folder = "INBOX") =>
        _bodies.LoadRawAsync(folder, uid, async (consume, ct) =>
        {
            _downloads++;
            await consume(new MemoryStream(_server[(folder, uid)]), ct);
        });

    [Fact]
    public async Task ByteOriginaliPerSalvaConNomeDalDiscoOScaricati()
    {
        // Con a capo solo LF, come alcuni server: restano tali (byte originali, non riscritti).
        var lf = Encoding.UTF8.GetBytes("From: a@example.com\nSubject: Grezzo\n\nCorpo\n");
        Add(1, Recent, content: lf);
        Assert.Equal(lf, await Raw(1)); // non ancora in cache: scaricata, non salvata
        Assert.Equal(1, _downloads);

        await Open(1); // apertura normale: salvata
        Assert.Equal(2, _downloads);
        Assert.Equal(lf, await Raw(1)); // dal disco
        Assert.Equal(2, _downloads);
    }

    [Fact]
    public async Task PrimaAperturaScaricaESalvaLaSecondaLeggeDalDisco()
    {
        var f = Add(1, Recent);

        var first = await Open(1);
        var second = await Open(1);

        Assert.Equal(1, _downloads);
        Assert.Equal("Oggetto 1", first.Subject);
        Assert.Equal("Oggetto 1", second.Subject);
        var path = _cache.Bodies.PathFor(StoredSha(f, 1));
        Assert.Equal(_server[("INBOX", 1)], File.ReadAllBytes(path)); // byte originali del server
        Assert.Single(_cache.Search(MailSearchQuery.Parse("corpo messaggio"), null, 0, 10).Items); // subito cercabile
        Assert.Matches(@"[0-9a-f]{2}[/\\][0-9a-f]{2}[/\\][0-9a-f]{64}\.eml$", path);
    }

    [Fact]
    public async Task FileDanneggiatoVieneRiscaricato()
    {
        var f = Add(1, Recent);
        await Open(1);
        var path = _cache.Bodies.PathFor(StoredSha(f, 1));
        File.WriteAllText(path, "contenuto rovinato");

        var message = await Open(1);

        Assert.Equal(2, _downloads);
        Assert.Equal("Oggetto 1", message.Subject);
        Assert.Equal(_server[("INBOX", 1)], File.ReadAllBytes(path));
        Assert.Contains(_log, l => l.Contains("mancante o danneggiato"));
    }

    [Fact]
    public async Task FileMancanteVieneRiscaricato()
    {
        var f = Add(1, Recent);
        await Open(1);
        File.Delete(_cache.Bodies.PathFor(StoredSha(f, 1)));

        await Open(1);
        await Open(1);

        Assert.Equal(2, _downloads);
    }

    [Fact]
    public async Task FuoriDalLimiteNonVieneSalvato()
    {
        var f = Add(1, Old);

        var message = await Open(1);
        await Open(1);

        Assert.Equal("Oggetto 1", message.Subject);
        Assert.Equal(2, _downloads);
        Assert.Null(_cache.GetBodyRow(f, 1)!.Sha256);
        Assert.False(Directory.Exists(_cache.Bodies.Root) && Directory.EnumerateFiles(_cache.Bodies.Root, "*.eml", SearchOption.AllDirectories).Any());
    }

    [Theory]
    [InlineData("trash")]
    [InlineData("junk")]
    public async Task CestinoEIndesiderataSoloIntestazioni(string role)
    {
        var f = Add(1, Recent, "Cartella", role);

        await Open(1, "Cartella");

        Assert.Null(_cache.GetBodyRow(f, 1)!.Sha256);
    }

    [Fact]
    public async Task MessaggioNonAncoraInCacheSiApreSenzaSalvarlo()
    {
        Add(1, Recent, inCache: false);

        var message = await Open(1);

        Assert.Equal("Oggetto 1", message.Subject);
        Assert.Empty(_cache.GetReferencedBodies());
    }

    [Fact]
    public async Task StessoContenutoInDueCartelleUnSoloFile()
    {
        var content = Eml("Copia");
        var inbox = Add(1, Recent, content: content);
        var other = Add(7, Recent, "Archivio", content: content);

        await Open(1);
        await Open(7, "Archivio");

        Assert.Equal(StoredSha(inbox, 1), StoredSha(other, 7));
        Assert.Single(Directory.EnumerateFiles(_cache.Bodies.Root, "*.eml", SearchOption.AllDirectories));
    }

    [Fact]
    public async Task PuliziaTogliePrimaLaRigaPoiIlFile()
    {
        var f = Add(1, Recent);
        Add(2, Recent);
        await Open(1);
        await Open(2);
        var path1 = _cache.Bodies.PathFor(StoredSha(f, 1));
        var path2 = _cache.Bodies.PathFor(StoredSha(f, 2));
        _cache.DeleteMessages(f, [1]); // sparito dal server: la sincronizzazione toglie la riga

        var result = _bodies.Sweep(TimeSpan.Zero);

        Assert.Equal(1, result.FilesDeleted);
        Assert.False(File.Exists(path1));
        Assert.True(File.Exists(path2)); // ancora collegato
    }

    [Fact]
    public async Task PuliziaRispettaIlMargine()
    {
        var f = Add(1, Recent);
        await Open(1);
        _cache.DeleteMessages(f, [1]);

        var result = _bodies.Sweep(TimeSpan.FromMinutes(10));

        Assert.Equal(0, result.FilesDeleted); // appena scritto: potrebbe non essere ancora collegato
    }

    [Fact]
    public async Task PuliziaTogliILimiteRidotto()
    {
        var f = Add(1, DateTimeOffset.UtcNow.AddMonths(-5));
        await Open(1); // nel limite di 12 mesi
        var path = _cache.Bodies.PathFor(StoredSha(f, 1));

        var reduced = new BodyCache("main", _cache, new BodyPolicy(3));
        var result = reduced.Sweep(TimeSpan.Zero);

        Assert.Equal(1, result.BodiesDropped);
        Assert.Null(_cache.GetBodyRow(f, 1)!.Sha256);
        Assert.False(File.Exists(path));
    }

    [Fact]
    public async Task PuliziaEliminaITemporaneiRimastiMaNonFileEstranei()
    {
        Add(1, Recent);
        await Open(1);
        var temp = Path.Combine(_cache.Bodies.Root, "tmp", "interrotto.tmp");
        var other = Path.Combine(_cache.Bodies.Root, "LEGGIMI.txt");
        File.WriteAllText(temp, "x");
        File.WriteAllText(other, "x");

        _bodies.Sweep(TimeSpan.Zero);

        Assert.False(File.Exists(temp));
        Assert.True(File.Exists(other));
    }

    [Fact]
    public async Task FilePrivati()
    {
        if (OperatingSystem.IsWindows())
            return;
        var f = Add(1, Recent);
        await Open(1);
        var path = _cache.Bodies.PathFor(StoredSha(f, 1));

        Assert.Equal(CachePermissions.PrivateFile, File.GetUnixFileMode(path));
        Assert.Equal(CachePermissions.PrivateDirectory, File.GetUnixFileMode(Path.GetDirectoryName(path)!));
        Assert.Equal(CachePermissions.PrivateDirectory, File.GetUnixFileMode(Path.GetDirectoryName(Path.GetDirectoryName(path))!));
        Assert.Equal(CachePermissions.PrivateDirectory, File.GetUnixFileMode(_cache.Bodies.Root));
    }

    [Fact]
    public void ImprontaNonValidaRifiutata()
    {
        Assert.Throws<ArgumentException>(() => _cache.Bodies.PathFor("../../etc/passwd"));
        Assert.Throws<ArgumentException>(() => _cache.Bodies.PathFor(new string('A', 64)));
    }

    [Fact]
    public void LimiteDellaRegola()
    {
        var now = new DateTimeOffset(2026, 10, 30, 12, 0, 0, TimeSpan.Zero);
        var policy = new BodyPolicy(12);
        Assert.True(policy.Keeps(null, now.AddMonths(-12), now));
        Assert.False(policy.Keeps(null, now.AddMonths(-12).AddSeconds(-1), now));
        Assert.True(policy.Keeps("inbox", null, now)); // data sconosciuta: conservato
        Assert.False(policy.Keeps("trash", now, now));
        Assert.True(new BodyPolicy(null).Keeps("sent", now.AddYears(-20), now)); // "tutto"
    }

    [Fact]
    public void LimiteDallaConfigurazione()
    {
        Assert.Equal(BodyPolicy.Default, BodyPolicy.FromMonths(null));
        Assert.Equal(12, BodyPolicy.Default.Months);
        Assert.Null(BodyPolicy.FromMonths(0).Months); // 0 = tutte
        Assert.Equal(3, BodyPolicy.FromMonths(3).Months);
        Assert.Throws<ArgumentOutOfRangeException>(() => BodyPolicy.FromMonths(-1));

        var negative = new PostinoVip.Core.Account.MailAccountSettings { Id = "uno", Cache = new() { BodyMonths = -6 } };
        Assert.Throws<ArgumentException>(() => PostinoVip.Core.Account.MailAccountRegistry.Validate([negative]));
    }

    [Fact]
    public void CacheDellaVersione1VieneAggiornataSenzaPerdereDati()
    {
        // Database come lo creava la 0.0.56 (schema 1), con una mail già sincronizzata.
        var dir = Path.Combine(_dir, "accounts", "vecchio");
        Directory.CreateDirectory(dir);
        using (var db = new SqliteConnection($"Data Source={Path.Combine(dir, AccountCache.FileName)}"))
        {
            db.Open();
            using var cmd = db.CreateCommand();
            cmd.CommandText = """
                CREATE TABLE folders (id INTEGER PRIMARY KEY, full_name TEXT NOT NULL UNIQUE, uid_validity INTEGER, synced_at TEXT);
                CREATE TABLE messages (id INTEGER PRIMARY KEY, folder_id INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
                    uid INTEGER NOT NULL, flags INTEGER NOT NULL, subject TEXT, from_name TEXT, from_address TEXT, to_list TEXT,
                    cc_list TEXT, date TEXT, internal_date TEXT, size INTEGER, message_id TEXT, in_reply_to TEXT, UNIQUE (folder_id, uid));
                INSERT INTO folders(id, full_name, uid_validity) VALUES (1, 'INBOX', 5);
                INSERT INTO messages(folder_id, uid, flags, subject) VALUES (1, 42, 1, 'Vecchia');
                PRAGMA user_version = 1;
                """;
            cmd.ExecuteNonQuery();
        }
        SqliteConnection.ClearAllPools();

        var cache = new AccountCache(dir);
        var folder = cache.FindFolder("INBOX")!;

        Assert.Null(folder.Role);
        Assert.Equal(5u, folder.UidValidity);
        Assert.Equal("Vecchia", cache.GetPage(folder.Id, 0, 10).Items.Single().Subject);
        Assert.Null(cache.GetBodyRow(folder.Id, 42)!.Sha256);
        Assert.Null(cache.TakeInitializeNote()); // migrata, non ricreata
    }
}
