using System.Globalization;
using System.Text.RegularExpressions;
using MimeKit;

namespace PostinoVip.Core.Junk;

/// <summary>Perché una mail è (o non è) posta indesiderata. Va nel log al posto degli indirizzi.</summary>
public enum JunkReason
{
    /// <summary>Nessun motivo per spostarla.</summary>
    None,
    Self,
    SafeSender,
    Contact,
    SafeRecipient,
    BlockedSender,
    ServerSpam,
    ServerScore,
    NotInSafeLists,
}

public sealed record JunkVerdict(bool IsJunk, JunkReason Reason);

/// <summary>Giudizio del server scritto nella mail: segnata come spam, punteggio e soglia (null se assenti).</summary>
public sealed record ServerSpamMark(bool Spam, double? Score, double? Required);

/// <summary>
/// Decide se una mail nuova è posta indesiderata, nell'ordine di Outlook: prima gli attendibili (il proprio
/// indirizzo, i mittenti attendibili, i contatti se scelto, i destinatari attendibili), poi i mittenti bloccati,
/// poi il livello del filtro (scelta 2a: sul giudizio del server). Funzione pura: nessun accesso alla casella.
/// </summary>
public static partial class JunkClassifier
{
    /// <summary>
    /// Livello «Alta»: indesiderata anche una mail con punteggio almeno pari alla soglia meno questo margine
    /// (con SpamAssassin di serie, soglia 5,0: da 3,0 in su). Scelta di dettaglio, da confermare.
    /// </summary>
    public const double HighMargin = 2.0;

    public static JunkVerdict Classify(MimeMessage message, JunkSettings settings, string accountAddress,
        Func<string, bool>? isContact = null)
    {
        var sender = SenderAddress(message);
        if (sender is not null && string.Equals(sender, accountAddress, StringComparison.OrdinalIgnoreCase))
            return new(false, JunkReason.Self);
        if (sender is not null && Matches(settings.SafeSenders, sender))
            return new(false, JunkReason.SafeSender);
        if (sender is not null && settings.TrustContacts && isContact?.Invoke(sender) == true)
            return new(false, JunkReason.Contact);
        if (RecipientAddresses(message).Any(r => Matches(settings.SafeRecipients, r)))
            return new(false, JunkReason.SafeRecipient);
        if (sender is not null && Matches(settings.BlockedSenders, sender))
            return new(true, JunkReason.BlockedSender);

        switch (settings.Level)
        {
            case JunkLevel.SafeListsOnly:
                return new(true, JunkReason.NotInSafeLists);
            case JunkLevel.Low or JunkLevel.High:
                var mark = ServerMark(message);
                if (mark.Spam)
                    return new(true, JunkReason.ServerSpam);
                if (settings.Level == JunkLevel.High && mark is { Score: { } score, Required: { } required } && score >= required - HighMargin)
                    return new(true, JunkReason.ServerScore);
                return new(false, JunkReason.None);
            default:
                return new(false, JunkReason.None);
        }
    }

    /// <summary>Indirizzo del mittente (il primo di From), in minuscolo; null se manca.</summary>
    public static string? SenderAddress(MimeMessage message) =>
        message.From.Mailboxes.FirstOrDefault()?.Address is { Length: > 0 } a ? a.ToLowerInvariant() : null;

    /// <summary>Destinatari (A e Cc) e l'indirizzo della mailing list (List-Post: mailto), in minuscolo.</summary>
    public static IEnumerable<string> RecipientAddresses(MimeMessage message) =>
        message.To.Mailboxes.Concat(message.Cc.Mailboxes).Select(m => m.Address.ToLowerInvariant())
            .Concat(ListAddress(message) is { } list ? [list] : []);

    /// <summary>Indirizzo della mailing list da List-Post (RFC 2369, «&lt;mailto:lista@esempio.it&gt;»), null se manca.</summary>
    public static string? ListAddress(MimeMessage message)
    {
        var post = message.Headers["List-Post"];
        var m = post is null ? null : ListPostRegex().Match(post);
        return m is { Success: true } ? m.Groups[1].Value.ToLowerInvariant() : null;
    }

    /// <summary>La voce corrisponde all'indirizzo: uguale, oppure "@dominio" con lo stesso dominio (sottodomini esclusi).</summary>
    public static bool Matches(IReadOnlyList<string> entries, string address)
    {
        var a = address.ToLowerInvariant();
        var at = a.LastIndexOf('@');
        var domain = at < 0 ? null : a[at..];
        return entries.Any(e => e == a || (domain is not null && e == domain));
    }

    /// <summary>
    /// Giudizio del server dalle intestazioni: X-Spam-Flag (SpamAssassin), X-Spam (rspamd), X-Spam-Status
    /// («Yes, score=7.1 required=5.0 …»). Si legge solo la PRIMA di ogni intestazione: è quella aggiunta per
    /// ultima, dal server della casella (SpamAssassin toglie di serie quelle già presenti nella mail in arrivo).
    /// Una mail che si dichiara da sola «spam» finisce al più nella posta indesiderata: nessun danno.
    /// </summary>
    public static ServerSpamMark ServerMark(MimeMessage message)
    {
        static bool Yes(string? v) => v?.Trim() is { } t && (t.StartsWith("yes", StringComparison.OrdinalIgnoreCase)
            || t.StartsWith("true", StringComparison.OrdinalIgnoreCase));
        var status = message.Headers["X-Spam-Status"];
        var spam = Yes(message.Headers["X-Spam-Flag"]) || Yes(message.Headers["X-Spam"]) || Yes(status);
        double? score = null, required = null;
        if (status is not null)
        {
            if (ScoreRegex().Match(status) is { Success: true } s)
                score = double.Parse(s.Groups[1].Value, CultureInfo.InvariantCulture);
            if (RequiredRegex().Match(status) is { Success: true } r)
                required = double.Parse(r.Groups[1].Value, CultureInfo.InvariantCulture);
        }
        return new(spam, score, required);
    }

    [GeneratedRegex(@"<\s*mailto:([^>?\s]+@[^>?\s]+)", RegexOptions.IgnoreCase)]
    private static partial Regex ListPostRegex();

    [GeneratedRegex(@"\b(?:score|hits)=(-?\d+(?:\.\d+)?)", RegexOptions.IgnoreCase)]
    private static partial Regex ScoreRegex();

    [GeneratedRegex(@"\brequired=(-?\d+(?:\.\d+)?)", RegexOptions.IgnoreCase)]
    private static partial Regex RequiredRegex();
}
