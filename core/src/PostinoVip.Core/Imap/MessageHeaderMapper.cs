using MailKit;
using MimeKit;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Html;
using PostinoVip.Core.Mime;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Imap;

/// <summary>Converte i tipi MailKit/MimeKit nei modelli del core.</summary>
public static class MessageHeaderMapper
{
    public static MessageHeader FromEnvelope(UniqueId uid, Envelope? envelope, MessageFlags? flags = null,
        IEnumerable<string>? keywords = null)
    {
        var f = ToMailFlags(flags, keywords);
        return new MessageHeader(uid.Id, SubjectOrDefault(envelope?.Subject), FromOrDefault(envelope?.From), envelope?.Date,
            f.HasFlag(MailFlags.Seen), Flagged: f.HasFlag(MailFlags.Flagged), Completed: f.HasFlag(MailFlags.Completed),
            Categories: MailKeywords.CategoryNumbers(f));
    }

    /// <summary>Riga della cache da un FETCH (ENVELOPE, FLAGS, RFC822.SIZE, INTERNALDATE).</summary>
    public static HeaderRecord ToRecord(IMessageSummary s)
    {
        var env = s.Envelope;
        var from = env?.From.Mailboxes.FirstOrDefault();
        return new HeaderRecord(
            s.UniqueId.Id,
            ToMailFlags(s.Flags, s.Keywords),
            env?.Subject,
            string.IsNullOrWhiteSpace(from?.Name) ? null : from.Name,
            from?.Address,
            JoinAddresses(env?.To),
            JoinAddresses(env?.Cc),
            env?.Date,
            s.InternalDate,
            s.Size,
            env?.MessageId,
            env?.InReplyTo,
            s.PreviewText is null ? null : CleanPreview(s.PreviewText),
            HasAttachments(s),
            References: s.Fields.HasFlag(MessageSummaryItems.References) ? ConversationIds.Join(s.References) : null,
            Importance: s.Headers is null ? null : MailImportanceHeaders.From(s.Headers));
    }

    /// <summary>Lunghezza massima dell'anteprima salvata (la lista ne mostra una riga).</summary>
    public const int PreviewLength = 200;

    /// <summary>Anteprima su una riga: spazi e a capo ridotti a uno spazio, al massimo <see cref="PreviewLength"/> caratteri.</summary>
    public static string CleanPreview(string? text)
    {
        var clean = string.Join(' ', (text ?? "").Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
        return clean.Length <= PreviewLength ? clean : clean[..PreviewLength];
    }

    /// <summary>Allegati secondo la struttura (BODYSTRUCTURE); null se la struttura non è stata chiesta.</summary>
    public static bool? HasAttachments(IMessageSummary s) => s.Body is null ? null : s.Attachments.Any();

    /// <summary>Intestazione per la lista da una riga della cache: stesse regole di FromEnvelope.</summary>
    public static MessageHeader FromRecord(HeaderRecord r)
    {
        var from = r.FromName ?? r.FromAddress ?? "(mittente sconosciuto)";
        var flagged = r.Flags.HasFlag(MailFlags.Flagged);
        return new MessageHeader(r.Uid, SubjectOrDefault(r.Subject), from, r.Date, r.Flags.HasFlag(MailFlags.Seen),
            r.Preview, r.HasAttachments, r.InternalDate ?? r.Date,
            flagged, r.Flags.HasFlag(MailFlags.Completed), flagged ? r.FlagDue : null, MailKeywords.CategoryNumbers(r.Flags), r.Size,
            r.Importance ?? MailImportance.Normal);
    }

    /// <summary>Flag di sistema e parole chiave conosciute (<see cref="MailKeywords"/>); le altre parole chiave sono ignorate.</summary>
    public static MailFlags ToMailFlags(MessageFlags? flags, IEnumerable<string>? keywords = null)
    {
        var f = flags ?? MessageFlags.None;
        var result = MailKeywords.FromKeywords(keywords);
        if (f.HasFlag(MessageFlags.Seen)) result |= MailFlags.Seen;
        if (f.HasFlag(MessageFlags.Answered)) result |= MailFlags.Answered;
        if (f.HasFlag(MessageFlags.Flagged)) result |= MailFlags.Flagged;
        if (f.HasFlag(MessageFlags.Deleted)) result |= MailFlags.Deleted;
        if (f.HasFlag(MessageFlags.Draft)) result |= MailFlags.Draft;
        return result;
    }

    public static string? JoinAddresses(InternetAddressList? list)
    {
        var mailboxes = list?.Mailboxes.Select(m => m.ToString()).ToList();
        return mailboxes is null || mailboxes.Count == 0 ? null : string.Join(", ", mailboxes);
    }

    public static MessageDetail FromMimeMessage(UniqueId uid, MimeMessage message)
    {
        var html = message.HtmlBody is null
            ? null
            : HtmlBodySanitizer.Sanitize(message.HtmlBody, HtmlBodySanitizer.InlineImages(message));

        return new MessageDetail(
            uid.Id,
            SubjectOrDefault(message.Subject),
            FromOrDefault(message.From),
            message.To.Mailboxes.Select(m => m.ToString()).ToList(),
            message.Cc.Mailboxes.Select(m => m.ToString()).ToList(),
            message.Date == DateTimeOffset.MinValue ? null : message.Date,
            message.TextBody,
            html?.Html,
            html?.HasRemoteImages ?? false,
            Attachments.List(message),
            FromAddress: message.From.Mailboxes.FirstOrDefault()?.Address,
            Importance: MailImportanceHeaders.From(message.Headers),
            ReceiptTo: ReadReceipts.RequestedBy(message)?.Address);
    }

    private static string SubjectOrDefault(string? subject) =>
        string.IsNullOrWhiteSpace(subject) ? "(nessun oggetto)" : subject;

    // Preferisce il nome visualizzato; se manca usa l'indirizzo.
    private static string FromOrDefault(InternetAddressList? from)
    {
        var sender = from?.Mailboxes.FirstOrDefault();
        if (sender is null)
            return "(mittente sconosciuto)";
        return string.IsNullOrWhiteSpace(sender.Name) ? sender.Address : sender.Name;
    }
}
