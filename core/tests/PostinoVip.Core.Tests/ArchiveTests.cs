using PostinoVip.Core.Archive;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

public sealed class ArchiveTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-archive-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private static MailFolderInfo F(string fullName, string? role = null) =>
        new(fullName, fullName.Split('/')[^1], 0, role);

    [Fact]
    public void PropostaPrimaQuellaDelServerPoiIlNomePoiTuttaLaPosta()
    {
        Assert.Equal("Vecchie", ArchiveFolders.Suggest([F("INBOX", "inbox"), F("Archivio"), F("Vecchie", "archive")]));
        // Il nome: prima quella in cima all'account, senza distinguere maiuscole; non le cartelle con un ruolo.
        Assert.Equal("ARCHIVE", ArchiveFolders.Suggest([F("INBOX/Archivio"), F("ARCHIVE"), F("INBOX/AnniArchiviati")]));
        Assert.Equal("INBOX/Archivio", ArchiveFolders.Suggest([F("INBOX", "inbox"), F("INBOX/Archivio")]));
        Assert.Equal("[Gmail]/Tutti i messaggi", ArchiveFolders.Suggest([F("INBOX", "inbox"), F("[Gmail]/Tutti i messaggi", "all")]));
        Assert.Null(ArchiveFolders.Suggest([F("INBOX", "inbox"), F("Clienti"), F("INBOX/AnniArchiviati")]));
    }

    [Fact]
    public void RuoloSoloSullaCartellaSceltaCheEsisteAncora()
    {
        IReadOnlyList<MailFolderInfo> folders = [F("INBOX", "inbox"), F("Archivio"), F("Server", "archive"), F("Tutta", "all")];
        static string? Role(IReadOnlyList<MailFolderInfo> l, string n) => l.Single(f => f.FullName == n).SpecialUse;

        var none = ArchiveFolders.WithRole(folders, null);
        Assert.Null(Role(none, "Server")); // dichiarata dal server ma non scelta: nessun ruolo (1a)
        var chosen = ArchiveFolders.WithRole(folders, "Archivio");
        Assert.Equal("archive", Role(chosen, "Archivio"));
        Assert.Equal("all", Role(chosen, "Tutta"));
        Assert.Equal("archive", Role(ArchiveFolders.WithRole(folders, "Tutta"), "Tutta"));
        Assert.Null(ArchiveFolders.InUse(folders, "Sparita"));
        Assert.DoesNotContain(ArchiveFolders.WithRole(folders, "Sparita"), f => f.SpecialUse == "archive");
    }

    [Fact]
    public void CartelleCheNonPossonoEssereLArchivio()
    {
        IReadOnlyList<MailFolderInfo> folders = [F("INBOX", "inbox"), F("Inviata", "sent"), F("Bozze", "drafts"),
            F("Cestino", "trash"), F("Spam", "junk"), F("Scarti"), F("Archivio")];
        foreach (var f in new[] { "INBOX", "Inviata", "Bozze", "Cestino", "Spam", "Scarti", "Non esiste" })
            Assert.NotNull(ArchiveFolders.Refusal(folders, f, junkFolder: "Scarti"));
        Assert.Null(ArchiveFolders.Refusal(folders, "Archivio", junkFolder: "Scarti"));
    }

    [Fact]
    public void SceltaSalvataInModoPrivato()
    {
        var store = new ArchiveStore(_dir);
        Assert.Null(store.Load().Folder);
        Assert.Null(store.Save(new ArchiveSettings { Folder = "  " }).Folder);
        store.Save(new ArchiveSettings { Folder = "INBOX/Archivio" });
        Assert.Equal("INBOX/Archivio", new ArchiveStore(_dir).Load().Folder);
        if (!OperatingSystem.IsWindows())
            Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite, File.GetUnixFileMode(store.SettingsPath));
        Assert.Throws<FieldValidationException>(() => store.Save(new ArchiveSettings { Folder = "a\nb" }));
        File.WriteAllText(store.SettingsPath, "{rovinato");
        Assert.Null(store.Load().Folder);
    }
}
