using System.Diagnostics;

namespace PostinoVip.Core.Cache;

/// <summary>Esito di una sincronizzazione (diagnostica: solo numeri, mai contenuti).</summary>
/// <remarks>[Pending]: intestazioni nuove lasciate al giro dopo (sincronizzazione limitata, cartella non ancora completa).</remarks>
public sealed record SyncResult(string Folder, bool FirstSync, bool Reset, int Added, int Removed, int FlagsChanged, int Total,
    TimeSpan Elapsed, int Pending = 0)
{
    public bool Changed => Reset || Added > 0 || Removed > 0 || FlagsChanged > 0;

    public override string ToString() =>
        $"{Folder}: {(FirstSync ? "prima sincronizzazione, " : "")}{(Reset ? "UIDVALIDITY cambiato (cache della cartella azzerata), " : "")}" +
        $"+{Added} nuove, -{Removed} rimosse, {FlagsChanged} flag cambiati, {Total} in cache" +
        (Pending > 0 ? $", {Pending} ancora da scaricare" : "") + $", {Elapsed.TotalSeconds:0.00} s";
}

/// <summary>
/// Allinea le intestazioni di una cartella della cache a quelle del server (il server vince sempre):
/// 1. UIDVALIDITY diverso da quello salvato -> la cartella locale si svuota;
/// 2. UID SEARCH ALL -> gli UID locali assenti sul server vengono eliminati;
/// 3. gli UID nuovi vengono scaricati (ENVELOPE, FLAGS, dimensione) a blocchi;
/// 4. i flag dei messaggi già presenti vengono riletti tutti (il server di prova non ha CONDSTORE,
///    che permetterebbe di chiedere solo quelli cambiati).
/// Ogni passo è una transazione: un'interruzione lascia una cache coerente, completata al giro dopo.
/// </summary>
public static class FolderSynchronizer
{
    /// <summary>Intestazioni per FETCH: limita la memoria e la durata di ogni comando sulle cartelle grandi.</summary>
    public const int BatchSize = 500;

    /// <summary>
    /// Fino a quante mail nuove l'anteprima si chiede subito, durante la sincronizzazione (il caso
    /// normale: poche mail arrivate dall'ultima volta). Oltre, la riempie il download in background,
    /// per non rallentare la prima apertura di una cartella grande.
    /// </summary>
    public const int InlinePreviewLimit = 50;

    /// <summary>
    /// Intestazioni nuove scaricate al massimo quando la lista si apre (11/11/2026, scelta 1a): la prima apertura di una
    /// cartella grande risponde con le più recenti e il resto lo completa il download in background, che avvisa l'app
    /// («folder-synced»). Prima la lista aspettava tutta la cartella e l'app rinunciava dopo 30 s.
    /// </summary>
    public const int FirstPageLimit = 200;

    /// <param name="maxNew">Al massimo quante intestazioni nuove scaricare (dalle più recenti); le altre restano in
    /// <see cref="SyncResult.Pending"/> e la cartella non è segnata come sincronizzata. null = tutte.</param>
    public static async Task<SyncResult> SyncAsync(IFolderSource source, AccountCache cache, CancellationToken ct = default,
        int? maxNew = null)
    {
        var watch = Stopwatch.StartNew();
        var folder = cache.GetOrAddFolder(source.FullName);
        var firstSync = folder.SyncedAt is null;

        var reset = folder.UidValidity is { } stored && stored != source.UidValidity;
        if (folder.UidValidity != source.UidValidity)
            cache.ResetFolder(folder.Id, source.UidValidity); // anche la prima volta: salva UIDVALIDITY

        var local = cache.GetUids(folder.Id);
        var server = await source.GetUidsAsync(ct);
        var onServer = server.ToHashSet();

        var removed = cache.DeleteMessages(folder.Id, local.Where(u => !onServer.Contains(u)).ToList());

        // Flag dei messaggi già presenti, prima di scaricare i nuovi (che arrivano già con i loro flag).
        var flagsChanged = 0;
        if (local.Count > removed)
            flagsChanged = cache.UpdateFlags(folder.Id, await source.FetchFlagsAsync(ct));

        // I nuovi dal più recente: se la prima sincronizzazione di una cartella enorme si interrompe,
        // in cache ci sono già i messaggi che l'utente vede per primi.
        var added = 0;
        var fresh = server.Where(u => !local.Contains(u)).OrderDescending().ToList();
        var withPreview = fresh.Count <= InlinePreviewLimit;
        var pending = maxNew is { } max && fresh.Count > max ? fresh.Count - max : 0;
        foreach (var batch in fresh.Take(fresh.Count - pending).Chunk(BatchSize))
        {
            var headers = await source.FetchHeadersAsync(batch, withPreview, ct);
            cache.UpsertHeaders(folder.Id, headers);
            added += headers.Count;
        }

        if (pending == 0)
            cache.MarkSynced(folder.Id, DateTimeOffset.UtcNow);
        var total = cache.GetUids(folder.Id).Count;
        return new SyncResult(source.FullName, firstSync, reset, added, removed, flagsChanged, total, watch.Elapsed, pending);
    }
}
