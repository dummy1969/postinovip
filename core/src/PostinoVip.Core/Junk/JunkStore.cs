using System.Text.Json;
using MimeKit;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Junk;

/// <summary>Elenco della posta indesiderata in cui aggiungere una voce.</summary>
public enum JunkList { SafeSenders, SafeRecipients, BlockedSenders }

/// <summary>
/// Opzioni posta indesiderata di un account in <c>accounts/{id}/junk.json</c> e avanzamento del filtro in
/// <c>junk-state.json</c>. Scrittura atomica (temporaneo, fsync, rinomina), file 0600, come le regole. Le modifiche
/// passano da un lock: i comandi («Blocca mittente»...) leggono, aggiungono e salvano senza perdere altre modifiche.
/// </summary>
public sealed class JunkStore(string directory)
{
    public const int MaxEntries = 2000;
    public const int MaxEntryLength = 254;

    private static readonly ParserOptions Strict = new() { AddressParserComplianceMode = RfcComplianceMode.Strict };
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { WriteIndented = true };
    private readonly Lock _lock = new();

    public string SettingsPath { get; } = Path.Combine(directory, "junk.json");
    public string StatePath { get; } = Path.Combine(directory, "junk-state.json");

    public JunkSettings Load()
    {
        lock (_lock)
            return Read<JunkSettings>(SettingsPath) ?? new JunkSettings();
    }

    /// <summary>Controlla e salva le opzioni complete; restituisce quelle salvate (ripulite).</summary>
    public JunkSettings Save(JunkSettings settings)
    {
        var clean = Validate(settings);
        lock (_lock)
            Write(SettingsPath, clean);
        return clean;
    }

    /// <summary>
    /// Aggiunge <paramref name="entry"/> (indirizzo o "@dominio") a un elenco e la toglie dall'elenco opposto
    /// (un mittente bloccato non è più attendibile e viceversa, come in Outlook); restituisce la voce ripulita.
    /// </summary>
    public string Add(JunkList list, string entry)
    {
        var clean = CleanEntry(entry, "entry");
        lock (_lock)
        {
            var s = Read<JunkSettings>(SettingsPath) ?? new JunkSettings();
            static IReadOnlyList<string> With(IReadOnlyList<string> l, string e) =>
                l.Contains(e, StringComparer.Ordinal) ? l : [.. l, e];
            static IReadOnlyList<string> Without(IReadOnlyList<string> l, string e) => l.Where(x => x != e).ToList();
            s = list switch
            {
                JunkList.SafeSenders => s with { SafeSenders = With(s.SafeSenders, clean), BlockedSenders = Without(s.BlockedSenders, clean) },
                JunkList.BlockedSenders => s with { BlockedSenders = With(s.BlockedSenders, clean), SafeSenders = Without(s.SafeSenders, clean) },
                _ => s with { SafeRecipients = With(s.SafeRecipients, clean) },
            };
            Write(SettingsPath, Validate(s));
        }
        return clean;
    }

    public JunkProgress? LoadProgress()
    {
        lock (_lock)
            return Read<JunkProgress>(StatePath);
    }

    public void SaveProgress(JunkProgress progress)
    {
        lock (_lock)
            Write(StatePath, progress);
    }

    /// <summary>
    /// Opzioni ripulite (voci in minuscolo, senza spazi, senza doppioni; "esempio.it" diventa "@esempio.it") oppure
    /// FieldValidationException sul campo dell'elenco con un messaggio per l'utente.
    /// </summary>
    public static JunkSettings Validate(JunkSettings s)
    {
        if (!Enum.IsDefined(s.Level))
            throw new FieldValidationException("level", "Livello del filtro non valido.").WithCode("livelloDelFiltroNonValido");
        var folder = string.IsNullOrWhiteSpace(s.Folder) ? null : s.Folder;
        if (folder is { Length: > 1000 } || folder?.Any(char.IsControl) == true)
            throw new FieldValidationException("folder", "Cartella non valida.").WithCode("cartellaNonValida");
        return s with
        {
            Folder = folder,
            SafeSenders = CleanList(s.SafeSenders, "safeSenders"),
            SafeRecipients = CleanList(s.SafeRecipients, "safeRecipients"),
            BlockedSenders = CleanList(s.BlockedSenders, "blockedSenders"),
        };
    }

    private static List<string> CleanList(IReadOnlyList<string>? entries, string field)
    {
        var clean = (entries ?? []).Where(e => !string.IsNullOrWhiteSpace(e)).Select(e => CleanEntry(e, field))
            .Distinct(StringComparer.Ordinal).ToList();
        if (clean.Count > MaxEntries)
            throw new FieldValidationException(field, $"Al massimo {MaxEntries} voci per elenco.");
        return clean;
    }

    /// <summary>Voce ripulita: "nome@dominio" oppure "@dominio", in minuscolo; altrimenti FieldValidationException.</summary>
    public static string CleanEntry(string? entry, string field)
    {
        var e = (entry ?? "").Trim().ToLowerInvariant();
        if (e.Length == 0)
            throw new FieldValidationException(field, "Voce vuota.");
        if (e.Length > MaxEntryLength)
            throw new FieldValidationException(field, $"«{e[..20]}…»: al massimo {MaxEntryLength} caratteri.");
        if (!e.Contains('@'))
            e = "@" + e; // solo dominio, come accetta Outlook
        if (e.StartsWith('@'))
        {
            if (!IsDomain(e[1..]))
                throw new FieldValidationException(field, $"«{e}»: dominio non valido.");
            return e;
        }
        if (!MailboxAddress.TryParse(Strict, e, out var address) || address.Address != e || !IsDomain(address.Domain))
            throw new FieldValidationException(field, $"«{e}»: indirizzo non valido.");
        return e;
    }

    private static bool IsDomain(string d) =>
        d.Length is > 0 and <= 253 && d.Contains('.') && d.Split('.').All(l => l.Length is > 0 and <= 63
            && l.All(c => char.IsLetterOrDigit(c) || c == '-') && l[0] != '-' && l[^1] != '-');

    private static T? Read<T>(string path) where T : class
    {
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<T>(stream, Json);
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException or JsonException)
        {
            return null; // assente (opzioni di serie) o rovinato
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
