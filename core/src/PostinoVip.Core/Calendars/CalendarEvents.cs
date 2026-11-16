// RecurrenceId (obsoleto in Ical.Net 5 a favore di RecurrenceIdentifier, che aggiunge RANGE) basta qui: niente RANGE.
#pragma warning disable CS0618
using System.Collections.Concurrent;
using System.Globalization;
using Ical.Net.CalendarComponents;
using Ical.Net.DataTypes;
using Ical.Net.Serialization;
using NodaTime;
using NodaTime.TimeZones;

namespace PostinoVip.Core.Calendars;

/// <summary>
/// Ricorrenza come la finestra «Ricorrenza» di Outlook (K2b): <see cref="Frequency"/> "daily", "weekly", "monthly",
/// "yearly"; ogni <see cref="Interval"/>; settimanale nei giorni <see cref="Days"/> ("MO".."SU"); mensile/annuale il giorno
/// <see cref="MonthDay"/> oppure «il primo/…/quarto/ultimo» (<see cref="Week"/> 1..4 o -1) giorno <see cref="Days"/>[0];
/// annuale nel mese <see cref="Month"/>; fine dopo <see cref="Count"/> occorrenze o entro <see cref="Until"/> (aaaa-mm-gg).
/// </summary>
public sealed record EventRecurrence(string Frequency, int Interval = 1, IReadOnlyList<string>? Days = null, int? MonthDay = null,
    int? Week = null, int? Month = null, int? Count = null, string? Until = null);

/// <summary>
/// Dati di un appuntamento scritti dall'app. Orari: ora locale "aaaa-mm-ggThh:mm" nel fuso <see cref="TimeZone"/> (assente =
/// quello del computer); giornata intera: date "aaaa-mm-gg" di inizio e fine, comprese. <see cref="KeepRecurrence"/>: la
/// ricorrenza (anche personalizzata) resta com'è e <see cref="Recurrence"/> non si guarda.
/// </summary>
public sealed record EventInput(string? Summary, string? Location, string? Description, string Start, string End, bool AllDay,
    string? TimeZone = null, int? ReminderMinutes = null, EventRecurrence? Recurrence = null, bool KeepRecurrence = false);

/// <summary>
/// Un appuntamento (la serie, se ricorrente) come lo legge l'app: inizio e fine nell'ora locale del suo fuso
/// (<see cref="TimeZone"/>), o date comprese per la giornata intera. <see cref="CustomRecurrence"/>: regola che la finestra
/// «Ricorrenza» non sa mostrare (si vede, si conserva modificando il resto). <see cref="Exceptions"/>: occorrenze spostate o
/// tolte dalla serie. <see cref="RecurrenceId"/>: una sola occorrenza (K4a), null per la serie.
/// </summary>
public sealed record EventDetail(string Id, string CalendarId, string Uid, string Summary, string? Location, string? Description,
    string Start, string End, bool AllDay, string TimeZone, int? ReminderMinutes, EventRecurrence? Recurrence, string? CustomRecurrence,
    int Exceptions, int Attendees, string? RecurrenceId = null);

/// <summary>
/// Un'occorrenza in un periodo: inizio e fine in UTC ("…Z"), o date comprese per la giornata intera; <see cref="RecurrenceId"/>
/// = l'occorrenza originale della serie (per il K4), null se non ricorrente.
/// </summary>
public sealed record EventOccurrence(string CalendarId, string EventId, string Uid, string? RecurrenceId, string Start, string End,
    bool AllDay, string Summary, string? Location, bool Recurring, int? ReminderMinutes);

/// <summary><see cref="Skipped"/>: appuntamenti che non si sono potuti leggere o espandere (saltati, gli altri si vedono).</summary>
public sealed record OccurrencePage(IReadOnlyList<EventOccurrence> Items, bool Truncated, int Skipped = 0);

/// <summary>
/// Appuntamenti dal testo iCalendar dei calendari (K2b, con Ical.Net): occorrenze di un periodo con le ricorrenze espanse
/// (eccezioni comprese), dettaglio della serie, creazione e modifica. La modifica lavora sul testo esistente: cambia solo
/// i campi indicati e conserva il resto (partecipanti, proprietà X-…, promemoria non toccati).
/// </summary>
public static class CalendarEvents
{
    static CalendarEvents() => TimeZones.Install();

    public const int MaxDays = 400;
    public const int MaxOccurrences = 5000;
    public const string ProductId = "-//PostinoVip//Calendario//IT";
    private static readonly string[] DayCodes = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];

    private static readonly ConcurrentDictionary<string, Ical.Net.Calendar> Parsed = new();

    // ---------------------------------------------------------------- fusi orari

    /// <summary>Il fuso del computer con il nome IANA (anche da un nome di Windows); "UTC" se non si sa.</summary>
    public static string LocalTimeZone() => TimeZones.Local();

    /// <summary>Nome IANA del fuso (accetta anche quelli di Windows), null se sconosciuto.</summary>
    public static string? NormalizeZone(string? id) => TimeZones.Name(id);

    private static DateTimeZone Zone(string? id) =>
        (NormalizeZone(id) is { } n ? DateTimeZoneProviders.Tzdb.GetZoneOrNull(n) : null) ?? DateTimeZone.Utc;

    /// <summary>Istante di un CalDateTime: con fuso o UTC come lo calcola Ical.Net; senza fuso («floating») nell'ora del computer.</summary>
    private static DateTimeOffset Instant(CalDateTime t, string localZone)
    {
        if (t.IsUtc || t.TzId is not null)
            return new DateTimeOffset(t.AsUtc, TimeSpan.Zero);
        var local = LocalDateTime.FromDateTime(t.Value);
        return Zone(localZone).AtLeniently(local).ToDateTimeOffset().ToUniversalTime();
    }

    // ---------------------------------------------------------------- lettura

    /// <summary>Il testo letto con Ical.Net, tenuto in memoria per impronta (lo stesso testo non si rilegge).</summary>
    private static Ical.Net.Calendar? Load(CalendarItem item)
    {
        if (Parsed.TryGetValue(item.Fingerprint, out var cached))
            return cached;
        var cal = CalendarText.Load(item.Text);
        if (cal is null)
            return null;
        if (Parsed.Count > 10_000)
            Parsed.Clear();
        Parsed[item.Fingerprint] = cal;
        return cal;
    }

    /// <summary>
    /// Le occorrenze di [from, to) nei calendari indicati, dal più presto (al massimo <see cref="MaxOccurrences"/>; oltre,
    /// <see cref="OccurrencePage.Truncated"/>). Comprese quelle iniziate prima e ancora in corso (fino a 31 giorni prima).
    /// </summary>
    public static OccurrencePage Occurrences(CalendarSet set, IEnumerable<string> calendarIds, DateTimeOffset from, DateTimeOffset to,
        string? localZone = null)
    {
        if (to <= from || (to - from).TotalDays > MaxDays)
            throw new FieldValidationException("to", $"Periodo non valido: al massimo {MaxDays} giorni, con la fine dopo l'inizio.").WithCode("periodoNonValidoAlMassimo", ("maxDays", MaxDays));
        localZone ??= LocalTimeZone();
        var result = new List<EventOccurrence>();
        var truncated = false;
        var skipped = 0;
        foreach (var calendarId in calendarIds)
        {
            foreach (var item in set.Store(calendarId).List())
            {
                if (Load(item) is not { } cal)
                {
                    skipped++;
                    continue;
                }
                var before = result.Count;
                try
                {
                var master = cal.Events.FirstOrDefault(e => e.RecurrenceId is null) ?? cal.Events.FirstOrDefault();
                if (master is null)
                    continue;
                var recurring = master.RecurrenceRule is not null || cal.Events.Count > 1 || master.RecurrenceDates.GetAllDates().Any();
                lock (cal)
                {
                    var start = new CalDateTime(from.AddDays(-31).UtcDateTime, "UTC");
                    foreach (var o in cal.GetOccurrences(start))
                    {
                        var ev = (CalendarEvent)o.Source;
                        var allDay = !o.Period.StartTime.HasTime;
                        var begin = allDay ? DateAsInstant(o.Period.StartTime) : Instant(o.Period.StartTime, localZone);
                        if (begin >= to)
                            break;
                        var endTime = o.Period.EffectiveEndTime ?? o.Period.StartTime;
                        var end = allDay ? DateAsInstant(endTime) : Instant(endTime, localZone);
                        if (end <= from && !(end == begin && begin >= from))
                            continue;
                        if (result.Count >= MaxOccurrences)
                        {
                            truncated = true;
                            break;
                        }
                        var originalStart = ev.RecurrenceId ?? o.Period.StartTime;
                        result.Add(new EventOccurrence(calendarId, item.Id, item.Uid,
                            recurring ? Format(originalStart, allDay, localZone, isEnd: false) : null,
                            Format(o.Period.StartTime, allDay, localZone, isEnd: false), Format(endTime, allDay, localZone, isEnd: true),
                            allDay, ev.Summary ?? "", ev.Location, recurring, Reminder(ev)));
                    }
                }
                }
                catch (Exception ex) when (ex is ArgumentException or InvalidOperationException or FormatException or ArithmeticException)
                {
                    // Un appuntamento che Ical.Net non sa espandere non toglie gli altri.
                    result.RemoveRange(before, result.Count - before);
                    skipped++;
                }
            }
        }
        return new OccurrencePage(result.OrderBy(o => o.AllDay ? o.Start + "T00:00:00Z" : o.Start, StringComparer.Ordinal).ToList(),
            truncated, skipped);
    }

    private static DateTimeOffset DateAsInstant(CalDateTime t) => new(t.Date.ToDateTime(TimeOnly.MinValue), TimeSpan.Zero);

    /// <summary>UTC "…Z" per gli orari; per la giornata intera la data (fine compresa: il giorno prima di DTEND).</summary>
    private static string Format(CalDateTime t, bool allDay, string localZone, bool isEnd)
    {
        if (allDay)
        {
            var date = t.Date;
            if (isEnd && t.HasTime is false)
                date = date.AddDays(-1);
            return date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        }
        return Instant(t, localZone).UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture);
    }

    /// <summary>Il dettaglio della serie (l'evento principale dell'oggetto).</summary>
    public static EventDetail Detail(string calendarId, CalendarItem item, string? localZone = null)
    {
        localZone ??= LocalTimeZone();
        var cal = Load(item) ?? throw new MailNotFoundException("Appuntamento non leggibile.").WithCode("appuntamentoNonLeggibile");
        var master = cal.Events.FirstOrDefault(e => e.RecurrenceId is null) ?? cal.Events.First();
        var allDay = master.IsAllDay;
        var (start, end, tz) = StartEnd(master, localZone);
        var rule = master.RecurrenceRule;
        var recurrence = rule is null ? null : FromRule(rule, master.DtStart!, localZone);
        var exceptions = cal.Events.Count(e => e.RecurrenceId is not null) + master.ExceptionDates.GetAllDates().Count();
        return new EventDetail(item.Id, calendarId, item.Uid, master.Summary ?? "", master.Location, master.Description, start, end,
            allDay, tz, Reminder(master), recurrence, rule is not null && recurrence is null ? rule.ToString() : null, exceptions,
            master.Attendees.Count);
    }

    /// <summary>Inizio e fine di un evento come li legge l'app (ora locale del suo fuso, o date comprese) e il fuso.</summary>
    private static (string Start, string End, string Zone) StartEnd(CalendarEvent ev, string localZone)
    {
        var tz = ev.DtStart?.TzId is { } z ? NormalizeZone(z) ?? localZone : localZone;
        if (ev.IsAllDay)
        {
            var s = ev.DtStart!.Date;
            var e = ev.DtEnd is { } dtEnd ? dtEnd.Date.AddDays(-1)
                : ev.Duration is { } d ? s.AddDays(Math.Max(0, (d.Days ?? 0) + 7 * (d.Weeks ?? 0) - 1)) : s;
            return (s.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), (e < s ? s : e).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture), tz);
        }
        var zone = Zone(tz);
        var si = Instant(ev.DtStart!, localZone);
        var ei = ev.DtEnd is { } end ? Instant(end, localZone) : ev.Duration is { } du ? si + du.ToTimeSpanUnspecified() : si;
        return (Local(si, zone), Local(ei, zone), tz);
    }

    // ---------------------------------------------------------------- una sola occorrenza (K4a)

    /// <summary>
    /// L'inizio originale dell'occorrenza <paramref name="recurrenceId"/> (come in <see cref="EventOccurrence.RecurrenceId"/>:
    /// UTC «…Z» o data) nella forma di DTSTART della serie: stesso fuso, o data per la giornata intera.
    /// </summary>
    private static CalDateTime OriginalStart(CalendarEvent master, string recurrenceId, string localZone)
    {
        if (!master.DtStart!.HasTime)
            return new CalDateTime(ParseDate(recurrenceId.Length >= 10 ? recurrenceId[..10] : recurrenceId, "recurrenceId"));
        if (!DateTimeOffset.TryParse(recurrenceId, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var instant))
            throw new FieldValidationException("recurrenceId", "Occorrenza non valida.").WithCode("occorrenzaNonValida");
        if (master.DtStart.IsUtc)
            return new CalDateTime(instant.UtcDateTime, "UTC");
        var zoneId = master.DtStart.TzId is { } z ? NormalizeZone(z) ?? localZone : localZone;
        var local = NodaTime.Instant.FromDateTimeOffset(instant).InZone(Zone(zoneId)).LocalDateTime.ToDateTimeUnspecified();
        return new CalDateTime(local, master.DtStart.TzId, true); // TzId nullo = ora senza fuso, come la serie
    }

    private static bool SameOccurrence(CalDateTime a, CalDateTime b) =>
        a.HasTime ? b.HasTime && a.AsUtc == b.AsUtc : !b.HasTime && a.Date == b.Date;

    private static (Ical.Net.Calendar Cal, CalendarEvent Master, CalDateTime Original, CalendarEvent? Override) Occurrence(
        string text, string recurrenceId, string localZone)
    {
        var cal = CalendarText.Load(text) ?? throw new FieldValidationException("event", "Appuntamento non leggibile.").WithCode("appuntamentoNonLeggibile");
        var master = cal.Events.FirstOrDefault(e => e.RecurrenceId is null) ?? throw new FieldValidationException("event", "Serie non trovata.").WithCode("serieNonTrovata");
        if (master.RecurrenceRule is null && !master.RecurrenceDates.GetAllDates().Any())
            throw new InvalidOperationException("L'appuntamento non è ricorrente: si modifica tutto.").WithCode("appuntamentoNonRicorrenteSiModifica");
        var original = OriginalStart(master, recurrenceId, localZone);
        var over = cal.Events.FirstOrDefault(e => e.RecurrenceId is { } r && SameOccurrence(r, original));
        return (cal, master, original, over);
    }

    /// <summary>Una sola occorrenza: quella modificata se c'è, altrimenti i dati della serie con l'ora dell'occorrenza.</summary>
    public static EventDetail OccurrenceDetail(string calendarId, CalendarItem item, string recurrenceId, string? localZone = null)
    {
        localZone ??= LocalTimeZone();
        var (cal, master, original, over) = Occurrence(item.Text, recurrenceId, localZone);
        var ev = over ?? master;
        string start, end, tz;
        if (over is not null)
            (start, end, tz) = StartEnd(over, localZone);
        else
        {
            var (ms, me, mz) = StartEnd(master, localZone);
            tz = mz;
            if (master.IsAllDay)
            {
                var span = DateOnly.Parse(me, CultureInfo.InvariantCulture).DayNumber - DateOnly.Parse(ms, CultureInfo.InvariantCulture).DayNumber;
                start = original.Date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                end = original.Date.AddDays(span).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            }
            else
            {
                var length = DateTime.Parse(me, CultureInfo.InvariantCulture) - DateTime.Parse(ms, CultureInfo.InvariantCulture);
                var s = Instant(original, localZone);
                start = Local(s, Zone(tz));
                end = Local(s + length, Zone(tz));
            }
        }
        return new EventDetail(item.Id, calendarId, item.Uid, ev.Summary ?? "", ev.Location, ev.Description, start, end, ev.IsAllDay, tz,
            Reminder(ev), null, null, 0, ev.Attendees.Count, recurrenceId);
    }

    /// <summary>
    /// Modifica solo un'occorrenza (3a): una VEVENT con lo stesso UID e RECURRENCE-ID (nuova, copiando i dati della serie, o
    /// quella che c'era); la serie non cambia. Ricorrenza e «keepRecurrence» qui non contano.
    /// </summary>
    public static string UpdateOccurrence(string text, string recurrenceId, EventInput input, string? localZone = null)
    {
        localZone ??= LocalTimeZone();
        var (cal, master, original, over) = Occurrence(text, recurrenceId, localZone);
        var isNew = over is null;
        over ??= new CalendarEvent
        {
            Uid = master.Uid,
            RecurrenceId = original,
            Sequence = master.Sequence,
        };
        if (isNew)
        {
            foreach (var a in master.Attendees)
                over.Attendees.Add(a);
            if (master.Organizer is { } organizer)
                over.Organizer = organizer;
            cal.Events.Add(over);
        }
        Apply(cal, over, input with { Recurrence = null, KeepRecurrence = true }, localZone, isNew, isOverride: true);
        return Serialize(cal);
    }

    /// <summary>Elimina solo un'occorrenza (3a): EXDATE nella serie e via l'eventuale occorrenza modificata.</summary>
    public static string DeleteOccurrence(string text, string recurrenceId, string? localZone = null)
    {
        localZone ??= LocalTimeZone();
        var (cal, master, original, over) = Occurrence(text, recurrenceId, localZone);
        if (over is not null)
        {
            var keep = cal.Children.Where(c => !ReferenceEquals(c, over)).ToList(); // per riferimento: Remove confronta l'UID
            cal.Children.Clear();
            foreach (var c in keep)
                cal.Children.Add(c);
        }
        master.ExceptionDates.Add(original);
        master.Sequence++;
        var now = new CalDateTime(DateTime.UtcNow, "UTC");
        master.LastModified = now;
        master.DtStamp = now;
        return Serialize(cal);
    }

    private static string Local(DateTimeOffset instant, DateTimeZone zone) =>
        NodaTime.Instant.FromDateTimeOffset(instant).InZone(zone).LocalDateTime.ToString("yyyy-MM-dd'T'HH:mm", CultureInfo.InvariantCulture);

    /// <summary>Minuti di anticipo del primo promemoria relativo all'inizio; null se non ce n'è.</summary>
    private static int? Reminder(CalendarEvent ev)
    {
        foreach (var a in ev.Alarms)
        {
            if (a.Trigger is { IsRelative: true, Duration: { } d } t && !string.Equals(t.Related, "END", StringComparison.OrdinalIgnoreCase))
            {
                var minutes = -(int)Math.Round(d.ToTimeSpanUnspecified().TotalMinutes);
                return Math.Max(0, minutes);
            }
        }
        return null;
    }

    // ---------------------------------------------------------------- ricorrenze

    /// <summary>La regola nel modello della finestra «Ricorrenza»; null se non vi rientra (resta «personalizzata»).</summary>
    public static EventRecurrence? FromRule(RecurrenceRule r, CalDateTime start, string localZone)
    {
        if (r.BySecond.Count + r.ByMinute.Count + r.ByHour.Count + r.ByYearDay.Count + r.ByWeekNo.Count > 0 || r.Interval < 1)
            return null;
        string? until = null;
        if (r.Until is { } u)
            until = (u.HasTime ? NodaTime.Instant.FromDateTimeOffset(Instant(u, localZone)).InZone(Zone(start.TzId ?? localZone)).Date.ToDateOnly() : u.Date)
                .ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var interval = r.Interval;
        var count = r.Count;
        switch (r.Frequency)
        {
            case Ical.Net.FrequencyType.Daily when r.ByDay.Count + r.ByMonthDay.Count + r.ByMonth.Count + r.BySetPosition.Count == 0:
                return new EventRecurrence("daily", interval, Count: count, Until: until);
            case Ical.Net.FrequencyType.Weekly when r.ByMonthDay.Count + r.ByMonth.Count + r.BySetPosition.Count == 0
                && r.ByDay.All(d => d.Offset is null):
                return new EventRecurrence("weekly", interval, r.ByDay.Count == 0 ? null : r.ByDay.Select(d => DayCodes[(int)d.DayOfWeek]).ToList(),
                    Count: count, Until: until);
            case Ical.Net.FrequencyType.Monthly when r.ByMonth.Count == 0:
                return MonthlyPart(r) is { } m ? new EventRecurrence("monthly", interval, m.Days, m.MonthDay, m.Week, Count: count, Until: until) : null;
            case Ical.Net.FrequencyType.Yearly when interval == 1 && r.ByMonth.Count <= 1:
                if (r.ByMonth.Count == 0 && r.ByDay.Count + r.ByMonthDay.Count + r.BySetPosition.Count == 0)
                    return new EventRecurrence("yearly", 1, MonthDay: start.Day, Month: start.Month, Count: count, Until: until);
                return r.ByMonth.Count == 1 && MonthlyPart(r) is { } y
                    ? new EventRecurrence("yearly", 1, y.Days, y.MonthDay, y.Week, r.ByMonth[0], count, until) : null;
            default:
                return null;
        }
    }

    /// <summary>«il giorno D» o «il primo/…/ultimo <giorno>» di una regola mensile/annuale; null se è altro.</summary>
    private static (IReadOnlyList<string>? Days, int? MonthDay, int? Week)? MonthlyPart(RecurrenceRule r)
    {
        if (r.ByDay.Count == 0 && r.BySetPosition.Count == 0)
            return r.ByMonthDay.Count switch
            {
                0 => (null, null, null), // il giorno di DTSTART
                1 when r.ByMonthDay[0] is >= 1 and <= 31 => (null, r.ByMonthDay[0], null),
                _ => null,
            };
        if (r.ByMonthDay.Count > 0 || r.ByDay.Count != 1)
            return null;
        var day = r.ByDay[0];
        var week = day.Offset ?? (r.BySetPosition.Count == 1 ? r.BySetPosition[0] : null);
        if (day.Offset is not null && r.BySetPosition.Count > 0)
            return null;
        return ValidWeek(week) ? ([DayCodes[(int)day.DayOfWeek]], null, week) : null;
    }

    /// <summary>«il primo/secondo/terzo/quarto» (1..4) o «l'ultimo» (-1).</summary>
    private static bool ValidWeek(int? week) => week is >= 1 and <= 4 || week == -1;

    /// <summary>La regola RRULE della finestra «Ricorrenza»; dati non validi -> errore sul campo «recurrence».</summary>
    public static RecurrenceRule ToRule(EventRecurrence rec, CalDateTime start, string zone)
    {
        static FieldValidationException Bad(string message) => new("recurrence", message);
        if (rec.Interval is < 1 or > 999)
            throw Bad("Ripetizione non valida (ogni 1–999).");
        if (rec.Count is < 1 or > 999)
            throw Bad("Numero di occorrenze non valido (1–999).");
        var frequency = rec.Frequency switch
        {
            "daily" => Ical.Net.FrequencyType.Daily,
            "weekly" => Ical.Net.FrequencyType.Weekly,
            "monthly" => Ical.Net.FrequencyType.Monthly,
            "yearly" => Ical.Net.FrequencyType.Yearly,
            _ => throw Bad("Tipo di ricorrenza non valido."),
        };
        var rule = new RecurrenceRule(frequency, frequency == Ical.Net.FrequencyType.Yearly ? 1 : rec.Interval);
        var days = (rec.Days ?? []).Select(d => d.ToUpperInvariant()).ToList();
        if (days.Any(d => Array.IndexOf(DayCodes, d) < 0) || days.Distinct().Count() != days.Count)
            throw Bad("Giorni della settimana non validi.");
        DayOfWeek Day(string code) => (DayOfWeek)Array.IndexOf(DayCodes, code);
        switch (frequency)
        {
            case Ical.Net.FrequencyType.Daily:
                if (days.Count > 0 || rec.MonthDay is not null || rec.Week is not null || rec.Month is not null)
                    throw Bad("La ricorrenza giornaliera non ha giorni né mesi.");
                break;
            case Ical.Net.FrequencyType.Weekly:
                if (rec.MonthDay is not null || rec.Week is not null || rec.Month is not null)
                    throw Bad("La ricorrenza settimanale ha solo i giorni della settimana.");
                foreach (var d in days.OrderBy(d => (Array.IndexOf(DayCodes, d) + 6) % 7))
                    rule.ByDay.Add(new WeekDay(Day(d)));
                break;
            default:
                if (frequency == Ical.Net.FrequencyType.Yearly)
                {
                    if (rec.Month is not (>= 1 and <= 12))
                        throw Bad("Mese non valido.");
                    rule.ByMonth.Add(rec.Month.Value);
                }
                else if (rec.Month is not null)
                    throw Bad("La ricorrenza mensile non ha un mese.");
                if (rec.Week is not null)
                {
                    if (!ValidWeek(rec.Week) || days.Count != 1 || rec.MonthDay is not null)
                        throw Bad("Scegliere «il primo/secondo/terzo/quarto/ultimo» e un giorno della settimana.");
                    rule.ByDay.Add(new WeekDay(Day(days[0]), rec.Week.Value));
                }
                else
                {
                    if (days.Count > 0 || rec.MonthDay is not (>= 1 and <= 31))
                        throw Bad("Giorno del mese non valido (1–31).");
                    rule.ByMonthDay.Add(rec.MonthDay.Value);
                }
                break;
        }
        if (rec.Count is not null && rec.Until is not null)
            throw Bad("Indicare un numero di occorrenze o una data di fine, non entrambi.");
        rule.Count = rec.Count;
        if (rec.Until is not null)
        {
            if (!DateOnly.TryParseExact(rec.Until, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var until)
                || until < start.Date)
                throw Bad("Data di fine della ricorrenza non valida (non prima dell'inizio).");
            if (!start.HasTime)
                rule.Until = new CalDateTime(until);
            else
            {
                // Con un fuso, UNTIL va in UTC (RFC 5545 3.3.10): la fine di quel giorno nell'ora locale.
                var last = Zone(zone).AtLeniently(LocalDateTime.FromDateTime(until.ToDateTime(new TimeOnly(23, 59, 59)))).ToDateTimeOffset();
                rule.Until = new CalDateTime(last.UtcDateTime, "UTC");
            }
        }
        return rule;
    }

    // ---------------------------------------------------------------- scrittura

    /// <summary>Un appuntamento nuovo, come testo iCalendar con il suo VTIMEZONE.</summary>
    public static string Create(EventInput input, string? localZone = null)
    {
        var cal = new Ical.Net.Calendar { ProductId = ProductId };
        var ev = new CalendarEvent { Uid = Guid.NewGuid().ToString() };
        cal.Events.Add(ev);
        Apply(cal, ev, input, localZone ?? LocalTimeZone(), isNew: true);
        return Serialize(cal);
    }

    /// <summary>
    /// Modifica la serie nel testo esistente. Cambiano solo i campi indicati; se cambiano inizio o ricorrenza, le occorrenze
    /// modificate e le esclusioni della serie si tolgono (come Outlook). SEQUENCE +1, LAST-MODIFIED e DTSTAMP adesso.
    /// </summary>
    public static string Update(string text, EventInput input, string? localZone = null)
    {
        var cal = CalendarText.Load(text) ?? throw new FieldValidationException("event", "Appuntamento non leggibile.").WithCode("appuntamentoNonLeggibile");
        var master = cal.Events.FirstOrDefault(e => e.RecurrenceId is null) ?? throw new FieldValidationException("event", "Serie non trovata.").WithCode("serieNonTrovata");
        Apply(cal, master, input, localZone ?? LocalTimeZone(), isNew: false);
        return Serialize(cal);
    }

    private static void Apply(Ical.Net.Calendar cal, CalendarEvent ev, EventInput input, string localZone, bool isNew,
        bool isOverride = false)
    {
        static string? Clean(string? s, string field, int max)
        {
            if (string.IsNullOrWhiteSpace(s))
                return null;
            var t = s.Trim();
            return t.Length <= max ? t : throw new FieldValidationException(field, $"Al massimo {max} caratteri.");
        }
        var summary = Clean(input.Summary, "summary", 500);
        var location = Clean(input.Location, "location", 500);
        var description = string.IsNullOrWhiteSpace(input.Description) ? null : input.Description.Length <= 20_000
            ? input.Description.TrimEnd() : throw new FieldValidationException("description", "Al massimo 20000 caratteri.").WithCode("alMassimo20000Caratteri");
        if (input.ReminderMinutes is < 0 or > 40320)
            throw new FieldValidationException("reminderMinutes", "Promemoria non valido (da 0 minuti a 4 settimane prima).").WithCode("promemoriaNonValidoDaMinuti");

        var zone = input.AllDay ? null : NormalizeZone(input.TimeZone) ?? (input.TimeZone is null ? localZone
            : throw new FieldValidationException("timeZone", "Fuso orario sconosciuto."));
        CalDateTime start, end;
        if (input.AllDay)
        {
            var s = ParseDate(input.Start, "start");
            var e = ParseDate(input.End, "end");
            if (e < s)
                throw new FieldValidationException("end", "La fine è prima dell'inizio.").WithCode("laFinePrimaDellInizio");
            start = new CalDateTime(s);
            end = new CalDateTime(e.AddDays(1)); // DTEND escluso (RFC 5545 3.6.1)
        }
        else
        {
            var s = ParseLocal(input.Start, "start");
            var e = ParseLocal(input.End, "end");
            if (e < s)
                throw new FieldValidationException("end", "La fine è prima dell'inizio.").WithCode("laFinePrimaDellInizio");
            start = new CalDateTime(s, zone, true);
            end = new CalDateTime(e, zone, true);
        }

        var startChanged = isNew || ev.DtStart is null || ev.DtStart.HasTime != start.HasTime || ev.DtStart.TzId != start.TzId
            || ev.DtStart.Value != start.Value;
        ev.Summary = summary;
        ev.Location = location;
        if (description != ev.Description)
        {
            ev.Description = description;
            ev.Properties.Remove("X-ALT-DESC"); // versione HTML della descrizione vecchia: non più valida
        }
        ev.DtStart = start;
        if (ev.Duration is not null)
            ev.Duration = null; // DURATION e DTEND non stanno insieme: si usa DTEND (Ical.Net rifiuta di toccarne uno se c'è l'altro)
        ev.DtEnd = end;

        var recurrenceChanged = false;
        if (!input.KeepRecurrence && !isOverride)
        {
            var before = ev.RecurrenceRule?.ToString();
            ev.RecurrenceRule = input.Recurrence is null ? null : ToRule(input.Recurrence, start, zone ?? localZone);
            recurrenceChanged = before != ev.RecurrenceRule?.ToString();
        }
        if (!isNew && !isOverride && (startChanged || recurrenceChanged))
        {
            // Le eccezioni puntano alle occorrenze di prima: con una serie diversa non valgono più.
            // cal.Events è una vista; e Children.Remove confronta gli eventi per UID (serie ed eccezioni ne hanno uno solo):
            // toglierebbe la serie. Si ricostruiscono i figli confrontando per riferimento.
            var keep = cal.Children.Where(c => c is not CalendarEvent e || ReferenceEquals(e, ev) || e.RecurrenceId is null).ToList();
            cal.Children.Clear();
            foreach (var c in keep)
                cal.Children.Add(c);
            ev.Properties.Remove("EXDATE");
            ev.Properties.Remove("RDATE");
        }

        if (isNew || input.ReminderMinutes != Reminder(ev))
        {
            ev.Alarms.Clear();
            if (input.ReminderMinutes is { } minutes)
                ev.Alarms.Add(new Alarm
                {
                    Action = "DISPLAY",
                    Trigger = new Trigger(Ical.Net.DataTypes.Duration.FromMinutes(-minutes)),
                    Description = summary ?? "Promemoria",
                });
        }

        var now = new CalDateTime(DateTime.UtcNow, "UTC");
        if (isNew)
            ev.Created = now;
        else
            ev.Sequence++;
        ev.LastModified = now;
        ev.DtStamp = now;

        if (zone is not null && !string.Equals(zone, "UTC", StringComparison.Ordinal) && cal.TimeZones.All(t => t.TzId != zone))
            cal.AddTimeZone(VTimeZone.FromDateTimeZone(zone, start.Value, includeHistoricalData: false));
    }

    private static DateOnly ParseDate(string? value, string field) =>
        DateOnly.TryParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)
            ? d : throw new FieldValidationException(field, "Data non valida (aaaa-mm-gg).");

    private static DateTime ParseLocal(string? value, string field) =>
        DateTime.TryParseExact(value, ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss"], CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)
            ? DateTime.SpecifyKind(d, DateTimeKind.Unspecified) : throw new FieldValidationException(field, "Ora non valida (aaaa-mm-ggThh:mm).");

    private static string Serialize(Ical.Net.Calendar cal) =>
        CalendarText.Normalize(new CalendarSerializer().SerializeToString(cal) ?? throw new InvalidOperationException("Serializzazione non riuscita.").WithCode("serializzazioneNonRiuscita"));
}
