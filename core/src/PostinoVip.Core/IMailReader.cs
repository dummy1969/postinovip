using PostinoVip.Core.Models;

namespace PostinoVip.Core;

/// <summary>Lettura della casella (sempre in sola lettura).</summary>
public interface IMailReader
{
    Task<IReadOnlyList<MailFolderInfo>> GetFoldersAsync(CancellationToken ct = default);

    /// <summary>Intestazioni dalla più recente: offset 0 = ultimo messaggio arrivato.</summary>
    /// <param name="unreadOnly">Solo i messaggi da leggere (filtro "Da leggere" di Outlook).</param>
    /// <param name="oldestFirst">In ordine crescente (dal più vecchio, A→Z, dal più piccolo). Filtro e ordine richiedono la cache locale.</param>
    /// <param name="sort">Colonna dell'ordinamento (3.9); diversa dalla data richiede la cache locale.</param>
    Task<MessagePage> GetHeadersAsync(string folder, int offset, int limit, bool unreadOnly = false, bool oldestFirst = false,
        CancellationToken ct = default, MessageSort sort = MessageSort.Date);

    /// <summary>
    /// Conversazioni della cartella dalla più recente (3.6), con le mail anche delle altre cartelle
    /// dell'account (tranne Posta eliminata e Indesiderata). Richiede la cache: senza, NotSupportedException.
    /// </summary>
    Task<ConversationPage> GetConversationsAsync(string folder, int offset, int limit, bool unreadOnly = false,
        bool oldestFirst = false, CancellationToken ct = default);

    Task<MessageDetail> GetMessageAsync(string folder, uint uid, CancellationToken ct = default);

    /// <summary>
    /// Il messaggio così com'è (per le regole, R1), dalla copia locale o con BODY.PEEK: non diventa letto.
    /// Senza copia locale non serve: NotSupportedException.
    /// </summary>
    Task<MimeKit.MimeMessage> GetMimeMessageAsync(string folder, uint uid, CancellationToken ct = default) =>
        throw new NotSupportedException("Il messaggio originale è disponibile solo con la copia locale.").WithCode("ilMessaggioOriginaleDisponibileSolo");

    /// <summary>
    /// I byte originali del messaggio (E1, «Salva con nome» .eml): dalla copia locale se c'è, altrimenti con
    /// BODY.PEEK[] (non diventa letto). Di serie: il messaggio riscritto da MimeKit (con gli a capo CRLF).
    /// </summary>
    async Task<byte[]> GetRawAsync(string folder, uint uid, CancellationToken ct = default)
    {
        var message = await GetMimeMessageAsync(folder, uid, ct);
        using var stream = new MemoryStream();
        await message.WriteToAsync(new MimeKit.FormatOptions { NewLineFormat = MimeKit.NewLineFormat.Dos }, stream, ct);
        return stream.ToArray();
    }

    /// <summary>Bozza di risposta / rispondi a tutti / inoltro del messaggio indicato.</summary>
    Task<ComposeDraft> GetDraftAsync(string folder, uint uid, DraftMode mode, string ownAddress, CancellationToken ct = default);

    /// <summary>Bozza da riaprire nella composizione (3.8).</summary>
    Task<ComposeContent> GetComposeAsync(string folder, uint uid, CancellationToken ct = default);

    /// <summary>Citazione dell'originale per l'invio di una risposta o di un inoltro formattati (3.7b).</summary>
    Task<Compose.MessageQuote> GetQuoteAsync(string folder, uint uid, DraftMode mode, CancellationToken ct = default);

    /// <summary>Allegato numero <paramref name="index"/> (vedi AttachmentInfo.Index).</summary>
    Task<AttachmentContent> GetAttachmentAsync(string folder, uint uid, int index, CancellationToken ct = default);

    /// <summary>
    /// Ricerca nella cache locale (sintassi: <see cref="Cache.MailSearchQuery"/>) in tutta la casella o
    /// nella cartella indicata. Senza cache: NotSupportedException.
    /// </summary>
    Task<SearchResult> SearchAsync(string query, string? folder, int offset, int limit, CancellationToken ct = default);

    /// <summary>
    /// Ricerca sul server (IMAP SEARCH) per le mail il cui corpo non è nella cache locale; in tutte le
    /// cartelle o solo in quella indicata. Risultati con FromServer = true. Senza cache: NotSupportedException.
    /// </summary>
    Task<SearchResult> SearchServerAsync(string query, string? folder, int offset, int limit, CancellationToken ct = default);

    /// <summary>Più allegati dello stesso messaggio con una sola lettura (es. per l'inoltro).</summary>
    Task<IReadOnlyList<AttachmentContent>> GetAttachmentsAsync(string folder, uint uid, IReadOnlyList<int> indexes,
        CancellationToken ct = default);
}
