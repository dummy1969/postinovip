using MailKit;
using MailKit.Search;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Imap;

/// <summary>
/// IFolderSource su una cartella MailKit già aperta in sola lettura (EXAMINE). La struttura (BODYSTRUCTURE: allegati,
/// anteprima) si chiede sempre a parte dalle intestazioni, attraverso <see cref="StructureGuard"/>: una mail con la
/// struttura illeggibile non blocca la lista.
/// </summary>
internal sealed class ImapFolderSource(IMailFolder folder, StructureGuard? guard = null) : IFolderSource
{
    private readonly StructureGuard _guard = guard ?? new StructureGuard();

    private const MessageSummaryItems HeaderItems =
        MessageSummaryItems.UniqueId | MessageSummaryItems.Envelope | MessageSummaryItems.Flags |
        MessageSummaryItems.Size | MessageSummaryItems.InternalDate |
        MessageSummaryItems.References; // BODY.PEEK[HEADER.FIELDS (REFERENCES)]: conversazioni (3.6)

    public string FullName => folder.FullName;

    public uint UidValidity => folder.UidValidity;

    public async Task<IReadOnlyList<uint>> GetUidsAsync(CancellationToken ct)
    {
        if (folder.Count == 0)
            return [];
        // UID SEARCH ALL (con ESEARCH la risposta è compatta: intervalli invece dell'elenco).
        var uids = await folder.SearchAsync(SearchQuery.All, ct);
        return uids.Select(u => u.Id).ToList();
    }

    public async Task<IReadOnlyList<HeaderRecord>> FetchHeadersAsync(IReadOnlyList<uint> uids, bool withPreview, CancellationToken ct)
    {
        if (uids.Count == 0)
            return [];
        // Più le intestazioni dell'importanza (P1): MailKit le chiede insieme a REFERENCES in BODY.PEEK[HEADER.FIELDS (…)].
        var summaries = await folder.FetchAsync(uids.Select(u => new UniqueId(u)).ToList(),
            new FetchRequest(HeaderItems, MailImportanceHeaders.Ids), ct);
        // Struttura (allegati) e anteprima a parte: le mail sospette o illeggibili restano senza, le completa il background.
        var items = MessageSummaryItems.UniqueId | MessageSummaryItems.BodyStructure | (withPreview ? MessageSummaryItems.PreviewText : 0);
        var structures = (await _guard.FetchAsync(folder, uids, new FetchRequest(items), probe: false, ct))
            .ToDictionary(s => s.UniqueId.Id);
        return summaries.Select(s =>
        {
            var record = MessageHeaderMapper.ToRecord(s);
            return structures.TryGetValue(record.Uid, out var b)
                ? record with
                {
                    Preview = b.PreviewText is null ? null : MessageHeaderMapper.CleanPreview(b.PreviewText),
                    HasAttachments = MessageHeaderMapper.HasAttachments(b),
                }
                : record;
        }).ToList();
    }

    public async Task<IReadOnlyList<PreviewRecord>> FetchPreviewsAsync(IReadOnlyList<uint> uids, CancellationToken ct)
    {
        if (uids.Count == 0)
            return [];
        var request = new FetchRequest(MessageSummaryItems.UniqueId | MessageSummaryItems.BodyStructure | MessageSummaryItems.PreviewText);
        // probe: è il download in background, che può permettersi di cercare la mail difettosa tra i gruppi sospetti.
        var summaries = await _guard.FetchAsync(folder, uids, request, probe: true, ct);
        return summaries
            .Select(s => new PreviewRecord(s.UniqueId.Id, MessageHeaderMapper.CleanPreview(s.PreviewText), MessageHeaderMapper.HasAttachments(s)))
            .ToList();
    }

    public async Task<IReadOnlyList<(uint Uid, string References)>> FetchReferencesAsync(IReadOnlyList<uint> uids, CancellationToken ct)
    {
        if (uids.Count == 0)
            return [];
        var request = new FetchRequest(MessageSummaryItems.UniqueId | MessageSummaryItems.References);
        var summaries = await folder.FetchAsync(uids.Select(u => new UniqueId(u)).ToList(), request, ct);
        return summaries.Select(s => (s.UniqueId.Id, ConversationIds.Join(s.References))).ToList();
    }

    public async Task<IReadOnlyList<(uint Uid, MailImportance Importance)>> FetchImportanceAsync(IReadOnlyList<uint> uids, CancellationToken ct)
    {
        if (uids.Count == 0)
            return [];
        var request = new FetchRequest(MessageSummaryItems.UniqueId, MailImportanceHeaders.Ids);
        var summaries = await folder.FetchAsync(uids.Select(u => new UniqueId(u)).ToList(), request, ct);
        return summaries.Select(s => (s.UniqueId.Id, MailImportanceHeaders.From(s.Headers))).ToList();
    }

    public async Task<IReadOnlyList<(uint Uid, MailFlags Flags)>> FetchFlagsAsync(CancellationToken ct)
    {
        if (folder.Count == 0)
            return [];
        // FETCH 1:* (UID FLAGS): pochi byte per messaggio.
        var summaries = await folder.FetchAsync(0, -1, new FetchRequest(MessageSummaryItems.UniqueId | MessageSummaryItems.Flags), ct);
        return summaries.Select(s => (s.UniqueId.Id, MessageHeaderMapper.ToMailFlags(s.Flags, s.Keywords))).ToList();
    }

    /// <summary>
    /// Traduzione per IMAP SEARCH: da: -> FROM, a: -> TO o CC, oggetto: -> SUBJECT; parole, frasi e
    /// allegato: -> SUBJECT o FROM o TO o CC o BODY (il nome di un allegato sta nelle intestazioni MIME
    /// del corpo). Non si usa TEXT: il server di prova (IceWarp) risponde sempre senza risultati,
    /// anche per parole presenti nell'oggetto (misurato il 30/10/2026). La corrispondenza segue le
    /// regole del server (RFC 3501: sottostringa, senza distinzione di maiuscole; accenti a
    /// discrezione del server).
    /// </summary>
    public async Task<IReadOnlyList<uint>> SearchAsync(MailSearchQuery query, CancellationToken ct)
    {
        if (folder.Count == 0 || query.IsEmpty)
            return [];

        SearchQuery imap = SearchQuery.All;
        foreach (var t in query.Terms)
        {
            SearchQuery term = t.Field switch
            {
                SearchField.Sender => SearchQuery.FromContains(t.Text),
                SearchField.Recipients => SearchQuery.ToContains(t.Text).Or(SearchQuery.CcContains(t.Text)),
                SearchField.Subject => SearchQuery.SubjectContains(t.Text),
                _ => SearchQuery.SubjectContains(t.Text)
                    .Or(SearchQuery.FromContains(t.Text))
                    .Or(SearchQuery.ToContains(t.Text))
                    .Or(SearchQuery.CcContains(t.Text))
                    .Or(SearchQuery.BodyContains(t.Text)),
            };
            imap = ReferenceEquals(imap, SearchQuery.All) ? term : imap.And(term);
        }
        var uids = await folder.SearchAsync(imap, ct);
        return uids.Select(u => u.Id).ToList();
    }

    public async Task<IReadOnlyDictionary<uint, bool>> FetchHasAttachmentsAsync(IReadOnlyList<uint> uids, CancellationToken ct)
    {
        var result = new Dictionary<uint, bool>();
        // A blocchi come le intestazioni: la struttura di un messaggio può essere lunga.
        foreach (var batch in uids.Chunk(500))
        {
            var structures = await _guard.FetchAsync(folder, batch,
                new FetchRequest(MessageSummaryItems.UniqueId | MessageSummaryItems.BodyStructure), probe: false, ct);
            foreach (var s in structures)
                result[s.UniqueId.Id] = s.Attachments.Any();
        }
        return result;
    }

    public async Task ReadRawAsync(uint uid, Func<Stream, CancellationToken, Task> consume, CancellationToken ct)
    {
        try
        {
            // UID FETCH ... BODY.PEEK[]: non imposta \Seen.
            await using var stream = await folder.GetStreamAsync(new UniqueId(uid), ct);
            await consume(stream, ct);
        }
        catch (MessageNotFoundException ex)
        {
            throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folder.FullName}'.", ex).WithCode("messaggioNonTrovatoIn2", ("uid", uid), ("fullName", folder.FullName));
        }
    }
}
