namespace PostinoVip.Core.Imap;

/// <summary>
/// Converte offset/limit "dal più recente" negli indici IMAP (0 = messaggio più vecchio).
/// Esempio: total=100, offset=0, limit=20 -> indici 80..99.
/// </summary>
public static class PageRange
{
    /// <returns>(First, Last) inclusivi, oppure null se la pagina è vuota.</returns>
    public static (int First, int Last)? Compute(int total, int offset, int limit)
    {
        if (offset < 0) throw new ArgumentOutOfRangeException(nameof(offset), "offset deve essere >= 0.");
        if (limit < 1) throw new ArgumentOutOfRangeException(nameof(limit), "limit deve essere >= 1.");

        var last = total - 1 - offset;
        if (last < 0)
            return null;

        var first = Math.Max(0, last - limit + 1);
        return (first, last);
    }
}
