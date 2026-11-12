using System.Text.Json;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Archive;

/// <summary>Scelta dell'utente per Archivia (A1, 1a): la cartella di archiviazione; null = non ancora scelta.</summary>
public sealed record ArchiveSettings
{
    public string? Folder { get; init; }
}

/// <summary>
/// Cartella di archiviazione di un account in <c>accounts/{id}/archive.json</c> (2a: per account, nel core).
/// Scrittura atomica (temporaneo, fsync, rinomina), file 0600, come la posta indesiderata.
/// </summary>
public sealed class ArchiveStore(string directory)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { WriteIndented = true };
    private readonly Lock _lock = new();

    public string SettingsPath { get; } = Path.Combine(directory, "archive.json");

    public ArchiveSettings Load()
    {
        lock (_lock)
        {
            try
            {
                using var stream = File.OpenRead(SettingsPath);
                return JsonSerializer.Deserialize<ArchiveSettings>(stream, Json) ?? new ArchiveSettings();
            }
            catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException or JsonException)
            {
                return new ArchiveSettings(); // assente (non ancora scelta) o rovinato
            }
        }
    }

    /// <summary>Controlla e salva la scelta; restituisce quella salvata (ripulita). Chi chiama controlla che la cartella esista.</summary>
    public ArchiveSettings Save(ArchiveSettings settings)
    {
        var clean = Validate(settings);
        lock (_lock)
        {
            CachePermissions.CreatePrivateDirectory(Path.GetDirectoryName(SettingsPath)!);
            var temp = SettingsPath + ".tmp";
            CachePermissions.CreatePrivateFile(temp);
            using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
            {
                JsonSerializer.Serialize(file, clean, Json);
                file.Flush(flushToDisk: true);
            }
            File.Move(temp, SettingsPath, overwrite: true);
        }
        return clean;
    }

    public static ArchiveSettings Validate(ArchiveSettings s)
    {
        var folder = string.IsNullOrWhiteSpace(s.Folder) ? null : s.Folder;
        if (folder is { Length: > 1000 } || folder?.Any(char.IsControl) == true)
            throw new FieldValidationException("folder", "Cartella non valida.");
        return s with { Folder = folder };
    }
}
