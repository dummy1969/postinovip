using System.Net;
using System.Net.Sockets;
using System.Text;
using Microsoft.Data.Sqlite;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

/// <summary>
/// Senza rete: una vera ImapConnection verso una porta di 127.0.0.1 su cui non ascolta nessuno
/// (collegamento rifiutato subito), con la cache già riempita come dopo una sessione normale.
/// </summary>
public sealed class OfflineTests : IAsyncLifetime
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-test-" + Guid.NewGuid().ToString("N"));
    private readonly AccountCache _cache;
    private readonly List<bool> _changes = [];
    private readonly ImapConnection _connection;
    private readonly CachedMailReader _reader;

    public OfflineTests()
    {
        _cache = new AccountCache(Path.Combine(_dir, "accounts", "main"));
        var settings = new ImapSettings { Host = "127.0.0.1", Port = ClosedPort(), Username = "io@example.com", Password = "x" };
        _connection = new ImapConnection(settings, onlineChanged: _changes.Add);
        _reader = new CachedMailReader("main", _connection, new ImapMailReader(_connection), _cache,
            new BodyCache("main", _cache, BodyPolicy.Default));
    }

    /// <summary>Una porta libera: aperta e subito chiusa, quindi nessuno ci ascolta.</summary>
    private static int ClosedPort()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        listener.Stop();
        return port;
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync()
    {
        await _connection.DisposeAsync();
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private static readonly DateTimeOffset Recent = DateTimeOffset.UtcNow.AddDays(-2);

    /// <summary>Cache come dopo una sessione con il server: INBOX sincronizzata con due mail, Archivio mai aperta.</summary>
    private long FillCache()
    {
        _cache.SetFolderInfo([
            new MailFolderInfo("INBOX", "INBOX", 2, "inbox"),
            new MailFolderInfo("Lavoro/Archivio", "Archivio", 9),
        ]);
        var inbox = _cache.FindFolder("INBOX")!;
        _cache.UpsertHeaders(inbox.Id, [
            new HeaderRecord(1, MailFlags.Seen, "Prima", null, "anna@example.com", null, null, Recent, Recent, 10, null, null),
            new HeaderRecord(2, MailFlags.None, "Seconda", null, "anna@example.com", null, null, Recent, Recent, 10, null, null),
        ]);
        _cache.MarkSynced(inbox.Id, DateTimeOffset.UtcNow);
        return inbox.Id;
    }

    [Fact]
    public async Task CartelleEListaDallaCopiaLocale()
    {
        FillCache();

        var folders = await _reader.GetFoldersAsync();
        var page = await _reader.GetHeadersAsync("INBOX", 0, 50);

        Assert.Equal([("INBOX", "INBOX", (int?)2, "inbox", (int?)1), ("Lavoro/Archivio", "Archivio", null, null, null)],
            folders.Select(f => (f.FullName, f.Name, f.Count, f.SpecialUse, f.Unread))); // la 1 è letta, la 2 no
        Assert.Equal([2u, 1u], page.Items.Select(m => m.Uid));
        Assert.Equal(2, page.Total);
        Assert.False(_connection.IsOnline);
        Assert.Equal([false], _changes); // avvisato una volta sola
    }

    [Fact]
    public async Task MailInCacheSiApreLeAltreNo()
    {
        var inbox = FillCache();
        var eml = "Subject: Prima\r\nFrom: anna@example.com\r\n\r\nTesto salvato\r\n"u8.ToArray();
        _cache.SetBody(inbox, 1, await _cache.Bodies.SaveAsync(new MemoryStream(eml)));

        _cache.SetFlags(inbox, 1, MailFlags.Seen | MailFlags.Flagged | MailFlags.Category5, new DateOnly(2026, 11, 6));

        var cached = await _reader.GetMessageAsync("INBOX", 1);
        Assert.Equal("Prima", cached.Subject);
        Assert.Equal((true, false, new DateOnly(2026, 11, 6)), (cached.Flagged, cached.Completed, cached.Due)); // dalla cache
        Assert.Equal([5], cached.Categories!);
        Assert.Contains("Testo salvato", cached.TextBody);

        await Assert.ThrowsAsync<MailOfflineException>(() => _reader.GetMessageAsync("INBOX", 2));
    }

    [Fact]
    public async Task CartellaMaiSincronizzataOCacheVuota()
    {
        await Assert.ThrowsAsync<MailOfflineException>(() => _reader.GetFoldersAsync()); // niente da mostrare

        FillCache();
        await Assert.ThrowsAsync<MailOfflineException>(() => _reader.GetHeadersAsync("Lavoro/Archivio", 0, 50));
    }

    [Fact]
    public async Task LaRicercaLocaleFunziona()
    {
        FillCache();

        var result = await _reader.SearchAsync("seconda", null, 0, 10);

        Assert.Equal([2u], result.Items.Select(i => i.Uid));
        await Assert.ThrowsAsync<MailOfflineException>(() => _reader.SearchServerAsync("seconda", null, 0, 10));
    }

    [Fact]
    public async Task PausaDopoIlPrimoErrore()
    {
        FillCache();
        await _reader.GetHeadersAsync("INBOX", 0, 50);

        var watch = System.Diagnostics.Stopwatch.StartNew();
        for (var i = 0; i < 20; i++)
            await _reader.GetHeadersAsync("INBOX", 0, 50);

        Assert.True(watch.Elapsed < TimeSpan.FromSeconds(2), $"20 liste in {watch.Elapsed}"); // nessun nuovo tentativo
        Assert.Equal(0, _connection.ConnectCount);
    }
}
