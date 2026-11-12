using System.Text;
using System.Text.RegularExpressions;
using AngleSharp.Dom;
using AngleSharp.Html.Parser;

namespace PostinoVip.Core.Html;

/// <summary>
/// Conversione HTML -> testo semplice per citare o inoltrare mail solo HTML.
/// Usa AngleSharp (già presente come dipendenza di HtmlSanitizer); va a capo sugli elementi di blocco.
/// </summary>
public static partial class HtmlText
{
    private static readonly HashSet<string> Block = new(StringComparer.OrdinalIgnoreCase)
    {
        "p", "div", "tr", "li", "ul", "ol", "table", "blockquote", "pre",
        "h1", "h2", "h3", "h4", "h5", "h6", "hr", "section", "article", "header", "footer",
    };

    private static readonly HashSet<string> Skip = new(StringComparer.OrdinalIgnoreCase) { "script", "style", "head", "title" };

    public static string ToPlainText(string html)
    {
        var document = new HtmlParser().ParseDocument(html);
        var sb = new StringBuilder();
        Append(document.Body ?? (INode)document, sb);

        var text = HorizontalSpace().Replace(sb.ToString(), " ");
        text = SpacesAroundNewline().Replace(text, "\n");
        text = ManyNewlines().Replace(text, "\n\n");
        return text.Trim();
    }

    private static void Append(INode node, StringBuilder sb)
    {
        foreach (var child in node.ChildNodes)
        {
            switch (child)
            {
                case IText text:
                    sb.Append(text.Data);
                    break;
                case IElement el when Skip.Contains(el.LocalName):
                    break;
                case IElement el when el.LocalName == "br":
                    sb.Append('\n');
                    break;
                case IElement el:
                    var block = Block.Contains(el.LocalName);
                    if (block) sb.Append('\n');
                    Append(el, sb);
                    if (block) sb.Append('\n');
                    break;
            }
        }
    }

    [GeneratedRegex(@"[ \t \r]+")]
    private static partial Regex HorizontalSpace();

    [GeneratedRegex(@" *\n *")]
    private static partial Regex SpacesAroundNewline();

    [GeneratedRegex(@"\n{3,}")]
    private static partial Regex ManyNewlines();
}
