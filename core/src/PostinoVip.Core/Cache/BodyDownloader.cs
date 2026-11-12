using System.Diagnostics;
using MimeKit;
using PostinoVip.Core.Imap;

namespace PostinoVip.Core.Cache;

/// <summary>Esito del download dei corpi di una cartella (diagnostica: solo numeri).</summary>
public sealed record DownloadResult(string Folder, int Downloaded, long Bytes, int Gone, int Indexed, TimeSpan Elapsed,
    int Previews = 0, int References = 0, int Importance = 0)
{
    public override string ToString() =>
        $"{Folder}: {Downloaded} corpi scaricati ({Bytes / 1024.0 / 1024.0:0.0} MB)" +
        (Gone > 0 ? $", {Gone} spariti dal server nel frattempo" : "") +
        (Indexed > 0 ? $", {Indexed} aggiunti alla ricerca" : "") +
        (Previews > 0 ? $", {Previews} anteprime aggiunte" : "") +
        (References > 0 ? $", {References} References aggiunte (conversazioni)" : "") +
        (Importance > 0 ? $", {Importance} importanze lette" : "") + $", {Elapsed.TotalSeconds:0.0} s";
}

/// <summary>
/// Un passaggio del download in background di un account: per ogni cartella (INBOX per prima)
/// sincronizza le intestazioni e scarica, dal più recente, i corpi che mancano e che la regola
/// (<see cref="BodyPolicy"/>) vuole conservare. Le cartelle solo intestazioni (Posta eliminata,
/// Indesiderata) vengono sincronizzate ma non scaricate.
/// Errori di una singola cartella: registrati, si passa alla successiva. Errori di connessione:
/// propagati al chiamante, che riconnette e ripete il passaggio (riprende da dove era rimasto,
/// perché ogni corpo viene collegato appena salvato).
/// </summary>
public sealed class BodyDownloader(string account, AccountCache cache, BodyPolicy policy, Action<string>? log = null)
{
    /// <summary>
    /// Intestazioni di una cartella sincronizzate (cartella, nuove scaricate, la cartella era incompleta: prima
    /// sincronizzazione o completata a blocchi). Lo usa <see cref="Imap.CacheDownloadWorker"/> per avvisare l'app.
    /// </summary>
    public Action<string, int, bool>? HeadersSynced { get; set; }

    /// <summary>Ogni quanti corpi scaricati scrivere l'avanzamento nel log.</summary>
    public const int ProgressEvery = 200;

    // Cartelle già segnalate come saltate: una cartella non apribile (es. "NO Insufficient rights")
    // non deve riempire il log a ogni passaggio. Usato da un solo worker alla volta.
    private readonly HashSet<string> _skipReported = new(StringComparer.Ordinal);

    public async Task<IReadOnlyList<DownloadResult>> RunPassAsync(IMailboxSource source, CancellationToken ct = default)
    {
        var folders = await source.GetFoldersAsync(ct);
        cache.RemoveFoldersNotIn(folders.Select(f => f.FullName).ToList());
        cache.SetFolderInfo(folders);

        var watch = Stopwatch.StartNew();
        var results = new List<DownloadResult>();
        // OrderBy è stabile: dopo INBOX le altre nell'ordine del server.
        foreach (var folder in folders.OrderBy(f => f.SpecialUse == "inbox" ? 0 : 1))
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                if (await source.ExamineAsync(folder.FullName, f => SyncFolderAsync(f, ct), ct) is { } result)
                    results.Add(result);
            }
            catch (Exception ex) when (ex is not OperationCanceledException && !ImapConnection.IsConnectionError(ex))
            {
                if (_skipReported.Add(folder.FullName))
                    log?.Invoke($"[{account}] cache: cartella {folder.FullName} saltata ({ex.GetType().Name}: {ex.Message}); " +
                                "non più segnalata fino al riavvio");
            }
        }
        // Conversazioni pronte prima che l'app le chieda (altrimenti le calcola la prima richiesta).
        var threads = cache.RecomputeThreadsIfDirty();
        if (threads > 0)
            log?.Invoke($"[{account}] cache: conversazioni ricalcolate, {threads} mail cambiate di conversazione");
        if (results.Count > 0)
            log?.Invoke($"[{account}] cache: passaggio completato, {results.Sum(r => r.Downloaded)} corpi in {watch.Elapsed.TotalSeconds:0.0} s");
        return results;
    }

    /// <returns>null se non c'era nessun corpo da scaricare.</returns>
    private async Task<DownloadResult?> SyncFolderAsync(IFolderSource source, CancellationToken ct)
    {
        // A blocchi, liberando la cartella tra uno e l'altro: la lista aperta nell'app aspetta al massimo un blocco.
        SyncResult sync;
        int added = 0;
        var incomplete = false;
        do
        {
            // Cartella vuota: primo blocco piccolo, così la lista aperta nell'app ha presto le più recenti.
            var step = cache.FindFolder(source.FullName) is { } known && cache.GetUids(known.Id).Count > 0
                ? FolderSynchronizer.BatchSize : FolderSynchronizer.FirstPageLimit;
            using (await cache.LockFolderAsync(source.FullName, ct))
                sync = await FolderSynchronizer.SyncAsync(source, cache, ct, step);
            added += sync.Added;
            incomplete |= sync.FirstSync || sync.Pending > 0;
            if (sync.Changed || sync.FirstSync)
                log?.Invoke($"[{account}] cache (in background) {sync}");
        } while (sync.Pending > 0);
        HeadersSynced?.Invoke(source.FullName, added, incomplete);

        var folder = cache.FindFolder(source.FullName)
            ?? throw new InvalidOperationException($"Cartella '{source.FullName}' assente dalla cache dopo la sincronizzazione.");
        var now = DateTimeOffset.UtcNow;
        var missing = cache.GetMissingBodies(folder.Id).Where(m => policy.Keeps(folder.Role, m.Arrived, now)).ToList();
        var watch = Stopwatch.StartNew();
        if (missing.Count > 0)
            log?.Invoke($"[{account}] cache: {missing.Count} corpi da scaricare in {source.FullName}");
        int downloaded = 0, gone = 0;
        long bytes = 0;
        foreach (var (uid, _) in missing)
        {
            ct.ThrowIfCancellationRequested();
            // Nel frattempo l'utente può averlo aperto (salvato dalla connessione dei comandi).
            if (cache.GetBodyRow(folder.Id, uid) is not { Sha256: null })
                continue;

            string? sha256 = null;
            try
            {
                await source.ReadRawAsync(uid, async (stream, c) => sha256 = await cache.Bodies.SaveAsync(stream, c), ct);
            }
            catch (MailNotFoundException)
            {
                gone++; // eliminato sul server dopo la sincronizzazione: la prossima toglierà la riga
                continue;
            }

            cache.SetBody(folder.Id, uid, sha256);
            downloaded++;
            bytes += new FileInfo(cache.Bodies.PathFor(sha256!)).Length;
            if (downloaded % ProgressEvery == 0)
                log?.Invoke($"[{account}] cache: {source.FullName} {downloaded}/{missing.Count} corpi ({bytes / 1024.0 / 1024.0:0.0} MB)");
        }

        var indexed = await IndexBodiesAsync(folder, ct);
        var previews = await FillPreviewsAsync(source, folder, ct);
        var references = await FillReferencesAsync(source, folder, ct);
        var importance = await FillImportanceAsync(source, folder, ct);
        if (missing.Count == 0 && indexed == 0 && previews == 0 && references == 0 && importance == 0)
            return null;

        var result = new DownloadResult(source.FullName, downloaded, bytes, gone, indexed, watch.Elapsed, previews, references, importance);
        log?.Invoke($"[{account}] cache {result}");
        return result;
    }

    /// <summary>Anteprime chieste al server per ogni blocco (MailKit scarica l'inizio di ogni messaggio).</summary>
    public const int PreviewBatchSize = 100;

    /// <summary>
    /// Anteprima e allegati per le mail senza corpo in cache (più vecchie del limite, Posta eliminata,
    /// Indesiderata, o arrivate in tante insieme): chiesti al server a blocchi, dal più recente. Quelle
    /// con il corpo le completa l'indicizzazione, senza rete.
    /// </summary>
    private async Task<int> FillPreviewsAsync(IFolderSource source, CachedFolder folder, CancellationToken ct)
    {
        // Prima, senza rete, quelle già nell'indice di ricerca (indicizzate prima dell'anteprima).
        var filled = cache.FillPreviewsFromIndex(folder.Id);
        foreach (var batch in cache.GetMissingPreviews(folder.Id).Chunk(PreviewBatchSize))
        {
            ct.ThrowIfCancellationRequested();
            var previews = await source.FetchPreviewsAsync(batch, ct);
            cache.SetPreviews(folder.Id, previews);
            filled += previews.Count;
        }
        return filled;
    }

    /// <summary>
    /// References per le mail salvate prima delle conversazioni (le nuove la ricevono con le intestazioni):
    /// solo quell'intestazione, a blocchi, dal più recente. Anche Posta eliminata e Indesiderata: un loro
    /// messaggio può legare due mail di altre cartelle.
    /// </summary>
    private async Task<int> FillReferencesAsync(IFolderSource source, CachedFolder folder, CancellationToken ct)
    {
        var filled = 0;
        foreach (var batch in cache.GetMissingReferences(folder.Id).Chunk(FolderSynchronizer.BatchSize))
        {
            ct.ThrowIfCancellationRequested();
            var refs = await source.FetchReferencesAsync(batch, ct);
            cache.SetReferences(folder.Id, refs);
            filled += refs.Count;
        }
        return filled;
    }

    /// <summary>
    /// Importanza (P1) per le mail salvate prima che la si leggesse (le nuove la ricevono con le intestazioni): solo
    /// quelle tre intestazioni, a blocchi, dal più recente. Sola lettura (BODY.PEEK).
    /// </summary>
    private async Task<int> FillImportanceAsync(IFolderSource source, CachedFolder folder, CancellationToken ct)
    {
        var filled = 0;
        foreach (var batch in cache.GetMissingImportance(folder.Id).Chunk(FolderSynchronizer.BatchSize))
        {
            ct.ThrowIfCancellationRequested();
            var values = await source.FetchImportanceAsync(batch, ct);
            cache.SetImportance(folder.Id, values);
            filled += values.Count;
        }
        return filled;
    }

    /// <summary>
    /// Mette nell'indice di ricerca i corpi in cache che non ci sono ancora: quelli appena scaricati
    /// qui sopra e quelli salvati prima che esistesse la ricerca. File mancante o danneggiato:
    /// scollegato, verrà riscaricato al passaggio successivo.
    /// </summary>
    private async Task<int> IndexBodiesAsync(CachedFolder folder, CancellationToken ct)
    {
        var indexed = 0;
        foreach (var (uid, sha256) in cache.GetBodiesToIndex(folder.Id))
        {
            ct.ThrowIfCancellationRequested();
            if (cache.Bodies.TryRead(sha256) is not { } bytes)
            {
                cache.SetBody(folder.Id, uid, null);
                continue;
            }
            var message = await MimeMessage.LoadAsync(new MemoryStream(bytes, writable: false), ct);
            cache.SetBody(folder.Id, uid, sha256, SearchText.From(message));
            indexed++;
        }
        return indexed;
    }
}
