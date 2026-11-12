
namespace PostinoVip.Core.Rules;

/// <summary>I dati di una mail che le regole guardano.</summary>
public sealed record RuleMessage(string From, IReadOnlyList<string> To, IReadOnlyList<string> Cc, string Subject, string Body,
    bool HasAttachments, long? Size)
{
    /// <summary>Dal messaggio originale: mittente e destinatari con nome e indirizzo, testo (anche dall'HTML), allegati.</summary>
    public static RuleMessage FromMime(MimeKit.MimeMessage message, long? size)
    {
        var text = Cache.SearchText.From(message);
        return new RuleMessage(
            string.Join(", ", message.From.Mailboxes.Select(m => m.ToString())),
            message.To.Mailboxes.Select(m => m.ToString()).ToList(),
            message.Cc.Mailboxes.Select(m => m.ToString()).ToList(),
            message.Subject ?? "", text.Body, text.HasAttachments, size);
    }
}

/// <summary>Valutazione delle regole (pura: niente rete né file), con le regole di Outlook.</summary>
public static class RuleMatcher
{
    /// <summary>La regola vale per la mail: attiva, condizioni tutte vere, nessuna eccezione vera.</summary>
    public static bool Matches(MailRule rule, RuleMessage m, string ownAddress) =>
        rule.Enabled
        && AllTrue(rule.Conditions, m, ownAddress)
        && (rule.Exceptions is not { IsEmpty: false } exceptions || !AnyTrue(exceptions, m, ownAddress));

    /// <summary>
    /// Le azioni da eseguire: quelle delle regole valide, in ordine, fino a una con "interrompi". Più "sposta":
    /// la prima sposta, le altre copiano (come Outlook); "elimina" prevale sugli spostamenti.
    /// </summary>
    public static PlannedActions Plan(IReadOnlyList<MailRule> rules, RuleMessage m, string ownAddress)
    {
        var plan = new PlannedActions();
        foreach (var rule in rules)
        {
            if (!Matches(rule, m, ownAddress))
                continue;
            plan.Rules.Add(rule.Name);
            var a = rule.Actions;
            plan.MarkRead |= a.MarkRead;
            plan.Flag |= a.Flag;
            if (a.Category is { } c && !plan.Categories.Contains(c))
                plan.Categories.Add(c);
            if (a.CopyTo is { } copy)
                plan.AddCopy(copy);
            if (a.Delete)
                plan.Delete = true;
            else if (a.MoveTo is { } move)
            {
                if (plan.MoveTo is null)
                    plan.MoveTo = move;
                else
                    plan.AddCopy(move);
            }
            if (a.StopProcessing)
                break;
        }
        if (plan.Delete && plan.MoveTo is { } moved)
        {
            plan.AddCopy(moved); // la regola con "sposta" resta rispettata: una copia lì
            plan.MoveTo = null;
        }
        return plan;
    }

    private static bool AllTrue(RuleConditions c, RuleMessage m, string me) =>
        Tests(c, m, me).All(t => t);

    private static bool AnyTrue(RuleConditions c, RuleMessage m, string me) =>
        Tests(c, m, me).Any(t => t);

    /// <summary>L'esito delle sole condizioni indicate.</summary>
    private static IEnumerable<bool> Tests(RuleConditions c, RuleMessage m, string me)
    {
        if (Words(c.From) is { Count: > 0 } from)
            yield return ContainsAny(m.From, from);
        if (Words(c.ToOrCc) is { Count: > 0 } toCc)
            yield return m.To.Concat(m.Cc).Any(r => ContainsAny(r, toCc));
        if (c.SentOnlyToMe)
            yield return m.To.Count == 1 && IsMe(m.To[0], me) && m.Cc.Count == 0;
        if (c.MeInTo)
            yield return m.To.Any(r => IsMe(r, me));
        if (c.MeInCc)
            yield return m.Cc.Any(r => IsMe(r, me));
        if (Words(c.SubjectContains) is { Count: > 0 } subject)
            yield return ContainsAny(m.Subject, subject);
        if (Words(c.SubjectOrBodyContains) is { Count: > 0 } text)
            yield return ContainsAny(m.Subject, text) || ContainsAny(m.Body, text);
        if (c.HasAttachments)
            yield return m.HasAttachments;
        if (c.SizeGreaterThanKb is { } kb)
            yield return m.Size is { } size && size > kb * 1024L;
    }

    private static List<string> Words(IReadOnlyList<string>? words) =>
        (words ?? []).Select(w => w.Trim()).Where(w => w.Length > 0).ToList();

    private static bool ContainsAny(string text, List<string> words) =>
        words.Any(w => text.Contains(w, StringComparison.OrdinalIgnoreCase));

    /// <summary>"Mario &lt;io@example.com&gt;" o "io@example.com" è il mio indirizzo.</summary>
    private static bool IsMe(string recipient, string me)
    {
        if (string.IsNullOrWhiteSpace(me))
            return false;
        var address = MimeKit.MailboxAddress.TryParse(recipient, out var parsed) ? parsed.Address : recipient.Trim();
        return string.Equals(address, me.Trim(), StringComparison.OrdinalIgnoreCase);
    }
}

/// <summary>Cosa fare di una mail dopo aver valutato le regole.</summary>
public sealed class PlannedActions
{
    public List<string> Rules { get; } = [];
    public bool MarkRead { get; set; }
    public bool Flag { get; set; }
    public List<int> Categories { get; } = [];
    public List<string> CopyTo { get; } = [];
    public string? MoveTo { get; set; }
    public bool Delete { get; set; }

    public bool IsEmpty => !MarkRead && !Flag && Categories.Count == 0 && CopyTo.Count == 0 && MoveTo is null && !Delete;

    public void AddCopy(string folder)
    {
        if (!CopyTo.Contains(folder, StringComparer.OrdinalIgnoreCase))
            CopyTo.Add(folder);
    }
}
