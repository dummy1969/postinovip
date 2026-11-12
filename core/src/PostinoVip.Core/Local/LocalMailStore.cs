using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Local;

/// <summary>Dati di una cartella locale (file <c>folder.json</c> nella sua cartella su disco).</summary>
public sealed record LocalFolderInfo(string? Role, uint UidValidity, uint UidNext);

/// <summary>
/// Le mail di un account POP3 sul computer (4.2, scelta 4a): **i file sono la fonte della verità**.
/// Ogni cartella di posta è una cartella su disco dentro <see cref="Root"/> (sottocartelle annidate per le
/// sottocartelle di posta, separatore "/"), con un file <c>folder.json</c> (ruolo, UIDVALIDITY, prossimo UID)
/// e un file <c>{uid}.eml</c> per messaggio, scritto in modo atomico (temporaneo, fsync, rinomina) e privato
/// (cartelle 0700, file 0600). Il nome della cartella di posta si ricava dal percorso (nomi codificati da
/// <see cref="EncodeSegment"/>): il database dell'account (<see cref="AccountCache"/>) è solo un indice che
/// si ricostruisce dai file; se si rovina si perdono al più letto, contrassegni e categorie.
/// Gli UID sono locali e crescenti per cartella, come in IMAP: il resto della copia locale (lista, ricerca,
/// conversazioni) funziona allo stesso modo, leggendo questa casella al posto del server.
/// </summary>
public sealed class LocalMailStore : IMailboxSource
{
    public const char Separator = '/';
    public const string Inbox = "INBOX";
    public const string MetaFile = "folder.json";

    /// <summary>Cartelle create la prima volta, con i nomi di Outlook in italiano.</summary>
    public static readonly IReadOnlyList<(string Name, string Role)> DefaultFolders =
    [
        (Inbox, "inbox"),
        ("Posta inviata", "sent"),
        ("Bozze", "drafts"),
        ("Posta eliminata", "trash"),
        ("Posta indesiderata", "junk"),
    ];

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private readonly Lock _lock = new();

    public LocalMailStore(string root)
    {
        Root = root;
    }

    public string Root { get; }

    /// <summary>Crea la cartella principale e le cartelle predefinite che mancano.</summary>
    public void EnsureDefaults()
    {
        lock (_lock)
        {
            CachePermissions.CreatePrivateDirectory(Root);
            foreach (var (name, role) in DefaultFolders)
            {
                var dir = DirectoryFor(name);
                if (ReadMeta(dir) is not { } info)
                    CreateFolderLocked(name, role);
                else if (info.Role != role)
                    WriteMeta(dir, info with { Role = role }); // folder.json rifatto dopo un danno: ruolo perso
            }
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Cartelle
    // ---------------------------------------------------------------------------------------------

    /// <summary>Tutte le cartelle (quelle con <c>folder.json</c>), con il numero di messaggi.</summary>
    public IReadOnlyList<(string FullName, LocalFolderInfo Info, int Count)> ListFolders()
    {
        lock (_lock)
        {
            if (!Directory.Exists(Root))
                return [];
            var result = new List<(string, LocalFolderInfo, int)>();
            foreach (var meta in Directory.EnumerateFiles(Root, MetaFile, SearchOption.AllDirectories))
            {
                var dir = Path.GetDirectoryName(meta)!;
                if (NameFor(dir) is not { } name || ReadMeta(dir) is not { } info)
                    continue;
                result.Add((name, info, Directory.EnumerateFiles(dir, "*.eml").Count()));
            }
            return result.OrderBy(f => f.Item1, StringComparer.OrdinalIgnoreCase).ToList();
        }
    }

    public bool FolderExists(string fullName) => File.Exists(Path.Combine(DirectoryFor(fullName), MetaFile));

    public LocalFolderInfo GetFolder(string fullName) =>
        ReadMeta(DirectoryFor(fullName)) ?? throw new MailNotFoundException($"Cartella '{fullName}' non trovata.");

    /// <summary>Crea la cartella (le cartelle madri devono esistere); già presente -> InvalidOperationException.</summary>
    public void CreateFolder(string fullName, string? role = null)
    {
        lock (_lock)
        {
            if (FolderExists(fullName))
                throw new InvalidOperationException($"La cartella '{fullName}' esiste già.");
            var parent = ParentOf(fullName);
            if (parent is not null && !FolderExists(parent))
                throw new MailNotFoundException($"Cartella '{parent}' non trovata.");
            CreateFolderLocked(fullName, role);
        }
    }

    private void CreateFolderLocked(string fullName, string? role)
    {
        // Ogni livello creato a parte: CreateDirectory applica i permessi solo all'ultimo.
        var dir = Root;
        foreach (var segment in fullName.Split(Separator))
        {
            dir = Path.Combine(dir, EncodeSegment(segment));
            CachePermissions.CreatePrivateDirectory(dir);
        }
        WriteMeta(dir, new LocalFolderInfo(role, NewUidValidity(), 1));
    }

    public static string? ParentOf(string fullName)
    {
        var i = fullName.LastIndexOf(Separator);
        return i < 0 ? null : fullName[..i];
    }

    // ---------------------------------------------------------------------------------------------
    // Messaggi
    // ---------------------------------------------------------------------------------------------

    public IReadOnlyList<uint> GetUids(string folder)
    {
        var dir = DirectoryFor(folder);
        if (!Directory.Exists(dir))
            throw new MailNotFoundException($"Cartella '{folder}' non trovata.");
        var uids = new List<uint>();
        foreach (var file in Directory.EnumerateFiles(dir, "*.eml"))
        {
            if (uint.TryParse(Path.GetFileNameWithoutExtension(file), NumberStyles.None, CultureInfo.InvariantCulture, out var uid) && uid > 0)
                uids.Add(uid);
        }
        uids.Sort();
        return uids;
    }

    public string PathFor(string folder, uint uid) =>
        Path.Combine(DirectoryFor(folder), uid.ToString(CultureInfo.InvariantCulture) + ".eml");

    public bool Exists(string folder, uint uid) => File.Exists(PathFor(folder, uid));

    /// <summary>Apre il messaggio in lettura; MailNotFoundException se non c'è.</summary>
    public FileStream OpenRead(string folder, uint uid)
    {
        try
        {
            return new FileStream(PathFor(folder, uid), FileMode.Open, FileAccess.Read, FileShare.Read | FileShare.Delete);
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException)
        {
            throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folder}'.");
        }
    }

    /// <summary>
    /// Aggiunge un messaggio alla cartella e restituisce il suo UID. Prima si riserva l'UID (folder.json),
    /// poi si scrive il file: un'interruzione a metà lascia al più un UID non usato, mai due messaggi con lo
    /// stesso UID. <paramref name="prefix"/>: righe di intestazione aggiunte in testa (es. X-UIDL del POP3).
    /// </summary>
    public async Task<uint> AddAsync(string folder, Stream content, string? prefix = null, CancellationToken ct = default)
    {
        var dir = DirectoryFor(folder);
        uint uid;
        lock (_lock)
        {
            var info = ReadMeta(dir) ?? throw new MailNotFoundException($"Cartella '{folder}' non trovata.");
            uid = info.UidNext;
            WriteMeta(dir, info with { UidNext = uid + 1 });
        }

        var target = PathFor(folder, uid);
        var temp = Path.Combine(dir, $".{uid}.{Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(4))}.tmp");
        CachePermissions.CreatePrivateFile(temp);
        try
        {
            await using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
            {
                if (prefix is not null)
                    await file.WriteAsync(Encoding.ASCII.GetBytes(prefix), ct);
                await content.CopyToAsync(file, ct);
                await file.FlushAsync(ct);
                file.Flush(flushToDisk: true);
            }
            File.Move(temp, target, overwrite: false);
        }
        catch
        {
            File.Delete(temp);
            throw;
        }
        return uid;
    }

    /// <summary>Elimina il file del messaggio; false se non c'era.</summary>
    public bool Delete(string folder, uint uid)
    {
        var path = PathFor(folder, uid);
        if (!File.Exists(path))
            return false;
        File.Delete(path);
        return true;
    }

    /// <summary>
    /// Sposta il messaggio in un'altra cartella (nuovo UID lì); restituisce il nuovo UID.
    /// Prima la copia completa, poi la cancellazione: un'interruzione lascia al più un doppione.
    /// </summary>
    public async Task<uint> MoveAsync(string folder, uint uid, string destination, CancellationToken ct = default)
    {
        uint copied;
        await using (var source = OpenRead(folder, uid))
            copied = await AddAsync(destination, source, ct: ct);
        Delete(folder, uid);
        return copied;
    }

    /// <summary>Copia il messaggio in un'altra cartella (nuovo UID lì); l'originale resta.</summary>
    public async Task<uint> CopyAsync(string folder, uint uid, string destination, CancellationToken ct = default)
    {
        await using var source = OpenRead(folder, uid);
        return await AddAsync(destination, source, ct: ct);
    }

    /// <summary>Valore di un'intestazione del messaggio (es. X-UIDL), letta senza caricare il corpo; null se manca.</summary>
    public string? ReadHeader(string folder, uint uid, string name)
    {
        try
        {
            using var stream = OpenRead(folder, uid);
            return MimeKit.HeaderList.Load(stream)[name]?.Trim();
        }
        catch (Exception ex) when (ex is MailNotFoundException or FormatException)
        {
            return null;
        }
    }

    /// <summary>
    /// Rinomina o sposta una cartella con le sottocartelle (una rinomina della cartella su disco: UID e
    /// UIDVALIDITY restano, quindi anche l'indice si aggiorna solo nel nome). La destinazione non deve esistere
    /// e la sua cartella madre sì.
    /// </summary>
    public void RenameFolder(string fullName, string newFullName)
    {
        lock (_lock)
        {
            var from = DirectoryFor(fullName);
            var to = DirectoryFor(newFullName);
            if (!File.Exists(Path.Combine(from, MetaFile)))
                throw new MailNotFoundException($"Cartella '{fullName}' non trovata.");
            if (ParentOf(newFullName) is { } parent && !FolderExists(parent))
                throw new MailNotFoundException($"Cartella '{parent}' non trovata.");
            if (string.Equals(from, to, StringComparison.OrdinalIgnoreCase))
            {
                // Solo maiuscole/minuscole: in due passi (su Windows e macOS i nomi non le distinguono).
                var temp = to + ".rinomina-" + Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(4));
                Directory.Move(from, temp);
                Directory.Move(temp, to);
                return;
            }
            if (Directory.Exists(to))
                throw new InvalidOperationException($"La cartella '{newFullName}' esiste già.");
            Directory.Move(from, to);
        }
    }

    /// <summary>Elimina DEFINITIVAMENTE la cartella con le sottocartelle e tutte le mail. Non reversibile.</summary>
    public void DeleteFolder(string fullName)
    {
        lock (_lock)
        {
            var dir = DirectoryFor(fullName);
            if (Directory.Exists(dir))
                Directory.Delete(dir, recursive: true);
        }
    }

    /// <summary>Cartella e sottocartelle (nomi completi), la cartella stessa per prima.</summary>
    public IReadOnlyList<string> FolderTree(string fullName) =>
        ListFolders().Select(f => f.FullName)
            .Where(n => n == fullName || n.StartsWith(fullName + Separator, StringComparison.Ordinal))
            .OrderBy(n => n.Length)
            .ToList();

    // ---------------------------------------------------------------------------------------------
    // IMailboxSource: la casella vista dalla copia locale (stesso percorso del server IMAP)
    // ---------------------------------------------------------------------------------------------

    public Task<IReadOnlyList<MailFolderInfo>> GetFoldersAsync(CancellationToken ct = default)
    {
        EnsureDefaults();
        IReadOnlyList<MailFolderInfo> folders = ListFolders()
            .Select(f => new MailFolderInfo(f.FullName, LastSegment(f.FullName), f.Count, f.Info.Role))
            .ToList();
        return Task.FromResult(folders);
    }

    public Task<T> ExamineAsync<T>(string folderName, Func<IFolderSource, Task<T>> action, CancellationToken ct = default)
    {
        var info = GetFolder(folderName);
        return action(new LocalFolderSource(this, folderName, info));
    }

    // ---------------------------------------------------------------------------------------------
    // Nomi e file di servizio
    // ---------------------------------------------------------------------------------------------

    public static string LastSegment(string fullName)
    {
        var i = fullName.LastIndexOf(Separator);
        return i < 0 ? fullName : fullName[(i + 1)..];
    }

    public string DirectoryFor(string fullName)
    {
        if (string.IsNullOrEmpty(fullName))
            throw new MailNotFoundException("Cartella non indicata.");
        var dir = Root;
        foreach (var segment in fullName.Split(Separator))
        {
            if (segment.Length == 0)
                throw new MailNotFoundException($"Cartella '{fullName}' non valida.");
            dir = Path.Combine(dir, EncodeSegment(segment));
        }
        return dir;
    }

    private string? NameFor(string directory)
    {
        var relative = Path.GetRelativePath(Root, directory);
        if (relative is "." || relative.StartsWith("..", StringComparison.Ordinal))
            return null;
        var segments = relative.Split(Path.DirectorySeparatorChar).Select(DecodeSegment).ToList();
        return segments.Any(s => s is null) ? null : string.Join(Separator, segments);
    }

    /// <summary>
    /// Nome di un livello della cartella -> nome della cartella su disco, valido su Linux, Windows e macOS:
    /// lettere, cifre, spazi e pochi segni restano; il resto (anche "%", "." iniziale, spazio o punto finale,
    /// nomi riservati di Windows) diventa %XX (UTF-8). Reversibile con <see cref="DecodeSegment"/>.
    /// </summary>
    public static string EncodeSegment(string segment)
    {
        var sb = new StringBuilder();
        var bytes = new byte[4];
        for (var i = 0; i < segment.Length; i++)
        {
            var c = segment[i];
            var safe = char.IsLetterOrDigit(c) || c is ' ' or '-' or '_' or '(' or ')' or '\'' or ',' or '+' or '&' or '!'
                       || (c == '.' && i > 0);
            if (char.IsSurrogate(c))
                safe = false;
            if (safe)
            {
                sb.Append(c);
                continue;
            }
            var length = char.IsHighSurrogate(c) && i + 1 < segment.Length
                ? Encoding.UTF8.GetBytes(segment.AsSpan(i++, 2), bytes)
                : Encoding.UTF8.GetBytes(segment.AsSpan(i, 1), bytes);
            for (var b = 0; b < length; b++)
                sb.Append('%').Append(bytes[b].ToString("X2", CultureInfo.InvariantCulture));
        }
        // Windows: niente spazio o punto alla fine, niente nomi riservati (CON, NUL, COM1...).
        if (sb.Length > 0 && sb[^1] is ' ' or '.')
        {
            var last = sb[^1];
            sb.Length--;
            sb.Append(last == ' ' ? "%20" : "%2E");
        }
        var name = sb.ToString();
        var stem = name.Split('.')[0].ToUpperInvariant();
        if (stem is "CON" or "PRN" or "AUX" or "NUL" || (stem.Length == 4 && (stem.StartsWith("COM") || stem.StartsWith("LPT")) && char.IsDigit(stem[3])))
            name = $"%{(int)name[0]:X2}{name[1..]}";
        return name;
    }

    public static string? DecodeSegment(string name)
    {
        if (!name.Contains('%'))
            return name;
        var bytes = new List<byte>();
        var sb = new StringBuilder();
        void Flush()
        {
            if (bytes.Count == 0) return;
            sb.Append(Encoding.UTF8.GetString(bytes.ToArray()));
            bytes.Clear();
        }
        for (var i = 0; i < name.Length; i++)
        {
            if (name[i] == '%' && i + 2 < name.Length
                && byte.TryParse(name.AsSpan(i + 1, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var b))
            {
                bytes.Add(b);
                i += 2;
                continue;
            }
            if (name[i] == '%')
                return null; // non è un nome scritto da noi
            Flush();
            sb.Append(name[i]);
        }
        Flush();
        return sb.ToString();
    }

    private static uint NewUidValidity() => (uint)RandomNumberGenerator.GetInt32(1, int.MaxValue);

    private static LocalFolderInfo? ReadMeta(string directory)
    {
        var path = Path.Combine(directory, MetaFile);
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<LocalFolderInfo>(stream, Json);
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException)
        {
            return null;
        }
        catch (JsonException)
        {
            // Rovinato: nuovo UIDVALIDITY (l'indice della cartella si rifà dai file) e UID oltre quelli presenti.
            var max = Directory.EnumerateFiles(directory, "*.eml")
                .Select(f => uint.TryParse(Path.GetFileNameWithoutExtension(f), out var u) ? u : 0)
                .DefaultIfEmpty(0u).Max();
            var repaired = new LocalFolderInfo(null, NewUidValidity(), max + 1);
            WriteMeta(directory, repaired);
            return repaired;
        }
    }

    private static void WriteMeta(string directory, LocalFolderInfo info)
    {
        var path = Path.Combine(directory, MetaFile);
        var temp = path + ".tmp";
        CachePermissions.CreatePrivateFile(temp);
        using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
        {
            JsonSerializer.Serialize(file, info, Json);
            file.Flush(flushToDisk: true);
        }
        File.Move(temp, path, overwrite: true);
    }
}
