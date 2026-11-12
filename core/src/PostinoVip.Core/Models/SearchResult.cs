namespace PostinoVip.Core.Models;

/// <summary>
/// Un messaggio trovato dalla ricerca. Snippet: estratto con le parole trovate racchiuse tra i
/// caratteri <see cref="SearchResult.HighlightStart"/> e <see cref="SearchResult.HighlightEnd"/>
/// (null se la ricerca era solo per filtri). BodySearched: false se del messaggio sono state cercate
/// solo le intestazioni (corpo non in cache: fuori dal limite, Posta eliminata, Indesiderata).
/// FromServer: trovato dalla ricerca sul server (IMAP SEARCH), senza estratto.
/// </summary>
public sealed record SearchHit(string Folder, uint Uid, string Subject, string From, DateTimeOffset? Date, bool Seen,
    string? Snippet, bool BodySearched, bool FromServer = false);

/// <summary>Una pagina di risultati, dal più recente; Total = tutti i messaggi trovati.</summary>
public sealed record SearchResult(int Total, int Offset, int Limit, IReadOnlyList<SearchHit> Items)
{
    public const char HighlightStart = '\u0002';
    public const char HighlightEnd = '\u0003';
}
