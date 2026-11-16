using MimeKit;
using MimeKit.Utils;
using PostinoVip.Core.Compose;

namespace PostinoVip.Core.Mime;

/// <summary>
/// Conferme di lettura (R1, RFC 8098 «Message Disposition Notification»). Chiederla: intestazione
/// <c>Disposition-Notification-To</c> con l'indirizzo del mittente. Rispondere: una mail
/// <c>multipart/report; report-type=disposition-notification</c> con una parte leggibile e una
/// <c>message/disposition-notification</c>. La parola chiave IMAP <c>$MDNSent</c> (RFC 3503) segna sul server
/// che alla mail si è già risposto (inviata o rifiutata), così la domanda non torna, neanche da un altro computer.
/// </summary>
public static class ReadReceipts
{
    /// <summary>Chiede la conferma di lettura a chi riceve <paramref name="message"/>, verso <paramref name="from"/>.</summary>
    public static void Request(MimeMessage message, MailboxAddress from) =>
        message.Headers[HeaderId.DispositionNotificationTo] = new MailboxAddress(from.Name, from.Address).ToString();

    /// <summary>
    /// L'indirizzo a cui mandare la conferma, o null se non va chiesta all'utente: nessuna richiesta, più indirizzi,
    /// indirizzo diverso dal mittente (RFC 8098: così una mail non può usare chi la legge per scrivere a terzi), o la
    /// mail è essa stessa una conferma (mai rispondere a una conferma).
    /// </summary>
    public static MailboxAddress? RequestedBy(MimeMessage message)
    {
        if (message.Headers[HeaderId.DispositionNotificationTo] is not { } value)
            return null;
        if (!InternetAddressList.TryParse(value, out var list) || list.Mailboxes.Count() != 1)
            return null;
        var to = list.Mailboxes.Single();
        var from = message.From.Mailboxes.FirstOrDefault();
        if (from is null || !string.Equals(from.Address, to.Address, StringComparison.OrdinalIgnoreCase))
            return null;
        if (message.Body is MultipartReport { ReportType: var type }
            && string.Equals(type, "disposition-notification", StringComparison.OrdinalIgnoreCase))
            return null;
        return to;
    }

    /// <summary>
    /// La conferma di lettura per <paramref name="original"/>, da <paramref name="from"/> (l'account che l'ha letta).
    /// <paramref name="automatic"/>: inviata da sola per l'opzione «Invia sempre» (altrimenti scelta dall'utente).
    /// </summary>
    /// <exception cref="InvalidOperationException">La mail non chiede la conferma (vedi <see cref="RequestedBy"/>).</exception>
    public static MimeMessage Build(MimeMessage original, MailboxAddress from, bool automatic, string version, DateTimeOffset readAt)
    {
        var to = RequestedBy(original)
            ?? throw new InvalidOperationException("La mail non chiede una conferma di lettura a questo indirizzo.").WithCode("laMailNonChiedeUna");
        var receipt = new MimeMessage();
        receipt.From.Add(from);
        receipt.To.Add(to);
        receipt.Subject = Texts.CoreTexts.Get("readReceiptSubject") + (original.Subject ?? "");
        receipt.Date = readAt;
        // Come per le mail scritte: dominio del mittente, non il nome del PC.
        receipt.MessageId = MimeUtils.GenerateMessageId(from.Domain);
        if (!string.IsNullOrEmpty(original.MessageId))
        {
            receipt.InReplyTo = original.MessageId;
            receipt.References.Add(original.MessageId);
        }

        var recipients = string.Join("; ", original.To.Mailboxes.Concat(original.Cc.Mailboxes).Select(m => m.ToString()));
        // Testo nella lingua dell'app (L6b, scelta 2a: anche per le conferme inviate da sole).
        static string L(string key) => Texts.CoreTexts.Get(key);
        var text = L("readReceiptIntro") + "\r\n\r\n" +
                   $"  {L("labelTo")} {recipients}\r\n" +
                   $"  {L("labelSubject")} {original.Subject}\r\n" +
                   (original.Date == DateTimeOffset.MinValue ? "" : $"  {L("labelSent")} {DraftBuilder.FormatDate(original.Date)}\r\n") +
                   "\r\n" + Texts.CoreTexts.Get("readReceiptRead", ("date", DraftBuilder.FormatDate(readAt))) + "\r\n";

        var notification = new MessageDispositionNotification();
        notification.Fields.Add("Reporting-UA", $"PostinoVip; PostinoVip {version}");
        if (original.Headers["Original-Recipient"] is { } originalRecipient)
            notification.Fields.Add("Original-Recipient", originalRecipient);
        notification.Fields.Add("Final-Recipient", $"rfc822;{from.Address}");
        if (!string.IsNullOrEmpty(original.MessageId))
            notification.Fields.Add("Original-Message-ID", $"<{original.MessageId}>");
        notification.Fields.Add("Disposition", automatic
            ? "automatic-action/MDN-sent-automatically; displayed"
            : "manual-action/MDN-sent-manually; displayed");

        receipt.Body = new MultipartReport("disposition-notification")
        {
            new TextPart("plain") { Text = text },
            notification,
        };
        return receipt;
    }
}
