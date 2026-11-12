namespace PostinoVip.Core.Cache;

/// <summary>
/// Message-ID per le conversazioni (3.6). Nella cache sono salvati senza parentesi angolari (come li
/// restituisce MailKit); per sicurezza si tolgono comunque "&lt;" e "&gt;" e gli spazi ai lati. Il confronto è
/// esatto: la parte prima della chiocciola distingue maiuscole e minuscole (RFC 5322).
/// </summary>
public static class ConversationIds
{
    /// <summary>Message-ID ripulito; null se vuoto.</summary>
    public static string? Normalize(string? id)
    {
        var clean = id?.Trim().Trim('<', '>').Trim();
        return string.IsNullOrEmpty(clean) ? null : clean;
    }

    /// <summary>I Message-ID salvati in messages.refs (separati da spazi).</summary>
    public static IEnumerable<string> Split(string? refs) =>
        (refs ?? "").Split(' ', StringSplitOptions.RemoveEmptyEntries).Select(Normalize).OfType<string>();

    /// <summary>Elenco di Message-ID (es. References di MailKit) nel formato di messages.refs; '' se vuoto.</summary>
    public static string Join(IEnumerable<string>? ids) =>
        string.Join(' ', (ids ?? []).Select(Normalize).OfType<string>());
}
