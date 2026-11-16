using PostinoVip.Core.Models;

namespace PostinoVip.Core.Imap;

/// <summary>IMailReader sulla connessione IMAP persistente condivisa.</summary>
public sealed class ImapMailReader(ImapConnection connection) : IMailReader
{
    public Task<IReadOnlyList<MailFolderInfo>> GetFoldersAsync(CancellationToken ct = default) =>
        connection.ReadAsync(s => s.GetFoldersAsync(ct), ct);

    public Task<MessagePage> GetHeadersAsync(string folder, int offset, int limit, bool unreadOnly = false, bool oldestFirst = false,
        CancellationToken ct = default, MessageSort sort = MessageSort.Date) =>
        unreadOnly || oldestFirst || sort != MessageSort.Date
            ? throw new NotSupportedException("Filtro \"Da leggere\" e ordine dal più vecchio richiedono la cache locale (Cache:Enabled=false).").WithCode("filtroDaLeggereOrdineDal")
            : connection.ReadAsync(s => s.GetHeadersAsync(folder, offset, limit, ct), ct);

    public Task<MessageDetail> GetMessageAsync(string folder, uint uid, CancellationToken ct = default) =>
        connection.ReadAsync(s => s.GetMessageAsync(folder, uid, ct), ct);

    public Task<MimeKit.MimeMessage> GetMimeMessageAsync(string folder, uint uid, CancellationToken ct = default) =>
        connection.ReadAsync(s => s.GetMimeMessageAsync(folder, uid, ct), ct);

    /// <summary>Byte originali con BODY.PEEK[] (E1): la mail non diventa letta.</summary>
    public Task<byte[]> GetRawAsync(string folder, uint uid, CancellationToken ct = default) =>
        connection.ReadAsync(async s =>
        {
            byte[] bytes = [];
            await s.ReadRawMessageAsync(folder, uid, async (stream, c) =>
            {
                using var copy = new MemoryStream();
                await stream.CopyToAsync(copy, c);
                bytes = copy.ToArray();
            }, ct);
            return bytes;
        }, ct);

    public Task<ComposeDraft> GetDraftAsync(string folder, uint uid, DraftMode mode, string ownAddress, CancellationToken ct = default) =>
        connection.ReadAsync(s => s.GetDraftAsync(folder, uid, mode, ownAddress, ct), ct);

    public Task<ComposeContent> GetComposeAsync(string folder, uint uid, CancellationToken ct = default) =>
        connection.ReadAsync(s => s.GetComposeAsync(folder, uid, ct), ct);

    public Task<Compose.MessageQuote> GetQuoteAsync(string folder, uint uid, DraftMode mode, CancellationToken ct = default) =>
        connection.ReadAsync(s => s.GetQuoteAsync(folder, uid, mode, ct), ct);

    public Task<IReadOnlyList<AttachmentContent>> GetAttachmentsAsync(string folder, uint uid, IReadOnlyList<int> indexes,
        CancellationToken ct = default) =>
        connection.ReadAsync(s => s.GetAttachmentsAsync(folder, uid, indexes, ct), ct);

    public Task<ConversationPage> GetConversationsAsync(string folder, int offset, int limit, bool unreadOnly = false,
        bool oldestFirst = false, CancellationToken ct = default) =>
        throw new NotSupportedException("Le conversazioni richiedono la cache locale (Cache:Enabled=false).").WithCode("leConversazioniRichiedonoLaCache");

    public Task<SearchResult> SearchAsync(string query, string? folder, int offset, int limit, CancellationToken ct = default) =>
        throw new NotSupportedException("La ricerca richiede la cache locale (Cache:Enabled=false).").WithCode("laRicercaRichiedeLaCache");

    public Task<SearchResult> SearchServerAsync(string query, string? folder, int offset, int limit, CancellationToken ct = default) =>
        throw new NotSupportedException("La ricerca richiede la cache locale (Cache:Enabled=false).").WithCode("laRicercaRichiedeLaCache");

    public Task<AttachmentContent> GetAttachmentAsync(string folder, uint uid, int index, CancellationToken ct = default) =>
        connection.ReadAsync(s => s.GetAttachmentAsync(folder, uid, index, ct), ct);
}
