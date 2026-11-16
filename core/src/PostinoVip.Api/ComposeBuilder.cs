using MimeKit;
using PostinoVip.Api.Contracts;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Eml;
using PostinoVip.Core.Mime;
using PostinoVip.Core.Models;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Api;

/// <summary>
/// Costruisce il messaggio MIME di una mail scritta nell'app (invio, bozza, Posta in uscita, 3.8): allegati
/// dal disco e ripresi dall'originale, citazione dall'originale o già pronta. Gli originali si leggono dalla
/// casella in cui stanno (possono essere di un altro account); senza connessione dalla copia locale.
/// </summary>
public static class ComposeBuilder
{
    public static async Task<MimeMessage> BuildAsync(MailAccount account, Func<string, MailAccount> accountById,
        ComposeRequest request, bool draft, CancellationToken ct, EmlStore? eml = null)
    {
        var attachments = request.Attachments
            .Select(a => new OutgoingAttachment(a.FileName, a.ContentType, a.Data))
            .ToList();
        if (request.ForwardAttachments is { Indexes.Count: > 0 } fwd)
        {
            IReadOnlyList<AttachmentContent> original;
            if (fwd.Eml is { } emlId)
            {
                // Inoltro di un file .eml aperto (E1).
                var file = OpenEml(eml, emlId, "forwardAttachments");
                original = fwd.Indexes
                    .Select(i => Attachments.Extract(file, i) ?? throw new MailNotFoundException($"Allegato {i} non trovato.").WithCode("allegatoNonTrovato", ("i", i)))
                    .ToList();
            }
            else
            {
                if (string.IsNullOrEmpty(fwd.Folder))
                    throw new FieldValidationException("forwardAttachments", "Indicare la cartella del messaggio originale.").WithCode("indicareLaCartellaDelMessaggio");
                var source = fwd.Account is null ? account : accountById(fwd.Account);
                original = await source.Reader.GetAttachmentsAsync(fwd.Folder, fwd.Uid, fwd.Indexes, ct); // JSON: nessuna decodifica %2F
            }
            attachments.AddRange(original.Select(a => new OutgoingAttachment(a.FileName, a.ContentType, a.Data)));
        }

        MessageQuote? quote = null;
        if (request.Quote is { } q)
        {
            if (q.Html is { } html)
            {
                quote = QuoteBuilder.FromHtml(html);
            }
            else
            {
                if (string.IsNullOrEmpty(q.Folder) && q.Eml is null)
                    throw new FieldValidationException("quote", "Indicare la cartella del messaggio originale.").WithCode("indicareLaCartellaDelMessaggio");
                if (!Enum.TryParse<DraftMode>(q.Mode, ignoreCase: true, out var mode) || !Enum.IsDefined(mode))
                    throw new FieldValidationException("quote", $"Modalità non valida: {q.Mode} (reply, replyAll, forward).").WithCode("modalitaNonValidaReplyReplyall", ("mode", q.Mode));
                if (q.Eml is { } emlId)
                {
                    quote = QuoteBuilder.ForSending(OpenEml(eml, emlId, "quote"), mode);
                }
                else
                {
                    var source = q.Account is null ? account : accountById(q.Account);
                    quote = await source.Reader.GetQuoteAsync(q.Folder!, q.Uid, mode, ct);
                }
            }
        }

        var msg = new OutgoingMessage(account.Address, Clean(request.To), Clean(request.Cc), request.Subject, request.Body,
            request.InReplyTo, Clean(request.References), attachments, request.HtmlBody, quote, Clean(request.Bcc),
            request.Importance, request.ReadReceipt);
        return MimeMessageBuilder.Build(msg, draft);
    }

    private static MimeMessage OpenEml(EmlStore? eml, string id, string field) =>
        eml is null
            ? throw new FieldValidationException(field, "File .eml non disponibili qui.")
            : eml.Get(id);

    // Spazi attorno agli indirizzi e voci vuote (es. virgola finale) non sono errori.
    public static List<string> Clean(List<string> addresses) =>
        addresses.Select(a => a.Trim()).Where(a => a.Length > 0).ToList();
}
