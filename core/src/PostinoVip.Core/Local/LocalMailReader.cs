using MailKit;
using MimeKit;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Mime;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Local;

/// <summary>
/// IMailReader di un account POP3 (4.2): tutto dal computer. Prima di ogni lettura la cartella dell'indice
/// (<see cref="AccountCache"/>) viene allineata ai file di <see cref="LocalMailStore"/> con la stessa
/// sincronizzazione usata per i server IMAP (solo le differenze; tutto locale, quindi veloce), poi i corpi
/// nuovi entrano nell'indice di ricerca. Non serve la rete: un account POP3 è sempre "connesso" per la lettura.
/// </summary>
public sealed class LocalMailReader(string account, LocalMailStore store, AccountCache cache, Action<string>? log = null) : IMailReader
{
    public async Task<IReadOnlyList<MailFolderInfo>> GetFoldersAsync(CancellationToken ct = default)
    {
        var folders = await store.GetFoldersAsync(ct);
        cache.RemoveFoldersNotIn(folders.Select(f => f.FullName).ToList());
        cache.SetFolderInfo(folders);
        LogInitializeNote();
        // Da leggere: dall'indice, dopo aver allineato ogni cartella (locale: costa poco).
        var result = new List<MailFolderInfo>();
        foreach (var f in folders)
        {
            var cached = await SyncAsync(f.FullName, ct);
            var (unread, _) = cache.GetPage(cached.Id, 0, 1, unreadOnly: true);
            result.Add(f with { Unread = unread });
        }
        return result;
    }

    public async Task<MessagePage> GetHeadersAsync(string folder, int offset, int limit, bool unreadOnly = false, bool oldestFirst = false,
        CancellationToken ct = default, MessageSort sort = MessageSort.Date)
    {
        var cached = await SyncAsync(folder, ct);
        var (total, items) = cache.GetPage(cached.Id, offset, limit, unreadOnly, oldestFirst, sort);
        return new MessagePage(total, offset, limit, items.Select(MessageHeaderMapper.FromRecord).ToList());
    }

    public async Task<ConversationPage> GetConversationsAsync(string folder, int offset, int limit, bool unreadOnly = false,
        bool oldestFirst = false, CancellationToken ct = default)
    {
        var cached = await SyncAsync(folder, ct);
        var (total, items) = cache.GetConversations(cached, offset, limit, unreadOnly, oldestFirst);
        var conversations = items.Select(c =>
        {
            var messages = c.Messages.Select(m => new ConversationMessage(m.Folder, MessageHeaderMapper.FromRecord(m.Header))).ToList();
            return new Conversation(c.Thread, messages.Count, messages.Count(m => !m.Message.Seen),
                messages.Any(m => m.Message.HasAttachments == true), messages);
        }).ToList();
        return new ConversationPage(total, offset, limit, conversations);
    }

    /// <summary>
    /// Allinea l'indice della cartella ai file e indicizza i corpi nuovi. Lo stesso lock della copia IMAP:
    /// una sincronizzazione alla volta per cartella (lista dell'app e scaricamento POP3 in parallelo).
    /// </summary>
    public async Task<CachedFolder> SyncAsync(string folder, CancellationToken ct = default)
    {
        var info = store.FolderExists(folder) ? store.GetFolder(folder) : throw new MailNotFoundException($"Cartella '{folder}' non trovata.").WithCode("cartellaNonTrovata3", ("folder", folder));
        var source = new LocalFolderSource(store, folder, info);
        using var _ = await cache.LockFolderAsync(folder, ct);
        var result = await FolderSynchronizer.SyncAsync(source, cache, ct);
        if (result.Reset)
            log?.Invoke($"[{account}] copia locale {result}");
        var cached = cache.FindFolder(folder)
            ?? throw new InvalidOperationException($"Cartella '{folder}' assente dall'indice dopo la sincronizzazione.").WithCode("cartellaAssenteDallIndiceDopo", ("folder", folder));

        var indexed = 0;
        foreach (var uid in cache.GetUnindexedBodies(cached.Id))
        {
            ct.ThrowIfCancellationRequested();
            MimeMessage message;
            try
            {
                message = await LoadAsync(folder, uid, ct);
            }
            catch (Exception ex) when (ex is MailNotFoundException or FormatException)
            {
                continue; // sparito o illeggibile: la prossima sincronizzazione lo sistema
            }
            cache.SetLocalBodyIndexed(cached.Id, uid, SearchText.From(message));
            indexed++;
        }
        if (indexed > 0 && result.Added > 0)
            log?.Invoke($"[{account}] copia locale {folder}: {result.Added} mail aggiunte all'indice");
        return cached;
    }

    private void LogInitializeNote()
    {
        if (cache.TakeInitializeNote() is { } note)
            log?.Invoke($"[{account}] copia locale: {note} (le mail sono nei file: l'indice si rifà da lì)");
    }

    public async Task<MessageDetail> GetMessageAsync(string folder, uint uid, CancellationToken ct = default)
    {
        var detail = MessageHeaderMapper.FromMimeMessage(new UniqueId(uid), await LoadAsync(folder, uid, ct));
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
            var h = MessageHeaderMapper.FromRecord(new HeaderRecord(r.Uid, r.Flags, r.Subject, r.FromName, r.FromAddress,
                null, null, r.Date, null, null, null, null));
            return new SearchHit(r.Folder, r.Uid, h.Subject, h.From, h.Date, h.Seen, r.Snippet, r.BodyIndexed);
        }).ToList();
        return Task.FromResult(new SearchResult(total, offset, limit, items));
    }

    /// <summary>Con il POP3 tutte le mail sono già nell'indice locale: il server non ha niente in più.</summary>
    public Task<SearchResult> SearchServerAsync(string query, string? folder, int offset, int limit, CancellationToken ct = default) =>
        Task.FromResult(new SearchResult(0, offset, limit, []));

    /// <summary>Il file della mail scaricata con il POP3, così com'è (E1).</summary>
    public async Task<byte[]> GetRawAsync(string folder, uint uid, CancellationToken ct = default)
    {
        await using var stream = store.OpenRead(folder, uid);
        using var copy = new MemoryStream();
        await stream.CopyToAsync(copy, ct);
        return copy.ToArray();
    }

    private async Task<MimeMessage> LoadAsync(string folder, uint uid, CancellationToken ct)
    {
        await using var stream = store.OpenRead(folder, uid);
        return await MimeMessage.LoadAsync(stream, ct);
    }
}
