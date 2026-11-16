using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using MimeKit;
using PostinoVip.Core.Html;
using PostinoVip.Core.Mime;
using PostinoVip.Core.Models;
using PostinoVip.Core.Texts;

namespace PostinoVip.Core.Compose;

/// <summary>Costruisce le bozze di risposta / rispondi a tutti / inoltro a partire dal messaggio originale.</summary>
public static partial class DraftBuilder
{

    /// <param name="ownAddress">Indirizzo dell'account: escluso dai destinatari di "rispondi a tutti".</param>
    /// QuoteHtml: anteprima formattata della citazione (3.7b); Body: la citazione in testo (app precedenti, testo normale).
    /// PlainText: l'originale non ha una parte HTML.
    public static ComposeDraft Build(MimeMessage original, DraftMode mode, string ownAddress) => (mode switch
    {
        DraftMode.Reply => Reply(original, ownAddress, all: false),
        DraftMode.ReplyAll => Reply(original, ownAddress, all: true),
        DraftMode.Forward => Forward(original),
        _ => throw new ArgumentOutOfRangeException(nameof(mode)),
    }) with { QuoteHtml = QuoteBuilder.DisplayHtml(original), PlainText = original.HtmlBody is null };

    /// <summary>Citazione in testo semplice da aggiungere sotto quello che si scrive (anche per la parte text/plain).</summary>
    public static string QuoteText(MimeMessage original, DraftMode mode) => mode == DraftMode.Forward
        ? ForwardText(original)
        : "\n\n" + QuoteHeader(original) + "\n" + Quote(BodyText(original));

    private static ComposeDraft Reply(MimeMessage original, string ownAddress, bool all)
    {
        bool IsOwn(MailboxAddress m) => m.Address.Equals(ownAddress, StringComparison.OrdinalIgnoreCase);

        // Reply-To ha la precedenza su From (liste di distribuzione, form di contatto...).
        var targets = (original.ReplyTo.Mailboxes.Any() ? original.ReplyTo : original.From).Mailboxes.ToList();

        // Risposta a un messaggio inviato da me (es. dalla posta inviata): si riscrive ai destinatari originali.
        if (targets.All(IsOwn))
            targets = original.To.Mailboxes.ToList();

        var to = new List<MailboxAddress>(targets);
        var cc = new List<MailboxAddress>();
        if (all)
        {
            to.AddRange(original.To.Mailboxes);
            cc.AddRange(original.Cc.Mailboxes);
        }

        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var toList = Distinct(to, seen, IsOwn);
        var ccList = Distinct(cc, seen, IsOwn);

        var references = original.References.ToList();
        if (!string.IsNullOrEmpty(original.MessageId) && !references.Contains(original.MessageId))
            references.Add(original.MessageId);

        return new ComposeDraft(
            toList,
            ccList,
            Prefix(original.Subject, CoreTexts.Get("replyPrefix"), ReplyPrefix()),
            QuoteText(original, DraftMode.Reply),
            string.IsNullOrEmpty(original.MessageId) ? null : original.MessageId,
            references);
    }

    private static ComposeDraft Forward(MimeMessage original) =>
        new([], [], Prefix(original.Subject, CoreTexts.Get("forwardPrefix"), ForwardPrefix()), ForwardText(original), null, [],
            Attachments.List(original));

    private static string ForwardText(MimeMessage original)
    {
        var sb = new StringBuilder();
        // Testi nella lingua dell'app (L6b, scelta 3a).
        sb.Append("\n\n").Append(CoreTexts.Get("forwardHeader")).Append('\n');
        sb.Append($"{CoreTexts.Get("labelFrom")} {original.From}\n");
        if (original.Date != DateTimeOffset.MinValue)
            sb.Append($"{CoreTexts.Get("labelDate")} {FormatDate(original.Date)}\n");
        sb.Append($"{CoreTexts.Get("labelSubject")} {original.Subject}\n");
        sb.Append($"{CoreTexts.Get("labelTo")} {original.To}\n");
        if (original.Cc.Count > 0)
            sb.Append($"{CoreTexts.Get("labelCc")} {original.Cc}\n");
        sb.Append('\n').Append(BodyText(original));
        return sb.ToString();
    }

    private static List<string> Distinct(IEnumerable<MailboxAddress> list, HashSet<string> seen, Func<MailboxAddress, bool> isOwn) =>
        list.Where(m => !isOwn(m) && seen.Add(m.Address)).Select(m => m.ToString()).ToList();

    private static string Prefix(string? subject, string prefix, Regex existing)
    {
        subject ??= "";
        return existing.IsMatch(subject) ? subject : prefix + subject;
    }

    private static string QuoteHeader(MimeMessage m)
    {
        var from = m.From.Mailboxes.FirstOrDefault()?.ToString() ?? CoreTexts.Get("unknownSender");
        return m.Date == DateTimeOffset.MinValue
            ? CoreTexts.Get("wrote", ("from", from))
            : CoreTexts.Get("wroteOn", ("date", FormatDate(m.Date)), ("from", from));
    }

    // Forma della lingua dell'app (Texts/*.json), senza cultura: il core gira con InvariantGlobalization, senza ICU.
    internal static string FormatDate(DateTimeOffset d) => CoreTexts.Date(d);

    /// <summary>Testo dell'originale: text/plain se c'è, altrimenti l'HTML convertito in testo.</summary>
    private static string BodyText(MimeMessage m)
    {
        if (!string.IsNullOrWhiteSpace(m.TextBody))
            return m.TextBody.TrimEnd();
        if (m.HtmlBody is not null)
            return HtmlText.ToPlainText(m.HtmlBody);
        return "";
    }

    private static string Quote(string text) =>
        string.Join("\n", text.ReplaceLineEndings("\n").Split('\n').Select(l => l.Length == 0 ? ">" : "> " + l));

    // Prefissi già presenti, in tutte le lingue (scelta 3a): inglesi (RE:, FW:, Fwd:), di Outlook in italiano (R:, I:),
    // tedeschi (AW:, WG:) e svedesi (SV:): non si raddoppiano.
    [GeneratedRegex(@"^\s*(re|r|aw|sv)\s*:", RegexOptions.IgnoreCase)]
    private static partial Regex ReplyPrefix();

    [GeneratedRegex(@"^\s*(fwd?|fw|i|wg)\s*:", RegexOptions.IgnoreCase)]
    private static partial Regex ForwardPrefix();
}
