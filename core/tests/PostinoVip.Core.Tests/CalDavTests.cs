using System.Net;
using PostinoVip.Core.Calendars;
using PostinoVip.Core.Dav;

namespace PostinoVip.Core.Tests;

// Calendario K2a: archivio .ics per calendario, calendari dell'account e sincronizzazione CalDAV nei due sensi con un
// server finto (scoperta dei soli calendari di eventi, più calendari, prima volta con conferma, modifiche, conflitti).
public class CalDavTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-caldav-" + Guid.NewGuid().ToString("N"));
    private readonly FakeCardDavServer _server = new(caldav: true);
    private readonly CalendarSet _set;
    private readonly List<string> _log = [];

    public CalDavTests() => _set = new CalendarSet(Path.Combine(_dir, "calendars"));

    public void Dispose()
    {
        _server.Dispose();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private static readonly DateTimeOffset Now = new(2026, 11, 6, 12, 0, 0, TimeSpan.Zero);

    private DavClient Client(string? password = null) =>
        new(new NetworkCredential(_server.User, password ?? _server.Password), kind: DavKind.CalDav);

    private async Task<DavResult> SyncAsync(bool confirm = false, DateTimeOffset? now = null)
    {
        using var job = new CalDavSyncJob(Client(), _set, DavClient.StartUrl(_server.Url, "x", DavKind.CalDav), _log.Add);
        return await job.RunAsync(now ?? Now, confirm, CancellationToken.None);
    }

    private CalendarStore Default => _set.Store(_set.Default.Id);

    private static string Event(string uid, string summary, string? lastModified = null, string? rrule = null) =>
        FakeCardDavServer.Event(uid, summary, lastModified: lastModified, rrule: rrule);

    // ---------------------------------------------------------------------------------------------
    // Archivio
    // ---------------------------------------------------------------------------------------------

    [Fact]
    public void TestoControllatoEOraDellaModificaConservata()
    {
        Assert.Equal("a", CalendarText.Check(Event("a", "Prova")));
        Assert.Null(CalendarText.Check("non è iCalendar"));
        Assert.Null(CalendarText.Check("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VTODO\r\nUID:t\r\nEND:VTODO\r\nEND:VCALENDAR\r\n"));
        var two = Event("a", "Uno").Replace("END:VCALENDAR", Event("b", "Due")[(Event("b", "Due").IndexOf("BEGIN:VEVENT"))..]);
        Assert.Null(CalendarText.Check(two)); // due UID nello stesso oggetto: no
        Assert.Equal(new DateTimeOffset(2026, 11, 2, 8, 0, 0, TimeSpan.Zero), CalendarText.LastModified(Event("a", "x", "20261102T080000Z")));

        var item = Default.SaveLocal(null, Event("a", "Prova"));
        Assert.Throws<FieldValidationException>(() => Default.SaveLocal(null, Event("a", "Stesso UID")));
        Assert.Throws<FieldValidationException>(() => Default.SaveLocal(null, "non valido"));
        var again = new CalendarSet(Path.Combine(_dir, "calendars")); // altro avvio: dal disco
        var loaded = again.Store(again.Default.Id).Find(item.Id)!;
        Assert.Equal(item.Fingerprint, loaded.Fingerprint);
        Assert.Equal(item.Updated!.Value.ToUnixTimeSeconds(), loaded.Updated!.Value.ToUnixTimeSeconds());
        Assert.Equal(CalendarSet.DefaultName, again.Default.Name);
        if (!OperatingSystem.IsWindows())
            Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite,
                File.GetUnixFileMode(Path.Combine(_dir, "calendars", again.Default.Id, "items", item.Id + ".ics")));
    }

    // ---------------------------------------------------------------------------------------------
    // Scoperta
    // ---------------------------------------------------------------------------------------------

    [Theory]
    [InlineData(true)]
    [InlineData(false)] // come IceWarp: nessun principal
    public async Task SoloICalendariDiEventi(bool principal)
    {
        _server.Principal = principal;
        _server.SecondCalendar = true;
        using var client = Client();
        var found = await client.DiscoverAllAsync(DavClient.StartUrl(_server.Url, "x", DavKind.CalDav), CancellationToken.None);
        Assert.Equal([FakeCardDavServer.CalendarPath, FakeCardDavServer.SecondCalendarPath], found.Select(f => f.Url.AbsolutePath));
        Assert.Equal(["Calendario", "Lavoro"], found.Select(f => f.Name));
    }

    // ---------------------------------------------------------------------------------------------
    // Sincronizzazione
    // ---------------------------------------------------------------------------------------------

    [Fact]
    public async Task PrimaVoltaPiuCalendariEConferma()
    {
        _server.SecondCalendar = true;
        _server.Put("s1.ics", Event("s1", "Dal server", "20261101T100000Z"));
        _server.Put("w1.ics", Event("w1", "Lavoro"), FakeCardDavServer.SecondCalendarPath);
        _server.Put("dup.ics", Event("dup", "Sia qui sia là"));
        Default.SaveLocal(null, Event("dup", "Sia qui sia là"));   // stesso UID: si collega, niente doppione
        var solo = Default.SaveLocal(null, Event("solo", "Solo qui"));

        // «Adesso» un'ora dopo l'ora vera: il doppione senza LAST-MODIFIED risulta cambiato dopo quello locale (vince il server),
        // qualunque sia l'ora in cui gira il test (con l'ora fissa di Now il risultato cambiava dopo le 12 del 06/11/2026).
        var later = DateTimeOffset.UtcNow.AddHours(1);
        var first = await SyncAsync(now: later);
        Assert.True(first.NeedsConfirmation);
        Assert.Equal(1, first.PendingUpload);
        Assert.DoesNotContain(_server.Requests, r => r.StartsWith("PUT") || r.StartsWith("DELETE"));
        var list = _set.List();
        Assert.Equal(["Calendario", "Lavoro"], list.Select(c => c.Name));
        Assert.All(list, c => Assert.NotNull(c.Href));
        Assert.Equal(3, Default.Count);                             // s1, dup, solo
        Assert.Equal("w1", Assert.Single(_set.Store(list[1].Id).List()).Uid);

        var confirmed = await SyncAsync(confirm: true, now: later);
        Assert.False(confirmed.NeedsConfirmation);
        Assert.Equal(1, confirmed.Uploaded);
        Assert.Equal(Default.Find(solo.Id)!.Text, _server.Cards["solo.ics"]); // testo così com'è
        Assert.False((await SyncAsync()).AnyChange);
    }

    [Fact]
    public async Task ModificheEdEliminazioniNeiDueSensi()
    {
        _server.Put("a.ics", Event("a", "Riunione", "20261101T100000Z", rrule: "FREQ=WEEKLY;COUNT=3"));
        _server.Put("b.ics", Event("b", "Pranzo", "20261101T100000Z"));
        await SyncAsync();
        Assert.Equal(2, Default.Count);

        _server.Put("a.ics", Event("a", "Riunione spostata", "20261102T100000Z", rrule: "FREQ=WEEKLY;COUNT=3"));
        _server.Remove("b.ics");
        var r = await SyncAsync();
        Assert.Equal((1, 1), (r.Downloaded, r.DeletedHere));
        var a = Assert.Single(Default.List());
        Assert.Contains("SUMMARY:Riunione spostata", a.Text);
        Assert.Equal(new DateTimeOffset(2026, 11, 2, 10, 0, 0, TimeSpan.Zero), a.Updated); // LAST-MODIFIED

        Default.SaveLocal(a.Id, Event("a", "Cambiato qui", rrule: "FREQ=WEEKLY;COUNT=3"));
        var nuovo = Default.SaveLocal(null, Event("c", "Nuovo qui"));
        var r2 = await SyncAsync();
        Assert.Equal(2, r2.Uploaded);
        Assert.Contains("SUMMARY:Cambiato qui", _server.Cards["a.ics"]); // stesso file sul server
        Assert.True(_server.Cards.ContainsKey("c.ics"));

        Default.DeleteLocal(nuovo.Id);
        var r3 = await SyncAsync();
        Assert.Equal(1, r3.DeletedThere);
        Assert.False(_server.Cards.ContainsKey("c.ics"));
        Assert.False((await SyncAsync()).AnyChange);
    }

    [Fact]
    public async Task ConflittoDecisoDaLastModified()
    {
        _server.Put("a.ics", Event("a", "Originale", "20261101T100000Z"));
        await SyncAsync();
        var a = Default.List()[0];
        Default.SaveLocal(a.Id, Event("a", "Computer")); // adesso
        _server.Put("a.ics", Event("a", "Server", DateTimeOffset.UtcNow.AddMinutes(1).ToString("yyyyMMdd'T'HHmmss'Z'")));
        var r = await SyncAsync(now: DateTimeOffset.UtcNow);
        Assert.Equal(1, r.Conflicts);
        Assert.Contains("SUMMARY:Server", Default.List()[0].Text);

        Default.SaveLocal(a.Id, Event("a", "Computer di nuovo"));
        _server.Put("a.ics", Event("a", "Server vecchio", "20261103T100000Z")); // prima della modifica sul computer
        await SyncAsync(now: DateTimeOffset.UtcNow);
        Assert.Contains("SUMMARY:Computer di nuovo", Default.List()[0].Text);
        Assert.Contains("SUMMARY:Computer di nuovo", _server.Cards["a.ics"]);
    }

    [Fact]
    public async Task CampiSconosciutiEPromemoriaRestanoUguali()
    {
        var text = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//IceWarp//IceWarp Server 13.0.3.13 x64//EN\r\n"
            + "BEGIN:VTIMEZONE\r\nTZID:Europe/Amsterdam\r\nBEGIN:STANDARD\r\nDTSTART:19701025T030000\r\nTZOFFSETFROM:+0200\r\nTZOFFSETTO:+0100\r\n"
            + "RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10\r\nEND:STANDARD\r\nBEGIN:DAYLIGHT\r\nDTSTART:19700329T020000\r\nTZOFFSETFROM:+0100\r\n"
            + "TZOFFSETTO:+0200\r\nRRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=3\r\nEND:DAYLIGHT\r\nEND:VTIMEZONE\r\n"
            + "BEGIN:VEVENT\r\nUID:iw-1\r\nDTSTAMP:20261106T090000Z\r\nDTSTART;TZID=Europe/Amsterdam:20261110T140000\r\n"
            + "DTEND;TZID=Europe/Amsterdam:20261110T150000\r\nSUMMARY:Da IceWarp\r\nX-ICEWARP-QUALCOSA:valore\r\n"
            + "BEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT15M\r\nDESCRIPTION:Promemoria\r\nEND:VALARM\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n";
        _server.Put("iw-1.ics", text);
        await SyncAsync();
        Assert.Equal(text, Default.List()[0].Text);
    }

    [Fact]
    public async Task CalendarioSparitoDalServerRestaSulComputer()
    {
        _server.SecondCalendar = true;
        _server.Put("w1.ics", Event("w1", "Lavoro"), FakeCardDavServer.SecondCalendarPath);
        await SyncAsync();
        var work = _set.List()[1];
        _server.SecondCalendar = false;
        await SyncAsync();
        var after = _set.Get(work.Id);
        Assert.Null(after.Href);
        Assert.Equal(1, _set.Store(work.Id).Count);
        Assert.Contains(_log, l => l.Contains("non più sul server"));
    }

    [Fact]
    public async Task ServerSpentoEPasswordSbagliata()
    {
        using (var job = new CalDavSyncJob(Client("sbagliata"), _set, DavClient.StartUrl(_server.Url, "x", DavKind.CalDav)))
        {
            var ex = await Assert.ThrowsAsync<DavException>(() => job.RunAsync(Now, false, CancellationToken.None));
            Assert.Contains("server del calendario", ex.Message);
        }
        _server.Dispose();
        await Assert.ThrowsAsync<MailOfflineException>(() => SyncAsync());
    }

    [Fact]
    public async Task LavoratoreParteDopoUnaModificaNellApp()
    {
        DavWorker.Debounce = TimeSpan.FromMilliseconds(10);
        var start = DavClient.StartUrl(_server.Url, "x", DavKind.CalDav);
        void Log(string m) { lock (_log) _log.Add(m); } // il lavoratore scrive da un altro thread
        var worker = new DavWorker("a1", wake => _set.LocalChanged += wake, () => new CalDavSyncJob(Client(), _set, start),
            null, Log, null, "CalDAV");
        using var cts = new CancellationTokenSource();
        var run = worker.RunAsync(cts.Token);
        await WaitFor(() => worker.Status.State == "ok");
        Default.SaveLocal(null, Event("n", "Nuovo"));
        await WaitFor(() => _server.Cards.ContainsKey("n.ics"));
        await WaitFor(() => { lock (_log) return _log.Any(l => l.StartsWith("[a1] CalDAV:")); }); // il log arriva a giro finito
        await cts.CancelAsync();
        await run;
    }

    private static async Task WaitFor(Func<bool> condition)
    {
        for (var i = 0; i < 200 && !condition(); i++)
            await Task.Delay(25);
        Assert.True(condition());
    }
}
