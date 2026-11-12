using NodaTime;
using NodaTime.TimeZones;

namespace PostinoVip.Core.Calendars;

/// <summary>
/// Fusi orari dei calendari, più tolleranti di quelli di serie di Ical.Net (trovato il 06/11/2026 con il calendario vero di
/// un account: un appuntamento con un TZID sconosciuto faceva fallire tutto il periodo). Accetta: nomi IANA; nomi di
/// Windows (Outlook: «W. Europe Standard Time»); nomi con un prefisso come quelli di Evolution/libical
/// («/freeassociation.sourceforge.net/Europe/Rome»); tutto il resto (es. «TZID», scritto così da qualche programma) = il fuso
/// del computer, che è la scelta più probabile per un appuntamento scritto da qui o da un collega vicino.
/// </summary>
public static class TimeZones
{
    private static int _installed;

    /// <summary>
    /// Imposta, una volta sola, questo risolutore per i TZID di Ical.Net (impostazione globale della libreria): lo chiamano i
    /// costruttori statici di <see cref="CalendarText"/> e <see cref="CalendarEvents"/>, da cui passa tutto il lavoro sui calendari.
    /// </summary>
    public static void Install()
    {
        if (Interlocked.Exchange(ref _installed, 1) == 0)
            Ical.Net.TimeZoneResolvers.TimeZoneResolver = Resolve;
    }

    /// <summary>Fuso del computer (sostituibile nei test).</summary>
    public static Func<string> Local { get; set; } = () => Name(TimeZoneInfo.Local.Id) ?? "UTC";

    /// <summary>Il fuso di un TZID qualunque; mai null (sconosciuto = quello del computer).</summary>
    public static DateTimeZone Resolve(string tzId) =>
        (Name(tzId) is { } n ? DateTimeZoneProviders.Tzdb.GetZoneOrNull(n) : null)
        ?? DateTimeZoneProviders.Tzdb.GetZoneOrNull(Local()) ?? DateTimeZone.Utc;

    /// <summary>Nome IANA di un TZID (anche Windows o con prefisso); null se sconosciuto.</summary>
    public static string? Name(string? tzId)
    {
        if (string.IsNullOrWhiteSpace(tzId))
            return null;
        var id = tzId.Trim().Trim('"');
        if (id is "UTC" or "Z" or "GMT")
            return "UTC";
        if (DateTimeZoneProviders.Tzdb.GetZoneOrNull(id) is not null)
            return id;
        if (TzdbDateTimeZoneSource.Default.WindowsMapping.PrimaryMapping.TryGetValue(id, out var iana))
            return iana;
        // Prefissi («/freeassociation.sourceforge.net/Tzfile/Europe/Rome»): si prova la coda, dalle ultime 3 parti in giù.
        var parts = id.Split('/', StringSplitOptions.RemoveEmptyEntries);
        for (var take = Math.Min(3, parts.Length); take >= 1; take--)
        {
            var tail = string.Join('/', parts[^take..]);
            if (tail != id && DateTimeZoneProviders.Tzdb.GetZoneOrNull(tail) is not null)
                return tail;
        }
        return null;
    }
}
