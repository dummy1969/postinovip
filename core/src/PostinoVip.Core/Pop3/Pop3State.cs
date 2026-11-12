using System.Text.Json;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Pop3;

/// <summary>Una mail del server POP3 già scaricata: quando, e se va tolta dal server alla prossima connessione.</summary>
public sealed record Pop3Entry(DateTimeOffset Downloaded, bool Remove = false);

/// <summary>
/// Le mail del server già scaricate, per UIDL (identificativo stabile del server POP3), in
/// <c>accounts/{id}/pop3.json</c> (scrittura atomica, 0600). Grazie a questo, con "Lascia una copia sul
/// server" una mail non si scarica due volte; le voci delle mail non più sul server vengono dimenticate.
/// Se si perde il file, alla connessione successiva si riscarica tutto ciò che è ancora sul server (doppioni,
/// mai mail perse).
/// </summary>
public sealed class Pop3State(string path)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private readonly Lock _lock = new();
    private Dictionary<string, Pop3Entry>? _entries;

    public string Path { get; } = path;

    public IReadOnlyDictionary<string, Pop3Entry> Entries
    {
        get
        {
            lock (_lock)
                return new Dictionary<string, Pop3Entry>(Load());
        }
    }

    public bool Contains(string uidl)
    {
        lock (_lock)
            return Load().ContainsKey(uidl);
    }

    public void MarkDownloaded(string uidl, DateTimeOffset when) => Update(e => e[uidl] = new Pop3Entry(when));

    /// <summary>La mail va tolta dal server alla prossima connessione ("Rimuovi quando eliminata da Posta eliminata").</summary>
    public void RequestRemoval(string uidl) => Update(e =>
    {
        if (e.TryGetValue(uidl, out var entry))
            e[uidl] = entry with { Remove = true };
    });

    /// <summary>Dimentica le voci indicate (mail tolte dal server, o non più presenti).</summary>
    public void Forget(IEnumerable<string> uidls) => Update(e =>
    {
        foreach (var u in uidls)
            e.Remove(u);
    });

    private void Update(Action<Dictionary<string, Pop3Entry>> change)
    {
        lock (_lock)
        {
            var entries = Load();
            change(entries);
            Save(entries);
        }
    }

    private Dictionary<string, Pop3Entry> Load()
    {
        if (_entries is not null)
            return _entries;
        try
        {
            using var stream = File.OpenRead(Path);
            _entries = JsonSerializer.Deserialize<Dictionary<string, Pop3Entry>>(stream, Json) ?? [];
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException or JsonException)
        {
            _entries = []; // assente o rovinato: si riscarica ciò che è sul server (doppioni, mai perdite)
        }
        return _entries;
    }

    private void Save(Dictionary<string, Pop3Entry> entries)
    {
        CachePermissions.CreatePrivateDirectory(System.IO.Path.GetDirectoryName(Path)!);
        var temp = Path + ".tmp";
        CachePermissions.CreatePrivateFile(temp);
        using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
        {
            JsonSerializer.Serialize(file, entries, Json);
            file.Flush(flushToDisk: true);
        }
        File.Move(temp, Path, overwrite: true);
    }
}
