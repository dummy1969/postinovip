using Microsoft.Data.Sqlite;
using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Models;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Tests;

public sealed class CacheAccountsTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "postinovip-test-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_root))
            Directory.Delete(_root, recursive: true);
    }

    private static MailAccountSettings Settings(string id, string address, string name = "") => new()
    {
        Id = id,
        Name = name,
        Imap = new ImapSettings { Host = "imap.example.com", Username = address, Password = "segreta" },
        Smtp = new SmtpSettings { Host = "smtp.example.com", Username = address, Password = "segreta" },
    };

    private string Dir(string id) => MailAccountRegistry.CacheDirectory(_root, id);

    /// <summary>Cartella di un account con qualche file (database e corpi).</summary>
    private void Fill(string id, string? address, int bytes = 1000)
    {
        if (address is not null)
            CacheAccounts.WriteInfo(_root, Settings(id, address));
        Directory.CreateDirectory(Path.Combine(Dir(id), "bodies", "ab", "cd"));
        File.WriteAllBytes(Path.Combine(Dir(id), "bodies", "ab", "cd", "x.eml"), new byte[bytes]);
    }

    [Fact]
    public async Task IlRegistroScriveDiChiSonoIDatiMaiLaPassword()
    {
        await using var registry = MailAccountRegistry.CreateImap([Settings("a1", "io@example.com", "Personale")], _root);

        var path = Path.Combine(Dir("a1"), CacheAccounts.InfoFileName);
        var json = File.ReadAllText(path);
        Assert.Contains("io@example.com", json);
        Assert.Contains("Personale", json);
        Assert.DoesNotContain("segreta", json);
        if (!OperatingSystem.IsWindows())
            Assert.Equal(CachePermissions.PrivateFile, File.GetUnixFileMode(path));
    }

    [Fact]
    public void SoloGliAccountNonConfigurati()
    {
        Fill("a1", "io@example.com");
        Fill("b2", "vecchio@example.com", 5000);
        Fill("main", address: null, 300); // cartella precedente ad account.json

        var orphans = CacheAccounts.ListOrphans(_root, ["a1"]);

        Assert.Equal([("main", null, 300L), ("b2", "vecchio@example.com", 5000L + new FileInfo(Path.Combine(Dir("b2"), "account.json")).Length)],
            orphans.Select(o => (o.Id, o.Address, o.SizeBytes)));
    }

    [Fact]
    public void EliminaSoloSuRichiestaESoloSeNonConfigurato()
    {
        Fill("a1", "io@example.com");
        Fill("b2", "vecchio@example.com");

        Assert.Throws<InvalidOperationException>(() => CacheAccounts.DeleteOrphan(_root, "a1", ["a1"]));
        CacheAccounts.DeleteOrphan(_root, "b2", ["a1"]);

        Assert.True(Directory.Exists(Dir("a1")));
        Assert.False(Directory.Exists(Dir("b2")));
        Assert.Throws<MailNotFoundException>(() => CacheAccounts.DeleteOrphan(_root, "b2", ["a1"])); // già eliminati
    }

    [Theory]
    [InlineData("..")]
    [InlineData("../accounts")]
    [InlineData("a/b")]
    [InlineData("")]
    public void IdNonValidiMaiUsatiComePercorso(string id)
    {
        Fill("a1", "io@example.com");

        Assert.Throws<MailNotFoundException>(() => CacheAccounts.DeleteOrphan(_root, id, []));

        Assert.True(Directory.Exists(Dir("a1")));
    }

    [Fact]
    public void CollegamentoSimbolicoNonSeguito()
    {
        if (OperatingSystem.IsWindows())
            return;
        var outside = Path.Combine(_root, "fuori");
        Directory.CreateDirectory(outside);
        File.WriteAllText(Path.Combine(outside, "importante.txt"), "da non cancellare");
        Directory.CreateDirectory(Path.Combine(_root, "accounts"));
        Directory.CreateSymbolicLink(Dir("link"), outside);

        Assert.DoesNotContain(CacheAccounts.ListOrphans(_root, []), o => o.Id == "link");
        Assert.Throws<MailNotFoundException>(() => CacheAccounts.DeleteOrphan(_root, "link", []));
        Assert.True(File.Exists(Path.Combine(outside, "importante.txt")));
    }

    [Fact]
    public async Task RicostruisciSvuotaDatabaseECorpiERestaUsabile()
    {
        var cache = new AccountCache(Dir("a1"));
        cache.SetFolderInfo([new MailFolderInfo("INBOX", "INBOX", 1, "inbox")]);
        var inbox = cache.FindFolder("INBOX")!;
        var when = DateTimeOffset.UtcNow;
        cache.UpsertHeaders(inbox.Id, [new HeaderRecord(1, MailFlags.None, "x", null, "a@example.com", null, null, when, when, 1, null, null)]);
        cache.SetBody(inbox.Id, 1, await cache.Bodies.SaveAsync(new MemoryStream("Subject: x\r\n\r\ny"u8.ToArray())));
        CacheAccounts.WriteInfo(_root, Settings("a1", "io@example.com"));

        cache.Reset();

        Assert.Null(cache.FindFolder("INBOX")); // database nuovo e vuoto
        Assert.False(Directory.Exists(cache.Bodies.Root));
        Assert.True(File.Exists(Path.Combine(Dir("a1"), CacheAccounts.InfoFileName))); // si sa ancora di chi è
        Assert.Contains("ricostruita", cache.TakeInitializeNote());
        cache.SetFolderInfo([new MailFolderInfo("INBOX", "INBOX", 0, "inbox")]);
        Assert.NotNull(cache.FindFolder("INBOX"));
    }
}
