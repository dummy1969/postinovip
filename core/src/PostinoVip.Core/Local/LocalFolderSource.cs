using MimeKit;
using MimeKit.Utils;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Local;

/// <summary>
/// Una cartella di <see cref="LocalMailStore"/> vista dalla sincronizzazione della copia locale, come se
/// fosse una cartella del server: gli UID sono i nomi dei file, intestazioni e anteprime vengono dal file.
/// I flag (letto, contrassegni, categorie) stanno solo nell'indice: i messaggi nuovi arrivano con quelli del
/// ruolo della cartella (Posta inviata e Bozze già lette), e <see cref="FetchFlagsAsync"/> non ne riporta
/// (l'indice resta com'è).
/// </summary>
public sealed class LocalFolderSource(LocalMailStore store, string fullName, LocalFolderInfo info) : IFolderSource
{
    public string FullName => fullName;
    public uint UidValidity => info.UidValidity;

    /// <summary>Flag di un messaggio appena comparso nella cartella.</summary>
    public static MailFlags InitialFlags(string? role) => role switch
    {
        "sent" => MailFlags.Seen,
        "drafts" => MailFlags.Seen | MailFlags.Draft,
        _ => MailFlags.None,
    };

    public Task<IReadOnlyList<uint>> GetUidsAsync(CancellationToken ct) => Task.FromResult(store.GetUids(fullName));

    public async Task<IReadOnlyList<HeaderRecord>> FetchHeadersAsync(IReadOnlyList<uint> uids, bool withPreview, CancellationToken ct)
    {
        var records = new List<HeaderRecord>();
        foreach (var uid in uids)
        {
            ct.ThrowIfCancellationRequested();
            if (await LoadAsync(uid, ct) is not var (message, size, modified))
                continue;
            var from = message.From.Mailboxes.FirstOrDefault();
            // Le mail locali si leggono intere: anteprima e allegati costano poco, si salvano sempre.
            var text = SearchText.From(message);
            records.Add(new HeaderRecord(
                uid,
                InitialFlags(info.Role),
                message.Subject,
                string.IsNullOrWhiteSpace(from?.Name) ? null : from.Name,
                from?.Address,
                MessageHeaderMapper.JoinAddresses(message.To),
                MessageHeaderMapper.JoinAddresses(message.Cc),
                message.Date == DateTimeOffset.MinValue ? null : message.Date,
                ArrivedAt(message) ?? modified,
                size,
                message.MessageId,
                message.InReplyTo,
                MessageHeaderMapper.CleanPreview(text.Body),
                text.HasAttachments,
                References: ConversationIds.Join(message.References),
                Importance: MailImportanceHeaders.From(message.Headers)));
        }
        return records;
    }

    public async Task<IReadOnlyList<PreviewRecord>> FetchPreviewsAsync(IReadOnlyList<uint> uids, CancellationToken ct)
    {
        var result = new List<PreviewRecord>();
        foreach (var uid in uids)
        {
            if (await LoadAsync(uid, ct) is var (message, _, _))
            {
                var text = SearchText.From(message);
                result.Add(new PreviewRecord(uid, MessageHeaderMapper.CleanPreview(text.Body), text.HasAttachments));
            }
        }
        return result;
    }

    public async Task<IReadOnlyList<(uint Uid, string References)>> FetchReferencesAsync(IReadOnlyList<uint> uids, CancellationToken ct)
    {
        var result = new List<(uint, string)>();
        foreach (var uid in uids)
        {
            if (await LoadAsync(uid, ct) is var (message, _, _))
                result.Add((uid, ConversationIds.Join(message.References)));
        }
        return result;
    }

    public async Task<IReadOnlyList<(uint Uid, MailImportance Importance)>> FetchImportanceAsync(IReadOnlyList<uint> uids, CancellationToken ct)
    {
        var result = new List<(uint, MailImportance)>();
        foreach (var uid in uids)
        {
            if (await LoadAsync(uid, ct) is var (message, _, _))
                result.Add((uid, MailImportanceHeaders.From(message.Headers)));
        }
        return result;
    }

    public Task<IReadOnlyList<(uint Uid, MailFlags Flags)>> FetchFlagsAsync(CancellationToken ct) =>
        Task.FromResult<IReadOnlyList<(uint, MailFlags)>>([]);

    public async Task ReadRawAsync(uint uid, Func<Stream, CancellationToken, Task> consume, CancellationToken ct)
    {
        await using var stream = store.OpenRead(fullName, uid);
        await consume(stream, ct);
    }

    /// <summary>Tutto è già nell'indice locale: non c'è un server in cui cercare.</summary>
    public Task<IReadOnlyList<uint>> SearchAsync(MailSearchQuery query, CancellationToken ct) =>
        Task.FromResult<IReadOnlyList<uint>>([]);

    public async Task<IReadOnlyDictionary<uint, bool>> FetchHasAttachmentsAsync(IReadOnlyList<uint> uids, CancellationToken ct)
    {
        var result = new Dictionary<uint, bool>();
        foreach (var uid in uids)
        {
            if (await LoadAsync(uid, ct) is var (message, _, _))
                result[uid] = SearchText.From(message).HasAttachments;
        }
        return result;
    }

    private async Task<(MimeMessage Message, long Size, DateTimeOffset Modified)?> LoadAsync(uint uid, CancellationToken ct)
    {
        try
        {
            await using var stream = store.OpenRead(fullName, uid);
            var message = await MimeMessage.LoadAsync(stream, ct);
            return (message, stream.Length, new DateTimeOffset(File.GetLastWriteTimeUtc(store.PathFor(fullName, uid)), TimeSpan.Zero));
        }
        catch (MailNotFoundException)
        {
            return null; // spostato o eliminato nel frattempo
        }
        catch (FormatException)
        {
            return null; // file non leggibile come mail: ignorato
        }
    }

    /// <summary>
    /// Arrivo sul server: la data del primo "Received" (aggiunto dall'ultimo server, quello della casella),
    /// altrimenti null (si usa la data del file). Serve a ordinare per arrivo anche le mail scaricate tutte
    /// insieme alla prima connessione POP3.
    /// </summary>
    public static DateTimeOffset? ArrivedAt(MimeMessage message)
    {
        var received = message.Headers[HeaderId.Received];
        if (received is null)
            return null;
        var semicolon = received.LastIndexOf(';');
        return semicolon >= 0 && DateUtils.TryParse(received[(semicolon + 1)..].Trim(), out var date) ? date : null;
    }
}
