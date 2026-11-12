using System.Net;
using System.Net.Http.Headers;
using System.Security.Authentication;
using System.Text;
using System.Xml.Linq;
using PostinoVip.Core.Security;

namespace PostinoVip.Core.Dav;

/// <summary>Errore del server DAV diverso dalla rete (credenziali, risposta inattesa): non si ritenta subito.</summary>
public sealed class DavException(string message, int? status = null, Exception? inner = null) : Exception(message, inner)
{
    public int? Status { get; } = status;
}

/// <summary>412: l'elemento sul server è cambiato (o esiste già) rispetto all'ETag indicato.</summary>
public sealed class DavPreconditionFailedException() : Exception("Elemento cambiato sul server.");

/// <summary>Raccolta sul server (rubrica o calendario): indirizzo, nome, ctag e sync-token attuali, report disponibili.</summary>
public sealed record DavCollection(Uri Url, string? Name, string? Ctag, string? SyncToken, bool SupportsSync, bool SupportsMultiget);

/// <summary>Una raccolta trovata dalla scoperta: indirizzo e nome mostrato.</summary>
/// <summary><see cref="ReadOnly"/> (G2): il server dice che l'utente non può scriverci (current-user-privilege-set, RFC 3744).</summary>
public sealed record DavCollectionInfo(Uri Url, string? Name, bool ReadOnly = false);

/// <summary>Differenze del server: href -> ETag degli elementi nuovi o cambiati, href eliminati, nuovo sync-token.</summary>
public sealed record DavChanges(Dictionary<string, string?> Changed, HashSet<string> Deleted, string? SyncToken);

/// <summary>Un elemento letto dal server (vCard o iCalendar così come arriva).</summary>
public sealed record DavResource(string Href, string? Etag, string Data);

/// <summary>
/// Cosa distingue CardDAV (RFC 6352) da CalDAV (RFC 4791) per il client: indirizzo .well-known, tipo della raccolta,
/// proprietà della cartella delle raccolte, report multiget, elemento con i dati, tipo MIME. Per CalDAV
/// <see cref="Component"/> filtra le raccolte che accettano quel tipo (es. VEVENT: niente Attività o Diario).
/// </summary>
public sealed record DavKind(string WellKnown, XName CollectionType, XName HomeSet, XName Multiget, XName DataElement,
    XNamespace Namespace, string ContentType, string Extension, string? Component, string ServerLabel, string CollectionLabel)
{
    private static readonly XNamespace Card = "urn:ietf:params:xml:ns:carddav";
    private static readonly XNamespace Cal = "urn:ietf:params:xml:ns:caldav";

    public static readonly DavKind CardDav = new("carddav", Card + "addressbook", Card + "addressbook-home-set",
        Card + "addressbook-multiget", Card + "address-data", Card, "text/vcard; charset=utf-8", ".vcf", null,
        "server dei contatti", "rubrica");

    public static readonly DavKind CalDav = new("caldav", Cal + "calendar", Cal + "calendar-home-set",
        Cal + "calendar-multiget", Cal + "calendar-data", Cal, "text/calendar; charset=utf-8", ".ics", "VEVENT",
        "server del calendario", "calendario");
}

/// <summary>
/// Client WebDAV per rubriche (CardDAV) e calendari (CalDAV) su HTTPS: scoperta delle raccolte (RFC 6764:
/// <c>.well-known</c>, <c>current-user-principal</c>, cartella delle raccolte, con la ricerca nelle cartelle come riserva
/// per i server che non indicano il principal, come IceWarp), elenco degli ETag, differenze con <c>sync-collection</c>
/// (RFC 6578), lettura con multiget (o GET), scrittura ed eliminazione condizionate (If-Match / If-None-Match).
/// Credenziali con Basic o Digest (le gestisce .NET), solo su HTTPS (HTTP solo verso questo computer, per i test).
/// Errori di rete e tempo scaduto -> <see cref="MailOfflineException"/>; gli href sono percorsi assoluti codificati.
/// </summary>
public sealed class DavClient : IDisposable
{
    public static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(20);
    public const int MaxResourceBytes = 1024 * 1024;
    private const int MaxRedirects = 5;

    private static readonly XNamespace D = "DAV:";
    private static readonly XNamespace CS = "http://calendarserver.org/ns/";
    private static readonly XNamespace Cal = "urn:ietf:params:xml:ns:caldav";

    private readonly HttpClient _http;
    private readonly string _user;
    private readonly DavKind _kind;

    /// <param name="kind">CardDAV (predefinito) o CalDAV.</param>
    /// <param name="handler">Solo per i test; altrimenti uno con le credenziali e il controllo del certificato.</param>
    public DavClient(NetworkCredential credential, TrustedCertificate? trust = null, HttpMessageHandler? handler = null,
        DavKind? kind = null)
    {
        _user = credential.UserName;
        _kind = kind ?? DavKind.CardDav;
        handler ??= Sockets(credential, trust);
        _http = new HttpClient(handler) { Timeout = RequestTimeout };
        _http.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("PostinoVip", "1"));
    }

    /// <summary>
    /// Con OAuth2 (C4d, Google): token di accesso nell'intestazione Authorization: Bearer, mandato solo a
    /// <paramref name="host"/> (un reindirizzamento verso un altro server non lo riceve). 401 -> token dimenticato
    /// (<paramref name="invalidate"/>) e «serve un nuovo accesso»; 403 di Google spiegato (API non attiva o permesso mancante).
    /// </summary>
    public DavClient(string user, Func<CancellationToken, Task<string>> accessToken, string host, string providerName,
        Action? invalidate = null, HttpMessageHandler? handler = null, DavKind? kind = null)
    {
        _user = user;
        _kind = kind ?? DavKind.CardDav;
        _http = new HttpClient(new BearerHandler(accessToken, host, providerName, _kind, invalidate)
        {
            InnerHandler = handler ?? Sockets(null, null),
        }) { Timeout = RequestTimeout };
        _http.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("PostinoVip", "1"));
    }

    private static SocketsHttpHandler Sockets(NetworkCredential? credential, TrustedCertificate? trust) => new()
    {
        Credentials = credential,
        PreAuthenticate = credential is not null,
        AllowAutoRedirect = false, // i reindirizzamenti li segue la scoperta, controllando lo schema
        ConnectTimeout = TimeSpan.FromSeconds(10),
        PooledConnectionLifetime = TimeSpan.FromMinutes(5),
        SslOptions = { RemoteCertificateValidationCallback = trust is null ? null : trust.Validate },
    };

    private sealed class BearerHandler(Func<CancellationToken, Task<string>> accessToken, string host, string provider, DavKind kind,
        Action? invalidate) : DelegatingHandler
    {
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var mine = request.RequestUri!.Host.Equals(host, StringComparison.OrdinalIgnoreCase);
            var (api, access, permission) = kind == DavKind.CalDav
                ? ("CalDAV", "al calendario", "del calendario")
                : ("CardDAV", "ai contatti", "dei contatti");
            if (mine)
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await accessToken(ct));
            var response = await base.SendAsync(request, ct);
            if (!mine)
                return response;
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                response.Dispose();
                invalidate?.Invoke();
                throw new DavException($"{provider} ha rifiutato l'accesso al {kind.ServerLabel}: rifai «Accedi con {provider}» " +
                    $"permettendo l'accesso {access}.", 401);
            }
            if (response.StatusCode == HttpStatusCode.Forbidden)
            {
                // Corpo JSON di Google con il motivo (mai token); solo le parole chiave, non il testo.
                var body = await response.Content.ReadAsStringAsync(ct);
                response.Dispose();
                if (body.Contains("SERVICE_DISABLED", StringComparison.Ordinal) || body.Contains("has not been used", StringComparison.Ordinal)
                    || body.Contains("is disabled", StringComparison.Ordinal))
                {
                    // Google indica la pagina della console per attivarla (con il numero del progetto: non è un segreto).
                    var link = System.Text.RegularExpressions.Regex.Match(body, "https://console\\.(?:developers|cloud)\\.google\\.com/apis/api/[A-Za-z0-9._/-]+/overview\\?project=[0-9A-Za-z-]+");
                    throw new DavException($"L'API {api} non è attiva nel progetto {provider} Cloud dell'app: va attivata nella console" +
                        (link.Success ? $" ({link.Value}); se è appena stata attivata, aspettare qualche minuto." : "."), 403);
                }
                if (body.Contains("SCOPE_INSUFFICIENT", StringComparison.Ordinal) || body.Contains("insufficient", StringComparison.OrdinalIgnoreCase))
                    throw new DavException($"L'accesso con {provider} non comprende il permesso {permission}: rifai «Accedi con {provider}».", 403);
                throw new DavException($"Il {kind.ServerLabel} ha rifiutato la richiesta (403).", 403);
            }
            return response;
        }
    }

    public DavKind Kind => _kind;

    public void Dispose() => _http.Dispose();

    /// <summary>
    /// Indirizzo da cui parte la scoperta: senza indirizzo scritto <c>https://host/.well-known/carddav</c> (o caldav);
    /// con un indirizzo senza percorso lo stesso su quel server; altrimenti l'indirizzo così com'è (anche la raccolta stessa).
    /// </summary>
    public static Uri StartUrl(string? configured, string host, DavKind? kind = null)
    {
        var wellKnown = "/.well-known/" + (kind ?? DavKind.CardDav).WellKnown;
        if (string.IsNullOrWhiteSpace(configured))
            return new Uri($"https://{host}{wellKnown}");
        var url = new Uri(configured.Trim(), UriKind.Absolute);
        return url.AbsolutePath is "" or "/" ? new Uri(url, wellKnown) : url;
    }

    /// <summary>Solo HTTPS; HTTP solo verso questo computer (server finto dei test).</summary>
    public static void EnsureAllowed(Uri url, DavKind? kind = null)
    {
        if (url.Scheme == Uri.UriSchemeHttps || (url.Scheme == Uri.UriSchemeHttp && url.IsLoopback))
            return;
        throw new DavException($"Indirizzo del {(kind ?? DavKind.CardDav).ServerLabel} non ammesso: serve https ({url.Scheme}://{url.Host}).");
    }

    // ---------------------------------------------------------------- scoperta

    /// <summary>La prima raccolta dell'utente: quella indicata, quella del principal, o la prima trovata nelle cartelle.</summary>
    public async Task<Uri> DiscoverAsync(Uri start, CancellationToken ct) => (await DiscoverAllAsync(start, ct))[0].Url;

    /// <summary>
    /// Le raccolte dell'utente del tipo giusto (per CalDAV solo quelle che accettano <see cref="DavKind.Component"/>):
    /// quella indicata, quelle della cartella del principal, o quelle della prima cartella che ne contiene (prima le
    /// cartelle col nome dell'utente). Nessuna -> <see cref="DavException"/>.
    /// </summary>
    public async Task<List<DavCollectionInfo>> DiscoverAllAsync(Uri start, CancellationToken ct)
    {
        var (url, root) = await PropfindAsync(start, 0,
            Props(D + "resourcetype", D + "displayname", D + "current-user-principal", _kind.HomeSet, Cal + "supported-calendar-component-set",
                D + "current-user-privilege-set"),
            ct, follow: true);
        var self = root.FirstOrDefault();
        if (self is not null && IsOfKind(self))
            return [new DavCollectionInfo(url, Text(self.Props, D + "displayname"), IsReadOnly(self))];

        if (self?.Href(D + "current-user-principal") is { } principalHref)
        {
            var principal = new Uri(url, principalHref);
            var (_, p) = await PropfindAsync(principal, 0, Props(_kind.HomeSet), ct);
            var homeHref = p.FirstOrDefault()?.Href(_kind.HomeSet) ?? self.Href(_kind.HomeSet);
            if (homeHref is not null && await CollectionsInAsync(new Uri(principal, homeHref), ct) is { Count: > 0 } found)
                return found;
        }
        else if (self?.Href(_kind.HomeSet) is { } home && await CollectionsInAsync(new Uri(url, home), ct) is { Count: > 0 } found)
            return found;

        // Riserva (server che non indicano il principal): cartelle sotto l'indirizzo, due livelli.
        var (_, children) = await PropfindAsync(url, 1, ListProps(), ct);
        var direct = children.Where(c => !SamePath(c.Url(url), url) && IsOfKind(c))
            .Select(c => new DavCollectionInfo(c.Url(url), Text(c.Props, D + "displayname"), IsReadOnly(c))).ToList();
        if (direct.Count > 0)
            return direct;
        var folders = children.Where(c => !SamePath(c.Url(url), url) && c.IsCollection).Select(c => c.Url(url)).ToList();
        // Prima le cartelle col nome dell'utente (IceWarp: /webdav/<utente>/), così una raccolta pubblica non passa davanti.
        var localPart = _user.Split('@')[0];
        folders = folders.OrderByDescending(f => Uri.UnescapeDataString(f.AbsolutePath).Contains(_user, StringComparison.OrdinalIgnoreCase))
            .ThenByDescending(f => localPart.Length > 0 && Uri.UnescapeDataString(f.AbsolutePath).Contains(localPart, StringComparison.OrdinalIgnoreCase))
            .ToList();
        foreach (var folder in folders.Take(30))
        {
            try
            {
                if (await CollectionsInAsync(folder, ct) is { Count: > 0 } found)
                    return found;
            }
            catch (DavException ex) when (ex.Status is 403 or 404 or 405)
            {
                // cartella non leggibile: si passa alla successiva
            }
        }
        throw new DavException($"Nessun{(_kind == DavKind.CalDav ? "" : "a")} {_kind.CollectionLabel} trovat{(_kind == DavKind.CalDav ? "o" : "a")} sul {_kind.ServerLabel}.");
    }

    private async Task<List<DavCollectionInfo>> CollectionsInAsync(Uri folder, CancellationToken ct)
    {
        var (_, items) = await PropfindAsync(folder, 1, ListProps(), ct);
        return items.Where(i => !SamePath(i.Url(folder), folder) && IsOfKind(i))
            .Select(i => new DavCollectionInfo(i.Url(folder), Text(i.Props, D + "displayname"), IsReadOnly(i))).ToList();
    }

    private XElement[] ListProps() =>
        Props(D + "resourcetype", D + "displayname", Cal + "supported-calendar-component-set", D + "current-user-privilege-set");

    /// <summary>
    /// Sola lettura solo se il server indica i permessi e tra questi non c'è nessuna scrittura (write, write-content, bind,
    /// all): senza l'indicazione si considera scrivibile, come prima.
    /// </summary>
    private static bool IsReadOnly(DavItem item)
    {
        var set = item.Props?.Element(D + "current-user-privilege-set");
        if (set is null)
            return false;
        var granted = set.Elements(D + "privilege").SelectMany(p => p.Elements()).Select(e => e.Name.LocalName).ToHashSet();
        return granted.Count > 0 && !granted.Overlaps(["write", "write-content", "bind", "all"]);
    }

    /// <summary>Raccolta del tipo giusto; per CalDAV deve accettare il componente (se il server lo dichiara).</summary>
    private bool IsOfKind(DavItem item)
    {
        if (item.Props?.Element(D + "resourcetype")?.Element(_kind.CollectionType) is null)
            return false;
        if (_kind.Component is null)
            return true;
        var set = item.Props.Element(Cal + "supported-calendar-component-set");
        return set is null || set.Elements(Cal + "comp").Any(c => string.Equals((string?)c.Attribute("name"), _kind.Component, StringComparison.OrdinalIgnoreCase));
    }

    // ---------------------------------------------------------------- lettura

    /// <summary>Nome, ctag, sync-token e report disponibili della raccolta.</summary>
    public async Task<DavCollection> GetCollectionAsync(Uri collection, CancellationToken ct)
    {
        var (_, items) = await PropfindAsync(collection, 0,
            Props(D + "displayname", CS + "getctag", D + "sync-token", D + "supported-report-set"), ct);
        var p = items.FirstOrDefault()?.Props;
        var reports = p?.Element(D + "supported-report-set")?.Descendants(D + "report").SelectMany(r => r.Elements())
            .Select(e => e.Name).ToHashSet() ?? [];
        return new DavCollection(collection, Text(p, D + "displayname"), Text(p, CS + "getctag"), Text(p, D + "sync-token"),
            reports.Contains(D + "sync-collection"), reports.Contains(_kind.Multiget));
    }

    /// <summary>Tutti gli elementi della raccolta con il loro ETag (href -> ETag).</summary>
    public async Task<Dictionary<string, string?>> ListEtagsAsync(Uri collection, CancellationToken ct)
    {
        var (_, items) = await PropfindAsync(collection, 1, Props(D + "getetag", D + "resourcetype"), ct);
        var result = new Dictionary<string, string?>();
        foreach (var i in items)
        {
            var url = i.Url(collection);
            if (SamePath(url, collection) || i.IsCollection || i.Props is null)
                continue;
            result[url.AbsolutePath] = Text(i.Props, D + "getetag");
        }
        return result;
    }

    /// <summary>
    /// Differenze dal <paramref name="syncToken"/> (vuoto = tutto) con sync-collection; null se il server rifiuta il
    /// token (scaduto) o il report: si ripiega sull'elenco completo.
    /// </summary>
    public async Task<DavChanges?> SyncCollectionAsync(Uri collection, string? syncToken, CancellationToken ct)
    {
        var changed = new Dictionary<string, string?>();
        var deleted = new HashSet<string>();
        var token = syncToken ?? "";
        for (var page = 0; page < 50; page++)
        {
            var body = new XDocument(new XElement(D + "sync-collection", new XAttribute(XNamespace.Xmlns + "d", D),
                new XElement(D + "sync-token", token), new XElement(D + "sync-level", "1"),
                new XElement(D + "prop", new XElement(D + "getetag"))));
            using var response = await SendAsync(new HttpMethod("REPORT"), collection, body, 0, ct);
            if (response.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.Conflict or HttpStatusCode.BadRequest
                or HttpStatusCode.NotImplemented or HttpStatusCode.MethodNotAllowed or HttpStatusCode.NotFound)
                return null;
            EnsureSuccess(response);
            var doc = await ReadXmlAsync(response, ct);
            var truncated = false;
            foreach (var i in ParseMultistatus(doc))
            {
                var url = i.Url(collection);
                if (SamePath(url, collection))
                {
                    truncated |= i.Status == 507;
                    continue;
                }
                var path = url.AbsolutePath;
                if (i.Status == 404)
                {
                    deleted.Add(path);
                    changed.Remove(path);
                }
                else if (i.Props is not null && !i.IsCollection)
                {
                    changed[path] = Text(i.Props, D + "getetag");
                    deleted.Remove(path);
                }
            }
            token = doc.Root?.Element(D + "sync-token")?.Value.Trim() ?? token;
            if (!truncated)
                return new DavChanges(changed, deleted, token);
        }
        return new DavChanges(changed, deleted, token);
    }

    /// <summary>
    /// Gli elementi indicati (a blocchi, con multiget se disponibile, altrimenti uno alla volta con GET).
    /// Quelli che non ci sono più mancano dal risultato; quelli troppo grandi o senza dati ci sono con Data vuoto
    /// (esistono: non vanno trattati come eliminati).
    /// </summary>
    public async Task<List<DavResource>> GetResourcesAsync(Uri collection, IReadOnlyCollection<string> hrefs, bool multiget, CancellationToken ct)
    {
        var result = new List<DavResource>();
        var list = hrefs.ToList();
        for (var i = 0; i < list.Count; i += 50)
        {
            var chunk = list.Skip(i).Take(50).ToList();
            List<DavResource>? got = null;
            if (multiget)
                got = await MultigetAsync(collection, chunk, ct);
            if (got is null)
            {
                multiget = false;
                got = [];
                foreach (var href in chunk)
                {
                    if (await GetResourceAsync(new Uri(collection, href), ct) is { } r)
                        got.Add(r);
                }
            }
            result.AddRange(got);
        }
        return result;
    }

    private async Task<List<DavResource>?> MultigetAsync(Uri collection, List<string> hrefs, CancellationToken ct)
    {
        var body = new XDocument(new XElement(_kind.Multiget,
            new XAttribute(XNamespace.Xmlns + "d", D), new XAttribute(XNamespace.Xmlns + "c", _kind.Namespace),
            new XElement(D + "prop", new XElement(D + "getetag"), new XElement(_kind.DataElement)),
            hrefs.Select(h => new XElement(D + "href", h))));
        using var response = await SendAsync(new HttpMethod("REPORT"), collection, body, 1, ct);
        if (response.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.BadRequest or HttpStatusCode.NotImplemented
            or HttpStatusCode.MethodNotAllowed or HttpStatusCode.UnsupportedMediaType)
            return null;
        EnsureSuccess(response);
        var doc = await ReadXmlAsync(response, ct);
        var resources = new List<DavResource>();
        foreach (var i in ParseMultistatus(doc))
        {
            if (i.Status is 404 or 410 || i.Props is null)
                continue;
            var data = i.Props.Element(_kind.DataElement)?.Value ?? "";
            if (Encoding.UTF8.GetByteCount(data) > MaxResourceBytes)
                data = "";
            resources.Add(new DavResource(i.Url(collection).AbsolutePath, Text(i.Props, D + "getetag"), data));
        }
        return resources;
    }

    private async Task<DavResource?> GetResourceAsync(Uri url, CancellationToken ct)
    {
        using var response = await SendAsync(HttpMethod.Get, url, null, null, ct);
        if (response.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.Gone)
            return null;
        EnsureSuccess(response);
        var bytes = await response.Content.ReadAsByteArrayAsync(ct);
        return new DavResource(url.AbsolutePath, response.Headers.ETag?.Tag, bytes.Length > MaxResourceBytes ? "" : Contacts.TextDecoding.Decode(bytes));
    }

    /// <summary>ETag attuale di un elemento (dopo una scrittura che non l'ha restituito); null se non c'è.</summary>
    public async Task<string?> GetEtagAsync(Uri url, CancellationToken ct)
    {
        var (_, items) = await PropfindAsync(url, 0, Props(D + "getetag"), ct);
        return Text(items.FirstOrDefault()?.Props, D + "getetag");
    }

    // ---------------------------------------------------------------- scrittura

    /// <summary>
    /// Scrive un elemento: con <paramref name="ifMatch"/> solo se sul server è ancora quella versione, senza solo se
    /// non esiste (If-None-Match: *). 412 -> <see cref="DavPreconditionFailedException"/>. Restituisce l'ETag
    /// nuovo se il server lo indica (forte), altrimenti null.
    /// </summary>
    public async Task<string?> PutAsync(Uri url, string data, string? ifMatch, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Put, url)
        {
            Content = new ByteArrayContent(Encoding.UTF8.GetBytes(data)),
        };
        request.Content.Headers.ContentType = MediaTypeHeaderValue.Parse(_kind.ContentType);
        if (ifMatch is null)
            request.Headers.TryAddWithoutValidation("If-None-Match", "*");
        else
            request.Headers.TryAddWithoutValidation("If-Match", ifMatch);
        using var response = await SendRequestAsync(request, ct);
        if (response.StatusCode == HttpStatusCode.PreconditionFailed)
            throw new DavPreconditionFailedException();
        EnsureSuccess(response);
        return response.Headers.ETag is { IsWeak: false } e ? e.Tag : null;
    }

    /// <summary>
    /// Elemento nuovo (C4d-b, scelta 1a): PUT su <paramref name="target"/> con If-None-Match: *; se il server non lo
    /// permette (come Google, che crea con POST, RFC 5995) POST sulla raccolta, che sceglie l'indirizzo (Location). Dopo
    /// un PUT rifiutato si usa subito il POST. Restituisce l'indirizzo, l'ETag (null se il server non lo dà) e come è
    /// andata (per il log: metodo, codice, Location; solo l'ultimo pezzo degli indirizzi).
    /// </summary>
    public async Task<(Uri Url, string? Etag, string How)> CreateAsync(Uri collection, Uri target, string data, CancellationToken ct)
    {
        if (!_createWithPost)
        {
            try
            {
                var (etag, status, putLocation) = await PutNewAsync(target, data, ct);
                // Google (verificato il 06/11/2026): 201 con Location = il suo id, ed è quello l'indirizzo dell'elemento.
                var where = putLocation is not null && Inside(collection, putLocation) ? putLocation : target;
                return (where, etag, $"PUT {status}, ETag {(etag is null ? "no" : "sì")}, Location {(putLocation is null ? "no" : Last(putLocation))}");
            }
            catch (DavException ex) when (ex.Status is 400 or 403 or 404 or 405 or 409 or 501)
            {
                _createWithPost = true;
            }
        }
        using var request = new HttpRequestMessage(HttpMethod.Post, collection)
        {
            Content = new ByteArrayContent(Encoding.UTF8.GetBytes(data)),
        };
        request.Content.Headers.ContentType = MediaTypeHeaderValue.Parse(_kind.ContentType);
        using var response = await SendRequestAsync(request, ct);
        EnsureSuccess(response);
        if (response.Headers.Location is not { } location)
            throw new DavException($"Il {_kind.ServerLabel} ha creato l'elemento senza dire dove (manca Location).");
        var url = new Uri(collection, location);
        if (!Inside(collection, url))
            throw new DavException($"Il {_kind.ServerLabel} ha creato l'elemento fuori dalla raccolta.");
        var postEtag = response.Headers.ETag is { IsWeak: false } e ? e.Tag : null;
        return (url, postEtag, $"POST {(int)response.StatusCode}, ETag {(postEtag is null ? "no" : "sì")}, Location {Last(url)}");
    }

    private static string Last(Uri url) => url.Segments.LastOrDefault() ?? "";

    /// <summary>Un elemento della raccolta: stesso server, sotto il suo percorso (non la raccolta stessa).</summary>
    private static bool Inside(Uri collection, Uri url) =>
        url.Host.Equals(collection.Host, StringComparison.OrdinalIgnoreCase) && url.Port == collection.Port
        && url.AbsolutePath.StartsWith(collection.AbsolutePath, StringComparison.Ordinal) && url.AbsolutePath.Length > collection.AbsolutePath.Length;

    private async Task<(string? Etag, int Status, Uri? Location)> PutNewAsync(Uri url, string data, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Put, url)
        {
            Content = new ByteArrayContent(Encoding.UTF8.GetBytes(data)),
        };
        request.Content.Headers.ContentType = MediaTypeHeaderValue.Parse(_kind.ContentType);
        request.Headers.TryAddWithoutValidation("If-None-Match", "*");
        using var response = await SendRequestAsync(request, ct);
        if (response.StatusCode == HttpStatusCode.PreconditionFailed)
            throw new DavPreconditionFailedException();
        EnsureSuccess(response);
        return (response.Headers.ETag is { IsWeak: false } e ? e.Tag : null, (int)response.StatusCode,
            response.Headers.Location is { } l ? new Uri(url, l) : null);
    }

    private bool _createWithPost;

    /// <summary>Elimina un elemento se sul server è ancora quella versione; già eliminato = riuscito.</summary>
    public async Task DeleteAsync(Uri url, string? ifMatch, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Delete, url);
        if (ifMatch is not null)
            request.Headers.TryAddWithoutValidation("If-Match", ifMatch);
        using var response = await SendRequestAsync(request, ct);
        if (response.StatusCode == HttpStatusCode.PreconditionFailed)
            throw new DavPreconditionFailedException();
        if (response.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.Gone)
            return;
        EnsureSuccess(response);
    }

    // ---------------------------------------------------------------- HTTP e XML

    private static XElement[] Props(params XName[] names) => names.Select(n => new XElement(n)).ToArray();

    private async Task<(Uri Url, List<DavItem> Items)> PropfindAsync(Uri url, int depth, XElement[] props, CancellationToken ct,
        bool follow = false)
    {
        var body = new XDocument(new XElement(D + "propfind",
            new XAttribute(XNamespace.Xmlns + "d", D), new XAttribute(XNamespace.Xmlns + "c", _kind.Namespace),
            new XAttribute(XNamespace.Xmlns + "cs", CS),
            _kind.Namespace == Cal ? null : new XAttribute(XNamespace.Xmlns + "cal", Cal),
            new XElement(D + "prop", props)));
        for (var i = 0; i <= MaxRedirects; i++)
        {
            using var response = await SendAsync(new HttpMethod("PROPFIND"), url, body, depth, ct);
            if (follow && (int)response.StatusCode is 301 or 302 or 303 or 307 or 308 && response.Headers.Location is { } location)
            {
                url = new Uri(url, location);
                continue;
            }
            EnsureSuccess(response);
            return (url, ParseMultistatus(await ReadXmlAsync(response, ct)));
        }
        throw new DavException($"Troppi reindirizzamenti dal {_kind.ServerLabel}.");
    }

    private Task<HttpResponseMessage> SendAsync(HttpMethod method, Uri url, XDocument? body, int? depth, CancellationToken ct)
    {
        var request = new HttpRequestMessage(method, url);
        if (body is not null)
        {
            request.Content = new ByteArrayContent(Encoding.UTF8.GetBytes(body.Declaration + body.ToString(SaveOptions.DisableFormatting)));
            request.Content.Headers.ContentType = MediaTypeHeaderValue.Parse("application/xml; charset=utf-8");
        }
        if (depth is not null)
            request.Headers.TryAddWithoutValidation("Depth", depth.ToString());
        return SendRequestAsync(request, ct, dispose: true);
    }

    private async Task<HttpResponseMessage> SendRequestAsync(HttpRequestMessage request, CancellationToken ct, bool dispose = false)
    {
        try
        {
            EnsureAllowed(request.RequestUri!, _kind);
            var response = await _http.SendAsync(request, ct);
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                response.Dispose();
                throw new DavException($"Il {_kind.ServerLabel} ha rifiutato nome utente o password.", 401);
            }
            return response;
        }
        catch (HttpRequestException ex) when (ex.InnerException is AuthenticationException)
        {
            throw new DavException($"Certificato del {_kind.ServerLabel} non valido.", inner: ex);
        }
        catch (HttpRequestException ex)
        {
            throw new MailOfflineException($"{Capital(_kind.ServerLabel)} non raggiungibile.", ex);
        }
        catch (TaskCanceledException ex) when (!ct.IsCancellationRequested)
        {
            throw new MailOfflineException($"Il {_kind.ServerLabel} non risponde.", ex);
        }
        finally
        {
            if (dispose)
                request.Dispose();
        }
    }

    private static string Capital(string s) => s.Length == 0 ? s : char.ToUpperInvariant(s[0]) + s[1..];

    private void EnsureSuccess(HttpResponseMessage response)
    {
        if (response.IsSuccessStatusCode)
            return;
        var code = (int)response.StatusCode;
        throw new DavException($"Il {_kind.ServerLabel} ha risposto {code} {response.ReasonPhrase}.", code);
    }

    private async Task<XDocument> ReadXmlAsync(HttpResponseMessage response, CancellationToken ct)
    {
        try
        {
            await using var stream = await response.Content.ReadAsStreamAsync(ct);
            return await XDocument.LoadAsync(stream, LoadOptions.None, ct);
        }
        catch (System.Xml.XmlException ex)
        {
            throw new DavException($"Risposta del {_kind.ServerLabel} non leggibile.", inner: ex);
        }
    }

    private static string? Text(XElement? props, XName name) =>
        props?.Element(name)?.Value.Trim() is { Length: > 0 } v ? v : null;

    private static bool SamePath(Uri a, Uri b) => a.AbsolutePath.TrimEnd('/') == b.AbsolutePath.TrimEnd('/');

    /// <summary>Una voce di una risposta multistatus: href, stato della voce (sync-collection: 404) e proprietà con 2xx.</summary>
    private sealed record DavItem(string HrefValue, int? Status, XElement? Props)
    {
        public Uri Url(Uri baseUrl) => new(baseUrl, HrefValue);

        public bool IsCollection => Props?.Element(D + "resourcetype")?.Element(D + "collection") is not null;

        public string? Href(XName property) => Props?.Element(property)?.Element(D + "href")?.Value.Trim() is { Length: > 0 } h ? h : null;
    }

    private static List<DavItem> ParseMultistatus(XDocument doc)
    {
        var items = new List<DavItem>();
        foreach (var r in doc.Root?.Elements(D + "response") ?? [])
        {
            var href = r.Element(D + "href")?.Value.Trim();
            if (string.IsNullOrEmpty(href))
                continue;
            XElement? props = null;
            foreach (var ps in r.Elements(D + "propstat"))
            {
                if (StatusCode(ps.Element(D + "status")?.Value) is >= 200 and < 300 && ps.Element(D + "prop") is { } p)
                {
                    props ??= new XElement(D + "prop");
                    props.Add(p.Elements());
                }
            }
            items.Add(new DavItem(href, StatusCode(r.Element(D + "status")?.Value), props));
        }
        return items;
    }

    /// <summary>"HTTP/1.1 404 Not Found" -> 404.</summary>
    private static int? StatusCode(string? status)
    {
        var parts = status?.Trim().Split(' ', 3);
        return parts is { Length: >= 2 } && int.TryParse(parts[1], out var code) ? code : null;
    }
}
