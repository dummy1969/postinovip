using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Calendars;

/// <summary>
/// Un appuntamento sul disco: il testo iCalendar così com'è (un UID, la serie con le eventuali occorrenze modificate),
/// l'impronta del testo e l'ora dell'ultima modifica (per i conflitti della sincronizzazione).
/// </summary>
public sealed record CalendarItem(string Id, string Uid, string Text, string Fingerprint, DateTimeOffset? Updated);

/// <summary>
/// Un calendario sul computer (K2a): <c>calendars/&lt;id&gt;/items/&lt;id&gt;.ics</c>, un oggetto iCalendar per
/// appuntamento (come una risorsa CalDAV), scritto in modo atomico con permessi privati; <c>updated.json</c> tiene l'ora
/// dell'ultima modifica di ognuno (quella dichiarata dal server, o l'ora in cui il core ha visto il cambiamento, o quella
/// della modifica nell'app). In memoria dopo la prima lettura: lo scrive solo il core.
/// </summary>
public sealed class CalendarStore(string directory)
{
    public const int MaxItems = 50_000;
    public const int MaxBytes = 1024 * 1024;

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly Lock _lock = new();
    private Dictionary<string, CalendarItem>? _items;
    private Dictionary<string, long>? _updated;

    public string Directory { get; } = directory;

    private string ItemsDirectory => Path.Combine(Directory, "items");

    /// <summary>Un appuntamento è cambiato per una richiesta dell'app (non per la sincronizzazione): CalDAV parte subito.</summary>
    public event Action? LocalChanged;

    public List<CalendarItem> List()
    {
        lock (_lock)
            return Loaded().Values.OrderBy(i => i.Id, StringComparer.Ordinal).ToList();
    }

    public int Count
    {
        get
        {
            lock (_lock)
                return Loaded().Count;
        }
    }

    public CalendarItem? Find(string id)
    {
        lock (_lock)
            return Loaded().GetValueOrDefault(id);
    }

    /// <summary>Un appuntamento con questo UID (gli UID sono unici in un calendario CalDAV).</summary>
    public CalendarItem? FindByUid(string uid)
    {
        lock (_lock)
            return Loaded().Values.FirstOrDefault(i => i.Uid == uid);
    }

    /// <summary>
    /// Salva un appuntamento scritto dall'app (K2b): nuovo con <paramref name="id"/> null. Controlla il testo
    /// (<see cref="CalendarText.Check"/>); l'ora della modifica è adesso. Fa partire la sincronizzazione.
    /// </summary>
    public CalendarItem SaveLocal(string? id, string text)
    {
        text = CalendarText.Normalize(text);
        var uid = CalendarText.Check(text) ?? throw new FieldValidationException("event", "Appuntamento non valido.");
        CalendarItem saved;
        lock (_lock)
        {
            var items = Loaded();
            if (id is not null && !items.ContainsKey(id))
                throw new MailNotFoundException("Appuntamento non trovato.");
            if (items.Values.Any(i => i.Uid == uid && i.Id != id))
                throw new FieldValidationException("event", "Esiste già un appuntamento con lo stesso UID.");
            if (id is null && items.Count >= MaxItems)
                throw new FieldValidationException("event", $"Il calendario ha già {MaxItems} appuntamenti.");
            saved = Save(id ?? NewId(), uid, text, DateTimeOffset.UtcNow);
        }
        LocalChanged?.Invoke();
        return saved;
    }

    /// <summary>Elimina un appuntamento dall'app (con CalDAV l'eliminazione va poi sul server).</summary>
    public void DeleteLocal(string id)
    {
        lock (_lock)
        {
            if (!Loaded().ContainsKey(id))
                throw new MailNotFoundException("Appuntamento non trovato.");
            Remove(id);
        }
        LocalChanged?.Invoke();
    }

    /// <summary>
    /// Scrive un appuntamento arrivato dal server: con <paramref name="id"/> sostituisce quello (o lo ricrea con lo stesso
    /// id), altrimenti ne crea uno nuovo. Con <paramref name="expectedFingerprint"/> solo se nel frattempo l'app non l'ha
    /// cambiato. Non fa scattare <see cref="LocalChanged"/>.
    /// </summary>
    public (CalendarItem? Item, Dav.DavApplyOutcome Outcome) ApplyFromSync(string? id, string text, DateTimeOffset updated, string? expectedFingerprint)
    {
        text = CalendarText.Normalize(text);
        if (Encoding.UTF8.GetByteCount(text) > MaxBytes || CalendarText.Check(text) is not { } uid)
            return (null, Dav.DavApplyOutcome.Invalid);
        lock (_lock)
        {
            var items = Loaded();
            if (id is not null && items.TryGetValue(id, out var current))
            {
                if (expectedFingerprint is not null && current.Fingerprint != expectedFingerprint)
                    return (current, Dav.DavApplyOutcome.ChangedMeanwhile);
            }
            else if (items.Count >= MaxItems)
                return (null, Dav.DavApplyOutcome.Full);
            return (Save(id is not null && IsValidId(id) ? id : NewId(), uid, text, updated), Dav.DavApplyOutcome.Saved);
        }
    }

    /// <summary>Elimina un appuntamento eliminato sul server; false se nel frattempo l'app l'ha cambiato (si conserva, 3a).</summary>
    public bool RemoveFromSync(string id, string expectedFingerprint)
    {
        lock (_lock)
        {
            if (!Loaded().TryGetValue(id, out var current) || current.Fingerprint != expectedFingerprint)
                return false;
            Remove(id);
            return true;
        }
    }

    public static string Fingerprint(string text) => Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(text)));

    public static bool IsValidId(string id) => id.Length is > 0 and <= 32 && id.All(char.IsAsciiHexDigitLower);

    private CalendarItem Save(string id, string uid, string text, DateTimeOffset updated)
    {
        CachePermissions.CreatePrivateDirectory(Directory);
        CachePermissions.CreatePrivateDirectory(ItemsDirectory);
        var path = PathOf(id);
        WriteAtomic(path, Encoding.UTF8.GetBytes(text));
        var item = new CalendarItem(id, uid, text, Fingerprint(text), updated);
        Loaded()[id] = item;
        _updated![id] = updated.ToUnixTimeSeconds();
        SaveUpdated();
        return item;
    }

    private void Remove(string id)
    {
        Loaded().Remove(id);
        File.Delete(PathOf(id));
        if (_updated!.Remove(id))
            SaveUpdated();
    }

    private Dictionary<string, CalendarItem> Loaded()
    {
        if (_items is not null)
            return _items;
        _updated = ReadUpdated();
        var items = new Dictionary<string, CalendarItem>();
        if (System.IO.Directory.Exists(ItemsDirectory))
        {
            foreach (var file in System.IO.Directory.EnumerateFiles(ItemsDirectory, "*.ics"))
            {
                var id = Path.GetFileNameWithoutExtension(file);
                if (!IsValidId(id))
                    continue;
                try
                {
                    // Un file illeggibile si salta (resta sul disco, non si perde).
                    var text = File.ReadAllText(file, Encoding.UTF8);
                    if (CalendarText.Check(text) is not { } uid)
                        continue;
                    DateTimeOffset? updated = _updated.TryGetValue(id, out var u) ? DateTimeOffset.FromUnixTimeSeconds(u) : CalendarText.LastModified(text);
                    items[id] = new CalendarItem(id, uid, text, Fingerprint(text), updated);
                }
                catch (IOException)
                {
                }
            }
        }
        return _items = items;
    }

    private string UpdatedPath => Path.Combine(Directory, "updated.json");

    private Dictionary<string, long> ReadUpdated()
    {
        try
        {
            return JsonSerializer.Deserialize<Dictionary<string, long>>(File.ReadAllText(UpdatedPath), Json) ?? [];
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException or JsonException)
        {
            return [];
        }
    }

    private void SaveUpdated()
    {
        CachePermissions.CreatePrivateDirectory(Directory);
        WriteAtomic(UpdatedPath, JsonSerializer.SerializeToUtf8Bytes(_updated, Json));
    }

    private static void WriteAtomic(string path, byte[] data)
    {
        var temp = path + ".tmp";
        CachePermissions.CreatePrivateFile(temp);
        using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
        {
            file.Write(data);
            file.Flush(flushToDisk: true);
        }
        File.Move(temp, path, overwrite: true);
    }

    private string PathOf(string id) =>
        IsValidId(id) ? Path.Combine(ItemsDirectory, id + ".ics") : throw new MailNotFoundException("Appuntamento non trovato.");

    private static string NewId() => Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(8));
}
