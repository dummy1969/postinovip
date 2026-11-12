using PostinoVip.Core.Imap;

namespace PostinoVip.Core.Cache;

/// <summary>
/// Ricerca sul server per le mail che la ricerca locale ha visto solo dalle intestazioni (corpo non in
/// cache: fuori dal limite, Posta eliminata, Indesiderata). Per ogni cartella (una o tutte): prima
/// sincronizza le intestazioni (i risultati hanno sempre mittente, oggetto e data), poi IMAP SEARCH,
/// e tiene solo i messaggi il cui corpo non è nell'indice locale: gli altri la ricerca locale li ha
/// già controllati per intero.
/// </summary>
public static class ServerSearch
{
    /// <returns>Risultati dal più recente e cartelle saltate (es. non apribili).</returns>
    public static async Task<(IReadOnlyList<SearchRow> Rows, IReadOnlyList<string> Skipped)> RunAsync(IMailboxSource source,
        AccountCache cache, MailSearchQuery query, string? folder, CancellationToken ct = default)
    {
        if (query.IsEmpty)
            return ([], []);

        var folders = folder is not null ? [folder] : (await source.GetFoldersAsync(ct)).Select(f => f.FullName).ToList();
        var found = new List<(SearchRow Row, long Arrived)>();
        var skipped = new List<string>();
        foreach (var name in folders)
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                found.AddRange(await source.ExamineAsync(name, async f =>
                {
                    using (await cache.LockFolderAsync(f.FullName, ct))
                        await FolderSynchronizer.SyncAsync(f, cache, ct);
                    var uids = await f.SearchAsync(query, ct);
                    var cached = cache.FindFolder(f.FullName)!;
                    var rows = cache.GetRowsWithoutIndexedBody(cached.Id, uids.ToHashSet());
                    if (query.HasAttachments is not { } wanted)
                        return rows;

                    // allegati:sì/no: la struttura si chiede al server solo per i messaggi che non la
                    // hanno ancora in cache, e si salva (vale anche per la ricerca locale).
                    var known = cache.GetHasAttachments(cached.Id, rows.Select(r => r.Row.Uid).ToList());
                    var unknown = rows.Select(r => r.Row.Uid).Where(u => !known.ContainsKey(u)).ToList();
                    if (unknown.Count > 0)
                    {
                        var fetched = await f.FetchHasAttachmentsAsync(unknown, ct);
                        cache.SetHasAttachments(cached.Id, fetched);
                        foreach (var (u, has) in fetched)
                            known[u] = has;
                    }
                    return rows.Where(r => known.TryGetValue(r.Row.Uid, out var has) && has == wanted).ToList();
                }, ct));
            }
            catch (Exception ex) when (folder is null && ex is not OperationCanceledException && !ImapConnection.IsConnectionError(ex))
            {
                skipped.Add(name); // con tutte le cartelle, una non apribile non ferma la ricerca
            }
        }
        var rows = found.OrderByDescending(f => f.Arrived).ThenByDescending(f => f.Row.Uid).Select(f => f.Row).ToList();
        return (rows, skipped);
    }
}
