namespace PostinoVip.Core.Dav;

/// <summary>Esito di una sincronizzazione (solo numeri: niente nomi, indirizzi od oggetti nel log).</summary>
public sealed record DavResult(int Downloaded, int Uploaded, int DeletedHere, int DeletedThere, int Conflicts,
    int PendingUpload, bool NeedsConfirmation, string? CollectionName)
{
    /// <summary>I dati sul computer sono cambiati: l'app li rilegge.</summary>
    public bool LocalChanged => Downloaded + DeletedHere > 0;

    public bool AnyChange => Downloaded + Uploaded + DeletedHere + DeletedThere > 0;

    /// <summary>Somma di più raccolte (i calendari di un account).</summary>
    public static DavResult Sum(IReadOnlyList<DavResult> parts, string? name) => new(
        parts.Sum(p => p.Downloaded), parts.Sum(p => p.Uploaded), parts.Sum(p => p.DeletedHere), parts.Sum(p => p.DeletedThere),
        parts.Sum(p => p.Conflicts), parts.Sum(p => p.PendingUpload), parts.Any(p => p.NeedsConfirmation), name);

    public string Describe(string label) =>
        $"{label}: {Downloaded} dal server, {Uploaded} sul server, {DeletedHere} eliminati qui, {DeletedThere} eliminati sul server, "
        + $"{Conflicts} conflitti" + (NeedsConfirmation ? $", {PendingUpload} in attesa di conferma" : "");

    public override string ToString() => Describe("CardDAV");
}

/// <summary>Un elemento sul computer come lo vede la sincronizzazione.</summary>
/// <param name="Fingerprint">Impronta del contenuto: diversa da quella salvata = cambiato sul computer.</param>
/// <param name="Updated">Ora dell'ultima modifica (per i conflitti).</param>
/// <param name="DuplicateKey">Chiave dei doppioni della prima volta (stesso contatto o stesso appuntamento).</param>
public sealed record DavLocalItem(string Id, string Fingerprint, DateTimeOffset? Updated, string DuplicateKey);

/// <summary>Un elemento del server già letto: il valore lo interpreta l'archivio, Updated è l'ora dichiarata (REV, LAST-MODIFIED).</summary>
public sealed record DavIncoming(object Value, DateTimeOffset? Updated, string DuplicateKey);

public enum DavApplyOutcome { Saved, Invalid, ChangedMeanwhile, Full }

/// <summary>Esito di <see cref="IDavItemStore.Apply"/>: l'elemento scritto (o quello attuale, se cambiato nel frattempo).</summary>
public sealed record DavApplyResult(DavLocalItem? Item, DavApplyOutcome Outcome);

/// <summary>Testo da caricare sul server, l'elemento così come è stato esportato e il nome del file sul server (dall'UID).</summary>
public sealed record DavExport(string Data, DavLocalItem Item, string FileName);

/// <summary>
/// Gli elementi sul computer di una raccolta (la rubrica di un account, un calendario), visti dalla sincronizzazione:
/// <see cref="Apply"/> e <see cref="Remove"/> scrivono solo se nel frattempo l'app non ha cambiato l'elemento.
/// </summary>
public interface IDavItemStore
{
    /// <summary>Nome degli elementi al plurale, per il log (es. «contatti»).</summary>
    string ItemsLabel { get; }

    int MaxItems { get; }

    IReadOnlyList<DavLocalItem> List();

    DavLocalItem? Find(string id);

    /// <summary>Legge un elemento del server; null = non utilizzabile (resta ignorato finché non cambia).</summary>
    DavIncoming? Parse(string data);

    /// <summary>
    /// Scrive la versione del server: con <paramref name="id"/> sostituisce quell'elemento (o lo ricrea con lo stesso id),
    /// altrimenti ne crea uno nuovo; <paramref name="updated"/> è l'ora della modifica da conservare.
    /// </summary>
    DavApplyResult Apply(string? id, DavIncoming incoming, DateTimeOffset updated, string? expectedFingerprint);

    bool Remove(string id, string expectedFingerprint);

    /// <summary>L'elemento da caricare, con un UID (lo aggiunge se manca); null se l'app lo sta cambiando proprio adesso.</summary>
    DavExport? Export(string id, string expectedFingerprint);
}

/// <summary>Una sincronizzazione completa (una rubrica o tutti i calendari di un account), eseguita dal <see cref="DavWorker"/>.</summary>
public interface IDavSyncJob : IDisposable
{
    /// <param name="confirm">L'utente ha confermato il caricamento degli elementi che sono solo sul computer (2a).</param>
    Task<DavResult> RunAsync(DateTimeOffset now, bool confirm, CancellationToken ct);
}

/// <summary>
/// Sincronizzazione nei due sensi di una raccolta sul computer con una raccolta DAV (C4b per i contatti, K2a per i
/// calendari). Regole decise dall'utente:
/// <list type="bullet">
/// <item>2a: la raccolta diventa quella del server; gli elementi uguali (stessa <see cref="DavLocalItem.DuplicateKey"/>) si
/// collegano invece di duplicarsi; 4a: prima della conferma i dati vanno solo dal server al computer, gli elementi solo
/// sul computer restano lì (<see cref="DavResult.NeedsConfirmation"/>); senza elementi da caricare non serve.</item>
/// <item>3b + 1a: conflitto (cambiato da entrambe le parti) = vince la modifica più recente. Computer: ora della
/// modifica nell'app; server: l'ora dichiarata se c'è e non è oltre <see cref="FutureTolerance"/> nel futuro,
/// altrimenti l'ora in cui il core vede il cambiamento; a parità vince il server.</item>
/// <item>3a: le eliminazioni passano nei due sensi, ma un elemento cambiato dall'altra parte si conserva.</item>
/// </list>
/// Differenze del server con sync-collection se c'è, altrimenti ctag + elenco degli ETag; scritture condizionate con
/// If-Match / If-None-Match (412 = cambiato nel frattempo: si rilegge al giro successivo). Lo stato si salva spesso:
/// un'interruzione al più ripete un passo, e il caricamento di un elemento nuovo va sempre allo stesso indirizzo
/// (dall'UID), quindi non si duplica.
/// </summary>
/// <param name="collection">Raccolta già nota (calendari: dall'elenco dell'account); null = scoperta da <paramref name="start"/>.</param>
/// <param name="readOnly">G2: raccolta di sola lettura sul server: solo dal server al computer, mai scritture.</param>
public class DavSync(DavClient client, IDavItemStore store, DavStateStore stateStore, Uri start, string source,
    Action<string>? log = null, Uri? collection = null, bool readOnly = false) : IDavSyncJob
{
    public static readonly TimeSpan FutureTolerance = TimeSpan.FromMinutes(5);
    private const int SaveEvery = 25;

    private int _downloaded, _uploaded, _deletedHere, _deletedThere, _conflicts;

    private string Label => client.Kind == DavKind.CalDav ? "CalDAV" : "CardDAV";

    public async Task<DavResult> RunAsync(DateTimeOffset now, bool confirm, CancellationToken ct)
    {
        _downloaded = _uploaded = _deletedHere = _deletedThere = _conflicts = 0;
        var state = stateStore.Load();
        if (state.Source != source)
            state = new DavState { Source = source }; // altra raccolta o altro server: da capo (con nuova conferma)
        if (state.Collection is null)
        {
            var found = collection ?? await client.DiscoverAsync(start, ct);
            state.Collection = WithSlash(found).AbsoluteUri;
            stateStore.Save(state);
        }
        var url = new Uri(state.Collection);
        var info = await client.GetCollectionAsync(url, ct);
        state.CollectionName = info.Name;
        if (confirm)
            state.Confirmed = true;

        var entries = state.Entries.GroupBy(e => e.Href).ToDictionary(g => g.Key, g => g.First());

        // 1. Differenze del server.
        var (changed, deleted, token) = await ServerChangesAsync(state, info, entries, ct);
        var toFetch = changed.Keys
            .Union(entries.Values.Where(e => e.ServerPending && !deleted.Contains(e.Href)).Select(e => e.Href))
            .ToList();
        var resources = toFetch.Count == 0 ? [] : await client.GetResourcesAsync(url, toFetch, info.SupportsMultiget, ct);
        var got = resources.Select(c => c.Href).ToHashSet();
        foreach (var href in toFetch.Where(h => !got.Contains(h) && entries.ContainsKey(h)))
            deleted.Add(href); // sparito tra l'elenco e la lettura

        // 2. Applicate sul computer.
        var locals = store.List();
        var mapped = entries.Values.Where(e => e.ItemId is not null).Select(e => e.ItemId!).ToHashSet();
        var unmappedByKey = locals.Where(c => !mapped.Contains(c.Id))
            .GroupBy(c => c.DuplicateKey).ToDictionary(g => g.Key, g => new Queue<DavLocalItem>(g));
        var full = false;
        foreach (var res in resources)
        {
            entries.TryGetValue(res.Href, out var entry);
            var parsed = res.Data.Length == 0 ? null : store.Parse(res.Data);
            if (parsed is null)
            {
                // Dato del server non leggibile: l'elemento sul computer (se c'è) resta com'è.
                if (entry is null)
                    entries[res.Href] = new DavEntry { Href = res.Href, Etag = res.Etag };
                else
                {
                    entry.Etag = res.Etag;
                    entry.ServerPending = false;
                }
                continue;
            }
            var serverTime = parsed.Updated is { } t && t <= now + FutureTolerance ? t : now;

            if (entry?.ItemId is { } id)
            {
                var local = store.Find(id);
                if (local is null)
                {
                    log?.Invoke($"{Label}: elemento {id} eliminato qui ma cambiato sul server: ricreato");
                    Apply(entry, id, parsed, serverTime, res.Etag, expected: null);
                }
                else if (local.Fingerprint == entry.Fingerprint)
                    Apply(entry, id, parsed, serverTime, res.Etag, entry.Fingerprint);
                else
                    Resolve(state, entry, local, parsed, serverTime, res.Etag);
                continue;
            }

            // Nuovo sul server (o prima non leggibile): elemento uguale solo sul computer -> si collegano (2a).
            if (unmappedByKey.TryGetValue(parsed.DuplicateKey, out var same) && same.Count > 0)
            {
                var local = same.Dequeue();
                var link = new DavEntry { Href = res.Href, ItemId = local.Id };
                entries[res.Href] = link;
                Resolve(state, link, local, parsed, serverTime, res.Etag);
                continue;
            }
            var r = store.Apply(null, parsed, serverTime, null);
            switch (r.Outcome)
            {
                case DavApplyOutcome.Saved:
                    entries[res.Href] = new DavEntry { Href = res.Href, Etag = res.Etag, ItemId = r.Item!.Id, Fingerprint = r.Item.Fingerprint };
                    _downloaded++;
                    break;
                case DavApplyOutcome.Invalid:
                    entries[res.Href] = new DavEntry { Href = res.Href, Etag = res.Etag };
                    break;
                default:
                    if (!full)
                        log?.Invoke($"{Label}: {store.ItemsLabel} pieni ({store.MaxItems}), elementi del server non scaricati");
                    full = true;
                    break;
            }
        }

        foreach (var href in deleted)
        {
            if (!entries.Remove(href, out var entry) || entry.ItemId is not { } id || store.Find(id) is not { } local)
                continue;
            if (local.Fingerprint == entry.Fingerprint && store.Remove(id, entry.Fingerprint))
                _deletedHere++;
            else
                log?.Invoke($"{Label}: elemento {id} eliminato sul server ma cambiato qui: si conserva e si ricarica");
            // se conservato non è più collegato: nella fase 3 torna sul server come elemento nuovo (3a)
        }

        state.Entries = entries.Values.ToList();
        state.Ctag = info.Ctag;
        state.SyncToken = token;
        stateStore.Save(state);

        // 3. Conferma della prima volta (2a, 4a) e modifiche del computer verso il server.
        var current = store.List().ToDictionary(c => c.Id);
        mapped = entries.Values.Where(e => e.ItemId is not null).Select(e => e.ItemId!).ToHashSet();
        var localNew = current.Values.Where(c => !mapped.Contains(c.Id)).ToList();
        if (readOnly)
        {
            if (localNew.Count > 0 || entries.Values.Any(e => e.ItemId is { } id && (!current.TryGetValue(id, out var l) || l.Fingerprint != e.Fingerprint)))
                log?.Invoke($"{Label}: raccolta di sola lettura sul server: le modifiche fatte qui non vengono caricate");
            Save(state, entries);
            return Result(0, needsConfirmation: false, info.Name);
        }
        if (!state.Confirmed)
        {
            if (localNew.Count > 0)
                return Result(localNew.Count, needsConfirmation: true, info.Name);
            state.Confirmed = true;
            stateStore.Save(state);
        }

        var ops = 0;
        foreach (var entry in entries.Values.Where(e => e.ItemId is not null && !e.ServerPending).ToList())
        {
            var target = new Uri(url, entry.Href);
            if (!current.TryGetValue(entry.ItemId!, out var local))
            {
                try
                {
                    await client.DeleteAsync(target, entry.Etag, ct);
                    entries.Remove(entry.Href);
                    _deletedThere++;
                }
                catch (DavPreconditionFailedException)
                {
                    entry.ServerPending = true; // cambiato sul server: al prossimo giro si ricrea qui (3a)
                }
            }
            else if (local.Fingerprint != entry.Fingerprint)
            {
                if (store.Export(local.Id, local.Fingerprint) is not { } export)
                    continue;
                try
                {
                    var etag = await client.PutAsync(target, export.Data, entry.Etag, ct) ?? await client.GetEtagAsync(target, ct);
                    entry.Etag = etag;
                    entry.Fingerprint = export.Item.Fingerprint;
                    _uploaded++;
                }
                catch (DavPreconditionFailedException)
                {
                    entry.ServerPending = true; // cambiato anche sul server: conflitto al prossimo giro
                }
            }
            else
                continue;
            if (++ops % SaveEvery == 0)
                Save(state, entries);
        }

        foreach (var local in localNew)
        {
            if (store.Export(local.Id, local.Fingerprint) is not { } export)
                continue;
            var href = new Uri(url, export.FileName).AbsolutePath;
            if (entries.ContainsKey(href))
                href = new Uri(url, local.Id + client.Kind.Extension).AbsolutePath;
            var target = new Uri(url, href);
            try
            {
                var (created, etag, how) = await client.CreateAsync(url, target, export.Data, ct);
                href = created.AbsolutePath; // con il POST lo sceglie il server
                log?.Invoke($"{Label}: elemento {local.Id} caricato ({how}), indirizzo {created.Segments.LastOrDefault()}");
                etag ??= await client.GetEtagAsync(created, ct);
                entries[href] = new DavEntry { Href = href, Etag = etag, ItemId = local.Id, Fingerprint = export.Item.Fingerprint };
                _uploaded++;
            }
            catch (DavPreconditionFailedException)
            {
                // C'è già (caricato da un giro interrotto): si rilegge e si confronta al prossimo giro.
                entries[href] = new DavEntry { Href = href, ItemId = local.Id, ServerPending = true };
            }
            if (++ops % SaveEvery == 0)
                Save(state, entries);
        }
        Save(state, entries);
        return Result(0, needsConfirmation: false, info.Name);
    }

    private async Task<(Dictionary<string, string?> Changed, HashSet<string> Deleted, string? Token)> ServerChangesAsync(
        DavState state, DavCollection info, Dictionary<string, DavEntry> entries, CancellationToken ct)
    {
        if (state.Ctag is not null && info.Ctag == state.Ctag && (info.SyncToken is null || info.SyncToken == state.SyncToken))
            return ([], [], state.SyncToken);

        if (info.SupportsSync && state.SyncToken is not null
            && await client.SyncCollectionAsync(info.Url, state.SyncToken, ct) is { } diff)
        {
            var changed = diff.Changed.Where(p => !entries.TryGetValue(p.Key, out var e) || e.Etag is null || p.Value is null || e.Etag != p.Value)
                .ToDictionary(p => p.Key, p => p.Value);
            return (changed, diff.Deleted.Where(entries.ContainsKey).ToHashSet(), diff.SyncToken);
        }

        // Elenco completo (prima volta, token scaduto o server senza sync-collection).
        var initial = info.SupportsSync ? await client.SyncCollectionAsync(info.Url, null, ct) : null;
        var listing = initial?.Changed ?? await client.ListEtagsAsync(info.Url, ct);
        var changedAll = listing.Where(p => !entries.TryGetValue(p.Key, out var e) || e.Etag is null || p.Value is null || e.Etag != p.Value)
            .ToDictionary(p => p.Key, p => p.Value);
        var deletedAll = entries.Keys.Where(h => !listing.ContainsKey(h)).ToHashSet();
        return (changedAll, deletedAll, initial?.SyncToken ?? info.SyncToken);
    }

    /// <summary>Applica la versione del server all'elemento collegato.</summary>
    private void Apply(DavEntry entry, string id, DavIncoming incoming, DateTimeOffset updated, string? etag, string? expected)
    {
        var r = store.Apply(id, incoming, updated, expected);
        entry.Etag = etag;
        switch (r.Outcome)
        {
            case DavApplyOutcome.Saved:
                entry.Fingerprint = r.Item!.Fingerprint;
                entry.ServerPending = false;
                _downloaded++;
                break;
            case DavApplyOutcome.Invalid:
                entry.ServerPending = false; // versione del server non utilizzabile: resta quella del computer
                break;
            default:
                entry.ServerPending = true; // cambiato dall'app proprio adesso (o archivio pieno): al prossimo giro
                break;
        }
    }

    /// <summary>Cambiato da entrambe le parti: vince la modifica più recente, a parità il server (3b, 1a).</summary>
    private void Resolve(DavState state, DavEntry entry, DavLocalItem local, DavIncoming incoming, DateTimeOffset serverTime, string? etag)
    {
        var localTime = local.Updated ?? DateTimeOffset.MinValue;
        var serverWins = serverTime >= localTime;
        if (entry.Fingerprint.Length > 0)
        {
            _conflicts++;
            log?.Invoke($"{Label}: conflitto sull'elemento {local.Id} (computer {localTime:u}, server {serverTime:u}): "
                + (serverWins ? "vince il server" : "vince il computer"));
        }
        if (serverWins)
        {
            Apply(entry, local.Id, incoming, serverTime, etag, local.Fingerprint);
            return;
        }
        // Vince il computer: la sua versione va sul server (impronta diversa = da caricare), sopra quella appena letta.
        // Prima della conferma (4a) niente verso il server: il conflitto si rivaluta al prossimo giro.
        entry.Etag = etag;
        entry.ServerPending = !state.Confirmed;
    }

    /// <summary>Nome del file sul server dall'UID (stesso elemento = stesso indirizzo anche ripetendo il caricamento).</summary>
    public static string FileNameFromUid(string? uid, string id, string extension)
    {
        uid ??= "";
        if (uid.StartsWith("urn:uuid:", StringComparison.OrdinalIgnoreCase))
            uid = uid[9..];
        var safe = new string(uid.Where(ch => char.IsAsciiLetterOrDigit(ch) || ch is '-' or '_' or '.').Take(100).ToArray()).Trim('.');
        return (safe.Length > 0 ? safe : id) + extension;
    }

    /// <summary>Chiude il client HTTP (uno per giro).</summary>
    public void Dispose() => client.Dispose();

    private void Save(DavState state, Dictionary<string, DavEntry> entries)
    {
        state.Entries = entries.Values.ToList();
        stateStore.Save(state);
    }

    private DavResult Result(int pending, bool needsConfirmation, string? name) =>
        new(_downloaded, _uploaded, _deletedHere, _deletedThere, _conflicts, pending, needsConfirmation, name);

    private static Uri WithSlash(Uri url) =>
        url.AbsolutePath.EndsWith('/') ? url : new UriBuilder(url) { Path = url.AbsolutePath + "/" }.Uri;
}
