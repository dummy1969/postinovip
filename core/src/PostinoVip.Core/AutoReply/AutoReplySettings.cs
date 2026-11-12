using System.Security.Cryptography;
using System.Text.Json;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.AutoReply;

/// <summary>
/// Risposte automatiche di un account (scelta 2a), come la finestra di Outlook: attive sì/no, intervallo di tempo
/// facoltativo, un messaggio formattato (HTML più versione in testo; <see cref="Document"/> è il documento
/// dell'editor dell'app, conservato così com'è per riaprirlo senza perdite).
/// </summary>
public sealed record AutoReplySettings
{
    public bool Enabled { get; init; }
    public DateTimeOffset? Start { get; init; }
    public DateTimeOffset? End { get; init; }
    public string Html { get; init; } = "";
    public string Text { get; init; } = "";
    public string? Document { get; init; }

    /// <summary>Si inviano adesso: attive e dentro l'intervallo (se c'è).</summary>
    public bool IsActive(DateTimeOffset now) => Enabled && (Start is null || now >= Start) && (End is null || now < End);

    /// <summary>Una mail arrivata in quel momento riceve la risposta (le mail arrivate ad app chiusa, 1a).</summary>
    public bool Covers(DateTimeOffset arrived) => Enabled && (Start is null || arrived >= Start) && (End is null || arrived < End);
}

/// <summary>
/// Stato interno: "generazione" (cambia a ogni attivazione o cambio di intervallo: si ricomincia a rispondere a
/// tutti, scelta 3a), fin dove sono state esaminate le mail, a chi si è già risposto in questa generazione.
/// </summary>
/// <see cref="ActivatedAt"/>: quando sono state attivate; al primo giro si risponde alle mail arrivate da allora
/// (anche a quella che fa partire il giro), non a quelle già presenti.
public sealed record AutoReplyState(string Generation, uint? UidValidity, uint? LastUid, IReadOnlyList<string> Replied,
    DateTimeOffset? ActivatedAt = null);

/// <summary>
/// <c>accounts/{id}/autoreply.json</c> (impostazioni) e <c>autoreply-state.json</c> (stato), scritti in modo
/// atomico, 0600. Il registro contiene indirizzi: resta sul computer, come la copia locale, e non va nei log.
/// </summary>
public sealed class AutoReplyStore(string directory)
{
    public const int MaxHtmlLength = 200_000;

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private readonly Lock _lock = new();

    public string SettingsPath { get; } = Path.Combine(directory, "autoreply.json");
    public string StatePath { get; } = Path.Combine(directory, "autoreply-state.json");

    public AutoReplySettings Load()
    {
        lock (_lock)
            return Read<AutoReplySettings>(SettingsPath) ?? new AutoReplySettings();
    }

    /// <summary>
    /// Controlla e salva. Attivazione (spente -> attive) o intervallo cambiato: nuova generazione, si risponde di
    /// nuovo a tutti e solo alle mail che arrivano da quel momento.
    /// </summary>
    public AutoReplySettings Save(AutoReplySettings settings)
    {
        if (settings.Enabled && string.IsNullOrWhiteSpace(settings.Text) && string.IsNullOrWhiteSpace(settings.Html))
            throw new FieldValidationException("text", "Scrivere il messaggio della risposta automatica.");
        if (settings.Start is { } s && settings.End is { } e && e <= s)
            throw new FieldValidationException("end", "La fine deve venire dopo l'inizio.");
        if (settings.Html.Length > MaxHtmlLength || (settings.Document?.Length ?? 0) > MaxHtmlLength * 2)
            throw new FieldValidationException("text", "Il messaggio è troppo lungo.");
        lock (_lock)
        {
            var previous = Read<AutoReplySettings>(SettingsPath) ?? new AutoReplySettings();
            Write(SettingsPath, settings);
            var restart = settings.Enabled && (!previous.Enabled || previous.Start != settings.Start || previous.End != settings.End);
            if (restart || Read<AutoReplyState>(StatePath) is null)
                Write(StatePath, new AutoReplyState(NewGeneration(), null, null, [], DateTimeOffset.UtcNow));
        }
        return settings;
    }

    public AutoReplyState LoadState()
    {
        lock (_lock)
            return Read<AutoReplyState>(StatePath) ?? new AutoReplyState(NewGeneration(), null, null, []);
    }

    public void SaveState(AutoReplyState state)
    {
        lock (_lock)
            Write(StatePath, state);
    }

    private static string NewGeneration() => Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(8));

    private static T? Read<T>(string path) where T : class
    {
        try
        {
            using var stream = File.OpenRead(path);
            return JsonSerializer.Deserialize<T>(stream, Json);
        }
        catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException or JsonException)
        {
            return null;
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
