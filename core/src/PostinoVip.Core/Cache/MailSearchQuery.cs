using System.Text.RegularExpressions;

namespace PostinoVip.Core.Cache;

/// <summary>Dove cercare un termine: ovunque (null) o in un campo.</summary>
public enum SearchField
{
    Sender,
    Recipients,
    Subject,
    Attachments,
}

/// <summary>Un termine della ricerca: parola (anche come inizio di parola) o frase esatta, in un campo o ovunque.</summary>
public sealed record SearchTerm(SearchField? Field, string Text, bool IsPhrase);

/// <summary>
/// Ricerca scritta dall'utente:
/// - parole: tutte devono comparire, ognuna anche come inizio di parola ("fatt" trova "fattura");
/// - "frase esatta" tra virgolette;
/// - filtri: da: (mittente), a: (destinatari A e Cc), oggetto:, allegato: (nomi degli allegati),
///   allegati:sì / allegati:no; anche in inglese, in tutte e due le lingue dell'app (tappa «Lingua», L6d, scelta 4a):
///   from:, to:, subject:, attachment:, hasattachments:yes / hasattachments:no.
/// Un filtro sconosciuto (es. "ore 10:30", "http://...") viene cercato come testo normale.
/// Tradotta per l'indice locale (<see cref="Match"/>, FTS5) e per il server (IMAP SEARCH, in
/// ImapFolderSource). Il testo dell'utente non entra mai nella sintassi FTS5: ogni termine diventa
/// una stringa tra virgolette, quindi AND/OR/NOT o caratteri come * e ( non hanno effetti speciali.
/// </summary>
public sealed partial record MailSearchQuery(IReadOnlyList<SearchTerm> Terms, bool? HasAttachments)
{
    private static readonly Dictionary<string, SearchField> Fields = new(StringComparer.OrdinalIgnoreCase)
    {
        ["da"] = SearchField.Sender,
        ["a"] = SearchField.Recipients,
        ["oggetto"] = SearchField.Subject,
        ["allegato"] = SearchField.Attachments,
        ["from"] = SearchField.Sender,
        ["to"] = SearchField.Recipients,
        ["subject"] = SearchField.Subject,
        ["attachment"] = SearchField.Attachments,
    };

    /// <summary>Filtro «ha allegati» nelle due lingue.</summary>
    private static bool IsAttachmentsFilter(string prefix) =>
        prefix.Equals("allegati", StringComparison.OrdinalIgnoreCase) || prefix.Equals("hasattachments", StringComparison.OrdinalIgnoreCase);

    /// <summary>Nessuna condizione: non si cerca nulla (invece di restituire tutta la casella).</summary>
    public bool IsEmpty => Terms.Count == 0 && HasAttachments is null;

    /// <summary>Espressione FTS5 per l'indice locale; null se ci sono solo filtri.</summary>
    public string? Match => Terms.Count == 0 ? null : string.Join(" AND ", Terms.Select(ToFts5));

    public static MailSearchQuery Parse(string? text)
    {
        var terms = new List<SearchTerm>();
        bool? hasAttachments = null;
        foreach (Match m in TermPattern().Matches(text ?? ""))
        {
            var prefix = m.Groups["field"].Success ? m.Groups["field"].Value : null;
            var isPhrase = m.Groups["phrase"].Success;
            var value = isPhrase ? m.Groups["phrase"].Value : m.Groups["word"].Value;

            if (prefix is not null && IsAttachmentsFilter(prefix) && !isPhrase
                && YesNo(value) is { } yes)
            {
                hasAttachments = yes;
                continue;
            }

            SearchField? field = null;
            if (prefix is not null)
            {
                if (Fields.TryGetValue(prefix, out var known))
                {
                    field = known;
                }
                else
                {
                    // Non è un filtro: il testo intero è una parola da cercare.
                    value = m.Value.Trim('"');
                    isPhrase = m.Value.Contains('"');
                }
            }
            if (!value.Any(char.IsLetterOrDigit))
                continue; // solo punteggiatura: per l'indice non è una parola

            terms.Add(new SearchTerm(field, value, isPhrase));
        }
        return new MailSearchQuery(terms, hasAttachments);
    }

    private static string ToFts5(SearchTerm t)
    {
        var quoted = "\"" + t.Text.Replace("\"", "\"\"") + "\"" + (t.IsPhrase ? "" : "*");
        var column = t.Field switch
        {
            SearchField.Sender => "sender",
            SearchField.Recipients => "recipients",
            SearchField.Subject => "subject",
            SearchField.Attachments => "attachments",
            _ => null,
        };
        return column is null ? quoted : $"{column} : {quoted}";
    }

    private static bool? YesNo(string value) => value.ToLowerInvariant() switch
    {
        "sì" or "si" or "s" or "yes" or "y" or "true" => true,
        "no" or "n" or "false" => false,
        _ => null,
    };

    // Facoltativo "campo:" (solo lettere), poi "frase tra virgolette" oppure una parola senza spazi.
    [GeneratedRegex("""(?:(?<field>\p{L}+):)?(?:"(?<phrase>[^"]*)"?|(?<word>\S+))""")]
    private static partial Regex TermPattern();
}
