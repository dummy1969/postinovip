using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text.Json;
using MimeKit;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Outbox;

/// <summary>Tipo di elemento in coda: mail da inviare (Posta in uscita) o bozza da salvare sul server.</summary>
public enum OutboxKind { Send, Draft }

/// <summary>
/// Elemento della coda locale (3.8). Send: inviata da <see cref="SendAfter"/> in poi (null = appena c'è
/// connessione), con copia in Posta inviata se <see cref="SaveCopy"/>, poi eliminata dalla coda insieme alla
/// bozza <see cref="DeleteDraftUid"/>. Draft: salvata in Bozze al ritorno della connessione, al posto di
/// <see cref="ReplaceDraftUid"/>. <see cref="Error"/>: l'ultimo invio non è riuscito per un motivo che non è la
/// connessione (es. destinatario rifiutato): niente nuovi tentativi da soli finché non si chiede "Invia ora".
/// </summary>
public sealed record OutboxItem(
    string Id,
    OutboxKind Kind,
    DateTimeOffset Created,
    string Subject,
    IReadOnlyList<string> To,
    DateTimeOffset? SendAfter = null,
    bool SaveCopy = false,
    uint? DeleteDraftUid = null,
    uint? ReplaceDraftUid = null,
    string? Error = null)
{
    public bool IsDue(DateTimeOffset now) => Error is null && (Kind == OutboxKind.Draft || SendAfter is null || SendAfter <= now);
}

/// <summary>
/// Coda locale di un account, in <c>accounts/{id}/outbox/</c>: per ogni elemento il messaggio già costruito
/// (<c>{id}.eml</c>) e i suoi dati (<c>{id}.json</c>), scritti in modo atomico (file temporaneo, fsync,
/// rinomina), cartella 0700 e file 0600 come la copia locale. Si scrive prima il messaggio e poi i dati,
/// si cancellano prima i dati: un elemento senza dati non esiste (il messaggio orfano viene tolto).
/// Resta anche quando si ricostruisce la copia locale: sono mail non ancora sul server.
/// </summary>
public sealed class OutboxStore(string directory)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private readonly Lock _lock = new();

    /// <summary>Bozze in attesa già salvate sul server in questa esecuzione: id locale -> UID in Bozze.</summary>
    private readonly ConcurrentDictionary<string, uint> _uploaded = new();

    public string Directory { get; } = directory;

    public static string NewId() => Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(8));

    public void Save(OutboxItem item, MimeMessage message)
    {
        if (!IsValidId(item.Id))
            throw new ArgumentException("Id non valido.", nameof(item));
        lock (_lock)
        {
            CachePermissions.CreatePrivateDirectory(Directory);
            WriteAtomic(PathFor(item.Id, ".eml"), stream => message.WriteTo(stream));
            WriteAtomic(PathFor(item.Id, ".json"), stream => JsonSerializer.Serialize(stream, item, Json));
        }
    }

    /// <summary>Aggiorna solo i dati (es. errore dell'ultimo invio, "Invia ora").</summary>
    public void Update(OutboxItem item)
    {
        lock (_lock)
        {
            if (!File.Exists(PathFor(item.Id, ".json")))
                return;
            WriteAtomic(PathFor(item.Id, ".json"), stream => JsonSerializer.Serialize(stream, item, Json));
        }
    }

    public IReadOnlyList<OutboxItem> List()
    {
        lock (_lock)
        {
            if (!System.IO.Directory.Exists(Directory))
                return [];
            var items = new List<OutboxItem>();
            foreach (var file in System.IO.Directory.EnumerateFiles(Directory, "*.json"))
            {
                var item = TryRead(file);
                if (item is not null && File.Exists(PathFor(item.Id, ".eml")))
                    items.Add(item);
            }
            return items.OrderBy(i => i.Created).ToList();
        }
    }

    public OutboxItem? Get(string id) => IsValidId(id) ? List().FirstOrDefault(i => i.Id == id) : null;

    public MimeMessage? LoadMessage(string id)
    {
        if (!IsValidId(id))
            return null;
        var path = PathFor(id, ".eml");
        lock (_lock)
        {
            if (!File.Exists(path))
                return null;
            using var stream = File.OpenRead(path);
            return MimeMessage.Load(stream);
        }
    }

    public bool Remove(string id)
    {
        if (!IsValidId(id))
            return false;
        lock (_lock)
        {
            var json = PathFor(id, ".json");
            var existed = File.Exists(json);
            File.Delete(json);
            File.Delete(PathFor(id, ".eml"));
            return existed;
        }
    }

    /// <summary>La bozza in attesa <paramref name="localId"/> è stata salvata sul server con questo UID.</summary>
    public void MarkUploaded(string localId, uint? uid)
    {
        if (uid is { } u)
            _uploaded[localId] = u;
    }

    public uint? UploadedUid(string localId) => _uploaded.TryGetValue(localId, out var uid) ? uid : null;

    public int SendCount => List().Count(i => i.Kind == OutboxKind.Send);

    private string PathFor(string id, string extension) => Path.Combine(Directory, id + extension);

    // Gli id finiscono nei nomi dei file: solo esadecimali minuscoli (come NewId).
    private static bool IsValidId(string id) => id.Length is > 0 and <= 32 && id.All(c => c is >= '0' and <= '9' or >= 'a' and <= 'f');

    private static OutboxItem? TryRead(string path)
    {
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<OutboxItem>(stream, Json);
        }
        catch (Exception ex) when (ex is JsonException or IOException)
        {
            return null; // file rovinato o scritto a metà: ignorato
        }
    }

    private void WriteAtomic(string target, Action<Stream> write)
    {
        var temp = target + ".tmp";
        CachePermissions.CreatePrivateFile(temp); // privato fin dalla creazione (lo svuota se c'era)
        using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
        {
            write(file);
            file.Flush(flushToDisk: true); // fsync prima della rinomina
        }
        File.Move(temp, target, overwrite: true);
    }
}
