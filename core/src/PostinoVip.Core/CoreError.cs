using System.Globalization;

namespace PostinoVip.Core;

/// <summary>
/// Codici degli errori per l'app (tappa «Lingua», L6, scelta 2a): un errore porta, oltre al testo italiano (per i log e per
/// un'app che non conosce il codice), un codice e i suoi valori; l'app mostra il testo nella sua lingua. Codice e valori
/// stanno in <see cref="Exception.Data"/>, così vale per qualsiasi tipo di eccezione.
/// </summary>
public static class CoreError
{
    private const string CodeKey = "PostinoVip.Code";
    private const string ArgsKey = "PostinoVip.Args";

    private static readonly IReadOnlyDictionary<string, string> NoArgs = new Dictionary<string, string>();

    /// <summary>Aggiunge a <paramref name="exception"/> il codice e i valori (testi semplici, senza dati riservati).</summary>
    public static T WithCode<T>(this T exception, string code, params (string Name, object? Value)[] args) where T : Exception
    {
        exception.Data[CodeKey] = code;
        exception.Data[ArgsKey] = args.ToDictionary(a => a.Name, a => Convert.ToString(a.Value, CultureInfo.InvariantCulture) ?? "");
        return exception;
    }

    public static string? CodeOf(Exception exception) => exception.Data[CodeKey] as string;

    public static IReadOnlyDictionary<string, string> ArgsOf(Exception exception) =>
        exception.Data[ArgsKey] as IReadOnlyDictionary<string, string> ?? NoArgs;
}

/// <summary>
/// Lingua dell'app (scelta 2a): quella dell'ultima richiesta (intestazione Accept-Language). Serve ai testi che il core
/// scrive da solo (risposte automatiche, conferme di lettura, pagina del browser dopo l'accesso). Di serie italiano.
/// </summary>
public static class UiLanguage
{
    public static readonly string[] Supported = ["it", "en", "es", "fr", "de"];

    private static volatile string _current = "it";

    public static string Current => _current;

    /// <summary>Prima lingua di Accept-Language che il core conosce; le altre lasciano quella di prima.</summary>
    public static void Set(string? acceptLanguage)
    {
        foreach (var part in (acceptLanguage ?? "").Split(','))
        {
            var tag = part.Split(';')[0].Trim();
            var language = tag.Length >= 2 ? tag[..2].ToLowerInvariant() : "";
            if (Supported.Contains(language))
            {
                _current = language;
                return;
            }
        }
    }
}
