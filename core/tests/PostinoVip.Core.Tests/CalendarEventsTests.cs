using PostinoVip.Core.Calendars;

namespace PostinoVip.Core.Tests;

// Calendario K2b: appuntamenti dal testo iCalendar (Ical.Net) — occorrenze con le ricorrenze espanse, dettaglio, creazione e
// modifica che conserva il resto del testo, modello della finestra «Ricorrenza».
public class CalendarEventsTests : IDisposable
{
    private const string Rome = "Europe/Rome";
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-events-" + Guid.NewGuid().ToString("N"));
    private readonly CalendarSet _set;

    public CalendarEventsTests() => _set = new CalendarSet(Path.Combine(_dir, "calendars"));

    public void Dispose()
    {
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private string Cal => _set.Default.Id;
    private CalendarStore Store => _set.Store(Cal);

    private static DateTimeOffset T(string iso) => DateTimeOffset.Parse(iso, System.Globalization.CultureInfo.InvariantCulture);

    private OccurrencePage Range(string from, string to) => CalendarEvents.Occurrences(_set, [Cal], T(from), T(to), Rome);

    private CalendarItem Save(EventInput input) => Store.SaveLocal(null, CalendarEvents.Create(input, Rome));

    [Fact]
    public void NuovoSettimanaleConPromemoriaACavalloDelCambioDellOra()
    {
        var item = Save(new EventInput("Riunione", "Sala 1", "Ordine del giorno", "2026-10-15T09:00", "2026-10-15T10:00", false,
            Rome, 15, new EventRecurrence("weekly", Days: ["TH"], Count: 4)));
        Assert.Contains("BEGIN:VTIMEZONE\r\nTZID:Europe/Rome", item.Text);
        Assert.Contains("RRULE:FREQ=WEEKLY;COUNT=4;BYDAY=TH", item.Text);
        Assert.Contains("TRIGGER:-PT15M", item.Text);

        var page = Range("2026-10-01T00:00:00Z", "2026-12-01T00:00:00Z");
        Assert.Equal(["2026-10-15T07:00:00Z", "2026-10-22T07:00:00Z", "2026-10-29T08:00:00Z", "2026-11-05T08:00:00Z"],
            page.Items.Select(o => o.Start)); // 09:00 di Roma, prima e dopo il 25/10
        Assert.All(page.Items, o => Assert.True(o.Recurring));
        Assert.Equal("2026-10-15T08:00:00Z", page.Items[0].End);
        Assert.Equal(page.Items[0].Start, page.Items[0].RecurrenceId);
        Assert.Equal(15, page.Items[0].ReminderMinutes);

        var d = CalendarEvents.Detail(Cal, item, Rome);
        Assert.Equal(("Riunione", "Sala 1", "Ordine del giorno"), (d.Summary, d.Location, d.Description));
        Assert.Equal(("2026-10-15T09:00", "2026-10-15T10:00", Rome, false), (d.Start, d.End, d.TimeZone, d.AllDay));
        Assert.Equal(("weekly", 1, 4), (d.Recurrence!.Frequency, d.Recurrence.Interval, d.Recurrence.Count));
        Assert.Equal(["TH"], d.Recurrence.Days!);
        Assert.Null(d.CustomRecurrence);
        Assert.Equal(15, d.ReminderMinutes);
    }

    [Fact]
    public void GiornataInteraConDateComprese()
    {
        var item = Save(new EventInput("Ferie", null, null, "2026-11-03", "2026-11-04", true));
        Assert.Contains("DTSTART;VALUE=DATE:20261103", item.Text);
        Assert.Contains("DTEND;VALUE=DATE:20261105", item.Text); // DTEND escluso
        var o = Assert.Single(Range("2026-11-01T00:00:00Z", "2026-11-30T00:00:00Z").Items);
        Assert.Equal(("2026-11-03", "2026-11-04", true, false), (o.Start, o.End, o.AllDay, o.Recurring));
        var d = CalendarEvents.Detail(Cal, item, Rome);
        Assert.Equal(("2026-11-03", "2026-11-04", true), (d.Start, d.End, d.AllDay));
        Assert.Empty(Range("2026-11-05T00:00:00Z", "2026-11-30T00:00:00Z").Items);
    }

    [Fact]
    public void PeriodoComprendeQuelloIniziatoPrimaEPeriodoTroppoLungo()
    {
        Save(new EventInput("Conferenza", null, null, "2026-11-09T09:00", "2026-11-12T18:00", false, Rome));
        Assert.Single(Range("2026-11-10T00:00:00Z", "2026-11-11T00:00:00Z").Items);
        var ex = Assert.Throws<FieldValidationException>(() => Range("2026-01-01T00:00:00Z", "2027-03-01T00:00:00Z"));
        Assert.Equal("to", ex.Field);
    }

    [Fact]
    public void ModificaConservaIlRestoDelTesto()
    {
        var text = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//IceWarp//IceWarp Server 13.0.3.13 x64//EN\r\n"
            + "BEGIN:VEVENT\r\nUID:iw-1\r\nDTSTAMP:20261106T090000Z\r\nSEQUENCE:2\r\nDTSTART;TZID=Europe/Rome:20261110T140000\r\n"
            + "DTEND;TZID=Europe/Rome:20261110T150000\r\nSUMMARY:Da IceWarp\r\nX-ICEWARP-QUALCOSA:valore\r\n"
            + "ATTENDEE;CN=Anna:mailto:anna@example.com\r\n"
            + "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT30M\r\nDESCRIPTION:Promemoria\r\nEND:VALARM\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";
        var item = Store.SaveLocal(null, text);
        var updated = CalendarEvents.Update(item.Text,
            new EventInput("Da IceWarp, rinominato", null, null, "2026-11-10T14:00", "2026-11-10T15:00", false, Rome, 30, KeepRecurrence: true), Rome);
        Assert.Contains("SUMMARY:Da IceWarp\\, rinominato", updated);
        Assert.Contains("X-ICEWARP-QUALCOSA:valore", updated);
        Assert.Contains("ATTENDEE;CN=Anna:mailto:anna@example.com", updated);
        Assert.Contains("TRIGGER:-PT30M", updated);        // promemoria uguale: non toccato
        Assert.Contains("SEQUENCE:3", updated);
        Assert.Contains("LAST-MODIFIED:", updated);
        Assert.Equal(1, CalendarEvents.Detail(Cal, Store.SaveLocal(item.Id, updated), Rome).Attendees);
    }

    [Fact]
    public void CambiareInizioORicorrenzaTogliLeEccezioni()
    {
        var text = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//prova//IT\r\n"
            + "BEGIN:VEVENT\r\nUID:serie\r\nDTSTAMP:20261001T000000Z\r\nDTSTART;TZID=Europe/Rome:20261102T090000\r\n"
            + "DTEND;TZID=Europe/Rome:20261102T100000\r\nRRULE:FREQ=DAILY;COUNT=5\r\nEXDATE;TZID=Europe/Rome:20261103T090000\r\nSUMMARY:Serie\r\nEND:VEVENT\r\n"
            + "BEGIN:VEVENT\r\nUID:serie\r\nDTSTAMP:20261001T000000Z\r\nRECURRENCE-ID;TZID=Europe/Rome:20261104T090000\r\n"
            + "DTSTART;TZID=Europe/Rome:20261104T150000\r\nDTEND;TZID=Europe/Rome:20261104T160000\r\nSUMMARY:Spostata\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";
        var item = Store.SaveLocal(null, text);
        var page = Range("2026-11-01T00:00:00Z", "2026-11-10T00:00:00Z").Items;
        Assert.Equal(4, page.Count);                                  // 5 meno l'esclusa
        Assert.Contains(page, o => o.Summary == "Spostata" && o.Start == "2026-11-04T14:00:00Z" && o.RecurrenceId == "2026-11-04T08:00:00Z");
        Assert.Equal(2, CalendarEvents.Detail(Cal, item, Rome).Exceptions);

        // Solo l'oggetto: le eccezioni restano.
        var same = CalendarEvents.Update(item.Text, new EventInput("Serie nuova", null, null, "2026-11-02T09:00", "2026-11-02T10:00", false,
            Rome, KeepRecurrence: true), Rome);
        Assert.Contains("RECURRENCE-ID", same);
        Assert.Contains("EXDATE", same);
        // Inizio spostato alle 10: come Outlook le eccezioni si tolgono.
        var moved = CalendarEvents.Update(item.Text, new EventInput("Serie", null, null, "2026-11-02T10:00", "2026-11-02T11:00", false,
            Rome, KeepRecurrence: true), Rome);
        Assert.DoesNotContain("RECURRENCE-ID", moved);
        Assert.DoesNotContain("EXDATE", moved);
        Assert.Contains("RRULE:FREQ=DAILY;COUNT=5", moved);
    }

    [Theory]
    [InlineData("monthly", 2, null, 2, "TU", null, "RRULE:FREQ=MONTHLY;INTERVAL=2;BYDAY=2TU")]   // il secondo martedì ogni 2 mesi
    [InlineData("monthly", 1, 15, null, null, null, "RRULE:FREQ=MONTHLY;BYMONTHDAY=15")]
    [InlineData("monthly", 1, null, -1, "FR", null, "RRULE:FREQ=MONTHLY;BYDAY=-1FR")]            // l'ultimo venerdì
    [InlineData("yearly", 1, 25, null, null, 12, "RRULE:FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=25")]
    [InlineData("daily", 3, null, null, null, null, "RRULE:FREQ=DAILY;INTERVAL=3")]
    public void RicorrenzeDellaFinestraAndataERitorno(string freq, int interval, int? monthDay, int? week, string? day, int? month, string expected)
    {
        var rec = new EventRecurrence(freq, interval, day is null ? null : [day], monthDay, week, month);
        var item = Save(new EventInput("R", null, null, "2026-11-10T09:00", "2026-11-10T09:30", false, Rome, Recurrence: rec));
        Assert.Contains(expected, item.Text);
        var back = CalendarEvents.Detail(Cal, item, Rome).Recurrence!;
        Assert.Equal((rec.Frequency, rec.Interval, rec.MonthDay, rec.Week, rec.Month), (back.Frequency, back.Interval, back.MonthDay, back.Week, back.Month));
        Assert.Equal(rec.Days ?? [], back.Days ?? []);
    }

    [Fact]
    public void FineEntroUnaDataEInUtc()
    {
        var item = Save(new EventInput("R", null, null, "2026-11-02T09:00", "2026-11-02T10:00", false, Rome,
            Recurrence: new EventRecurrence("weekly", Days: ["MO", "WE"], Until: "2026-11-11")));
        Assert.Contains("RRULE:FREQ=WEEKLY;UNTIL=20261111T225959Z;BYDAY=MO,WE", item.Text);
        Assert.Equal(4, Range("2026-11-01T00:00:00Z", "2026-12-01T00:00:00Z").Items.Count); // 2, 4, 9, 11
        Assert.Equal("2026-11-11", CalendarEvents.Detail(Cal, item, Rome).Recurrence!.Until);
    }

    [Fact]
    public void RegolaPersonalizzataSiVedeESiConserva()
    {
        var text = FakeCardDavServer.Event("x", "Due volte al giorno", rrule: "FREQ=DAILY;COUNT=2;BYHOUR=9,15");
        var item = Store.SaveLocal(null, text);
        var d = CalendarEvents.Detail(Cal, item, Rome);
        Assert.Null(d.Recurrence);
        Assert.Contains("BYHOUR=9,15", d.CustomRecurrence);
        var kept = CalendarEvents.Update(item.Text, new EventInput("Rinominato", null, null, d.Start, d.End, false, Rome, KeepRecurrence: true), Rome);
        Assert.Contains("BYHOUR=9,15", kept);
        var removed = CalendarEvents.Update(item.Text, new EventInput("Senza ripetizione", null, null, d.Start, d.End, false, Rome), Rome);
        Assert.DoesNotContain("RRULE:FREQ=DAILY", removed); // (le RRULE del VTIMEZONE restano: sono le regole dell'ora legale)
    }

    [Fact]
    public void ControlliEFusi()
    {
        FieldValidationException Bad(EventInput i) => Assert.Throws<FieldValidationException>(() => CalendarEvents.Create(i, Rome));
        Assert.Equal("end", Bad(new EventInput("x", null, null, "2026-11-10T10:00", "2026-11-10T09:00", false)).Field);
        Assert.Equal("start", Bad(new EventInput("x", null, null, "domani", "2026-11-10T09:00", false)).Field);
        Assert.Equal("timeZone", Bad(new EventInput("x", null, null, "2026-11-10T09:00", "2026-11-10T10:00", false, "Marte/Olympus")).Field);
        Assert.Equal("recurrence", Bad(new EventInput("x", null, null, "2026-11-10T09:00", "2026-11-10T10:00", false,
            Recurrence: new EventRecurrence("weekly", Days: ["XX"]))).Field);
        Assert.Equal("recurrence", Bad(new EventInput("x", null, null, "2026-11-10T09:00", "2026-11-10T10:00", false,
            Recurrence: new EventRecurrence("monthly", Count: 3, Until: "2027-01-01"))).Field);
        Assert.Equal("reminderMinutes", Bad(new EventInput("x", null, null, "2026-11-10T09:00", "2026-11-10T10:00", false, ReminderMinutes: -5)).Field);
        Assert.Equal("Europe/Berlin", CalendarEvents.NormalizeZone("W. Europe Standard Time"));
        Assert.Null(CalendarEvents.NormalizeZone("Inesistente"));
        Assert.NotNull(CalendarEvents.NormalizeZone(CalendarEvents.LocalTimeZone()));
    }

    [Fact]
    public void OraSenzaFusoNellOraDelComputer()
    {
        var text = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//prova//IT\r\nBEGIN:VEVENT\r\nUID:f\r\nDTSTAMP:20261101T000000Z\r\n"
            + "DTSTART:20261110T090000\r\nDTEND:20261110T100000\r\nSUMMARY:Senza fuso\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";
        Store.SaveLocal(null, text);
        Assert.Equal("2026-11-10T08:00:00Z", Assert.Single(Range("2026-11-10T00:00:00Z", "2026-11-11T00:00:00Z").Items).Start);
    }

    // ---------------------------------------------------------------- K4a: una sola occorrenza

    private CalendarItem WeeklySeries() => Save(new EventInput("Riunione", "Sala 1", "Note", "2026-11-02T09:00", "2026-11-02T10:00", false,
        Rome, 15, new EventRecurrence("weekly", Days: ["MO"], Count: 4)));

    private List<EventOccurrence> November() => Range("2026-11-01T00:00:00Z", "2026-12-01T00:00:00Z").Items.ToList();

    [Fact]
    public void SoloQuestaOccorrenzaModificata()
    {
        var item = WeeklySeries();
        var second = November()[1];
        Assert.Equal("2026-11-09T08:00:00Z", second.RecurrenceId);
        var detail = CalendarEvents.OccurrenceDetail(Cal, item, second.RecurrenceId!, Rome);
        Assert.Equal(("2026-11-09T09:00", "2026-11-09T10:00", "Riunione", 15), (detail.Start, detail.End, detail.Summary, detail.ReminderMinutes));
        Assert.Equal(second.RecurrenceId, detail.RecurrenceId);

        var text = CalendarEvents.UpdateOccurrence(item.Text, second.RecurrenceId!,
            new EventInput("Riunione spostata", "Sala 2", null, "2026-11-09T15:00", "2026-11-09T16:30", false, Rome, 30), Rome);
        Assert.Contains("RECURRENCE-ID;TZID=Europe/Rome:20261109T090000", text);
        item = Store.SaveLocal(item.Id, text);
        var list = November();
        Assert.Equal(4, list.Count);
        var moved = Assert.Single(list, o => o.Summary == "Riunione spostata");
        Assert.Equal(("2026-11-09T14:00:00Z", "2026-11-09T15:30:00Z", "2026-11-09T08:00:00Z", 30), (moved.Start, moved.End, moved.RecurrenceId, moved.ReminderMinutes));
        Assert.All(list.Where(o => o != moved), o => Assert.Equal("Riunione", o.Summary));

        // La seconda modifica della stessa occorrenza cambia l'eccezione, non ne aggiunge un'altra.
        text = CalendarEvents.UpdateOccurrence(item.Text, second.RecurrenceId!,
            new EventInput("Riunione spostata di nuovo", "Sala 2", null, "2026-11-09T16:00", "2026-11-09T17:00", false, Rome, 30), Rome);
        Assert.Equal(1, text.Split("RECURRENCE-ID").Length - 1);
        item = Store.SaveLocal(item.Id, text);
        Assert.Equal("Riunione spostata di nuovo", CalendarEvents.OccurrenceDetail(Cal, item, second.RecurrenceId!, Rome).Summary);
        Assert.Equal(1, CalendarEvents.Detail(Cal, item, Rome).Exceptions);

        // La serie modificata senza cambiare ora tiene l'eccezione.
        text = CalendarEvents.Update(item.Text, new EventInput("Riunione settimanale", "Sala 1", "Note", "2026-11-02T09:00", "2026-11-02T10:00",
            false, Rome, 15, KeepRecurrence: true), Rome);
        Assert.Contains("RECURRENCE-ID", text);
    }

    [Fact]
    public void SoloQuestaOccorrenzaEliminata()
    {
        var item = WeeklySeries();
        var list = November();
        var text = CalendarEvents.UpdateOccurrence(item.Text, list[1].RecurrenceId!,
            new EventInput("Spostata", null, null, "2026-11-09T15:00", "2026-11-09T16:00", false, Rome), Rome);
        item = Store.SaveLocal(item.Id, text);
        item = Store.SaveLocal(item.Id, CalendarEvents.DeleteOccurrence(item.Text, list[1].RecurrenceId!, Rome)); // quella modificata
        item = Store.SaveLocal(item.Id, CalendarEvents.DeleteOccurrence(item.Text, list[2].RecurrenceId!, Rome)); // una normale
        Assert.DoesNotContain("RECURRENCE-ID", item.Text);
        Assert.Contains("EXDATE", item.Text);
        Assert.Equal(["2026-11-02T08:00:00Z", "2026-11-23T08:00:00Z"], November().Select(o => o.Start));
        Assert.Equal(2, CalendarEvents.Detail(Cal, item, Rome).Exceptions);
    }

    [Fact]
    public void OccorrenzaDiGiornataInteraENonRicorrente()
    {
        var item = Save(new EventInput("Ferie", null, null, "2026-11-02", "2026-11-03", true, Recurrence: new EventRecurrence("weekly", Days: ["MO"], Count: 2)));
        var second = November()[1];
        Assert.Equal("2026-11-09", second.RecurrenceId);
        var d = CalendarEvents.OccurrenceDetail(Cal, item, second.RecurrenceId!, Rome);
        Assert.Equal(("2026-11-09", "2026-11-10", true), (d.Start, d.End, d.AllDay));
        item = Store.SaveLocal(item.Id, CalendarEvents.DeleteOccurrence(item.Text, second.RecurrenceId!, Rome));
        Assert.Single(November());

        var single = Save(new EventInput("Una volta", null, null, "2026-11-04T09:00", "2026-11-04T10:00", false, Rome));
        Assert.Throws<InvalidOperationException>(() => CalendarEvents.DeleteOccurrence(single.Text, "2026-11-04T08:00:00Z", Rome));
    }

    // ---------------------------------------------------------------- fusi scritti male da altri programmi

    private static string WithZone(string uid, string tzid, string vtimezone = "") =>
        "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//IceWarp//IceWarp Server 13.0.3.13 x64//EN\r\n" + vtimezone
        + $"BEGIN:VEVENT\r\nUID:{uid}\r\nDTSTAMP:20261101T000000Z\r\nDTSTART;TZID={tzid}:20261110T090000\r\n"
        + $"DTEND;TZID={tzid}:20261110T100000\r\nSUMMARY:{uid}\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";

    [Fact]
    public void FusiSconosciutiOConPrefissoNonBloccanoIlCalendario()
    {
        var bogus = "BEGIN:VTIMEZONE\r\nTZID:TZID\r\nBEGIN:STANDARD\r\nDTSTART:19701025T030000\r\nTZOFFSETFROM:+0200\r\n"
            + "TZOFFSETTO:+0100\r\nEND:STANDARD\r\nEND:VTIMEZONE\r\n";
        var sconosciuto = Store.SaveLocal(null, WithZone("sconosciuto", "TZID", bogus));          // come in un calendario vero
        Store.SaveLocal(null, WithZone("libical", "/freeassociation.sourceforge.net/Europe/Rome")); // Evolution/libical
        Store.SaveLocal(null, WithZone("windows", "W. Europe Standard Time"));                     // Outlook
        Store.SaveLocal(null, WithZone("normale", "Europe/Rome"));

        var page = Range("2026-11-01T00:00:00Z", "2026-12-01T00:00:00Z");
        Assert.Equal(0, page.Skipped);
        Assert.Equal(4, page.Items.Count);
        Assert.All(page.Items, o => Assert.Equal("2026-11-10T08:00:00Z", o.Start)); // 09:00 a Roma (il computer, nei test: Roma)
        Assert.Equal("Europe/Rome", TimeZones.Name("/freeassociation.sourceforge.net/Europe/Rome"));
        Assert.Null(TimeZones.Name("TZID"));

        // Il dettaglio dà un fuso valido (quello del computer), così salvando non c'è errore e il TZID si corregge.
        var d = CalendarEvents.Detail(Cal, sconosciuto, Rome);
        Assert.Equal(Rome, d.TimeZone);
        var fixedText = CalendarEvents.Update(sconosciuto.Text, new EventInput("sconosciuto", null, null, d.Start, d.End, false, d.TimeZone,
            KeepRecurrence: true), Rome);
        Assert.Contains("DTSTART;TZID=Europe/Rome:20261110T090000", fixedText);
    }
}
