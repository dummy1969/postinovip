using AngleSharp.Html.Parser;
using MimeKit;
using PostinoVip.Core.Html;
using PostinoVip.Core.Mime;
using PostinoVip.Core.Models;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Compose;

/// <summary>
/// Riapre una bozza nella composizione (3.8): destinatari, oggetto, testo scritto e citazione separati grazie
/// al contenitore <see cref="MimeMessageBuilder.BodyElementId"/>; una bozza di un altro programma entra intera.
/// </summary>
public static class ComposeReader
{
    public static ComposeContent Read(MimeMessage m)
    {
        string? html = null;
        string? quote = null;
        if (m.HtmlBody is { } source)
        {
            var images = HtmlBodySanitizer.InlineImages(m);
            var document = new HtmlParser().ParseDocument(source);
            if (document.GetElementById(MimeMessageBuilder.BodyElementId) is { } written)
            {
                html = HtmlBodySanitizer.Sanitize(written.InnerHtml, images).Html;
                written.Remove();
                var rest = document.Body?.InnerHtml.Trim() ?? "";
                quote = rest.Length == 0 ? null : HtmlBodySanitizer.Sanitize(rest, images).Html;
            }
            else
            {
                html = HtmlBodySanitizer.Sanitize(source, images).Html;
            }
        }

        return new ComposeContent(
            m.To.Mailboxes.Select(Address).ToList(),
            m.Cc.Mailboxes.Select(Address).ToList(),
            m.Subject ?? "",
            html,
            html is null ? (m.TextBody ?? "").TrimEnd() : "",
            string.IsNullOrEmpty(m.InReplyTo) ? null : m.InReplyTo,
            m.References.ToList(),
            quote,
            Attachments.List(m),
            m.Bcc.Mailboxes.Select(Address).ToList(),
            MailImportanceHeaders.From(m.Headers),
            m.Headers.Contains(HeaderId.DispositionNotificationTo));
    }

    // Indirizzo di una bozza scritto male (senza dominio): resta il testo, da correggere prima dell'invio.
    private static string Address(MailboxAddress a) => a.Address.Contains('@') ? a.ToString() : a.Address;
}
