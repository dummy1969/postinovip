using System.Text.RegularExpressions;
using Ganss.Xss;
using MimeKit;

namespace PostinoVip.Core.Html;

/// <summary>HTML ripulito e se contiene ancora riferimenti a immagini remote (bloccate di default dall'app).</summary>
public sealed record SanitizedHtml(string Html, bool HasRemoteImages);

/// <summary>
/// Rende sicuro l'HTML di una mail prima di passarlo alla UI:
/// - toglie script, iframe, form, handler on* e tutto ciò che non è in whitelist (HtmlSanitizer);
/// - sostituisce le immagini inline "cid:" con URI "data:" ricavati dalle parti MIME;
/// - segnala la presenza di immagini remote (usate anche per tracciare l'apertura).
/// </summary>
public static partial class HtmlBodySanitizer
{
    public static SanitizedHtml Sanitize(string html, IReadOnlyDictionary<string, string>? inlineImages = null)
    {
        if (inlineImages is { Count: > 0 })
            html = CidReference().Replace(html, m =>
                inlineImages.TryGetValue(m.Groups["id"].Value, out var dataUri) ? dataUri : m.Value);

        var sanitizer = CreateSanitizer();
        var clean = sanitizer.Sanitize(html);
        return new SanitizedHtml(clean, RemoteImage().IsMatch(clean));
    }

    /// <summary>Content-ID (senza &lt; &gt;) -> data URI per le immagini incorporate nel messaggio.</summary>
    public static IReadOnlyDictionary<string, string> InlineImages(MimeMessage message)
    {
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var part in message.BodyParts.OfType<MimePart>())
        {
            if (string.IsNullOrEmpty(part.ContentId) || part.Content is null
                || !part.ContentType.MediaType.Equals("image", StringComparison.OrdinalIgnoreCase))
                continue;

            using var ms = new MemoryStream();
            part.Content.DecodeTo(ms);
            result[part.ContentId] = $"data:{part.ContentType.MimeType};base64,{Convert.ToBase64String(ms.ToArray())}";
        }
        return result;
    }

    /// <summary>
    /// HTML in uscita (scritto nell'app o citazione dell'originale): stesse regole della lettura, ma le
    /// immagini incorporate restano "cid:" (e "data:" per quelle incollate, che il core trasforma in parti).
    /// </summary>
    public static string SanitizeForSending(string html)
    {
        var sanitizer = CreateSanitizer();
        sanitizer.AllowedSchemes.Add("cid");
        return sanitizer.Sanitize(html);
    }

    private static HtmlSanitizer CreateSanitizer()
    {
        // Istanza nuova per chiamata: la configurazione è mutabile, così non si condivide stato tra richieste.
        var sanitizer = new HtmlSanitizer();
        sanitizer.AllowedSchemes.Add("mailto");
        sanitizer.AllowedSchemes.Add("data"); // immagini inline già convertite

        // Elementi interattivi: in una mail non servono e possono simulare moduli di login.
        foreach (var tag in new[] { "form", "input", "button", "select", "option", "textarea", "label", "fieldset", "legend" })
            sanitizer.AllowedTags.Remove(tag);

        // "display" sulle parti di una tabella (es. <td style="display: block">, usato da molte newsletter per
        // centrare il contenuto): il visualizzatore HTML dell'app (flutter_widget_from_html_core 0.17.4) non
        // disegna più nulla della tabella, cioè di solito l'intera mail. Le celle restano celle.
        // "min-width" sulle tabelle (le mail di Google: <table style="max-width: 516px; min-width: 220px"> con le
        // colonnine vuote da 8 px ai lati): il visualizzatore divide la larghezza minima in parti uguali tra tutte le
        // colonne e non misura più il contenuto, e il testo finisce in una colonna di 30-70 px, una sillaba per riga.
        // Senza "min-width" misura le celle e la tabella si allarga fino a "max-width" come in un browser.
        sanitizer.PostProcessNode += (_, e) =>
        {
            if (e.Node is not AngleSharp.Dom.IElement element || !TableParts.Contains(element.LocalName))
                return;
            RemoveStyleProperty(element, DisplayProperty());
            if (element.LocalName == "table")
                RemoveStyleProperty(element, MinWidthProperty());
        };
        return sanitizer;
    }

    private static void RemoveStyleProperty(AngleSharp.Dom.IElement element, Regex property)
    {
        if (element.GetAttribute("style") is not { } style || !property.IsMatch(style))
            return;
        var cleaned = property.Replace(style, "").Trim().TrimEnd(';').Trim();
        if (cleaned.Length == 0)
            element.RemoveAttribute("style");
        else
            element.SetAttribute("style", cleaned);
    }

    private static readonly HashSet<string> TableParts = ["table", "thead", "tbody", "tfoot", "tr", "td", "th"];

    [GeneratedRegex(@"(?<![\w-])display\s*:\s*[^;]*;?", RegexOptions.IgnoreCase)]
    private static partial Regex DisplayProperty();

    [GeneratedRegex(@"(?<![\w-])min-width\s*:\s*[^;]*;?", RegexOptions.IgnoreCase)]
    private static partial Regex MinWidthProperty();

    [GeneratedRegex(@"cid:(?<id>[^""'\s)>]+)", RegexOptions.IgnoreCase)]
    private static partial Regex CidReference();

    // L'output di HtmlSanitizer è normalizzato: attributi tra doppi apici e, dentro style,
    // virgolette codificate come &quot; (es. url(&quot;http://...&quot;)).
    [GeneratedRegex(@"(src=""\s*https?:|url\(\s*(&quot;|')?\s*https?:)", RegexOptions.IgnoreCase)]
    private static partial Regex RemoteImage();
}
