using System.Text.RegularExpressions;
using MimeKit;
using MimeKit.Utils;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Html;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Smtp;

/// <summary>Costruisce il MimeMessage da inviare; separato dal servizio per poterlo testare senza rete.</summary>
public static partial class MimeMessageBuilder
{
    // Il parser predefinito di MimeKit è permissivo (accetta anche testo malformato):
    // per gli indirizzi digitati dall'utente si usa la modalità rigorosa.
    private static readonly ParserOptions StrictOptions = new()
    {
        AddressParserComplianceMode = RfcComplianceMode.Strict,
    };

    /// <summary>Limite di 25 MB sul totale degli allegati (scelta dell'utente: compatibilità con i provider più diffusi).</summary>
    public const long MaxAttachmentBytes = 25L * 1024 * 1024;

    /// <summary>
    /// Contenitore del testo scritto nell'HTML (3.8): riaprendo una bozza il core separa così quello che si è
    /// scritto dalla citazione. Fuori dal testo ripulito: HtmlSanitizer toglierebbe l'id.
    /// </summary>
    public const string BodyElementId = "postinovip-body";

    /// <param name="draft">Bozza (3.8): destinatari facoltativi e indirizzi non ancora corretti accettati così come sono.</param>
    /// <exception cref="InvalidAddressException">Indirizzo non valido o nessun destinatario.</exception>
    /// <exception cref="FieldValidationException">Allegati oltre il limite (campo "attachments").</exception>
    public static MimeMessage Build(OutgoingMessage msg, bool draft = false)
    {
        // Basta un destinatario in A, Cc o Ccn (come Outlook: si può inviare anche solo in copia nascosta).
        if (msg.To.Count == 0 && msg.Cc.Count == 0 && (msg.Bcc?.Count ?? 0) == 0 && !draft)
            throw new InvalidAddressException("to", "Indicare almeno un destinatario.");

        var message = new MimeMessage();
        var from = ParseAddress("from", msg.From);
        message.From.Add(from);

        // Il Message-ID predefinito di MimeKit usa il nome del PC come dominio (lo rivelerebbe ai
        // destinatari): si usa il dominio del mittente. Fissato qui, prima dell'invio, è lo stesso
        // nella mail ricevuta e nella copia in Posta inviata.
        message.MessageId = MimeUtils.GenerateMessageId(from.Domain);
        foreach (var to in msg.To)
            message.To.Add(draft ? DraftAddress(to) : ParseAddress("to", to));
        foreach (var cc in msg.Cc)
            message.Cc.Add(draft ? DraftAddress(cc) : ParseAddress("cc", cc));
        foreach (var bcc in msg.Bcc ?? [])
            message.Bcc.Add(draft ? DraftAddress(bcc) : ParseAddress("bcc", bcc));

        // Collegamento al thread: i client raggruppano le risposte usando queste intestazioni.
        if (!string.IsNullOrWhiteSpace(msg.InReplyTo))
            message.InReplyTo = msg.InReplyTo;
        foreach (var reference in msg.References ?? [])
            message.References.Add(reference);

        message.Subject = msg.Subject;
        message.Date = DateTimeOffset.Now;
        MailImportanceHeaders.Apply(message, msg.Importance);
        // «Richiedi conferma di lettura» (R1): al mittente stesso; anche nelle bozze, per riaprirle con la scelta.
        if (msg.ReadReceipt)
            Mime.ReadReceipts.Request(message, from);
        var attachments = msg.Attachments ?? [];
        var text = msg.Body + (msg.Quote?.Text ?? "");
        if (attachments.Count == 0 && msg.HtmlBody is null)
        {
            message.Body = new TextPart("plain") { Text = text };
            return message;
        }

        // Testo formattato (3.7b): HTML ripulito, immagini incollate ("data:") trasformate in parti
        // collegate, citazione dell'originale in fondo con le sue immagini incorporate.
        string? html = null;
        var inline = new List<InlinePart>(msg.Quote?.Inline ?? []);
        if (msg.HtmlBody is not null)
        {
            string Embed(string clean) => DataImage().Replace(clean, m =>
            {
                var id = MimeUtils.GenerateMessageId(from.Domain);
                inline.Add(new InlinePart(id, m.Groups["type"].Value, Convert.FromBase64String(m.Groups["data"].Value)));
                return $"src=\"cid:{id}\"";
            });
            var written = Embed(HtmlBodySanitizer.SanitizeForSending(msg.HtmlBody));
            // Citazione passata come HTML (bozza riaperta): le sue immagini "data:" diventano parti anch'esse.
            var quoteHtml = msg.Quote is null ? "" : Embed(msg.Quote.Html);
            html = "<html><head><meta charset=\"utf-8\"></head><body>" + $"<div id=\"{BodyElementId}\">" + written + "</div>"
                   + quoteHtml + "</body></html>";
        }

        var totalBytes = attachments.Sum(a => (long)a.Data.Length) + inline.Sum(i => (long)i.Data.Length);
        if (totalBytes > MaxAttachmentBytes)
            throw new FieldValidationException("attachments",
                $"Allegati troppo grandi: {totalBytes / 1048576.0:0.0} MB, massimo {MaxAttachmentBytes / 1048576} MB.");

        // multipart/mixed: testo (o multipart/alternative testo + HTML, con le immagini in multipart/related)
        // e allegati, codificati in base64 da MimeKit.
        var builder = new BodyBuilder { TextBody = text, HtmlBody = html };
        foreach (var part in inline)
        {
            var resource = builder.LinkedResources.Add("immagine", part.Data, ContentType.Parse(part.ContentType));
            resource.ContentId = part.ContentId;
            resource.ContentDisposition = new ContentDisposition(ContentDisposition.Inline);
        }
        foreach (var a in attachments)
        {
            var name = SafeName(a.FileName);
            builder.Attachments.Add(name, a.Data, ParseContentType(a.ContentType, name));
        }
        message.Body = builder.ToMessageBody();
        return message;
    }

    // Dopo HtmlSanitizer gli attributi sono tra doppi apici.
    [GeneratedRegex(@"src=""data:(?<type>image/[a-z0-9.+-]+);base64,(?<data>[A-Za-z0-9+/=\s]+)""", RegexOptions.IgnoreCase)]
    private static partial Regex DataImage();

    // Il nome arriva dall'app (o da una mail inoltrata): niente percorsi, solo il nome del file.
    private static string SafeName(string fileName)
    {
        var name = fileName.Split('/', '\\').Last().Trim();
        return name.Length == 0 ? "allegato" : name;
    }

    private static ContentType ParseContentType(string? declared, string fileName)
    {
        if (!string.IsNullOrWhiteSpace(declared) && ContentType.TryParse(declared, out var parsed))
            return parsed;
        return ContentType.Parse(MimeTypes.GetMimeType(fileName)); // application/octet-stream se sconosciuta
    }

    /// <summary>Indirizzo di una bozza: valido se possibile, altrimenti il testo così com'è (si correggerà prima dell'invio).</summary>
    private static MailboxAddress DraftAddress(string text) =>
        MailboxAddress.TryParse(StrictOptions, text, out var address) ? address : new MailboxAddress("", text.Trim());

    private static MailboxAddress ParseAddress(string field, string text)
    {
        MailboxAddress address;
        try
        {
            address = MailboxAddress.Parse(StrictOptions, text);
        }
        catch (ParseException ex)
        {
            throw new InvalidAddressException(field, $"Indirizzo non valido: {text}", ex);
        }

        // RFC 5322 ammette anche la sola parte locale ("mario"): per l'invio serve il dominio.
        if (!address.Address.Contains('@'))
            throw new InvalidAddressException(field, $"Indirizzo senza dominio: {text}");

        return address;
    }
}
