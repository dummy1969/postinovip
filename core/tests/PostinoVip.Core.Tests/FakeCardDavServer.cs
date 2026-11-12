using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Xml.Linq;

namespace PostinoVip.Core.Tests;

/// <summary>
/// Server DAV finto su 127.0.0.1 (solo HTTP, solo per i test), con autenticazione Basic. Rubrica (CardDAV, predefinito)
/// o calendari (CalDAV, <c>caldav: true</c>). Struttura: <c>/.well-known/carddav</c> (o caldav) -> 301 <c>/dav/</c>; con
/// <see cref="Principal"/> <c>/dav/</c> indica <c>current-user-principal</c> = <c>/dav/principals/u/</c> con la cartella
/// delle raccolte <c>/dav/u/</c>; senza (come IceWarp) si trova solo esplorando le cartelle. In <c>/dav/u/</c>: per
/// CardDAV un calendario (da ignorare) e la rubrica <see cref="BookPath"/>; per CalDAV i calendari «Attività» (solo VTODO,
/// da ignorare), <see cref="CalendarPath"/> e, con <see cref="SecondCalendar"/>, <see cref="SecondCalendarPath"/>.
/// Ogni raccolta con ctag, sync-token (<see cref="SupportsSync"/>), multiget (<see cref="SupportsMultiget"/>), GET, PUT e
/// DELETE condizionati. Registra le richieste.
/// </summary>
public sealed class FakeCardDavServer : IDisposable
{
    public const string BookPath = "/dav/u/Contatti/";
    public const string CalendarPath = "/dav/u/Calendario/";
    public const string SecondCalendarPath = "/dav/u/Lavoro/";
    public const string TasksPath = "/dav/u/Attivita/";
    public const string HolidaysPath = "/dav/u/Festivita/";
    private static readonly XNamespace D = "DAV:";
    private static readonly XNamespace C = "urn:ietf:params:xml:ns:carddav";
    private static readonly XNamespace Cal = "urn:ietf:params:xml:ns:caldav";
    private static readonly XNamespace CS = "http://calendarserver.org/ns/";

    private readonly HttpListener _listener = new();
    private readonly Lock _lock = new();
    private readonly bool _caldav;
    private readonly Dictionary<string, (string Etag, string Data)> _cards = [];
    private readonly List<(int N, string Href)> _log = []; // modifiche ed eliminazioni, per sync-collection
    private int _version;

    public FakeCardDavServer(bool caldav = false)
    {
        _caldav = caldav;
        var port = FreePort();
        Url = $"http://127.0.0.1:{port}/";
        _listener.Prefixes.Add(Url);
        _listener.Start();
        _ = Task.Run(LoopAsync);
    }

    public string Url { get; }
    public string User { get; set; } = "u@example.com";
    public string Password { get; set; } = "segreta";
    public bool Principal { get; set; } = true;

    /// <summary>C4d: accetta (anche) «Authorization: Bearer» con un token che soddisfa la condizione, come Google.</summary>
    public Func<string, bool>? AcceptBearer { get; set; }

    /// <summary>C4d: risponde 403 con questo corpo JSON a ogni richiesta autenticata (API non attiva, permesso mancante).</summary>
    public string? ForbiddenBody { get; set; }

    /// <summary>
    /// C4d-b, come Google: un elemento nuovo non si crea con PUT (403) ma con POST sulla raccolta, che sceglie l'indirizzo
    /// (Location); con <see cref="PostWithoutEtag"/> la risposta non dà l'ETag.
    /// </summary>
    public bool CreateWithPost { get; set; }
    public bool PostWithoutEtag { get; set; }

    /// <summary>Come Google (verificato): il PUT di un elemento nuovo lo salva con un id scelto qui e lo indica in Location.</summary>
    public bool PutCreatesWithOwnId { get; set; }
    private int _posted;

    /// <summary>Intestazioni Authorization ricevute.</summary>
    public ConcurrentQueue<string> Authorizations { get; } = new();
    public bool SupportsSync { get; set; } = true;
    public bool SupportsMultiget { get; set; } = true;

    /// <summary>CalDAV: un secondo calendario di eventi, «Lavoro».</summary>
    public bool SecondCalendar { get; set; }

    /// <summary>
    /// G2, come Google: un calendario «Festività» di sola lettura (permessi solo read, elencato per primo; le scritture
    /// rispondono 403) e i permessi di scrittura indicati per gli altri.
    /// </summary>
    public bool Holidays { get; set; }

    /// <summary>Eseguito una volta prima della prossima PUT o DELETE (un altro programma cambia il server proprio allora).</summary>
    public Action? BeforeNextWrite { get; set; }

    /// <summary>Richieste ricevute ("METODO percorso"), anche quelle respinte con 401.</summary>
    public ConcurrentQueue<string> Requests { get; } = new();

    /// <summary>Raccolta principale: la rubrica, o il calendario «Calendario».</summary>
    public string MainPath => _caldav ? CalendarPath : BookPath;

    public string Ctag
    {
        get { lock (_lock) return "c" + _version; }
    }

    /// <summary>Elementi della raccolta principale (nome del file -> testo).</summary>
    public Dictionary<string, string> Cards => In(MainPath);

    /// <summary>Elementi di una raccolta (nome del file -> testo).</summary>
    public Dictionary<string, string> In(string collection)
    {
        lock (_lock)
            return _cards.Where(p => p.Key.StartsWith(collection, StringComparison.Ordinal))
                .ToDictionary(p => p.Key[collection.Length..], p => p.Value.Data);
    }

    /// <summary>Un altro programma scrive un elemento sul server (nella raccolta principale, o in quella indicata).</summary>
    public void Put(string name, string data, string? collection = null)
    {
        lock (_lock)
            Write((collection ?? MainPath) + name, data);
    }

    /// <summary>Un altro programma elimina un elemento dal server.</summary>
    public void Remove(string name, string? collection = null)
    {
        lock (_lock)
            Delete((collection ?? MainPath) + name);
    }

    public static string Card(string uid, string given, string family, string email, string? rev = null, string? note = null) =>
        "BEGIN:VCARD\r\nVERSION:3.0\r\n" + $"UID:{uid}\r\nFN:{given} {family}\r\nN:{family};{given};;;\r\nEMAIL;TYPE=INTERNET:{email}\r\n"
        + (note is null ? "" : $"NOTE:{note}\r\n") + (rev is null ? "" : $"REV:{rev}\r\n") + "END:VCARD\r\n";

    /// <summary>Un appuntamento iCalendar di un'ora (ora di Roma; inizio aaaammggThhmmss), con LAST-MODIFIED se indicato.</summary>
    public static string Event(string uid, string summary, string start = "20261110T090000", string? lastModified = null,
        string? rrule = null)
    {
        var end = $"{start[..9]}{int.Parse(start[9..11]) + 1:00}{start[11..]}";
        return "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//prova//IT\r\nBEGIN:VEVENT\r\n" + $"UID:{uid}\r\nDTSTAMP:20261101T000000Z\r\n"
            + $"DTSTART;TZID=Europe/Rome:{start}\r\nDTEND;TZID=Europe/Rome:{end}\r\n"
            + $"SUMMARY:{summary}\r\n" + (rrule is null ? "" : $"RRULE:{rrule}\r\n")
            + (lastModified is null ? "" : $"LAST-MODIFIED:{lastModified}\r\n") + "END:VEVENT\r\nEND:VCALENDAR\r\n";
    }

    private IEnumerable<string> Collections =>
        _caldav ? (Holidays ? new[] { HolidaysPath } : []).Concat([TasksPath, CalendarPath]).Concat(SecondCalendar ? [SecondCalendarPath] : []) : [BookPath];

    private void Write(string href, string data)
    {
        _version++;
        _cards[href] = ($"\"e{_version}\"", data);
        _log.Add((_version, href));
    }

    private void Delete(string href)
    {
        if (_cards.Remove(href))
        {
            _version++;
            _log.Add((_version, href));
        }
    }

    private async Task LoopAsync()
    {
        while (true)
        {
            HttpListenerContext ctx;
            try { ctx = await _listener.GetContextAsync(); }
            catch { return; }
            try
            {
                await HandleAsync(ctx);
            }
            catch
            {
                ctx.Response.StatusCode = 500;
            }
            ctx.Response.Close();
        }
    }

    private async Task HandleAsync(HttpListenerContext ctx)
    {
        var req = ctx.Request;
        var res = ctx.Response;
        var path = Uri.UnescapeDataString(req.Url!.AbsolutePath);
        Requests.Enqueue($"{req.HttpMethod} {path}");
        var expected = "Basic " + Convert.ToBase64String(Encoding.UTF8.GetBytes($"{User}:{Password}"));
        var auth = req.Headers["Authorization"] ?? "";
        Authorizations.Enqueue(auth);
        var bearerOk = AcceptBearer is { } accept && auth.StartsWith("Bearer ", StringComparison.Ordinal) && accept(auth[7..]);
        if (auth != expected && !bearerOk)
        {
            res.StatusCode = 401;
            res.AddHeader("WWW-Authenticate", "Basic realm=\"prova\"");
            return;
        }
        if (ForbiddenBody is { } forbidden)
        {
            res.StatusCode = 403;
            res.ContentType = "application/json";
            var bytes = Encoding.UTF8.GetBytes(forbidden);
            await res.OutputStream.WriteAsync(bytes);
            return;
        }
        string body;
        using (var reader = new StreamReader(req.InputStream, Encoding.UTF8))
            body = await reader.ReadToEndAsync();
        var depth = req.Headers["Depth"] ?? "0";

        if (path == (_caldav ? "/.well-known/caldav" : "/.well-known/carddav"))
        {
            res.StatusCode = 301;
            res.RedirectLocation = "/dav/";
            return;
        }
        if (req.HttpMethod is "PUT" or "DELETE" or "POST" && path.StartsWith(HolidaysPath, StringComparison.Ordinal))
        {
            res.StatusCode = 403;
            return;
        }
        if (req.HttpMethod is "PUT" or "DELETE" or "POST" && BeforeNextWrite is { } hook)
        {
            BeforeNextWrite = null;
            hook();
        }
        lock (_lock)
        {
            var collection = Collections.FirstOrDefault(c => path.StartsWith(c, StringComparison.Ordinal) && path.Length > c.Length);
            switch (req.HttpMethod)
            {
                case "PROPFIND":
                    Multistatus(res, Propfind(path, depth));
                    return;
                case "REPORT":
                    Report(res, path, XDocument.Parse(body));
                    return;
                case "GET" when _cards.TryGetValue(path, out var card):
                    res.AddHeader("ETag", card.Etag);
                    res.ContentType = _caldav ? "text/calendar; charset=utf-8" : "text/vcard; charset=utf-8";
                    Bytes(res, card.Data);
                    return;
                case "POST" when CreateWithPost && Collections.Contains(path):
                {
                    var href = $"{path}g{++_posted}";
                    Write(href, body);
                    res.StatusCode = 201;
                    res.AddHeader("Location", Url.TrimEnd('/') + href);
                    if (!PostWithoutEtag)
                        res.AddHeader("ETag", _cards[href].Etag);
                    return;
                }
                case "PUT" when collection is not null && CreateWithPost && !_cards.ContainsKey(path):
                    res.StatusCode = 403;
                    return;
                case "PUT" when collection is not null && PutCreatesWithOwnId && !_cards.ContainsKey(path) && req.Headers["If-Match"] is null:
                {
                    var href = $"{collection}id{++_posted}";
                    Write(href, body);
                    res.StatusCode = 201;
                    res.AddHeader("Location", Url.TrimEnd('/') + href);
                    res.AddHeader("ETag", _cards[href].Etag);
                    return;
                }
                case "PUT" when collection is not null:
                {
                    var exists = _cards.TryGetValue(path, out var old);
                    if ((req.Headers["If-None-Match"] == "*" && exists) || (req.Headers["If-Match"] is { } m && (!exists || m != old.Etag)))
                    {
                        res.StatusCode = 412;
                        return;
                    }
                    Write(path, body);
                    res.StatusCode = exists ? 204 : 201;
                    res.AddHeader("ETag", _cards[path].Etag);
                    return;
                }
                case "DELETE" when collection is not null:
                {
                    if (!_cards.TryGetValue(path, out var old))
                    {
                        res.StatusCode = 404;
                        return;
                    }
                    if (req.Headers["If-Match"] is { } m && m != old.Etag)
                    {
                        res.StatusCode = 412;
                        return;
                    }
                    Delete(path);
                    res.StatusCode = 204;
                    return;
                }
                default:
                    res.StatusCode = 404;
                    return;
            }
        }
    }

    private static XElement Collection(params XElement?[] extra) => new(D + "resourcetype", new XElement(D + "collection"), extra);

    /// <summary>Tipo e proprietà di una raccolta del server.</summary>
    private XElement[] CollectionProps(string path)
    {
        if (!_caldav)
            return [Collection(new XElement(C + "addressbook")), new XElement(D + "displayname", "Contatti")];
        var (name, comp) = path switch
        {
            TasksPath => ("Attività", "VTODO"),
            SecondCalendarPath => ("Lavoro", "VEVENT"),
            HolidaysPath => ("Festività", "VEVENT"),
            _ => ("Calendario", "VEVENT"),
        };
        XElement Privileges(params string[] names) => new(D + "current-user-privilege-set",
            names.Select(n => new XElement(D + "privilege", new XElement(D + n))));
        return [Collection(new XElement(Cal + "calendar")), new XElement(D + "displayname", name),
            new XElement(Cal + "supported-calendar-component-set", new XElement(Cal + "comp", new XAttribute("name", comp))),
            .. Holidays ? [path == HolidaysPath ? Privileges("read", "read-free-busy") : Privileges("read", "write", "write-content")] : Array.Empty<XElement>()];
    }

    private List<XElement> Propfind(string path, string depth)
    {
        var items = new List<XElement>();
        var homeSet = _caldav ? Cal + "calendar-home-set" : C + "addressbook-home-set";
        switch (path)
        {
            case "/dav/":
                items.Add(Response("/dav/", Collection(), Principal ? new XElement(D + "current-user-principal", new XElement(D + "href", "/dav/principals/u/")) : null));
                if (depth == "1")
                {
                    items.Add(Response("/dav/altro/", Collection()));
                    items.Add(Response("/dav/u/", Collection()));
                }
                break;
            case "/dav/principals/u/":
                items.Add(Response(path, Collection(), new XElement(homeSet, new XElement(D + "href", "/dav/u/"))));
                break;
            case "/dav/altro/":
                items.Add(Response(path, Collection()));
                break;
            case "/dav/u/":
                items.Add(Response(path, Collection()));
                if (depth == "1")
                {
                    if (!_caldav)
                        items.Add(Response("/dav/u/Calendario/", Collection(new XElement(Cal + "calendar"))));
                    items.AddRange(Collections.Select(c => Response(c, CollectionProps(c))));
                }
                break;
            default:
                if (Collections.Contains(path))
                {
                    var reports = new XElement(D + "supported-report-set");
                    if (SupportsSync)
                        reports.Add(new XElement(D + "supported-report", new XElement(D + "report", new XElement(D + "sync-collection"))));
                    if (SupportsMultiget)
                        reports.Add(new XElement(D + "supported-report", new XElement(D + "report",
                            new XElement(_caldav ? Cal + "calendar-multiget" : C + "addressbook-multiget"))));
                    items.Add(Response(path, [.. CollectionProps(path), new XElement(CS + "getctag", Ctag),
                        SupportsSync ? new XElement(D + "sync-token", "t" + _version) : null, reports]));
                    if (depth == "1")
                        items.AddRange(_cards.Where(c => c.Key.StartsWith(path, StringComparison.Ordinal))
                            .Select(c => Response(c.Key, new XElement(D + "resourcetype"), new XElement(D + "getetag", c.Value.Etag))));
                }
                else if (_cards.TryGetValue(path, out var card))
                    items.Add(Response(path, new XElement(D + "getetag", card.Etag)));
                break;
        }
        return items;
    }

    private void Report(HttpListenerResponse res, string path, XDocument doc)
    {
        if (!Collections.Contains(path))
        {
            res.StatusCode = 404;
            return;
        }
        var root = doc.Root!;
        var multiget = _caldav ? Cal + "calendar-multiget" : C + "addressbook-multiget";
        var data = _caldav ? Cal + "calendar-data" : C + "address-data";
        if (root.Name == multiget && SupportsMultiget)
        {
            var items = root.Elements(D + "href").Select(h => Uri.UnescapeDataString(h.Value)).Select(h => _cards.TryGetValue(h, out var card)
                ? Response(h, new XElement(D + "getetag", card.Etag), new XElement(data, card.Data))
                : new XElement(D + "response", new XElement(D + "href", h), new XElement(D + "status", "HTTP/1.1 404 Not Found"))).ToList();
            Multistatus(res, items);
            return;
        }
        if (root.Name == D + "sync-collection" && SupportsSync)
        {
            var token = root.Element(D + "sync-token")?.Value ?? "";
            var items = new List<XElement>();
            if (token == "")
                items.AddRange(_cards.Where(c => c.Key.StartsWith(path, StringComparison.Ordinal))
                    .Select(c => Response(c.Key, new XElement(D + "getetag", c.Value.Etag))));
            else if (token.StartsWith('t') && int.TryParse(token[1..], out var from) && from <= _version)
            {
                foreach (var href in _log.Where(l => l.N > from && l.Href.StartsWith(path, StringComparison.Ordinal)).Select(l => l.Href).Distinct())
                    items.Add(_cards.TryGetValue(href, out var card)
                        ? Response(href, new XElement(D + "getetag", card.Etag))
                        : new XElement(D + "response", new XElement(D + "href", href), new XElement(D + "status", "HTTP/1.1 404 Not Found")));
            }
            else
            {
                res.StatusCode = 403; // valid-sync-token
                return;
            }
            Multistatus(res, items, new XElement(D + "sync-token", "t" + _version));
            return;
        }
        res.StatusCode = 403;
    }

    private static XElement Response(string href, params XElement?[] props) =>
        new(D + "response", new XElement(D + "href", href),
            new XElement(D + "propstat", new XElement(D + "prop", props.Where(p => p is not null)), new XElement(D + "status", "HTTP/1.1 200 OK")));

    private static void Multistatus(HttpListenerResponse res, List<XElement> items, XElement? extra = null)
    {
        res.StatusCode = 207;
        res.ContentType = "application/xml; charset=utf-8";
        var doc = new XDocument(new XElement(D + "multistatus", new XAttribute(XNamespace.Xmlns + "d", D), items, extra));
        Bytes(res, doc.ToString());
    }

    private static void Bytes(HttpListenerResponse res, string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        res.ContentLength64 = bytes.Length;
        res.OutputStream.Write(bytes);
    }

    private static int FreePort()
    {
        var l = new TcpListener(IPAddress.Loopback, 0);
        l.Start();
        var port = ((IPEndPoint)l.LocalEndpoint).Port;
        l.Stop();
        return port;
    }

    public void Dispose()
    {
        try { _listener.Stop(); } catch { }
        _listener.Close();
    }
}
