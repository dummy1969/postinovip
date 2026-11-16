using MailKit;
using MimeKit;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Mime;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Cache;

/// <summary>
/// IMailReader con la cache locale: la lista dei messaggi viene prima sincronizzata con il server
/// (solo le differenze) e poi letta dal database; apertura, bozze e allegati usano il corpo salvato
/// su disco, scaricandolo solo se manca (<see cref="BodyCache"/>). L'elenco cartelle passa al server.
/// Sincronizzazione e download avvengono sulla connessione IMAP dell'account, quindi uno alla volta.
/// La lista scarica al massimo <see cref="FolderSynchronizer.FirstPageLimit"/> intestazioni nuove: se ne restano,
/// [headersPending] (cartella) chiede al download in background di completarla.
/// </summary>
public sealed class CachedMailReader(string account, ImapConnection connection, IMailReader inner, AccountCache cache,
    BodyCache bodies, Action<string>? log = null, Action<string>? headersPending = null) : IMailReader
{
    private int _capabilitiesLogged;

    public async Task<IReadOnlyList<MailFolderInfo>> GetFoldersAsync(CancellationToken ct = default)
    {
        try
        {
            IReadOnlyList<MailFolderInfo> folders;
            try
            {
                folders = await inner.GetFoldersAsync(ct);
            }
            catch (MailOfflineException) when (cache.GetFolderList() is { Count: > 0 } cached)
            {
                return cached; // senza connessione: l'elenco dell'ultima volta
            }
            var removed = cache.RemoveFoldersNotIn(folders.Select(f => f.FullName).ToList());
            if (removed > 0)
                log?.Invoke($"[{account}] cache: {removed} cartelle non più presenti sul server eliminate");
            cache.SetFolderInfo(folders);
            return folders;
        }
        finally
        {
            LogInitializeNote(); // es. database rovinato e ricreato alla prima apertura
        }
    }

    private void LogInitializeNote()
    {
        if (cache.TakeInitializeNote() is { } note)
            log?.Invoke($"[{account}] cache: {note}");
    }

    public async Task<MessagePage> GetHeadersAsync(string folder, int offset, int limit, bool unreadOnly = false, bool oldestFirst = false,
        CancellationToken ct = default, MessageSort sort = MessageSort.Date)
    {
        string fullName;
        SyncResult result;
        try
        {
            (fullName, result) = await SyncAsync(folder, ct);
        }
        catch (MailOfflineException) when (cache.FindFolder(folder) is { SyncedAt: not null } offline)
        {
            // Senza connessione: la lista dell'ultima sincronizzazione.
            var (offlineTotal, offlineItems) = cache.GetPage(offline.Id, offset, limit, unreadOnly, oldestFirst, sort);
            return new MessagePage(offlineTotal, offset, limit, offlineItems.Select(MessageHeaderMapper.FromRecord).ToList());
        }

        LogInitializeNote();
        if (result.Changed || result.FirstSync)
            log?.Invoke($"[{account}] cache {result}");

        var cached = cache.FindFolder(fullName)
            ?? throw new InvalidOperationException($"Cartella '{fullName}' assente dalla cache dopo la sincronizzazione.").WithCode("cartellaAssenteDallaCacheDopo", ("fullName", fullName));
        var (total, items) = cache.GetPage(cached.Id, offset, limit, unreadOnly, oldestFirst, sort);
        return new MessagePage(total, offset, limit, items.Select(MessageHeaderMapper.FromRecord).ToList());
    }

    public async Task<ConversationPage> GetConversationsAsync(string folder, int offset, int limit, bool unreadOnly = false,
        bool oldestFirst = false, CancellationToken ct = default)
    {
        CachedFolder cached;
        try
        {
            var (fullName, result) = await SyncAsync(folder, ct);
            LogInitializeNote();
            if (result.Changed || result.FirstSync)
                log?.Invoke($"[{account}] cache {result}");
            cached = cache.FindFolder(fullName)
                ?? throw new InvalidOperationException($"Cartella '{fullName}' assente dalla cache dopo la sincronizzazione.").WithCode("cartellaAssenteDallaCacheDopo", ("fullName", fullName));
        }
        catch (MailOfflineException) when (cache.FindFolder(folder) is { SyncedAt: not null } offline)
        {
            cached = offline; // senza connessione: le conversazioni dell'ultima sincronizzazione
        }

        var (total, items) = cache.GetConversations(cached, offset, limit, unreadOnly, oldestFirst);
        var conversations = items.Select(c =>
        {
            var messages = c.Messages.Select(m => new ConversationMessage(m.Folder, MessageHeaderMapper.FromRecord(m.Header))).ToList();
            return new Conversation(c.Thread, messages.Count, messages.Count(m => !m.Message.Seen),
                messages.Any(m => m.Message.HasAttachments == true), messages);
        }).ToList();
        return new ConversationPage(total, offset, limit, conversations);
    }

    // Cartelle lasciate incomplete da una sincronizzazione limitata già sincronizzate in passato (SyncedAt non nullo).
    private readonly System.Collections.Concurrent.ConcurrentDictionary<string, bool> _incomplete = new(StringComparer.Ordinal);

    private async Task<(string FullName, SyncResult Result)> SyncAsync(string folder, CancellationToken ct)
    {
        // Prima di mettersi in fila sulla connessione: se il download in background sta completando questa cartella,
        // la risposta viene dalla copia locale (regole, posta indesiderata e lista non aspettano tutta la cartella).
        if (cache.FindFolder(folder) is { } known && FromCacheWhileBusy(known.FullName, locked: false) is { } early)
            return (known.FullName, early);
        var synced = await connection.ReadAsync(async s =>
        {
            LogCapabilitiesOnce(s);
            return await s.ExamineAsync(folder, async source =>
            {
                var gate = cache.TryLockFolder(source.FullName);
                if (gate is null)
                {
                    if (FromCacheWhileBusy(source.FullName, locked: true) is { } busy)
                        return (source.FullName, busy);
                    // Cartella vuota o completa: si aspetta il blocco in corso del download in background (al massimo un
                    // blocco di intestazioni, non tutta la cartella).
                    gate = await cache.LockFolderAsync(source.FullName, ct);
                    if (FromCacheWhileBusy(source.FullName, locked: true) is { } filled)
                    {
                        gate.Dispose(); // nel frattempo il background ha salvato le più recenti: bastano quelle
                        return (source.FullName, filled);
                    }
                }
                using (gate)
                {
                    var limit = headersPending is null ? (int?)null : FolderSynchronizer.FirstPageLimit;
                    return (source.FullName, await FolderSynchronizer.SyncAsync(source, cache, ct, limit));
                }
            }, ct);
        }, ct);
        if (synced.Item2.Pending > 0)
        {
            _incomplete[synced.FullName] = true;
            headersPending?.Invoke(synced.FullName);
        }
        else
        {
            _incomplete.TryRemove(synced.FullName, out _);
        }
        return synced;
    }

    /// <summary>
    /// Esito «dalla copia locale» se la cartella è incompleta, ha già delle mail e il download in background la sta
    /// sincronizzando ([locked]: blocco già trovato occupato); altrimenti null. Il background poi avvisa l'app.
    /// </summary>
    private SyncResult? FromCacheWhileBusy(string fullName, bool locked)
    {
        if (headersPending is null || cache.FindFolder(fullName) is not { } folder)
            return null;
        if (folder.SyncedAt is not null && !_incomplete.ContainsKey(fullName))
            return null;
        if (!locked)
        {
            using var probe = cache.TryLockFolder(fullName);
            if (probe is not null)
                return null; // libera: si sincronizza normalmente
        }
        var count = cache.GetUids(folder.Id).Count;
        if (count == 0)
            return null;
        headersPending(fullName);
        return new SyncResult(fullName, false, false, 0, 0, 0, count, TimeSpan.Zero, Pending: 1);
    }

    public async Task<MessageDetail> GetMessageAsync(string folder, uint uid, CancellationToken ct = default)
    {
        var detail = MessageHeaderMapper.FromMimeMessage(new UniqueId(uid), await LoadAsync(folder, uid, ct));
        // Contrassegno e categorie dall'ultima sincronizzazione (servono anche per una mail aperta da una ricerca).
        if (cache.FindFolder(folder) is not { } cached || cache.GetFlags(cached.Id, uid) is not var (flags, due))
            return detail;
        var flagged = flags.HasFlag(MailFlags.Flagged);
        return detail with
        {
            Flagged = flagged, Completed = flags.HasFlag(MailFlags.Completed), Due = flagged ? due : null,
            Categories = MailKeywords.CategoryNumbers(flags),
            ReceiptHandled = (flags & MailFlags.ReceiptHandled) != 0,
        };
    }

    public Task<MimeMessage> GetMimeMessageAsync(string folder, uint uid, CancellationToken ct = default) => LoadAsync(folder, uid, ct);

    public async Task<ComposeDraft> GetDraftAsync(string folder, uint uid, DraftMode mode, string ownAddress, CancellationToken ct = default) =>
        DraftBuilder.Build(await LoadAsync(folder, uid, ct), mode, ownAddress);

    public async Task<ComposeContent> GetComposeAsync(string folder, uint uid, CancellationToken ct = default) =>
        ComposeReader.Read(await LoadAsync(folder, uid, ct));

    public async Task<MessageQuote> GetQuoteAsync(string folder, uint uid, DraftMode mode, CancellationToken ct = default) =>
        QuoteBuilder.ForSending(await LoadAsync(folder, uid, ct), mode);

    public async Task<AttachmentContent> GetAttachmentAsync(string folder, uint uid, int index, CancellationToken ct = default) =>
        Attachments.Extract(await LoadAsync(folder, uid, ct), index)
            ?? throw new MailNotFoundException($"Allegato {index} non trovato nel messaggio {uid}.").WithCode("allegatoNonTrovatoNelMessaggio", ("index", index), ("uid", uid));

    public async Task<IReadOnlyList<AttachmentContent>> GetAttachmentsAsync(string folder, uint uid, IReadOnlyList<int> indexes,
        CancellationToken ct = default)
    {
        var message = await LoadAsync(folder, uid, ct);
        return indexes
            .Select(i => Attachments.Extract(message, i)
                ?? throw new MailNotFoundException($"Allegato {i} non trovato nel messaggio {uid}.").WithCode("allegatoNonTrovatoNelMessaggio2", ("i", i), ("uid", uid)))
            .ToList();
    }

    public Task<SearchResult> SearchAsync(string query, string? folder, int offset, int limit, CancellationToken ct = default)
    {
        var (total, rows) = cache.Search(MailSearchQuery.Parse(query), folder, offset, limit);
        var items = rows.Select(r =>
        {
            // Stesse regole della lista per oggetto e mittente mancanti.
            var h = MessageHeaderMapper.FromRecord(new HeaderRecord(r.Uid, r.Flags, r.Subject, r.FromName, r.FromAddress,
                null, null, r.Date, null, null, null, null));
            return new SearchHit(r.Folder, r.Uid, h.Subject, h.From, h.Date, h.Seen, r.Snippet, r.BodyIndexed);
        }).ToList();
        return Task.FromResult(new SearchResult(total, offset, limit, items));
    }

    public async Task<SearchResult> SearchServerAsync(string query, string? folder, int offset, int limit, CancellationToken ct = default)
    {
        var parsed = MailSearchQuery.Parse(query);
        var (rows, skipped) = await connection.ReadAsync(s => ServerSearch.RunAsync(s, cache, parsed, folder, ct), ct);
        foreach (var f in skipped)
            log?.Invoke($"[{account}] ricerca sul server: cartella {f} saltata");
        var items = rows.Skip(offset).Take(limit).Select(r =>
        {
            var h = MessageHeaderMapper.FromRecord(new HeaderRecord(r.Uid, r.Flags, r.Subject, r.FromName, r.FromAddress,
                null, null, r.Date, null, null, null, null));
            return new SearchHit(r.Folder, r.Uid, h.Subject, h.From, h.Date, h.Seen, null, BodySearched: true, FromServer: true);
        }).ToList();
        return new SearchResult(rows.Count, offset, limit, items);
    }

    public Task<byte[]> GetRawAsync(string folder, uint uid, CancellationToken ct = default) =>
        bodies.LoadRawAsync(folder, uid, (consume, c) =>
            connection.ReadAsync(async s =>
            {
                await s.ReadRawMessageAsync(folder, uid, consume, c);
                return true;
            }, c), ct);

    private Task<MimeMessage> LoadAsync(string folder, uint uid, CancellationToken ct) =>
        bodies.LoadAsync(folder, uid, (consume, c) =>
            connection.ReadAsync(async s =>
            {
                await s.ReadRawMessageAsync(folder, uid, consume, c);
                return true;
            }, c), ct);

    /// <summary>Una volta per account: quali estensioni utili alla cache annuncia il server dopo il login.</summary>
    private void LogCapabilitiesOnce(ImapMailService session)
    {
        if (Interlocked.Exchange(ref _capabilitiesLogged, 1) == 0)
            log?.Invoke($"[{account}] IMAP dopo il login: {session.CacheCapabilities}; cache in {cache.Path}");
    }
}
