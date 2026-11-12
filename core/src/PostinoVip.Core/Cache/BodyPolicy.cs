namespace PostinoVip.Core.Cache;

/// <summary>
/// Quali corpi conservare nella cache: solo quelli dei messaggi arrivati sul server negli ultimi
/// <see cref="Months"/> mesi (null = tutti), mai quelli di Posta eliminata e Indesiderata (solo
/// intestazioni). Fuori dalla regola un messaggio si apre lo stesso ma non viene salvato, e la
/// pulizia toglie quelli usciti (col passare del tempo o riducendo il limite).
/// </summary>
public sealed record BodyPolicy(int? Months)
{
    public static readonly BodyPolicy Default = new(12);

    /// <summary>Nessun corpo nella cache dei corpi: account POP3, le cui mail stanno già nei file locali (4.2).</summary>
    public static readonly BodyPolicy None = new(-1);

    /// <summary>Dalla configurazione: null = predefinito (12 mesi), 0 = tutte le mail.</summary>
    public static BodyPolicy FromMonths(int? months) => months switch
    {
        null => Default,
        0 => new BodyPolicy((int?)null),
        > 0 => new BodyPolicy(months),
        _ => throw new ArgumentOutOfRangeException(nameof(months), months, "Il limite in mesi non può essere negativo."),
    };

    private static readonly string[] HeadersOnlyRoles = ["trash", "junk"];

    /// <param name="folderRole">Ruolo SPECIAL-USE della cartella (es. "trash"), null se nessuno.</param>
    /// <param name="arrived">Arrivo sul server (INTERNALDATE, altrimenti l'intestazione Date); null = sconosciuto, conservato.</param>
    public bool Keeps(string? folderRole, DateTimeOffset? arrived, DateTimeOffset now) =>
        Months is not < 0
        && !HeadersOnlyRoles.Contains(folderRole)
        && (Months is null || arrived is null || arrived >= now.AddMonths(-Months.Value));
}
