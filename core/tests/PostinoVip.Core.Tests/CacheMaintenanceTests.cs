using Microsoft.Data.Sqlite;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

public sealed class CacheMaintenanceTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-test-" + Guid.NewGuid().ToString("N"));
    private string AccountDir => Path.Combine(_dir, "accounts", "main");

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private static readonly DateTimeOffset When = new(2026, 10, 1, 9, 0, 0, TimeSpan.FromHours(2));

    /// <summary>Cache con <paramref name="count"/> intestazioni in INBOX (con oggetti lunghi: più pagine).</summary>
    private AccountCache Filled(int count)
    {
        var cache = new AccountCache(AccountDir);
        cache.SetFolderInfo([new MailFolderInfo("INBOX", "INBOX", count, "inbox")]);
        var inbox = cache.FindFolder("INBOX")!;
        cache.UpsertHeaders(inbox.Id, Enumerable.Range(1, count)
            .Select(i => new HeaderRecord((uint)i, MailFlags.None, $"Oggetto {i} " + new string('x', 300), null,
                "anna@example.com", null, null, When, When, 100, null, null))
            .ToList());
        return cache;
    }

    private IReadOnlyList<string> Quarantined() =>
        Directory.EnumerateFiles(AccountDir, AccountCache.FileName + AccountCache.QuarantineInfix + "*")
            .Select(Path.GetFileName).Order().ToList()!;

    /// <summary>Chiude tutte le connessioni: SQLite riporta il WAL nel file principale.</summary>
    private static void CloseAll() => SqliteConnection.ClearAllPools();

    private static object? Scalar(string path, string sql)
    {
        using var db = new SqliteConnection($"Data Source={path};Pooling=False");
        db.Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = sql;
        return cmd.ExecuteScalar();
    }

    [Fact]
    public void FileNonDatabaseMessoDaParteECacheRicreata()
    {
        Directory.CreateDirectory(AccountDir);
        File.WriteAllText(Path.Combine(AccountDir, AccountCache.FileName), "questo non è un database SQLite, " + new string('!', 200));

        var cache = new AccountCache(AccountDir);
        var folders = cache.GetFolderList(); // la prima apertura controlla e ricrea

        Assert.Empty(folders);
        var moved = Assert.Single(Quarantined());
        Assert.Matches(@"^index\.db\.rovinato-\d{8}-\d{6}$", moved);
        Assert.StartsWith("questo non è", File.ReadAllText(Path.Combine(AccountDir, moved)));
        Assert.Contains("rovinato", cache.TakeInitializeNote());
        Assert.Equal((long)AccountCache.SchemaVersion, Scalar(cache.Path, "PRAGMA user_version"));
        // Nessuna connessione rimasta aperta sul file messo da parte: su Windows il rename fallirebbe.
        Assert.Equal(0, OpenHandles(Path.Combine(AccountDir, moved)));
    }

    /// <summary>File aperti da questo processo che puntano a <paramref name="path"/> (solo Linux: /proc/self/fd).</summary>
    private static int OpenHandles(string path) =>
        Directory.Exists("/proc/self/fd")
            ? new DirectoryInfo("/proc/self/fd").EnumerateFileSystemInfos().Count(f => f.LinkTarget == path)
            : 0;

    [Fact]
    public void PaginaRovinataTrovataDalControlloPeriodico()
    {
        var cache = Filled(400);
        Assert.Null(cache.CheckIntegrity()); // integro: nulla da fare
        CloseAll();

        // Rovina il contenuto di alcune pagine interne (non l'intestazione del file).
        using (var f = new FileStream(cache.Path, FileMode.Open, FileAccess.Write))
        {
            var pageSize = 4096;
            f.Position = pageSize * 3;
            f.Write(Enumerable.Repeat((byte)0xAB, pageSize * 4).ToArray());
        }

        var note = cache.CheckIntegrity();

        Assert.NotNull(note);
        Assert.Contains("rovinato", note);
        Assert.Single(Quarantined());
        Assert.Null(cache.FindFolder("INBOX")); // ricreata vuota: si riempirà dal server
        Assert.Null(cache.CheckIntegrity());
    }

    [Fact]
    public void SiTieneSoloLUltimoDatabaseRovinato()
    {
        Directory.CreateDirectory(AccountDir);
        var old = Path.Combine(AccountDir, AccountCache.FileName + AccountCache.QuarantineInfix + "20260101-000000");
        File.WriteAllText(old, "vecchio");
        File.WriteAllText(Path.Combine(AccountDir, AccountCache.FileName), new string('?', 500));

        new AccountCache(AccountDir).GetFolderList();

        Assert.False(File.Exists(old));
        Assert.Single(Quarantined());
    }

    [Fact]
    public void RecuperoIncrementaleAttivoEDavveroUsato()
    {
        var cache = Filled(600);
        Assert.Equal(2L, Scalar(cache.Path, "PRAGMA auto_vacuum")); // INCREMENTAL

        cache.DeleteMessages(cache.FindFolder("INBOX")!.Id, Enumerable.Range(1, 600).Select(i => (uint)i).ToList());
        // Pagine del database secondo SQLite (non la dimensione dei file: il -wal può sparire quando
        // altri test chiudono tutte le connessioni).
        var before = Convert.ToInt64(Scalar(cache.Path, "PRAGMA page_count"));
        Assert.True(Convert.ToInt64(Scalar(cache.Path, "PRAGMA freelist_count")) > 0);

        var freed = cache.ReclaimSpace();

        Assert.True(freed > 0);
        Assert.Equal(0L, Scalar(cache.Path, "PRAGMA freelist_count"));
        Assert.True(Convert.ToInt64(Scalar(cache.Path, "PRAGMA page_count")) < before);
        Assert.Equal(0, cache.ReclaimSpace()); // niente altro da restituire
    }

    [Fact]
    public void DatabaseEsistenteSenzaRecuperoVieneConvertitoUnaVolta()
    {
        // Come i database creati fino all'8d: auto_vacuum = NONE.
        Directory.CreateDirectory(AccountDir);
        var path = Path.Combine(AccountDir, AccountCache.FileName);
        Scalar(path, "CREATE TABLE prova(x); PRAGMA user_version = 0;");
        Assert.Equal(0L, Scalar(path, "PRAGMA auto_vacuum"));

        var cache = new AccountCache(AccountDir);
        cache.GetFolderList();

        Assert.Equal(2L, Scalar(path, "PRAGMA auto_vacuum"));
        Assert.Empty(Quarantined());
        Assert.Null(cache.TakeInitializeNote());
    }
}
