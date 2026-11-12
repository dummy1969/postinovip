using System.Text.Json;
using System.Text.Json.Serialization;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Dav;

/// <summary>
/// Un elemento del server già visto (contatto o appuntamento): href, ETag dell'ultima versione nota, elemento locale collegato (null = dato del
/// server non utilizzabile, ignorato finché non cambia) e impronta dell'elemento locale all'ultima sincronizzazione
/// (diversa = cambiato sul computer). <see cref="ServerPending"/>: la versione del server non è ancora stata applicata
/// (elemento cambiato nel frattempo, conflitto rinviato fino alla conferma, scrittura rifiutata con 412): si rilegge
/// al giro successivo.
/// </summary>
public sealed class DavEntry
{
    public string Href { get; set; } = "";
    public string? Etag { get; set; }
    /// <summary>Elemento locale collegato (contatto o appuntamento); in JSON «contactId», il nome del primo formato (C4b).</summary>
    [JsonPropertyName("contactId")]
    public string? ItemId { get; set; }
    public string Fingerprint { get; set; } = "";
    public bool ServerPending { get; set; }
}

/// <summary>
/// Stato della sincronizzazione di un account (<c>accounts/&lt;id&gt;/carddav.json</c>): da dove è partita la scoperta
/// (<see cref="Source"/>: se cambia si ricomincia da capo), rubrica trovata, ctag e sync-token dell'ultima volta,
/// conferma della prima volta (2a) e contatti collegati.
/// </summary>
public sealed class DavState
{
    public string Source { get; set; } = "";
    /// <summary>Indirizzo della raccolta sul server (rubrica o calendario); in JSON «book», come nel C4b.</summary>
    [JsonPropertyName("book")]
    public string? Collection { get; set; }

    [JsonPropertyName("bookName")]
    public string? CollectionName { get; set; }
    public string? Ctag { get; set; }
    public string? SyncToken { get; set; }
    public bool Confirmed { get; set; }
    public List<DavEntry> Entries { get; set; } = [];
}

/// <summary>Lettura e scrittura atomica (0600) di <see cref="DavState"/>; file assente o rovinato = da capo.</summary>
public sealed class DavStateStore(string path)
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public string Path { get; } = path;

    public DavState Load()
    {
        try
        {
            using var stream = File.OpenRead(Path);
            return JsonSerializer.Deserialize<DavState>(stream, Json) ?? new DavState();
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException or JsonException)
        {
            // Perso o rovinato: la prossima sincronizzazione ricollega i contatti uguali (stesso nome e indirizzi)
            // invece di duplicarli, e chiede di nuovo la conferma se ci sono contatti solo sul computer.
            return new DavState();
        }
    }

    public void Save(DavState state)
    {
        CachePermissions.CreatePrivateDirectory(System.IO.Path.GetDirectoryName(Path)!);
        var temp = Path + ".tmp";
        CachePermissions.CreatePrivateFile(temp);
        using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
        {
            JsonSerializer.Serialize(file, state, Json);
            file.Flush(flushToDisk: true);
        }
        File.Move(temp, Path, overwrite: true);
    }
}
