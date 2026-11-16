using System.Security.Cryptography;

namespace PostinoVip.Core.Cache;

/// <summary>
/// I messaggi grezzi (.eml) di un account, uno per file, nominati con lo SHA-256 del contenuto:
/// <c>bodies/ab/cd/abcd….eml</c>. Un file non cambia mai (stesso nome = stesso contenuto): due copie
/// dello stesso messaggio in cartelle diverse occupano un solo file, e l'impronta permette di
/// riconoscere un file danneggiato.
/// Salvataggio atomico: file temporaneo in <c>bodies/tmp</c>, scritto sul disco (fsync), poi rinominato.
/// Un'interruzione lascia al massimo un temporaneo o un file non ancora collegato al database:
/// li elimina la pulizia (<see cref="DeleteUnreferenced"/>).
/// </summary>
public sealed class BodyStore(string root)
{
    private const string Extension = ".eml";
    private const string TempExtension = ".tmp";

    public string Root { get; } = root;

    private string TempDirectory => Path.Combine(Root, "tmp");

    /// <summary>Salva il contenuto e ne restituisce l'impronta (64 caratteri esadecimali minuscoli).</summary>
    public async Task<string> SaveAsync(Stream content, CancellationToken ct = default)
    {
        // Ogni livello creato a parte: CreateDirectory applica i permessi solo all'ultima cartella.
        CachePermissions.CreatePrivateDirectory(Root);
        CachePermissions.CreatePrivateDirectory(TempDirectory);
        var temp = Path.Combine(TempDirectory, Guid.NewGuid().ToString("N") + TempExtension);
        try
        {
            string sha256;
            using (var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256))
            await using (var file = new FileStream(temp, PrivateCreateOptions()))
            {
                var buffer = new byte[81920];
                int read;
                while ((read = await content.ReadAsync(buffer, ct)) > 0)
                {
                    hash.AppendData(buffer, 0, read);
                    await file.WriteAsync(buffer.AsMemory(0, read), ct);
                }
                await file.FlushAsync(ct);
                file.Flush(flushToDisk: true); // fsync: il contenuto è sul disco prima del rename
                sha256 = Convert.ToHexStringLower(hash.GetHashAndReset());
            }

            var target = PathFor(sha256);
            var level2 = Path.GetDirectoryName(target)!;
            CachePermissions.CreatePrivateDirectory(Path.GetDirectoryName(level2)!);
            CachePermissions.CreatePrivateDirectory(level2);
            // Sempre sovrascritto, anche se esiste già: il file ha così una data recente e la pulizia
            // (margine sulla data) non lo considera vecchio prima che venga collegato alla sua riga.
            File.Move(temp, target, overwrite: true);
            return sha256;
        }
        catch
        {
            TryDelete(temp);
            throw;
        }
    }

    /// <summary>Contenuto del file, solo se esiste e l'impronta corrisponde; altrimenti null (va riscaricato).</summary>
    public byte[]? TryRead(string sha256)
    {
        byte[] bytes;
        try
        {
            bytes = File.ReadAllBytes(PathFor(sha256));
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException)
        {
            return null;
        }
        return Convert.ToHexStringLower(SHA256.HashData(bytes)) == sha256 ? bytes : null;
    }

    public string PathFor(string sha256)
    {
        // L'impronta arriva dal database: controllata comunque, finisce in un percorso.
        if (!IsSha256(sha256))
            throw new ArgumentException("Impronta SHA-256 non valida.", nameof(sha256)).WithCode("improntaSha256NonValida");
        return Path.Combine(Root, sha256[..2], sha256[2..4], sha256 + Extension);
    }

    public static bool IsSha256(string s) => s.Length == 64 && s.All(char.IsAsciiHexDigitLower);

    /// <summary>
    /// Elimina i file .eml non collegati al database e i temporanei rimasti, se modificati prima di
    /// <paramref name="olderThan"/>: il margine protegge un file appena salvato e non ancora collegato
    /// alla sua riga. Nel caso raro in cui un salvataggio sovrascriva un file proprio mentre la pulizia lo
    /// elimina, il file risulta mancante alla lettura e viene riscaricato.
    /// </summary>
    public (int Files, long Bytes) DeleteUnreferenced(IReadOnlySet<string> referenced, DateTimeOffset olderThan)
    {
        if (!Directory.Exists(Root))
            return (0, 0);

        var files = 0;
        long bytes = 0;
        foreach (var file in new DirectoryInfo(Root).EnumerateFiles("*", SearchOption.AllDirectories))
        {
            if (file.Extension is not (Extension or TempExtension))
                continue; // non creato da noi: non si tocca
            if (file.Extension == Extension && referenced.Contains(Path.GetFileNameWithoutExtension(file.Name)))
                continue;
            if (file.LastWriteTimeUtc > olderThan.UtcDateTime)
                continue;

            var length = file.Length;
            if (TryDelete(file.FullName))
            {
                files++;
                bytes += length;
            }
        }
        return (files, bytes);
    }

    private static FileStreamOptions PrivateCreateOptions()
    {
        var options = new FileStreamOptions { Mode = FileMode.CreateNew, Access = FileAccess.Write };
        if (!OperatingSystem.IsWindows())
            options.UnixCreateMode = CachePermissions.PrivateFile; // mai leggibile da altri, nemmeno per un istante
        return options;
    }

    private static bool TryDelete(string path)
    {
        try
        {
            File.Delete(path);
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }
}
