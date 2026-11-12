using MailKit;
using MailKit.Net.Imap;
using MailKit.Security;
using MimeKit;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Mime;
using PostinoVip.Core.Models;
using PostinoVip.Core.Security;

namespace PostinoVip.Core.Imap;

/// <summary>
/// Sessione IMAP. Le letture aprono le cartelle con EXAMINE (FolderAccess.ReadOnly), scaricano solo
/// ENVELOPE/FLAGS e leggono il messaggio con BODY.PEEK[]: nessun flag viene modificato.
/// Le operazioni di scrittura (sezione dedicata in fondo) aprono la cartella in ReadWrite solo per sé
/// e la chiudono sempre senza EXPUNGE.
/// </summary>
public sealed class ImapMailService : IMailboxSource, IAsyncDisposable
{
    private readonly ImapSettings _settings;
    private readonly ImapClient _client = new();

    /// <param name="operationTimeout">
    /// Tempo massimo di ogni lettura/scrittura sulla rete (null = quello di MailKit, 2 minuti). Con la rete
    /// staccata a connessione aperta il server semplicemente tace: senza un limite breve un comando resta
    /// fermo 2 minuti. Allo scadere MailKit lancia TimeoutException e chiude la connessione.
    /// Non va usato per l'IDLE, in cui il server tace legittimamente per minuti.
    /// </param>
    public ImapMailService(ImapSettings settings, TimeSpan? operationTimeout = null)
    {
        if (string.IsNullOrWhiteSpace(settings.Host))
            throw new ArgumentException("Host IMAP non configurato.", nameof(settings));
        if (string.IsNullOrWhiteSpace(settings.Username) || (string.IsNullOrEmpty(settings.Password) && settings.AccessToken is null))
            throw new ArgumentException("Credenziali IMAP mancanti (Imap:Username / Imap:Password).", nameof(settings));

        _settings = settings;
        if (operationTimeout is { } timeout)
            _client.Timeout = (int)timeout.TotalMilliseconds;
    }

    public async Task ConnectAsync(CancellationToken ct = default)
    {
        // Crittografia scelta per l'account (4.1). Certificato: validazione di sistema, più al massimo
        // il certificato di cui l'utente ha scelto di fidarsi (TrustedCertificate).
        var trust = new TrustedCertificate(_settings.Host, _settings.Port, _settings.CertificateSha256);
        _client.ServerCertificateValidationCallback = trust.Validate;
        try
        {
            await _client.ConnectAsync(_settings.Host, _settings.Port, _settings.EffectiveSecurity.ToMailKit(), ct);
        }
        catch (SslHandshakeException ex) when (trust.Rejected is { } rejected)
        {
            throw new UntrustedCertificateException(rejected, ex);
        }
        await OAuth.MailAuth.AuthenticateAsync(_client, _settings.Username, _settings.Password, _settings.AccessToken, ct);
    }

    /// <summary>Connessione aperta e autenticata.</summary>
    public bool IsAlive => _client.IsConnected && _client.IsAuthenticated;

    /// <summary>NOOP: verifica che la connessione sia ancora viva (e la tiene attiva).</summary>
    public Task PingAsync(CancellationToken ct = default) => _client.NoOpAsync(ct);

    public async Task<IReadOnlyList<MailFolderInfo>> GetFoldersAsync(CancellationToken ct = default)
    {
        var personal = _client.PersonalNamespaces[0];
        // Numero di messaggi e di non letti nello stesso STATUS (MESSAGES UNSEEN).
        var folders = await _client.GetFoldersAsync(personal, StatusItems.Count | StatusItems.Unread, subscribedOnly: false, ct);

        return folders
            .Where(f => f.Exists)
            .Select(f => new MailFolderInfo(f.FullName, f.Name, f.Count, SpecialUse.FromAttributes(f.Attributes, f.FullName), f.Unread))
            .OrderBy(f => f.FullName, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    public async Task<MessagePage> GetHeadersAsync(string folderName, int offset, int limit, CancellationToken ct = default)
    {
        var folder = await OpenAsync(folderName, FolderAccess.ReadOnly, ct);
        try
        {
            var range = PageRange.Compute(folder.Count, offset, limit);
            if (range is null)
                return new MessagePage(folder.Count, offset, limit, []);

            var request = new FetchRequest(MessageSummaryItems.UniqueId | MessageSummaryItems.Envelope | MessageSummaryItems.Flags);
            var summaries = await folder.FetchAsync(range.Value.First, range.Value.Last, request, ct);

            // Più recenti in cima.
            var items = summaries
                .OrderByDescending(s => s.Index)
                .Select(s => MessageHeaderMapper.FromEnvelope(s.UniqueId, s.Envelope, s.Flags, s.Keywords))
                .ToList();

            return new MessagePage(folder.Count, offset, limit, items);
        }
        finally
        {
            await folder.CloseAsync(expunge: false, ct);
        }
    }

    public async Task<MessageDetail> GetMessageAsync(string folderName, uint uid, CancellationToken ct = default)
    {
        var message = await LoadMessageAsync(folderName, uid, ct);
        return MessageHeaderMapper.FromMimeMessage(new UniqueId(uid), message);
    }

    public async Task<ComposeDraft> GetDraftAsync(string folderName, uint uid, DraftMode mode, string ownAddress, CancellationToken ct = default)
    {
        var message = await LoadMessageAsync(folderName, uid, ct);
        return DraftBuilder.Build(message, mode, ownAddress);
    }

    public async Task<ComposeContent> GetComposeAsync(string folderName, uint uid, CancellationToken ct = default) =>
        ComposeReader.Read(await LoadMessageAsync(folderName, uid, ct));

    public async Task<MessageQuote> GetQuoteAsync(string folderName, uint uid, DraftMode mode, CancellationToken ct = default) =>
        QuoteBuilder.ForSending(await LoadMessageAsync(folderName, uid, ct), mode);

    public async Task<AttachmentContent> GetAttachmentAsync(string folderName, uint uid, int index, CancellationToken ct = default)
    {
        // Scarica di nuovo tutto il messaggio: semplice, da ottimizzare (BODYSTRUCTURE + singola parte) con la cache.
        var message = await LoadMessageAsync(folderName, uid, ct);
        return Attachments.Extract(message, index)
            ?? throw new MailNotFoundException($"Allegato {index} non trovato nel messaggio {uid}.");
    }

    public async Task<IReadOnlyList<AttachmentContent>> GetAttachmentsAsync(string folderName, uint uid, IReadOnlyList<int> indexes,
        CancellationToken ct = default)
    {
        var message = await LoadMessageAsync(folderName, uid, ct);
        return indexes
            .Select(i => Attachments.Extract(message, i)
                ?? throw new MailNotFoundException($"Allegato {i} non trovato nel messaggio {uid}."))
            .ToList();
    }

    /// <summary>Il messaggio così com'è, con BODY.PEEK (R1: conferma di lettura senza copia locale).</summary>
    public Task<MimeMessage> GetMimeMessageAsync(string folderName, uint uid, CancellationToken ct = default) =>
        LoadMessageAsync(folderName, uid, ct);

    private async Task<MimeMessage> LoadMessageAsync(string folderName, uint uid, CancellationToken ct)
    {
        var folder = await OpenAsync(folderName, FolderAccess.ReadOnly, ct);
        try
        {
            // GetMessageAsync usa UID FETCH ... BODY.PEEK[]: non imposta \Seen.
            return await folder.GetMessageAsync(new UniqueId(uid), ct);
        }
        catch (MessageNotFoundException ex)
        {
            throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folderName}'.", ex);
        }
        finally
        {
            await folder.CloseAsync(expunge: false, ct);
        }
    }

    /// <summary>
    /// Il messaggio così come sta sul server (byte originali, per la cache), passato a <paramref name="consume"/>.
    /// </summary>
    public async Task ReadRawMessageAsync(string folderName, uint uid, Func<Stream, CancellationToken, Task> consume,
        CancellationToken ct = default)
    {
        var folder = await OpenAsync(folderName, FolderAccess.ReadOnly, ct);
        try
        {
            // UID FETCH ... BODY.PEEK[]: non imposta \Seen.
            await using var stream = await folder.GetStreamAsync(new UniqueId(uid), ct);
            await consume(stream, ct);
        }
        catch (MessageNotFoundException ex)
        {
            throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folderName}'.", ex);
        }
        finally
        {
            await folder.CloseAsync(expunge: false, ct);
        }
    }

    /// <summary>
    /// Apre la cartella in sola lettura (EXAMINE) per la durata di <paramref name="action"/>, che la
    /// vede come IFolderSource (sincronizzazione della cache).
    /// </summary>
    public async Task<T> ExamineAsync<T>(string folderName, Func<IFolderSource, Task<T>> action, CancellationToken ct = default)
    {
        var folder = await OpenAsync(folderName, FolderAccess.ReadOnly, ct);
        try
        {
            return await action(new ImapFolderSource(folder));
        }
        finally
        {
            await folder.CloseAsync(expunge: false, ct);
        }
    }

    /// <summary>Estensioni utili alla cache annunciate dal server dopo il login (diagnostica).</summary>
    public string CacheCapabilities
    {
        get
        {
            var caps = _client.Capabilities;
            string YesNo(ImapCapabilities c) => caps.HasFlag(c) ? "sì" : "no";
            return $"CONDSTORE {YesNo(ImapCapabilities.CondStore)}, QRESYNC {YesNo(ImapCapabilities.QuickResync)}, " +
                   $"ESEARCH {YesNo(ImapCapabilities.ESearch)}, IDLE {YesNo(ImapCapabilities.Idle)}";
        }
    }

    private async Task<IMailFolder> OpenAsync(string folderName, FolderAccess access, CancellationToken ct)
    {
        var folder = await GetFolderAsync(folderName, ct);
        await folder.OpenAsync(access, ct);
        return folder;
    }

    /// <summary>
    /// Tiene INBOX aperta in sola lettura e attende cambiamenti con IDLE (RFC 2177), rinnovato ogni
    /// <paramref name="idleRenew"/>; senza IDLE fa un NOOP ogni <paramref name="pollInterval"/>.
    /// <paramref name="onChanged"/> riceve il nuovo numero di messaggi: va tenuto rapido, perché
    /// viene chiamato mentre MailKit legge le risposte del server.
    /// Ritorna solo per cancellazione; un errore di connessione si propaga al chiamante.
    /// </summary>
    public async Task WatchInboxAsync(Action<int> onChanged, TimeSpan idleRenew, TimeSpan pollInterval, CancellationToken ct)
    {
        var inbox = _client.Inbox;
        await inbox.OpenAsync(FolderAccess.ReadOnly, ct);

        void Notify(object? sender, EventArgs e) => onChanged(inbox.Count);
        inbox.CountChanged += Notify;          // EXISTS: nuova posta (o conteggio cambiato)
        inbox.MessageExpunged += Notify;       // EXPUNGE: messaggio rimosso (anche da altri client)
        inbox.MessageFlagsChanged += Notify;   // FETCH FLAGS: es. letto da un altro client
        try
        {
            var useIdle = _client.Capabilities.HasFlag(ImapCapabilities.Idle);
            while (!ct.IsCancellationRequested)
            {
                if (useIdle)
                {
                    // "done" chiude l'IDLE allo scadere del rinnovo; ct interrompe tutto.
                    using var done = new CancellationTokenSource(idleRenew);
                    await _client.IdleAsync(done.Token, ct);
                }
                else
                {
                    await Task.Delay(pollInterval, ct);
                    await _client.NoOpAsync(ct);
                }
            }
        }
        finally
        {
            inbox.CountChanged -= Notify;
            inbox.MessageExpunged -= Notify;
            inbox.MessageFlagsChanged -= Notify;
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Scrittura: ogni metodo modifica la casella e va usato solo dopo una scelta esplicita dell'utente.
    // ---------------------------------------------------------------------------------------------

    /// <summary>Flag che <see cref="UpdateFlagsAsync"/> può cambiare.</summary>
    public const MailFlags EditableFlags =
        MailFlags.Flagged | MailFlags.Completed | MailFlags.Categories | MailFlags.MdnSent | MailFlags.Junk | MailFlags.NotJunk;

    /// <summary>
    /// Contrassegno, "completato" e categorie su una o più mail: STORE +FLAGS e -FLAGS (\Flagged e parole
    /// chiave) sull'insieme degli UID, poi rilettura. Il server deve accettare parole chiave nuove (\* in
    /// PERMANENTFLAGS) o già conoscerle; altrimenti nessuna modifica e NotSupportedException.
    /// </summary>
    /// <returns>I flag letti dal server dopo la modifica, solo per le mail trovate.</returns>
    public async Task<IReadOnlyDictionary<uint, MailFlags>> UpdateFlagsAsync(string folderName, IReadOnlyCollection<uint> uids,
        MailFlags add, MailFlags remove, CancellationToken ct = default)
    {
        if (((add | remove) & ~EditableFlags) != 0)
            throw new ArgumentException("Solo contrassegno, completato, categorie, $MDNSent e posta indesiderata si possono cambiare qui.");
        var folder = await OpenAsync(folderName, FolderAccess.ReadWrite, ct);
        try
        {
            var keywords = MailKeywords.ToKeywords(add | remove).ToList();
            var userDefined = folder.PermanentFlags.HasFlag(MessageFlags.UserDefined);
            var unknown = keywords.Where(k => !userDefined && !folder.PermanentKeywords.Contains(k)).ToList();
            if (unknown.Count > 0)
                throw new NotSupportedException($"Il server non permette di salvare le parole chiave {string.Join(", ", unknown)} in '{folderName}'.");

            var ids = ToIds(uids);
            foreach (var (action, flags) in new[] { (StoreAction.Add, add), (StoreAction.Remove, remove) })
            {
                if (flags == MailFlags.None)
                    continue;
                var system = flags.HasFlag(MailFlags.Flagged) ? MessageFlags.Flagged : MessageFlags.None;
                var request = new StoreFlagsRequest(action, system, MailKeywords.ToKeywords(flags).ToHashSet()) { Silent = true };
                await folder.StoreAsync(ids, request, ct);
            }

            // Rilettura: conferma la modifica e rileva gli UID inesistenti (STORE su UID assente non dà errore).
            var summaries = await folder.FetchAsync(ids, new FetchRequest(MessageSummaryItems.UniqueId | MessageSummaryItems.Flags), ct);
            return summaries.ToDictionary(m => m.UniqueId.Id, m => MessageHeaderMapper.ToMailFlags(m.Flags, m.Keywords));
        }
        finally
        {
            await folder.CloseAsync(expunge: false, ct);
        }
    }

    public async Task<MailFlags> UpdateFlagsAsync(string folderName, uint uid, MailFlags add, MailFlags remove,
        CancellationToken ct = default) =>
        (await UpdateFlagsAsync(folderName, [uid], add, remove, ct)).TryGetValue(uid, out var flags)
            ? flags
            : throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folderName}'.");

    /// <summary>Imposta o toglie \Seen su una o più mail; restituisce lo stato letto dal server, solo per le mail trovate.</summary>
    public async Task<IReadOnlyDictionary<uint, bool>> SetSeenAsync(string folderName, IReadOnlyCollection<uint> uids, bool seen,
        CancellationToken ct = default)
    {
        var folder = await OpenAsync(folderName, FolderAccess.ReadWrite, ct);
        try
        {
            var ids = ToIds(uids);
            var request = new StoreFlagsRequest(seen ? StoreAction.Add : StoreAction.Remove, MessageFlags.Seen) { Silent = true };
            await folder.StoreAsync(ids, request, ct);

            // Rilettura dei flag: conferma la modifica e rileva UID inesistenti (STORE su UID assente non dà errore).
            var summaries = await folder.FetchAsync(ids, new FetchRequest(MessageSummaryItems.UniqueId | MessageSummaryItems.Flags), ct);
            return summaries.ToDictionary(m => m.UniqueId.Id, m => m.Flags?.HasFlag(MessageFlags.Seen) ?? false);
        }
        finally
        {
            // expunge: false -> nessun messaggio con \Deleted viene rimosso.
            await folder.CloseAsync(expunge: false, ct);
        }
    }

    public async Task<bool> SetSeenAsync(string folderName, uint uid, bool seen, CancellationToken ct = default) =>
        (await SetSeenAsync(folderName, [uid], seen, ct)).TryGetValue(uid, out var result)
            ? result
            : throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folderName}'.");

    /// <summary>APPEND nella cartella con ruolo \Sent (scelta per ruolo, mai per nome).</summary>
    public async Task<string> AppendToSentAsync(MimeMessage message, CancellationToken ct = default)
    {
        var sent = await FindSpecialAsync(FolderAttributes.Sent, ct)
            ?? throw new MailNotFoundException("Il server non dichiara una cartella \\Sent (Posta inviata): copia non salvata.");

        // APPEND non richiede di aprire la cartella; \Seen: la propria mail inviata è già "letta".
        await sent.AppendAsync(new AppendRequest(message, MessageFlags.Seen), ct);
        return sent.FullName;
    }

    /// <summary>
    /// Bozza in Bozze (3.8): APPEND con \Draft e \Seen; la precedente si elimina solo dopo (UID EXPUNGE del suo
    /// solo UID), così un errore a metà lascia al più una bozza in più, mai nessuna.
    /// </summary>
    public async Task<DraftSaved> SaveDraftAsync(MimeMessage message, uint? replaceUid, CancellationToken ct = default)
    {
        var drafts = await FindSpecialAsync(FolderAttributes.Drafts, ct)
            ?? throw new MailNotFoundException("Il server non dichiara una cartella \\Drafts (Bozze): bozza non salvata.");
        var uid = await drafts.AppendAsync(new AppendRequest(message, MessageFlags.Draft | MessageFlags.Seen), ct);
        if (replaceUid is { } old && old != uid?.Id)
            await DeleteDraftAsync(old, ct);
        return new DraftSaved(drafts.FullName, uid?.Id);
    }

    public async Task DeleteDraftAsync(uint uid, CancellationToken ct = default)
    {
        var drafts = await FindSpecialAsync(FolderAttributes.Drafts, ct)
            ?? throw new MailNotFoundException("Il server non dichiara una cartella \\Drafts (Bozze).");
        RequireUidPlus();
        var folder = await OpenAsync(drafts.FullName, FolderAccess.ReadWrite, ct);
        try
        {
            var found = await ExistingAsync(folder, [uid], ct);
            if (found.Count == 0)
                return;
            await folder.StoreAsync(found, new StoreFlagsRequest(StoreAction.Add, MessageFlags.Deleted) { Silent = true }, ct);
            await folder.ExpungeAsync(found, ct); // UID EXPUNGE: solo questa bozza
        }
        finally
        {
            await folder.CloseAsync(expunge: false, ct);
        }
    }

    /// <summary>
    /// Sposta una o più mail. MOVE se il server lo supporta, altrimenti COPY + \Deleted + UID EXPUNGE
    /// dei soli UID spostati (UIDPLUS). Senza nessuno dei due rifiuta: un EXPUNGE semplice cancellerebbe
    /// anche gli altri messaggi \Deleted della cartella.
    /// </summary>
    /// <returns>Nome completo della cartella di destinazione e UID effettivamente spostati.</returns>
    public async Task<BatchResult> MoveAsync(string folderName, IReadOnlyCollection<uint> uids, string destinationName,
        CancellationToken ct = default)
    {
        if (string.Equals(folderName, destinationName, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Cartella di origine e destinazione coincidono.");

        var destination = await GetFolderAsync(destinationName, ct);
        return new BatchResult(destination.FullName, await MoveToAsync(folderName, uids, destination, ct));
    }

    public async Task<string> MoveAsync(string folderName, uint uid, string destinationName, CancellationToken ct = default) =>
        Single(await MoveAsync(folderName, [uid], destinationName, ct), folderName, uid).Destination!;

    /// <summary>
    /// Copia una o più mail (UID COPY). La cartella di origine si apre in sola lettura (EXAMINE): COPY
    /// non modifica gli originali.
    /// </summary>
    public async Task<BatchResult> CopyAsync(string folderName, IReadOnlyCollection<uint> uids, string destinationName,
        CancellationToken ct = default)
    {
        if (string.Equals(folderName, destinationName, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Cartella di origine e destinazione coincidono.");

        var destination = await GetFolderAsync(destinationName, ct);
        var folder = await OpenAsync(folderName, FolderAccess.ReadOnly, ct);
        try
        {
            var found = await ExistingAsync(folder, uids, ct);
            if (found.Count > 0)
                await folder.CopyToAsync(found, destination, ct);
            return new BatchResult(destination.FullName, found.Select(id => id.Id).ToList());
        }
        finally
        {
            await folder.CloseAsync(expunge: false, ct);
        }
    }

    /// <summary>Sposta una o più mail nella cartella con ruolo \Trash (Posta eliminata).</summary>
    public async Task<BatchResult> MoveToTrashAsync(string folderName, IReadOnlyCollection<uint> uids, CancellationToken ct = default)
    {
        var trash = await FindSpecialAsync(FolderAttributes.Trash, ct)
            ?? throw new MailNotFoundException("Il server non dichiara una cartella \\Trash (Posta eliminata).");
        if (string.Equals(trash.FullName, folderName, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Il messaggio è già in Posta eliminata: usare l'eliminazione definitiva.");

        return new BatchResult(trash.FullName, await MoveToAsync(folderName, uids, trash, ct));
    }

    public async Task<string> MoveToTrashAsync(string folderName, uint uid, CancellationToken ct = default) =>
        Single(await MoveToTrashAsync(folderName, [uid], ct), folderName, uid).Destination!;

    /// <summary>
    /// Eliminazione DEFINITIVA (\Deleted + UID EXPUNGE dei soli UID indicati), consentita solo nella
    /// cartella con ruolo \Trash. Non reversibile.
    /// </summary>
    /// <returns>UID effettivamente eliminati.</returns>
    public async Task<BatchResult> DeletePermanentlyAsync(string folderName, IReadOnlyCollection<uint> uids, CancellationToken ct = default)
    {
        var trash = await FindSpecialAsync(FolderAttributes.Trash, ct);
        if (trash is null || !string.Equals(trash.FullName, folderName, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("L'eliminazione definitiva è consentita solo in Posta eliminata.");
        RequireUidPlus();

        var folder = await OpenAsync(folderName, FolderAccess.ReadWrite, ct);
        try
        {
            var found = await ExistingAsync(folder, uids, ct);
            if (found.Count > 0)
            {
                await folder.StoreAsync(found, new StoreFlagsRequest(StoreAction.Add, MessageFlags.Deleted) { Silent = true }, ct);
                await folder.ExpungeAsync(found, ct); // UID EXPUNGE: solo questi UID
            }
            return new BatchResult(null, found.Select(id => id.Id).ToList());
        }
        finally
        {
            await folder.CloseAsync(expunge: false, ct);
        }
    }

    public async Task DeletePermanentlyAsync(string folderName, uint uid, CancellationToken ct = default) =>
        Single(await DeletePermanentlyAsync(folderName, [uid], ct), folderName, uid);

    private async Task<IReadOnlyList<uint>> MoveToAsync(string folderName, IReadOnlyCollection<uint> uids, IMailFolder destination,
        CancellationToken ct)
    {
        var useMove = _client.Capabilities.HasFlag(ImapCapabilities.Move);
        if (!useMove)
            RequireUidPlus();

        var folder = await OpenAsync(folderName, FolderAccess.ReadWrite, ct);
        try
        {
            var found = await ExistingAsync(folder, uids, ct);
            if (found.Count == 0)
                return [];
            if (useMove)
            {
                await folder.MoveToAsync(found, destination, ct);
            }
            else
            {
                await folder.CopyToAsync(found, destination, ct);
                await folder.StoreAsync(found, new StoreFlagsRequest(StoreAction.Add, MessageFlags.Deleted) { Silent = true }, ct);
                await folder.ExpungeAsync(found, ct); // UID EXPUNGE: solo questi UID
            }
            return found.Select(id => id.Id).ToList();
        }
        finally
        {
            await folder.CloseAsync(expunge: false, ct);
        }
    }

    private void RequireUidPlus()
    {
        if (!_client.Capabilities.HasFlag(ImapCapabilities.UidPlus))
            throw new NotSupportedException(
                "Il server non supporta MOVE né UIDPLUS: operazione rifiutata per non cancellare altri messaggi.");
    }

    private static IList<UniqueId> ToIds(IEnumerable<uint> uids) => uids.Distinct().Select(u => new UniqueId(u)).ToList();

    /// <summary>Gli UID che esistono ancora nella cartella (un altro programma può averne eliminati).</summary>
    private static async Task<IList<UniqueId>> ExistingAsync(IMailFolder folder, IReadOnlyCollection<uint> uids, CancellationToken ct)
    {
        var found = await folder.FetchAsync(ToIds(uids), new FetchRequest(MessageSummaryItems.UniqueId), ct);
        return found.Select(m => m.UniqueId).ToList();
    }

    /// <summary>Per le operazioni su una sola mail: se non c'era, MailNotFoundException (404) come prima.</summary>
    private static BatchResult Single(BatchResult result, string folderName, uint uid) =>
        result.Uids.Contains(uid) ? result : throw new MailNotFoundException($"Messaggio {uid} non trovato in '{folderName}'.");

    // ---------------------------------------------------------------------------------------------
    // Cartelle (3.4b): creare, rinominare, eliminare. MODIFICANO la casella.
    // ---------------------------------------------------------------------------------------------

    /// <summary>Crea una sottocartella di <paramref name="parentName"/> (null = in cima alla casella).</summary>
    public async Task<FolderChange> CreateFolderAsync(string? parentName, string name, CancellationToken ct = default)
    {
        var parent = parentName is null ? _client.GetFolder(_client.PersonalNamespaces[0]) : await GetFolderAsync(parentName, ct);
        if (parent.Attributes.HasFlag(FolderAttributes.NoInferiors))
            throw new InvalidOperationException($"La cartella '{parent.FullName}' non può contenere sottocartelle.");
        var separator = parent.DirectorySeparator;
        var clean = FolderNames.Validate(name, separator, topLevel: parentName is null);
        await RequireFreeNameAsync(parent, clean, except: null, ct);

        var created = await parent.CreateAsync(clean, isMessageFolder: true, ct)
            ?? throw new InvalidOperationException($"Il server non ha creato la cartella '{clean}'.");
        return new FolderChange(created.FullName, separator);
    }

    /// <summary>Rinomina dentro la stessa cartella madre (RENAME: le sottocartelle seguono).</summary>
    public async Task<FolderChange> RenameFolderAsync(string folderName, string newName, CancellationToken ct = default)
    {
        var folder = await GetFolderAsync(folderName, ct);
        await RequireOrdinaryAsync(folder, ct);
        var separator = folder.DirectorySeparator;
        var parent = await GetParentAsync(folder, ct);
        var clean = FolderNames.Validate(newName, separator, topLevel: string.IsNullOrEmpty(parent.FullName));
        if (clean == folder.Name)
            return new FolderChange(folder.FullName, separator); // nessun cambiamento

        // Solo maiuscole/minuscole diverse: la cartella stessa non conta come "già usato".
        await RequireFreeNameAsync(parent, clean, except: folder.Name, ct);
        await folder.RenameAsync(parent, clean, ct);
        return new FolderChange(folder.FullName, separator);
    }

    /// <summary>
    /// Fuori da Posta eliminata: RENAME dentro Posta eliminata (nome libero con " (2)"... se serve).
    /// Dentro Posta eliminata: DELETE definitivo, prima le sottocartelle più profonde (DELETE non
    /// elimina le sottocartelle, RFC 3501 6.3.4).
    /// </summary>
    public async Task<FolderDeletion> DeleteFolderAsync(string folderName, CancellationToken ct = default)
    {
        var folder = await GetFolderAsync(folderName, ct);
        var all = await RequireOrdinaryAsync(folder, ct);
        var separator = folder.DirectorySeparator;
        var trash = all.FirstOrDefault(f => f.Attributes.HasFlag(FolderAttributes.Trash))
            ?? throw new MailNotFoundException("Il server non dichiara una cartella \\Trash (Posta eliminata).");

        if (folder.FullName.StartsWith(trash.FullName + trash.DirectorySeparator, StringComparison.Ordinal))
        {
            var prefix = folder.FullName + separator;
            var inner = all
                .Where(f => f.Exists && f.FullName.StartsWith(prefix, StringComparison.Ordinal))
                .OrderByDescending(f => f.FullName.Count(c => c == separator));
            foreach (var sub in inner)
                await sub.DeleteAsync(ct);
            await folder.DeleteAsync(ct);
            return new FolderDeletion(null, true, separator);
        }

        var siblings = await trash.GetSubfoldersAsync(subscribedOnly: false, ct);
        var target = FolderNames.FirstFree(folder.Name, siblings.Select(f => f.Name));
        await folder.RenameAsync(trash, target, ct);
        return new FolderDeletion(folder.FullName, false, separator);
    }

    /// <summary>
    /// Sposta la cartella sotto un'altra (RENAME con una nuova cartella madre: mail e sottocartelle seguono).
    /// </summary>
    public async Task<FolderChange> MoveFolderAsync(string folderName, string? newParentName, CancellationToken ct = default)
    {
        var folder = await GetFolderAsync(folderName, ct);
        await RequireOrdinaryAsync(folder, ct);
        var separator = folder.DirectorySeparator;
        var parent = newParentName is null ? _client.GetFolder(_client.PersonalNamespaces[0]) : await GetFolderAsync(newParentName, ct);

        if (parent.FullName == folder.FullName || parent.FullName.StartsWith(folder.FullName + separator, StringComparison.Ordinal))
            throw new InvalidOperationException($"'{folder.FullName}' non può andare dentro sé stessa o una sua sottocartella.");
        if (parent.Attributes.HasFlag(FolderAttributes.NoInferiors))
            throw new InvalidOperationException($"La cartella '{parent.FullName}' non può contenere sottocartelle.");
        var current = await GetParentAsync(folder, ct);
        if (current.FullName == parent.FullName)
            return new FolderChange(folder.FullName, separator); // già lì: nessun cambiamento

        var topLevel = string.IsNullOrEmpty(parent.FullName);
        if (topLevel && folder.Name.Equals("INBOX", StringComparison.OrdinalIgnoreCase))
            throw new FieldValidationException("parent", "\"INBOX\" è il nome riservato della Posta in arrivo.");

        var target = folder.Name;
        if (parent.Attributes.HasFlag(FolderAttributes.Trash))
        {
            var siblings = await parent.GetSubfoldersAsync(subscribedOnly: false, ct);
            target = FolderNames.FirstFree(folder.Name, siblings.Where(f => f.Exists).Select(f => f.Name));
        }
        else
        {
            await RequireFreeNameAsync(parent, folder.Name, except: null, ct, field: "parent");
        }
        await folder.RenameAsync(parent, target, ct);
        return new FolderChange(folder.FullName, separator);
    }

    /// <summary>
    /// Rifiuta le cartelle con un ruolo (INBOX, Posta inviata, Posta eliminata...) e quelle che ne
    /// contengono una: spostarle o rinominarle romperebbe il funzionamento della casella.
    /// Restituisce l'elenco completo delle cartelle (letto qui con LIST).
    /// </summary>
    private async Task<IList<IMailFolder>> RequireOrdinaryAsync(IMailFolder folder, CancellationToken ct)
    {
        var all = await _client.GetFoldersAsync(_client.PersonalNamespaces[0], StatusItems.None, subscribedOnly: false, ct);
        var prefix = folder.FullName + folder.DirectorySeparator;
        foreach (var f in all)
        {
            var self = f.FullName == folder.FullName;
            if (!self && !f.FullName.StartsWith(prefix, StringComparison.Ordinal))
                continue;
            if (SpecialUse.FromAttributes(f.Attributes, f.FullName) is not null)
                throw new InvalidOperationException(self
                    ? $"'{folder.FullName}' è una cartella speciale: non si può rinominare, spostare né eliminare."
                    : $"'{folder.FullName}' contiene la cartella speciale '{f.FullName}': non si può rinominare, spostare né eliminare.");
        }
        if (SpecialUse.FromAttributes(folder.Attributes, folder.FullName) is not null)
            throw new InvalidOperationException($"'{folder.FullName}' è una cartella speciale: non si può rinominare, spostare né eliminare.");
        return all;
    }

    private async Task RequireFreeNameAsync(IMailFolder parent, string name, string? except, CancellationToken ct,
        string field = "name")
    {
        var siblings = await parent.GetSubfoldersAsync(subscribedOnly: false, ct);
        if (siblings.Any(f => f.Exists && f.Name != except && f.Name.Equals(name, StringComparison.OrdinalIgnoreCase)))
            throw new FieldValidationException(field, $"Esiste già una cartella \"{name}\" qui.");
    }

    /// <summary>Cartella madre dal nome completo (la radice della casella per quelle in cima).</summary>
    private async Task<IMailFolder> GetParentAsync(IMailFolder folder, CancellationToken ct)
    {
        var cut = folder.DirectorySeparator == '\0' ? -1 : folder.FullName.LastIndexOf(folder.DirectorySeparator);
        return cut < 0 ? _client.GetFolder(_client.PersonalNamespaces[0]) : await GetFolderAsync(folder.FullName[..cut], ct);
    }

    private async Task<IMailFolder?> FindSpecialAsync(FolderAttributes role, CancellationToken ct)
    {
        var personal = _client.PersonalNamespaces[0];
        var folders = await _client.GetFoldersAsync(personal, StatusItems.None, subscribedOnly: false, ct);
        return folders.FirstOrDefault(f => f.Attributes.HasFlag(role));
    }

    private async Task<IMailFolder> GetFolderAsync(string folderName, CancellationToken ct)
    {
        try
        {
            return string.Equals(folderName, "INBOX", StringComparison.OrdinalIgnoreCase)
                ? _client.Inbox
                : await _client.GetFolderAsync(folderName, ct);
        }
        catch (FolderNotFoundException ex)
        {
            throw new MailNotFoundException($"Cartella '{folderName}' non trovata.", ex);
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_client.IsConnected)
            await _client.DisconnectAsync(quit: true);
        _client.Dispose();
    }
}
