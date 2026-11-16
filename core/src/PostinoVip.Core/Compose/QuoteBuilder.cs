using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using MimeKit;
using PostinoVip.Core.Html;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Compose;

/// <summary>Immagine incorporata (multipart/related) di una mail in uscita, richiamata con "cid:".</summary>
public sealed record InlinePart(string ContentId, string ContentType, byte[] Data);

/// <summary>
/// Citazione dell'originale da aggiungere in fondo a una risposta o a un inoltro (scelta 3.7-6a):
/// testo per la parte text/plain, HTML ripulito per la parte text/html e le immagini incorporate
/// dell'originale richiamate dall'HTML.
/// </summary>
public sealed record MessageQuote(string Text, string Html, IReadOnlyList<InlinePart> Inline);

/// <summary>
/// Citazione formattata come Outlook: riga sottile, blocco Da / Inviato / A / Cc / Oggetto e sotto
/// l'originale com'era (HTML ripulito, oppure il testo semplice con gli a capo).
/// </summary>
public static partial class QuoteBuilder
{
    /// <summary>Per l'anteprima nell'app: immagini incorporate già come "data:" (come nel riquadro di lettura).</summary>
    public static string DisplayHtml(MimeMessage original) =>
        Header(original) + HtmlBodySanitizer.Sanitize(BodyHtml(original), HtmlBodySanitizer.InlineImages(original)).Html;

    /// <summary>Per l'invio: le immagini incorporate restano "cid:" e vengono allegate come parti collegate.</summary>
    public static MessageQuote ForSending(MimeMessage original, DraftMode mode)
    {
        var html = HtmlBodySanitizer.SanitizeForSending(BodyHtml(original));
        var referenced = CidReference().Matches(html).Select(m => m.Groups["id"].Value)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var inline = new List<InlinePart>();
        foreach (var part in original.BodyParts.OfType<MimePart>())
        {
            if (string.IsNullOrEmpty(part.ContentId) || part.Content is null || !referenced.Contains(part.ContentId))
                continue;
            using var ms = new MemoryStream();
            part.Content.DecodeTo(ms);
            inline.Add(new InlinePart(part.ContentId, part.ContentType.MimeType, ms.ToArray()));
        }
        return new MessageQuote(DraftBuilder.QuoteText(original, mode), Header(original) + html, inline);
    }

    /// <summary>
    /// Citazione già pronta, passata dall'app come HTML (bozza riaperta, 3.8: l'originale può non esserci più).
    /// Ripulita qui; le immagini "data:" le trasforma in parti il costruttore del messaggio.
    /// </summary>
    public static MessageQuote FromHtml(string html)
    {
        var clean = HtmlBodySanitizer.SanitizeForSending(html);
        return new MessageQuote("\n\n" + HtmlText.ToPlainText(clean).Trim(), clean, []);
    }

    /// <summary>Corpo dell'originale come HTML: quello della mail, altrimenti il testo con gli a capo.</summary>
    private static string BodyHtml(MimeMessage m)
    {
        if (m.HtmlBody is { } html)
            return html;
        // Un <br> per riga: lo stile white-space verrebbe tolto da HtmlSanitizer.
        var lines = (m.TextBody ?? "").TrimEnd().ReplaceLineEndings("\n").Split('\n').Select(WebUtility.HtmlEncode);
        return $"<div>{string.Join("<br>", lines)}</div>";
    }

    private static string Header(MimeMessage m)
    {
        static string E(string s) => WebUtility.HtmlEncode(s);
        var sb = new StringBuilder();
        sb.Append("<div style=\"border:none;border-top:solid #E1E1E1 1pt;padding:3pt 0 0 0;margin-top:12pt\">");
        sb.Append("<p style=\"margin:0 0 12pt 0\">");
        // Etichette nella lingua dell'app (L6b, scelta 3a), come l'intestazione della citazione di Outlook.
        static string L(string key) => $"<b>{WebUtility.HtmlEncode(Texts.CoreTexts.Get(key))}</b> ";
        sb.Append(L("labelFrom")).Append(E(m.From.ToString())).Append("<br>");
        if (m.Date != DateTimeOffset.MinValue)
            sb.Append(L("labelSent")).Append(E(DraftBuilder.FormatDate(m.Date))).Append("<br>");
        sb.Append(L("labelTo")).Append(E(m.To.ToString())).Append("<br>");
        if (m.Cc.Count > 0)
            sb.Append(L("labelCc")).Append(E(m.Cc.ToString())).Append("<br>");
        sb.Append(L("labelSubject")).Append(E(m.Subject ?? ""));
        sb.Append("</p></div>");
        return sb.ToString();
    }

    [GeneratedRegex(@"cid:(?<id>[^""'\s)>]+)", RegexOptions.IgnoreCase)]
    private static partial Regex CidReference();
}
