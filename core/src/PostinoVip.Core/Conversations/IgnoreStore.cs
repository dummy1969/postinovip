using System.Text.Json;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Conversations;

/// <summary>Conversazioni ignorate di un account: i loro Message-ID (senza parentesi angolari), dal più vecchio.</summary>
public sealed record IgnoreSettings
{
    public IReadOnlyList<string> MessageIds { get; init; } = [];
}

/// <summary>Fin dove il filtro delle conversazioni ignorate ha guardato la Posta in arrivo.</summary>
public sealed record IgnoreProgress(uint? UidValidity, uint LastUid);

/// <summary>
/// Conversazioni ignorate di un account in <c>accounts/{id}/ignore.json</c> e avanzamento del filtro in
/// <c>ignore-state.json</c>. Scrittura atomica (temporaneo, fsync, rinomina), file 0600, come la posta
/// indesiderata. Oltre <see cref="MaxIds"/> Message-ID si dimenticano i più vecchi.
/// </summary>
public sealed class IgnoreStore(string directory)
{
    public const int MaxIds = 20000;

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { WriteIndented = true };
    private readonly Lock _lock = new();

    public string SettingsPath { get; } = Path.Combine(directory, "ignore.json");
    public string StatePath { get; } = Path.Combine(directory, "ignore-state.json");

    /// <summary>I Message-ID delle conversazioni ignorate.</summary>
    public HashSet<string> Load()
    {
        lock (_lock)
            return (Read<IgnoreSettings>(SettingsPath)?.MessageIds ?? []).ToHashSet(StringComparer.Ordinal);
    }

    /// <summary>Aggiunge Message-ID (già ripuliti); restituisce quanti erano nuovi.</summary>
    public int Add(IEnumerable<string> ids)
    {
        lock (_lock)
        {
            var list = (Read<IgnoreSettings>(SettingsPath)?.MessageIds ?? []).ToList();
            var known = list.ToHashSet(StringComparer.Ordinal);
            var added = 0;
            foreach (var id in ids)
                if (Valid(id) && known.Add(id))
                {
                    list.Add(id);
                    added++;
                }
            if (added == 0)
                return 0;
            if (list.Count > MaxIds)
                list.RemoveRange(0, list.Count - MaxIds);
            Write(SettingsPath, new IgnoreSettings { MessageIds = list });
            return added;
        }
    }

    /// <summary>Toglie Message-ID; restituisce quanti c'erano.</summary>
    public int Remove(IEnumerable<string> ids)
    {
        lock (_lock)
        {
            var remove = ids.ToHashSet(StringComparer.Ordinal);
            var list = (Read<IgnoreSettings>(SettingsPath)?.MessageIds ?? []).ToList();
            var removed = list.RemoveAll(remove.Contains);
            if (removed > 0)
                Write(SettingsPath, new IgnoreSettings { MessageIds = list });
            return removed;
        }
    }

    public IgnoreProgress? LoadProgress()
    {
        lock (_lock)
            return Read<IgnoreProgress>(StatePath);
    }

    public void SaveProgress(IgnoreProgress progress)
    {
        lock (_lock)
            Write(StatePath, progress);
    }

    private static bool Valid(string? id) => id is { Length: > 0 and <= 1000 } && !id.Any(char.IsControl);

    private static T? Read<T>(string path) where T : class
    {
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<T>(stream, Json);
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException or JsonException)
        {
            return null; // assente (niente ignorato) o rovinato
        }
    }

    private static void Write<T>(string path, T value)
    {
        CachePermissions.CreatePrivateDirectory(Path.GetDirectoryName(path)!);
        var temp = path + ".tmp";
        CachePermissions.CreatePrivateFile(temp);
        using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
        {
            JsonSerializer.Serialize(file, value, Json);
            file.Flush(flushToDisk: true);
        }
        File.Move(temp, path, overwrite: true);
    }
}
