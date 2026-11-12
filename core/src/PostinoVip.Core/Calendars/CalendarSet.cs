using System.Security.Cryptography;
using System.Text.Json;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Calendars;

/// <summary>
/// Un calendario dell'account: id locale, nome mostrato e, se collegato a CalDAV, l'indirizzo sul server.
/// <see cref="ReadOnly"/> (G2, scelta 1a): sul server l'utente non può scriverci (es. le festività di Google): si vede ma
/// non si crea, modifica o elimina niente.
/// </summary>
public sealed record CalendarInfo(string Id, string Name, string? Href, bool ReadOnly = false);

/// <summary>
/// I calendari di un account (K2a, scelta 4a): <c>accounts/&lt;id&gt;/calendars/calendars.json</c> e una cartella per
/// calendario (<see cref="CalendarStore"/>). Ce n'è sempre almeno uno, «Calendario»; con CalDAV ognuno corrisponde a un
/// calendario del server (il primo, quello predefinito, prende il calendario principale del server). Restano sul computer
/// anche spegnendo la sincronizzazione e con «Ricostruisci cache».
/// </summary>
public sealed class CalendarSet(string directory)
{
    public const string DefaultName = "Calendario";
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { WriteIndented = true };

    private readonly Lock _lock = new();
    private readonly Dictionary<string, CalendarStore> _stores = [];
    private List<CalendarInfo>? _calendars;

    public string Directory { get; } = directory;

    /// <summary>Un appuntamento di uno qualsiasi dei calendari è cambiato nell'app.</summary>
    public event Action? LocalChanged;

    /// <summary>I calendari nell'ordine in cui si mostrano; il primo è quello predefinito.</summary>
    public List<CalendarInfo> List()
    {
        lock (_lock)
            return [.. Loaded()];
    }

    public CalendarInfo Default
    {
        get
        {
            lock (_lock)
                return Loaded()[0];
        }
    }

    public CalendarInfo Get(string id)
    {
        lock (_lock)
            return Loaded().FirstOrDefault(c => c.Id == id) ?? throw new MailNotFoundException("Calendario non trovato.");
    }

    /// <summary>L'archivio degli appuntamenti di un calendario.</summary>
    public CalendarStore Store(string id)
    {
        lock (_lock)
        {
            if (!Loaded().Any(c => c.Id == id))
                throw new MailNotFoundException("Calendario non trovato.");
            if (!_stores.TryGetValue(id, out var store))
            {
                store = new CalendarStore(Path.Combine(Directory, id));
                store.LocalChanged += () => LocalChanged?.Invoke();
                _stores[id] = store;
            }
            return store;
        }
    }

    /// <summary>Stato della sincronizzazione CalDAV di un calendario.</summary>
    public string StatePath(string id) => Path.Combine(Directory, id, "caldav.json");

    /// <summary>Collega un calendario a un calendario del server (nome del server, se ne ha uno).</summary>
    public CalendarInfo Link(string id, string href, string? name, bool readOnly = false)
    {
        lock (_lock)
        {
            var list = Loaded();
            var i = list.FindIndex(c => c.Id == id);
            if (i < 0)
                throw new MailNotFoundException("Calendario non trovato.");
            list[i] = list[i] with { Href = href, Name = string.IsNullOrWhiteSpace(name) ? list[i].Name : name.Trim(), ReadOnly = readOnly };
            Save();
            return list[i];
        }
    }

    /// <summary>Un calendario nuovo, in fondo (es. un altro calendario trovato sul server).</summary>
    public CalendarInfo Add(string name, string? href, bool readOnly = false)
    {
        lock (_lock)
        {
            var info = new CalendarInfo(NewId(), string.IsNullOrWhiteSpace(name) ? DefaultName : name.Trim(), href, readOnly);
            Loaded().Add(info);
            Save();
            return info;
        }
    }

    /// <summary>Il calendario non è più sul server: resta sul computer, senza collegamento (e senza il suo stato CalDAV).</summary>
    public void Unlink(string id)
    {
        lock (_lock)
        {
            var list = Loaded();
            var i = list.FindIndex(c => c.Id == id);
            if (i < 0)
                return;
            list[i] = list[i] with { Href = null, ReadOnly = false }; // scollegato: è solo sul computer
            Save();
            File.Delete(StatePath(id));
        }
    }

    public static bool IsValidId(string id) => CalendarStore.IsValidId(id);

    private string ListPath => Path.Combine(Directory, "calendars.json");

    private List<CalendarInfo> Loaded()
    {
        if (_calendars is not null)
            return _calendars;
        List<CalendarInfo>? list = null;
        try
        {
            list = JsonSerializer.Deserialize<List<CalendarInfo>>(File.ReadAllText(ListPath), Json)?
                .Where(c => IsValidId(c.Id)).GroupBy(c => c.Id).Select(g => g.First()).ToList();
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException or JsonException)
        {
            // Assente (primo uso) o rovinato: le cartelle dei calendari restano sul disco e si ritrovano qui sotto.
        }
        list ??= [];
        if (System.IO.Directory.Exists(Directory))
        {
            foreach (var dir in System.IO.Directory.EnumerateDirectories(Directory))
            {
                var id = Path.GetFileName(dir);
                if (IsValidId(id) && list.All(c => c.Id != id))
                    list.Add(new CalendarInfo(id, DefaultName, null)); // cartella senza voce: non si perde
            }
        }
        _calendars = list;
        if (list.Count == 0)
        {
            list.Add(new CalendarInfo(NewId(), DefaultName, null));
            Save();
        }
        return list;
    }

    private void Save()
    {
        CachePermissions.CreatePrivateDirectory(Path.GetDirectoryName(Directory)!);
        CachePermissions.CreatePrivateDirectory(Directory);
        var temp = ListPath + ".tmp";
        CachePermissions.CreatePrivateFile(temp);
        using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
        {
            JsonSerializer.Serialize(file, _calendars, Json);
            file.Flush(flushToDisk: true);
        }
        File.Move(temp, ListPath, overwrite: true);
    }

    private static string NewId() => Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(8));
}
