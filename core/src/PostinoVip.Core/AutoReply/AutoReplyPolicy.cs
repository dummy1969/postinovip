using MimeKit;

namespace PostinoVip.Core.AutoReply;

/// <summary>
/// Quando NON rispondere (RFC 3834, sezioni 2 e 3.1), regole fisse: niente risposte a mailing list e messaggi di
/// massa, ad altre risposte automatiche, a mittenti di sistema (MAILER-DAEMON, noreply…), a sé stessi, a mail in
/// cui il proprio indirizzo non è in A o Cc, a chi ha già ricevuto la risposta.
/// </summary>
public static class AutoReplyPolicy
{
    private static readonly string[] SystemSenders =
        ["mailer-daemon", "postmaster", "noreply", "no-reply", "no_reply", "donotreply", "do-not-reply", "do_not_reply", "bounce", "bounces"];

    /// <summary>A chi rispondere (indirizzo del mittente); null = non rispondere, con il motivo in <paramref name="reason"/>.</summary>
    public static string? Recipient(MimeMessage m, string ownAddress, IReadOnlyCollection<string> alreadyReplied, out string reason)
    {
        var auto = m.Headers[HeaderId.AutoSubmitted];
        if (auto is not null && !auto.Trim().StartsWith("no", StringComparison.OrdinalIgnoreCase))
            return Skip(out reason, "risposta o messaggio automatico");
        var precedence = m.Headers["Precedence"]?.Trim().ToLowerInvariant();
        if (precedence is "bulk" or "list" or "junk")
            return Skip(out reason, "messaggio di massa");
        if (m.Headers.Contains("List-Id") || m.Headers.Contains("List-Unsubscribe") || m.Headers.Contains("List-Post"))
            return Skip(out reason, "mailing list");
        var suppress = m.Headers["X-Auto-Response-Suppress"];
        if (suppress is not null && (suppress.Contains("OOF", StringComparison.OrdinalIgnoreCase) || suppress.Contains("All", StringComparison.OrdinalIgnoreCase)))
            return Skip(out reason, "il mittente chiede di non rispondere");
        if (m.Headers[HeaderId.ReturnPath]?.Trim() is "<>")
            return Skip(out reason, "mittente vuoto (avviso di sistema)");

        var from = m.From.Mailboxes.FirstOrDefault()?.Address?.Trim();
        if (string.IsNullOrEmpty(from) || !from.Contains('@'))
            return Skip(out reason, "senza mittente");
        var local = from[..from.IndexOf('@')].ToLowerInvariant();
        if (SystemSenders.Any(s => local == s || local.StartsWith(s + "+", StringComparison.Ordinal) || local.StartsWith(s + "-", StringComparison.Ordinal)))
            return Skip(out reason, "mittente di sistema");
        if (string.Equals(from, ownAddress, StringComparison.OrdinalIgnoreCase))
            return Skip(out reason, "mandata da me");
        var mine = m.To.Mailboxes.Concat(m.Cc.Mailboxes).Any(a => string.Equals(a.Address, ownAddress, StringComparison.OrdinalIgnoreCase));
        if (!mine)
            return Skip(out reason, "il mio indirizzo non è in A o Cc");
        if (alreadyReplied.Contains(from, StringComparer.OrdinalIgnoreCase))
            return Skip(out reason, "risposta già inviata");
        reason = "";
        return from;
    }

    private static string? Skip(out string reason, string why)
    {
        reason = why;
        return null;
    }

    /// <summary>
    /// La risposta: "Risposta automatica: …", collegata all'originale, con Auto-Submitted: auto-replied (RFC 3834) e
    /// X-Auto-Response-Suppress: All, così gli altri programmi non rispondono a loro volta.
    /// </summary>
    public static MimeMessage Build(MimeMessage original, string from, string to, AutoReplySettings settings)
    {
        var subject = original.Subject ?? "";
        var references = original.References.Concat(original.MessageId is { } id ? [id] : []).ToList();
        var message = Smtp.MimeMessageBuilder.Build(new Models.OutgoingMessage(
            from, [to], [], "Risposta automatica: " + subject,
            string.IsNullOrWhiteSpace(settings.Text) ? Html.HtmlText.ToPlainText(settings.Html) : settings.Text,
            InReplyTo: original.MessageId, References: references,
            HtmlBody: string.IsNullOrWhiteSpace(settings.Html) ? null : settings.Html));
        message.Headers.Add(HeaderId.AutoSubmitted, "auto-replied");
        message.Headers.Add("X-Auto-Response-Suppress", "All");
        return message;
    }
}
