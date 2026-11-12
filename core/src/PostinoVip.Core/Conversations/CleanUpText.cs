using System.Text;
using MimeKit;
using MimeKit.Cryptography;
using PostinoVip.Core.Html;

namespace PostinoVip.Core.Conversations;

/// <summary>
/// Pulisci conversazione (2b): una mail è superflua se una risposta diretta la cita per intero. «Per intero» = tutto
/// il testo scritto nella mail (le sue righe che iniziano con «>» sono citazioni di altre mail e non contano) compare
/// nel testo della risposta. Il confronto guarda solo lettere e cifre, in minuscolo, con un solo spazio tra le parole:
/// gli a capo rifatti, i «>» davanti alle righe citate e la punteggiatura cambiata dal programma di chi risponde non
/// impediscono di riconoscerla. Se la risposta ne ha tolto o cambiato un pezzo, la mail non è superflua.
/// </summary>
public static class CleanUpText
{
    /// <summary>Oltre questa lunghezza (normalizzata) la mail non si confronta: resta dov'è.</summary>
    public const int MaxLength = 64 * 1024;

    /// <summary>true se il testo scritto in <paramref name="original"/> compare per intero in <paramref name="reply"/>.</summary>
    public static bool IsQuotedIn(MimeMessage original, MimeMessage reply)
    {
        var own = Normalize(Body(original), skipQuoted: true);
        if (own.Length == 0 || own.Length > MaxLength)
            return false; // senza testo proprio non si può dire che sia citata
        // Spazi ai lati: parole intere («ciao» non è citata in «ciaone»).
        return $" {Normalize(Body(reply), skipQuoted: false)} ".Contains($" {own} ", StringComparison.Ordinal);
    }

    /// <summary>Mail con firma digitale o cifrata (S/MIME, PGP/MIME): non si sposta mai.</summary>
    public static bool IsSigned(MimeMessage message) =>
        message.Body is MultipartSigned or MultipartEncrypted or ApplicationPkcs7Mime;

    private static string Body(MimeMessage message)
    {
        var text = message.TextBody;
        if (string.IsNullOrWhiteSpace(text) && message.HtmlBody is { } html)
            text = HtmlText.ToPlainText(html);
        return text ?? "";
    }

    /// <summary>Lettere e cifre in minuscolo separate da un solo spazio; con <paramref name="skipQuoted"/> senza le righe «>».</summary>
    public static string Normalize(string text, bool skipQuoted)
    {
        var result = new StringBuilder(text.Length);
        foreach (var line in text.Split('\n'))
        {
            if (skipQuoted && line.TrimStart().StartsWith('>'))
                continue;
            foreach (var c in line)
            {
                if (char.IsLetterOrDigit(c))
                    result.Append(char.ToLowerInvariant(c));
                else if (result.Length > 0 && result[^1] != ' ')
                    result.Append(' ');
            }
            if (result.Length > 0 && result[^1] != ' ')
                result.Append(' ');
        }
        return result.ToString().Trim();
    }
}
