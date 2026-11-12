namespace PostinoVip.Core.Rules;

/// <summary>
/// Condizioni di una regola (scelta 2a), come la procedura guidata di Outlook: tutte quelle indicate devono
/// valere insieme (AND); dentro una condizione con più parole ne basta una (OR). Testo senza distinzione di
/// maiuscole. Null o vuoto = condizione non usata.
/// </summary>
public sealed record RuleConditions
{
    /// <summary>Il mittente (nome o indirizzo, anche solo il dominio) contiene una di queste parole.</summary>
    public IReadOnlyList<string>? From { get; init; }

    /// <summary>Un destinatario in A o Cc (nome o indirizzo) contiene una di queste parole.</summary>
    public IReadOnlyList<string>? ToOrCc { get; init; }

    /// <summary>Inviata solo a me: io unico destinatario in A e nessuno in Cc.</summary>
    public bool SentOnlyToMe { get; init; }

    /// <summary>Il mio indirizzo è in A.</summary>
    public bool MeInTo { get; init; }

    /// <summary>Il mio indirizzo è in Cc.</summary>
    public bool MeInCc { get; init; }

    public IReadOnlyList<string>? SubjectContains { get; init; }

    /// <summary>Oggetto o testo della mail contiene una di queste parole.</summary>
    public IReadOnlyList<string>? SubjectOrBodyContains { get; init; }

    public bool HasAttachments { get; init; }

    /// <summary>Dimensione maggiore di N KB.</summary>
    public int? SizeGreaterThanKb { get; init; }

    public bool IsEmpty =>
        Empty(From) && Empty(ToOrCc) && !SentOnlyToMe && !MeInTo && !MeInCc && Empty(SubjectContains)
        && Empty(SubjectOrBodyContains) && !HasAttachments && SizeGreaterThanKb is null;

    public bool NeedsBody => !Empty(SubjectOrBodyContains);

    private static bool Empty(IReadOnlyList<string>? words) => words is null || words.All(string.IsNullOrWhiteSpace);
}

/// <summary>
/// Azioni di una regola (scelta 3a). Non c'è "inoltra": partirebbe senza la conferma che PostinoVip chiede
/// a ogni invio. "Elimina" sposta in Posta eliminata, mai definitivamente.
/// </summary>
public sealed record RuleActions
{
    public string? MoveTo { get; init; }
    public string? CopyTo { get; init; }
    public bool Delete { get; init; }
    public bool MarkRead { get; init; }
    public bool Flag { get; init; }

    /// <summary>Categoria 1–6 da assegnare.</summary>
    public int? Category { get; init; }

    /// <summary>"Interrompi l'elaborazione di altre regole".</summary>
    public bool StopProcessing { get; init; }

    public bool IsEmpty => MoveTo is null && CopyTo is null && !Delete && !MarkRead && !Flag && Category is null;
}

/// <summary>
/// Una regola di un account (1a: la applica il core sul computer, alle mail nuove della Posta in arrivo).
/// Senza condizioni vale per tutte le mail. <see cref="Exceptions"/>: "tranne se…", basta una (OR).
/// </summary>
public sealed record MailRule
{
    public string Id { get; init; } = "";
    public string Name { get; init; } = "";
    public bool Enabled { get; init; } = true;
    public RuleConditions Conditions { get; init; } = new();
    public RuleConditions? Exceptions { get; init; }
    public RuleActions Actions { get; init; } = new();
}
