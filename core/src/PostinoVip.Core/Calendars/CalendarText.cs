namespace PostinoVip.Core.Calendars;

/// <summary>
/// Controlli sul testo iCalendar (RFC 5545) di un appuntamento, con Ical.Net: deve contenere almeno un VEVENT e un solo
/// UID (la serie e le sue occorrenze modificate), come una risorsa CalDAV (RFC 4791 4.1).
/// </summary>
public static class CalendarText
{
    static CalendarText() => TimeZones.Install();

    /// <summary>
    /// A capo CRLF come vuole la RFC 5545 (3.1): il testo che arriva dentro una risposta XML (multiget) li ha già
    /// trasformati in LF, come prevede la specifica XML.
    /// </summary>
    public static string Normalize(string text) => text.Replace("\r\n", "\n").Replace("\r", "\n").Replace("\n", "\r\n");

    /// <summary>Il calendario letto, o null se il testo non è iCalendar leggibile.</summary>
    public static Ical.Net.Calendar? Load(string text)
    {
        try
        {
            return Ical.Net.Calendar.Load(text);
        }
        catch (Exception ex) when (ex is not OutOfMemoryException)
        {
            return null; // Ical.Net segnala il testo non valido con eccezioni di vario tipo
        }
    }

    /// <summary>L'UID dell'appuntamento, o null se il testo non è un appuntamento valido.</summary>
    public static string? Check(string text)
    {
        var events = Load(text)?.Events;
        if (events is null || events.Count == 0)
            return null;
        var uids = events.Select(e => e.Uid).Distinct().ToList();
        return uids is [{ Length: > 0 } uid] ? uid : null;
    }

    /// <summary>LAST-MODIFIED più recente tra i VEVENT (la serie o un'occorrenza modificata); null se non c'è.</summary>
    public static DateTimeOffset? LastModified(string text) => LastModified(Load(text));

    public static DateTimeOffset? LastModified(Ical.Net.Calendar? calendar)
    {
        var times = calendar?.Events.Select(e => e.LastModified).Where(t => t is not null)
            .Select(t => new DateTimeOffset(t!.AsUtc, TimeSpan.Zero)).ToList();
        return times is { Count: > 0 } ? times.Max() : null;
    }
}
