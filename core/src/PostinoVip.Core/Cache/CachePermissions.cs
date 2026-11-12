namespace PostinoVip.Core.Cache;

/// <summary>
/// Permessi dei file della cache su Linux e macOS: cartelle 0700 e file 0600, leggibili solo
/// dall'utente (la cache contiene la posta, senza cifratura applicativa). Su Windows valgono le
/// autorizzazioni predefinite del profilo utente (%LOCALAPPDATA%).
/// </summary>
public static class CachePermissions
{
    public const UnixFileMode PrivateDirectory = UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute;
    public const UnixFileMode PrivateFile = UnixFileMode.UserRead | UnixFileMode.UserWrite;

    /// <summary>Crea la cartella (e quelle mancanti sopra) e la rende privata.</summary>
    public static void CreatePrivateDirectory(string path)
    {
        if (OperatingSystem.IsWindows())
        {
            Directory.CreateDirectory(path);
            return;
        }
        Directory.CreateDirectory(path, PrivateDirectory);
        // CreateDirectory non cambia i permessi di una cartella già esistente.
        File.SetUnixFileMode(path, PrivateDirectory);
    }

    /// <summary>Crea un file vuoto già privato (prima che SQLite lo apra: i file -wal e -shm ne copiano i permessi).</summary>
    public static void CreatePrivateFile(string path)
    {
        if (OperatingSystem.IsWindows())
        {
            File.Create(path).Dispose();
            return;
        }
        // Permessi decisi alla creazione: il file non è mai leggibile da altri, nemmeno per un istante.
        new FileStream(path, new FileStreamOptions { Mode = FileMode.Create, Access = FileAccess.Write, UnixCreateMode = PrivateFile })
            .Dispose();
        File.SetUnixFileMode(path, PrivateFile); // anche se il file esisteva già
    }
}
