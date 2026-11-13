using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using MimeKit;
using PostinoVip.Core;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Account;
using PostinoVip.Core.Models;

namespace PostinoVip.Api.Tests;

public static class FakeAccountsExtensions
{
    /// <summary>
    /// Sostituisce le caselle reali: gli account restano quelli della configurazione (id, indirizzo,
    /// stato), i servizi sono quelli finti restituiti da <paramref name="servicesFor"/> per ogni id.
    /// </summary>
    /// <param name="outboxRoot">Con una cartella: ogni account ha la sua Posta in uscita lì dentro (3.8).</param>
    public static void UseFakeAccounts(this IServiceCollection services,
        Func<string, (IMailReader Reader, IMailWriter Writer, IMailSender Sender)> servicesFor, string? outboxRoot = null)
    {
        services.RemoveAll<MailAccountRegistry>();
        services.AddSingleton(sp => new MailAccountRegistry(sp.GetRequiredService<IReadOnlyList<MailAccountSettings>>()
            .Select(a =>
            {
                var (reader, writer, sender) = servicesFor(a.Id);
                return new MailAccount(a, reader, writer, sender,
                    outbox: outboxRoot is null ? null : new PostinoVip.Core.Outbox.OutboxStore(Path.Combine(outboxRoot, a.Id)),
                    recent: outboxRoot is null ? null
                        : new PostinoVip.Core.Contacts.RecentAddresses(Path.Combine(outboxRoot, a.Id, "recent-addresses.json")));
            })
            .ToList()));
    }
}

/// <summary>IMailReader in memoria: registra gli argomenti ricevuti per verificarli nei test.</summary>
public sealed class FakeMailReader : IMailReader
{
    public (string Query, string? Folder, int Offset, int Limit)? LastSearchCall { get; private set; }

    public (string Query, string? Folder)? LastServerSearchCall { get; private set; }

    public Task<SearchResult> SearchServerAsync(string query, string? folder, int offset, int limit, CancellationToken ct = default)
    {
        LastServerSearchCall = (query, folder);
        return Task.FromResult(new SearchResult(1, offset, limit,
            [new SearchHit("Archivio", 9, "Vecchia", "Anna", null, true, null, true, FromServer: true)]));
    }

    public Task<SearchResult> SearchAsync(string query, string? folder, int offset, int limit, CancellationToken ct = default)
    {
        LastSearchCall = (query, folder, offset, limit);
        return Task.FromResult(new SearchResult(1, offset, limit,
            [new SearchHit("INBOX", 3, "Terza", "Mario", null, false, "la \u0002fattura\u0003 di ottobre", true)]));
    }

    public (string Folder, int Offset, int Limit)? LastHeadersCall { get; private set; }

    public (string Folder, int Offset, int Limit, bool Unread, bool OldestFirst)? LastConversationsCall { get; private set; }

    /// <summary>Una conversazione: risposta in INBOX (da leggere) alla mail in Posta inviata.</summary>
    public Task<ConversationPage> GetConversationsAsync(string folder, int offset, int limit, bool unreadOnly = false,
        bool oldestFirst = false, CancellationToken ct = default)
    {
        LastConversationsCall = (folder, offset, limit, unreadOnly, oldestFirst);
        ConversationMessage[] messages =
        [
            new(folder, new MessageHeader(5, "Re: Preventivo", "Anna", null, false, HasAttachments: true)),
            new("Posta inviata", new MessageHeader(2, "Preventivo", "Io", null, true)),
        ];
        return Task.FromResult(new ConversationPage(1, offset, limit, [new Conversation(42, 2, 1, true, messages)]));
    }

    public Task<IReadOnlyList<MailFolderInfo>> GetFoldersAsync(CancellationToken ct = default) =>
        Task.FromResult<IReadOnlyList<MailFolderInfo>>([new("INBOX", "INBOX", 3), new("INBOX/Sent", "Sent", 1)]);

    public (bool UnreadOnly, bool OldestFirst)? LastHeadersView { get; private set; }
    public MessageSort? LastHeadersSort { get; private set; }

    public Task<MessagePage> GetHeadersAsync(string folder, int offset, int limit, bool unreadOnly = false, bool oldestFirst = false,
        CancellationToken ct = default, MessageSort sort = MessageSort.Date)
    {
        LastHeadersCall = (folder, offset, limit);
        LastHeadersView = (unreadOnly, oldestFirst);
        LastHeadersSort = sort;
        if (folder == "SenzaRete")
            throw new MailOfflineException("Server non raggiungibile (SocketException: Connection refused).");
        if (folder == "Muto")
            throw new TimeoutException("Operation timed out after 10000 milliseconds");
        return Task.FromResult(new MessagePage(3, offset, limit,
            [new MessageHeader(3, "Terza", "Mario", null, false), new MessageHeader(2, "Seconda", "Anna", null, true)]));
    }

    public Task<MessageDetail> GetMessageAsync(string folder, uint uid, CancellationToken ct = default) =>
        uid == 3
            ? Task.FromResult(new MessageDetail(3, "Terza", "Mario", ["anna@example.com"], [], null, "ciao", null, false, []))
            : throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folder}'.");

    public (uint Uid, DraftMode Mode, string Own)? LastDraftCall { get; private set; }

    public Task<ComposeDraft> GetDraftAsync(string folder, uint uid, DraftMode mode, string ownAddress, CancellationToken ct = default)
    {
        LastDraftCall = (uid, mode, ownAddress);
        return Task.FromResult(new ComposeDraft(["mario@example.com"], [], "Re: Terza", "\n\n> ciao", "orig@example.com", ["orig@example.com"]));
    }

    public Task<ComposeContent> GetComposeAsync(string folder, uint uid, CancellationToken ct = default) =>
        uid == 3
            ? Task.FromResult(new ComposeContent(["mario@example.com"], [], "Bozza", "<p>ciao</p>", "", null, [], "<p>citato</p>", []))
            : throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folder}'.");

    public (string Folder, uint Uid, DraftMode Mode)? LastQuoteCall { get; private set; }

    public Task<PostinoVip.Core.Compose.MessageQuote> GetQuoteAsync(string folder, uint uid, DraftMode mode,
        CancellationToken ct = default)
    {
        LastQuoteCall = (folder, uid, mode);
        return Task.FromResult(new PostinoVip.Core.Compose.MessageQuote("\n\n> citato", "<p>citato</p>", []));
    }

    /// <summary>Byte «originali» restituiti da GET …/raw (E1), con a capo LF per vedere che non vengono riscritti.</summary>
    public static readonly byte[] Raw = "From: anna@example.com\nSubject: Originale\n\nCorpo\n"u8.ToArray();

    public List<(string Folder, uint Uid)> RawCalls { get; } = [];

    /// <summary>R1: uid 3 chiede la conferma di lettura (al mittente), uid 4 no.</summary>
    public Task<MimeMessage> GetMimeMessageAsync(string folder, uint uid, CancellationToken ct = default)
    {
        var dnt = uid == 3 ? "Disposition-Notification-To: Anna <anna@example.com>\r\n" : "";
        var text = $"From: Anna <anna@example.com>\r\nTo: me@example.com\r\nSubject: Riunione\r\nMessage-ID: <riunione@example.com>\r\n{dnt}\r\nCiao\r\n";
        return uid is 3 or 4
            ? Task.FromResult(MimeMessage.Load(new MemoryStream(System.Text.Encoding.UTF8.GetBytes(text))))
            : throw new MailNotFoundException($"Messaggio {uid} non trovato.");
    }

    public Task<byte[]> GetRawAsync(string folder, uint uid, CancellationToken ct = default)
    {
        RawCalls.Add((folder, uid));
        return uid == 3 ? Task.FromResult(Raw) : throw new MailNotFoundException($"Messaggio {uid} non trovato.");
    }

    public List<(string Folder, uint Uid, IReadOnlyList<int> Indexes)> AttachmentBatchCalls { get; } = [];

    public Task<IReadOnlyList<AttachmentContent>> GetAttachmentsAsync(string folder, uint uid, IReadOnlyList<int> indexes,
        CancellationToken ct = default)
    {
        AttachmentBatchCalls.Add((folder, uid, indexes));
        return Task.FromResult<IReadOnlyList<AttachmentContent>>(
            indexes.Select(i => new AttachmentContent($"originale{i}.pdf", "application/pdf", [(byte)i])).ToList());
    }

    public Task<AttachmentContent> GetAttachmentAsync(string folder, uint uid, int index, CancellationToken ct = default) =>
        uid == 3 && index == 0
            ? Task.FromResult(new AttachmentContent("foto.jpg", "image/jpeg", [0xFF, 0xD8, 0xFF]))
            : throw new MailNotFoundException($"Allegato {index} non trovato nel messaggio {uid}.");
}

/// <summary>IMailWriter in memoria: registra le modifiche richieste.</summary>
public sealed class FakeMailWriter : IMailWriter
{
    public List<(string Folder, uint Uid, bool Seen)> SeenCalls { get; } = [];
    public List<MimeMessage> Appended { get; } = [];

    /// <summary>Bozze salvate (messaggio, UID sostituito) ed eliminate (3.8).</summary>
    public List<(MimeMessage Message, uint? Replaced)> Drafts { get; } = [];
    public List<uint> DeletedDrafts { get; } = [];

    /// <summary>Se impostato, le operazioni sulle bozze falliscono con questa eccezione (es. MailOfflineException).</summary>
    public Exception? DraftFailure { get; set; }
    private uint _nextDraftUid = 100;

    public Task<DraftSaved> SaveDraftAsync(MimeMessage message, uint? replaceUid, CancellationToken ct = default)
    {
        if (DraftFailure is not null)
            throw DraftFailure;
        Drafts.Add((message, replaceUid));
        return Task.FromResult(new DraftSaved("Bozze", _nextDraftUid++));
    }

    public Task DeleteDraftAsync(uint uid, CancellationToken ct = default)
    {
        if (DraftFailure is not null)
            throw DraftFailure;
        DeletedDrafts.Add(uid);
        return Task.CompletedTask;
    }

    /// <summary>Se impostato, AppendToSentAsync fallisce con questa eccezione.</summary>
    public Exception? AppendFailure { get; set; }

    public const string Trash = "Posta eliminata";

    /// <summary>Flag correnti per (cartella, UID) e modifiche richieste (aggiunti, tolti).</summary>
    public Dictionary<(string, uint), MailFlags> Flags { get; } = [];
    public List<(string Folder, uint Uid, MailFlags Add, MailFlags Remove)> FlagCalls { get; } = [];

    public Task<MailFlags> UpdateFlagsAsync(string folder, uint uid, MailFlags add, MailFlags remove, CancellationToken ct = default)
    {
        if (uid == 999)
            throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folder}'.");
        FlagCalls.Add((folder, uid, add, remove));
        var flags = (Flags.GetValueOrDefault((folder, uid)) | add) & ~remove;
        Flags[(folder, uid)] = flags;
        return Task.FromResult(flags);
    }

    public List<(string From, uint Uid, string To)> Moves { get; } = [];
    public List<(string Folder, uint Uid)> PermanentDeletes { get; } = [];

    // Stesse regole del servizio reale (ImapMailService).
    public Task<string> MoveAsync(string folder, uint uid, string destination, CancellationToken ct = default)
    {
        if (folder.Equals(destination, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Cartella di origine e destinazione coincidono.");
        if (destination == "Inesistente")
            throw new MailNotFoundException("Cartella 'Inesistente' non trovata.");
        Moves.Add((folder, uid, destination));
        return Task.FromResult(destination);
    }

    public Task<string> MoveToTrashAsync(string folder, uint uid, CancellationToken ct = default)
    {
        if (folder == Trash)
            throw new InvalidOperationException("Il messaggio è già in Posta eliminata: usare l'eliminazione definitiva.");
        Moves.Add((folder, uid, Trash));
        return Task.FromResult(Trash);
    }

    public Task DeletePermanentlyAsync(string folder, uint uid, CancellationToken ct = default)
    {
        if (folder != Trash)
            throw new InvalidOperationException("L'eliminazione definitiva è consentita solo in Posta eliminata.");
        PermanentDeletes.Add((folder, uid));
        return Task.CompletedTask;
    }

    public Task<string> AppendToSentAsync(MimeMessage message, CancellationToken ct = default)
    {
        if (AppendFailure is not null)
            throw AppendFailure;
        Appended.Add(message);
        return Task.FromResult("Posta inviata");
    }

    // In blocco: gli UID 1–9 "esistono", gli altri vengono ignorati come farebbe il server.
    private static List<uint> Existing(IReadOnlyCollection<uint> uids) => uids.Where(u => u is >= 1 and <= 9).Order().ToList();

    public List<(string Folder, uint[] Uids, bool Seen)> SeenBatches { get; } = [];
    public List<(string Folder, uint[] Uids, MailFlags Add, MailFlags Remove)> FlagBatches { get; } = [];
    public List<(string From, uint[] Uids, string To)> MoveBatches { get; } = [];
    public List<(string Folder, uint[] Uids)> PermanentBatches { get; } = [];

    public Task<IReadOnlyDictionary<uint, bool>> SetSeenAsync(string folder, IReadOnlyCollection<uint> uids, bool seen,
        CancellationToken ct = default)
    {
        var found = Existing(uids);
        SeenBatches.Add((folder, found.ToArray(), seen));
        return Task.FromResult<IReadOnlyDictionary<uint, bool>>(found.ToDictionary(u => u, _ => seen));
    }

    public Task<IReadOnlyDictionary<uint, MailFlags>> UpdateFlagsAsync(string folder, IReadOnlyCollection<uint> uids,
        MailFlags add, MailFlags remove, CancellationToken ct = default)
    {
        var found = Existing(uids);
        FlagBatches.Add((folder, found.ToArray(), add, remove));
        var result = new Dictionary<uint, MailFlags>();
        foreach (var uid in found)
            result[uid] = Flags[(folder, uid)] = (Flags.GetValueOrDefault((folder, uid)) | add) & ~remove;
        return Task.FromResult<IReadOnlyDictionary<uint, MailFlags>>(result);
    }

    public Task<BatchResult> MoveAsync(string folder, IReadOnlyCollection<uint> uids, string destination, CancellationToken ct = default)
    {
        if (folder.Equals(destination, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Cartella di origine e destinazione coincidono.");
        var found = Existing(uids);
        MoveBatches.Add((folder, found.ToArray(), destination));
        return Task.FromResult(new BatchResult(destination, found));
    }

    public Task<BatchResult> MoveToTrashAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default)
    {
        if (folder == Trash)
            throw new InvalidOperationException("Il messaggio è già in Posta eliminata: usare l'eliminazione definitiva.");
        var found = Existing(uids);
        MoveBatches.Add((folder, found.ToArray(), Trash));
        return Task.FromResult(new BatchResult(Trash, found));
    }

    public Task<BatchResult> DeletePermanentlyAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default)
    {
        if (folder != Trash)
            throw new InvalidOperationException("L'eliminazione definitiva è consentita solo in Posta eliminata.");
        var found = Existing(uids);
        PermanentBatches.Add((folder, found.ToArray()));
        return Task.FromResult(new BatchResult(null, found));
    }

    public List<(string From, uint[] Uids, string To)> CopyBatches { get; } = [];

    public Task<BatchResult> CopyAsync(string folder, IReadOnlyCollection<uint> uids, string destination, CancellationToken ct = default)
    {
        if (folder.Equals(destination, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Cartella di origine e destinazione coincidono.");
        var found = Existing(uids);
        CopyBatches.Add((folder, found.ToArray(), destination));
        return Task.FromResult(new BatchResult(destination, found));
    }

    /// <summary>Cartelle spostate (vecchio nome, nuovo nome).</summary>
    public List<(string From, string To)> MovedFolders { get; } = [];

    // Regole del servizio reale: "Esistente" è già usato in ogni cartella madre tranne Posta eliminata.
    public Task<FolderChange> MoveFolderAsync(string folder, string? newParent, CancellationToken ct = default)
    {
        RequireOrdinary(folder);
        if (newParent == "Inesistente")
            throw new MailNotFoundException("Cartella 'Inesistente' non trovata.");
        if (newParent is not null && (newParent == folder || newParent.StartsWith(folder + "/", StringComparison.Ordinal)))
            throw new InvalidOperationException($"'{folder}' non può andare dentro sé stessa o una sua sottocartella.");
        var leaf = folder[(folder.LastIndexOf('/') + 1)..];
        if (leaf == "Esistente" && newParent != Trash)
            throw new FieldValidationException("parent", $"Esiste già una cartella \"{leaf}\" qui.");
        var to = newParent is null ? leaf : $"{newParent}/{(newParent == Trash && leaf == "Esistente" ? leaf + " (2)" : leaf)}";
        MovedFolders.Add((folder, to));
        return Task.FromResult(new FolderChange(to, '/'));
    }

    /// <summary>Cartelle create, rinominate (vecchio, nuovo) ed eliminate (nome, spostata in).</summary>
    public List<(string? Parent, string Name)> CreatedFolders { get; } = [];
    public List<(string From, string To)> RenamedFolders { get; } = [];
    public List<(string Folder, string? MovedTo)> DeletedFolders { get; } = [];

    // Regole essenziali del servizio reale: nomi validati, "INBOX" e Posta eliminata intoccabili.
    public Task<FolderChange> CreateFolderAsync(string? parent, string name, CancellationToken ct = default)
    {
        var clean = FolderNames.Validate(name, '/', topLevel: parent is null);
        if (clean == "Esistente")
            throw new FieldValidationException("name", $"Esiste già una cartella \"{clean}\" qui.");
        CreatedFolders.Add((parent, clean));
        return Task.FromResult(new FolderChange(parent is null ? clean : $"{parent}/{clean}", '/'));
    }

    public Task<FolderChange> RenameFolderAsync(string folder, string newName, CancellationToken ct = default)
    {
        RequireOrdinary(folder);
        var cut = folder.LastIndexOf('/');
        var clean = FolderNames.Validate(newName, '/', topLevel: cut < 0);
        var to = cut < 0 ? clean : $"{folder[..cut]}/{clean}";
        RenamedFolders.Add((folder, to));
        return Task.FromResult(new FolderChange(to, '/'));
    }

    public List<(string Folder, bool Subfolders)> EmptiedFolders { get; } = [];

    public Task<FolderEmptied> EmptyFolderAsync(string folder, bool subfolders, CancellationToken ct = default)
    {
        EmptiedFolders.Add((folder, subfolders));
        return Task.FromResult(new FolderEmptied(2, subfolders ? [$"{folder}/Vecchia"] : [], '/'));
    }

    public Task<FolderDeletion> DeleteFolderAsync(string folder, CancellationToken ct = default)
    {
        RequireOrdinary(folder);
        if (folder.StartsWith(Trash + "/", StringComparison.Ordinal))
        {
            DeletedFolders.Add((folder, null));
            return Task.FromResult(new FolderDeletion(null, true, '/'));
        }
        var to = $"{Trash}/{folder[(folder.LastIndexOf('/') + 1)..]}";
        DeletedFolders.Add((folder, to));
        return Task.FromResult(new FolderDeletion(to, false, '/'));
    }

    private static void RequireOrdinary(string folder)
    {
        if (folder is "INBOX" or Trash)
            throw new InvalidOperationException($"'{folder}' è una cartella speciale: non si può rinominare né eliminare.");
        if (folder == "Inesistente")
            throw new MailNotFoundException("Cartella 'Inesistente' non trovata.");
    }

    public Task<bool> SetSeenAsync(string folder, uint uid, bool seen, CancellationToken ct = default)
    {
        if (uid != 3)
            throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folder}'.");
        SeenCalls.Add((folder, uid, seen));
        return Task.FromResult(seen);
    }
}

public sealed class FakeMailSender : IMailSender
{
    public List<OutgoingMessage> Sent { get; } = [];

    public List<MimeMessage> SentMime { get; } = [];

    /// <summary>Se impostato, l'invio fallisce con questa eccezione (es. MailOfflineException: Posta in uscita).</summary>
    public Exception? Failure { get; set; }

    public Task<SendResult> SendAsync(OutgoingMessage msg, CancellationToken ct = default)
    {
        // Stessa costruzione (e validazione degli indirizzi) del servizio reale.
        var mime = PostinoVip.Core.Smtp.MimeMessageBuilder.Build(msg);
        Record(mime);
        return Task.FromResult(new SendResult("250 OK test", mime));
    }

    public Task<string> SendMimeAsync(MimeMessage message, CancellationToken ct = default)
    {
        if (Failure is not null)
            throw Failure;
        Record(message);
        return Task.FromResult("250 OK test");
    }

    // Dati principali come li ha costruiti il core, per i controlli dei test.
    private void Record(MimeMessage m)
    {
        SentMime.Add(m);
        Sent.Add(new OutgoingMessage(m.From.Mailboxes.First().Address, m.To.Mailboxes.Select(a => a.Address).ToList(),
            m.Cc.Mailboxes.Select(a => a.Address).ToList(), m.Subject ?? "", m.TextBody ?? "",
            string.IsNullOrEmpty(m.InReplyTo) ? null : m.InReplyTo, m.References.ToList(),
            m.Attachments.OfType<MimePart>().Select(p =>
            {
                using var ms = new MemoryStream();
                p.Content!.DecodeTo(ms);
                return new OutgoingAttachment(p.FileName ?? "", p.ContentType.MimeType, ms.ToArray());
            }).ToList()));
    }
}
