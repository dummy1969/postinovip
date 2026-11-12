using PostinoVip.Core.Dav;

namespace PostinoVip.Core.Calendars;

/// <summary>
/// Un calendario come lo vede la sincronizzazione: il testo iCalendar si conserva così com'è (niente dati persi), la chiave
/// dei doppioni è l'UID, l'ora della modifica è LAST-MODIFIED (2a; altrimenti quella in cui il core vede il cambiamento).
/// </summary>
public sealed class CalendarDavStore(CalendarStore store) : IDavItemStore
{
    public string ItemsLabel => "appuntamenti";
    public int MaxItems => CalendarStore.MaxItems;

    public IReadOnlyList<DavLocalItem> List() => store.List().Select(ToItem).ToList();

    public DavLocalItem? Find(string id) => store.Find(id) is { } i ? ToItem(i) : null;

    public DavIncoming? Parse(string data)
    {
        var calendar = CalendarText.Load(data);
        if (calendar is null || CalendarText.Check(data) is not { } uid)
            return null;
        return new DavIncoming(data, CalendarText.LastModified(calendar), uid);
    }

    public DavApplyResult Apply(string? id, DavIncoming incoming, DateTimeOffset updated, string? expectedFingerprint)
    {
        var (item, outcome) = store.ApplyFromSync(id, (string)incoming.Value, updated, expectedFingerprint);
        return new DavApplyResult(item is null ? null : ToItem(item), outcome);
    }

    public bool Remove(string id, string expectedFingerprint) => store.RemoveFromSync(id, expectedFingerprint);

    public DavExport? Export(string id, string expectedFingerprint) =>
        store.Find(id) is { } i && i.Fingerprint == expectedFingerprint
            ? new DavExport(i.Text, ToItem(i), DavSync.FileNameFromUid(i.Uid, i.Id, ".ics"))
            : null;

    private static DavLocalItem ToItem(CalendarItem i) => new(i.Id, i.Fingerprint, i.Updated, i.Uid);
}

/// <summary>
/// Un giro CalDAV di un account (K2a): scopre i calendari del server che accettano eventi (scelta 4a: tutti), li collega
/// ai calendari sul computer (il predefinito al primo del server, gli altri nuovi), poi sincronizza ognuno con le regole
/// comuni (<see cref="DavSync"/>). La conferma della prima volta vale per tutti; un calendario sparito dal server resta
/// sul computer, scollegato.
/// </summary>
public sealed class CalDavSyncJob(DavClient client, CalendarSet calendars, Uri start, Action<string>? log = null) : IDavSyncJob
{
    public async Task<DavResult> RunAsync(DateTimeOffset now, bool confirm, CancellationToken ct)
    {
        var found = await client.DiscoverAllAsync(start, ct);
        var server = found.Select(f => (Href: WithSlash(f.Url).AbsoluteUri, f.Name, f.ReadOnly)).DistinctBy(f => f.Href).ToList();

        // Collegamenti: quelli già noti, poi il predefinito (se non collegato) al primo scrivibile del server (G2: mai alle
        // festività di sola lettura), poi calendari nuovi.
        var local = calendars.List();
        foreach (var c in local.Where(c => c.Href is not null && server.All(s => s.Href != c.Href)))
        {
            log?.Invoke($"CalDAV: calendario {c.Id} non più sul server: resta sul computer, scollegato");
            calendars.Unlink(c.Id);
        }
        foreach (var s in server.OrderBy(s => s.ReadOnly)) // prima gli scrivibili: il predefinito va a uno di loro
        {
            var linked = calendars.List().FirstOrDefault(c => c.Href == s.Href);
            if (linked is not null)
            {
                if ((s.Name is { Length: > 0 } name && name != linked.Name) || s.ReadOnly != linked.ReadOnly)
                    calendars.Link(linked.Id, s.Href, s.Name, s.ReadOnly); // rinominato, o permessi cambiati sul server
                continue;
            }
            var free = s.ReadOnly ? null : calendars.List().FirstOrDefault(c => c.Href is null && c.Id == calendars.Default.Id);
            if (free is not null)
                calendars.Link(free.Id, s.Href, s.Name);
            else
                calendars.Add(s.Name ?? CalendarSet.DefaultName, s.Href, s.ReadOnly);
        }

        var results = new List<DavResult>();
        foreach (var c in calendars.List().Where(c => c.Href is not null))
        {
            var sync = new DavSync(client, new CalendarDavStore(calendars.Store(c.Id)), new DavStateStore(calendars.StatePath(c.Id)),
                start, start.AbsoluteUri + " " + c.Href, log, new Uri(c.Href!), readOnly: c.ReadOnly);
            results.Add(await sync.RunAsync(now, confirm, ct)); // il client lo chiude il giro, non la singola sincronizzazione
        }
        var names = calendars.List().Where(c => c.Href is not null).Select(c => c.Name).ToList();
        return DavResult.Sum(results, names.Count == 1 ? names[0] : $"{names.Count} calendari");
    }

    public void Dispose() => client.Dispose();

    private static Uri WithSlash(Uri url) =>
        url.AbsolutePath.EndsWith('/') ? url : new UriBuilder(url) { Path = url.AbsolutePath + "/" }.Uri;
}
