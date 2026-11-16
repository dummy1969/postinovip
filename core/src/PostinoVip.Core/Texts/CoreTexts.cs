using System.Collections.Concurrent;
using System.Globalization;
using System.Text.Json;

namespace PostinoVip.Core.Texts;

/// <summary>
/// Testi che il core scrive nelle mail e nel browser, nella lingua dell'app (tappa «Lingua», L6b, scelte 2a e 3a): un file
/// <c>Texts/&lt;lingua&gt;.json</c> incluso nella libreria per ogni lingua. Per una lingua nuova basta un file in più (e il
/// codice in <see cref="UiLanguage.Supported"/>). Un testo che manca in una lingua viene dall'italiano.
/// </summary>
public static class CoreTexts
{
    private const string Fallback = "it";

    private static readonly ConcurrentDictionary<string, IReadOnlyDictionary<string, string>> Loaded = new();

    /// <summary>Lingua forzata per il codice che gira in questo flusso (test, prove): ha la precedenza su quella dell'app.</summary>
    private static readonly AsyncLocal<string?> Override = new();

    /// <summary>Lingua usata adesso: quella forzata o quella dell'ultima richiesta dell'app.</summary>
    public static string Language => Override.Value ?? UiLanguage.Current;

    /// <summary>Usa <paramref name="language"/> fino al Dispose, solo in questo flusso (per i test).</summary>
    public static IDisposable Use(string language)
    {
        var before = Override.Value;
        Override.Value = language;
        return new Restore(() => Override.Value = before);
    }

    /// <summary>Il testo <paramref name="key"/> con i segnaposto {nome} sostituiti.</summary>
    public static string Get(string key, params (string Name, string Value)[] values)
    {
        var text = Lookup(Language, key) ?? Lookup(Fallback, key) ?? key;
        foreach (var (name, value) in values)
            text = text.Replace("{" + name + "}", value, StringComparison.Ordinal);
        return text;
    }

    /// <summary>Data e ora locali con la forma della lingua (senza dati di cultura: il core è in InvariantGlobalization).</summary>
    public static string Date(DateTimeOffset d) => d.ToLocalTime().ToString(Get("dateFormat"), CultureInfo.InvariantCulture);

    private static string? Lookup(string language, string key) =>
        Loaded.GetOrAdd(language, Load).TryGetValue(key, out var text) ? text : null;

    private static IReadOnlyDictionary<string, string> Load(string language)
    {
        var assembly = typeof(CoreTexts).Assembly;
        using var stream = assembly.GetManifestResourceStream($"PostinoVip.Core.Texts.{language}.json");
        if (stream is null)
            return new Dictionary<string, string>();
        return JsonSerializer.Deserialize<Dictionary<string, string>>(stream) ?? new Dictionary<string, string>();
    }

    private sealed class Restore(Action restore) : IDisposable
    {
        public void Dispose() => restore();
    }
}
