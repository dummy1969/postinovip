using MimeKit;
using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Conversations;

/// <summary>Esito di Ignora, Interrompi Ignora e Pulisci: mail spostate e cartella di destinazione.</summary>
/// <param name="Checked">Pulisci: mail esaminate (quelle della cartella nelle conversazioni scelte).</param>
public sealed record ConversationCommandResult(IReadOnlyList<uint> Moved, string? Destination, int Checked = 0);

/// <summary>Esito di un giro del filtro delle conversazioni ignorate (diagnostica: solo numeri).</summary>
public sealed record IgnoreRunResult(int Checked, int Moved, int Failed)
{
    public override string ToString() => $"conversazioni ignorate: {Checked} mail nuove controllate, {Moved} in Posta eliminata, {Failed} non riuscite";
}

/// <summary>
/// Ignora conversazione e Pulisci conversazione di un account (C1, come Outlook classico). Servono la copia locale
/// (le conversazioni sono calcolate lì) e la cartella Posta eliminata; niente si elimina definitivamente.
/// <list type="bullet">
/// <item><see cref="IgnoreAsync"/> (1b): le mail della conversazione nella cartella aperta vanno in Posta eliminata e
/// i Message-ID della conversazione si ricordano (ignore.json); <see cref="RunNewAsync"/> sposta lì le mail nuove della
/// Posta in arrivo che ne citano uno (dopo la posta indesiderata, prima di risposte automatiche e regole).</item>
/// <item><see cref="StopIgnoringAsync"/>: li dimentica e, da Posta eliminata, riporta la conversazione in Posta in arrivo.</item>
/// <item><see cref="CleanUpAsync"/> (2b, 3b): sposta in Posta eliminata le mail della cartella citate per intero da una
/// risposta diretta (<see cref="CleanUpText"/>), tranne quelle da leggere, contrassegnate, con categorie o firmate.</item>
/// </list>
/// Tutto MODIFICA la casella con lo stesso IMailWriter dei comandi. Nel log solo numeri, UID e nomi delle cartelle.
/// </summary>
public sealed class ConversationTools(MailAccount account, IgnoreStore store, Action<string>? log = null)
{
    public const string Inbox = "INBOX";

    private readonly SemaphoreSlim _gate = new(1, 1);

    private AccountCache Cache =>
        account.Bodies?.Cache ?? throw new NotSupportedException("Ignora e Pulisci richiedono la copia locale (Cache:Enabled=false).").WithCode("ignoraPulisciRichiedonoLaCopia");

    /// <summary>La cartella Posta eliminata dell'account; null se non c'è.</summary>
    public async Task<string?> TrashFolderAsync(CancellationToken ct = default) =>
        (await account.Reader.GetFoldersAsync(ct)).FirstOrDefault(f => f.SpecialUse == "trash")?.FullName;

    /// <summary>true se la conversazione di una delle mail è ignorata.</summary>
    public async Task<bool> IsIgnoredAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default)
    {
        var members = await MembersAsync(folder, uids, ct);
        var ignored = store.Load();
        return ignored.Count > 0 && members.Any(m => Keys(m).Any(ignored.Contains));
    }

    /// <summary>
    /// «Ignora conversazione»: ricorda i Message-ID delle conversazioni delle mail e sposta in Posta eliminata quelle
    /// della cartella <paramref name="folder"/> (1b; da Posta eliminata stessa nessuno spostamento).
    /// </summary>
    public async Task<ConversationCommandResult> IgnoreAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default)
    {
        var trash = await TrashFolderAsync(ct) ?? throw new InvalidOperationException("Nessuna cartella Posta eliminata in questo account.").WithCode("nessunaCartellaPostaEliminataIn");
        var members = await MembersAsync(folder, uids, ct);
        var threads = members.Where(m => m.Folder == folder && uids.Contains(m.Uid)).Select(m => m.Thread).ToHashSet();
        var conversation = members.Where(m => threads.Contains(m.Thread)).ToList();
        if (conversation.Count == 0)
            throw new MailNotFoundException($"Nessuna delle mail indicate è in '{folder}'.").WithCode("nessunaDelleMailIndicateIn", ("folder", folder));
        var added = store.Add(conversation.SelectMany(Keys).Distinct(StringComparer.Ordinal));
        var here = conversation.Where(m => m.Folder == folder).Select(m => m.Uid).Distinct().ToList();
        if (folder == trash)
            return new ConversationCommandResult([], trash);
        var result = await account.Writer.MoveToTrashAsync(folder, here, ct);
        log?.Invoke($"[{account.Id}] IGNORA conversazione: {added} riferimenti nuovi, {result.Uids.Count} mail {folder} -> {trash}");
        return new ConversationCommandResult(result.Uids, trash);
    }

    /// <summary>
    /// «Interrompi Ignora conversazione»: dimentica le conversazioni delle mail; da Posta eliminata le loro mail lì
    /// tornano in Posta in arrivo. Una conversazione non ignorata fuori da Posta eliminata: 409.
    /// </summary>
    public async Task<ConversationCommandResult> StopIgnoringAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default)
    {
        var trash = await TrashFolderAsync(ct);
        var members = await MembersAsync(folder, uids, ct);
        var threads = members.Where(m => m.Folder == folder && uids.Contains(m.Uid)).Select(m => m.Thread).ToHashSet();
        var conversation = members.Where(m => threads.Contains(m.Thread)).ToList();
        if (conversation.Count == 0)
            throw new MailNotFoundException($"Nessuna delle mail indicate è in '{folder}'.").WithCode("nessunaDelleMailIndicateIn", ("folder", folder));
        var removed = store.Remove(conversation.SelectMany(Keys));
        if (folder != trash)
        {
            if (removed == 0)
                throw new InvalidOperationException("La conversazione non è ignorata.").WithCode("laConversazioneNonIgnorata");
            log?.Invoke($"[{account.Id}] INTERROMPI IGNORA conversazione: {removed} riferimenti tolti");
            return new ConversationCommandResult([], null);
        }
        var here = conversation.Where(m => m.Folder == folder).Select(m => m.Uid).Distinct().ToList();
        var result = await account.Writer.MoveAsync(folder, here, Inbox, ct);
        log?.Invoke($"[{account.Id}] INTERROMPI IGNORA conversazione: {removed} riferimenti tolti, {result.Uids.Count} mail {folder} -> {Inbox}");
        return new ConversationCommandResult(result.Uids, result.Destination ?? Inbox);
    }

    /// <summary>
    /// «Pulisci conversazione» (mail indicate) o «Pulisci cartella» (<paramref name="uids"/> null): sposta in Posta
    /// eliminata le mail superflue della cartella. Non vale in Posta eliminata né nella posta indesiderata (409).
    /// </summary>
    public async Task<ConversationCommandResult> CleanUpAsync(string folder, IReadOnlyCollection<uint>? uids, CancellationToken ct = default)
    {
        var folders = await account.Reader.GetFoldersAsync(ct);
        var trash = folders.FirstOrDefault(f => f.SpecialUse == "trash")?.FullName
                    ?? throw new InvalidOperationException("Nessuna cartella Posta eliminata in questo account.").WithCode("nessunaCartellaPostaEliminataIn");
        var role = folders.FirstOrDefault(f => f.FullName == folder)?.SpecialUse;
        if (folder == trash || role == "junk" || folder == JunkFolder(folders))
            throw new InvalidOperationException("Pulisci non vale per Posta eliminata e per la posta indesiderata.").WithCode("pulisciNonValePerPosta");

        var members = await MembersAsync(folder, uids, ct);
        var threads = members.Where(m => m.Folder == folder && (uids is null || uids.Contains(m.Uid))).Select(m => m.Thread).ToHashSet();
        var conversation = members.Where(m => threads.Contains(m.Thread)).ToList();
        if (uids is not null && conversation.Count == 0)
            throw new MailNotFoundException($"Nessuna delle mail indicate è in '{folder}'.").WithCode("nessunaDelleMailIndicateIn", ("folder", folder));

        // Le risposte possono stare in qualunque cartella (es. Posta inviata), tranne Posta eliminata e posta indesiderata.
        var junk = JunkFolder(folders);
        var replies = conversation.Where(m => m.FolderRole is not ("trash" or "junk") && m.Folder != trash && m.Folder != junk
                                              && m.InReplyTo is not null)
            .ToLookup(m => (m.Thread, m.InReplyTo!));
        var here = conversation.Where(m => m.Folder == folder).ToList();
        var messages = new Dictionary<(string, uint), MimeMessage?>();
        var superfluous = new List<uint>();
        foreach (var m in here)
        {
            ct.ThrowIfCancellationRequested();
            if (m.MessageId is null || !Movable(m.Flags))
                continue;
            var direct = replies[(m.Thread, m.MessageId)].Where(r => r.MessageId != m.MessageId).ToList();
            if (direct.Count == 0)
                continue;
            var original = await ReadAsync(messages, m, ct);
            if (original is null || CleanUpText.IsSigned(original))
                continue;
            foreach (var reply in direct)
            {
                if (await ReadAsync(messages, reply, ct) is { } r && CleanUpText.IsQuotedIn(original, r))
                {
                    superfluous.Add(m.Uid);
                    break;
                }
            }
        }
        if (superfluous.Count == 0)
            return new ConversationCommandResult([], trash, here.Count);
        var result = await account.Writer.MoveToTrashAsync(folder, superfluous, ct);
        log?.Invoke($"[{account.Id}] PULISCI {(uids is null ? "cartella" : "conversazione")} {folder}: {here.Count} mail esaminate, {result.Uids.Count} -> {trash}");
        return new ConversationCommandResult(result.Uids, trash, here.Count);
    }

    /// <summary>Filtro sulle mail nuove della Posta in arrivo: quelle di una conversazione ignorata vanno in Posta eliminata.</summary>
    public async Task<IgnoreRunResult> RunNewAsync(CancellationToken ct = default)
    {
        if (account.Bodies?.Cache is not { } cache)
            return new IgnoreRunResult(0, 0, 0);
        await _gate.WaitAsync(ct);
        try
        {
            await account.Reader.GetHeadersAsync(Inbox, 0, 1, ct: ct); // sincronizza la Posta in arrivo
            if (cache.FindFolder(Inbox) is not { } folder)
                return new IgnoreRunResult(0, 0, 0);
            var uids = cache.GetUids(folder.Id);
            var max = uids.Count == 0 ? 0 : uids.Max();
            var progress = store.LoadProgress();
            var ignored = store.Load();
            if (progress is null || progress.UidValidity != folder.UidValidity || ignored.Count == 0)
            {
                if (progress is null || progress.UidValidity != folder.UidValidity || progress.LastUid != max)
                    store.SaveProgress(new IgnoreProgress(folder.UidValidity, max));
                return new IgnoreRunResult(0, 0, 0);
            }
            var fresh = uids.Where(u => u > progress.LastUid).ToHashSet();
            if (fresh.Count == 0)
                return new IgnoreRunResult(0, 0, 0);
            var trash = await TrashFolderAsync(ct);
            var matches = cache.GetThreadMembers(folder.Id, fresh)
                .Where(m => m.Folder == Inbox && fresh.Contains(m.Uid) && Keys(m).Any(ignored.Contains)).ToList();
            int moved = 0, failed = 0;
            if (matches.Count > 0 && trash is null)
            {
                log?.Invoke($"[{account.Id}] conversazioni ignorate: nessuna cartella Posta eliminata, {matches.Count} mail lasciate");
            }
            else if (matches.Count > 0)
            {
                try
                {
                    store.Add(matches.Select(m => m.MessageId).OfType<string>()); // la catena continua anche dalle mail nuove
                    moved = (await account.Writer.MoveToTrashAsync(Inbox, matches.Select(m => m.Uid).Distinct().ToList(), ct)).Uids.Count;
                }
                catch (Exception ex) when (ex is not (OperationCanceledException or MailOfflineException))
                {
                    failed = matches.Count;
                    log?.Invoke($"[{account.Id}] conversazioni ignorate: mail non spostate ({ex.GetType().Name}: {ex.Message})");
                }
            }
            store.SaveProgress(new IgnoreProgress(folder.UidValidity, fresh.Max()));
            var result = new IgnoreRunResult(fresh.Count, moved, failed);
            if (moved > 0 || failed > 0)
                log?.Invoke($"[{account.Id}] {result}");
            return result;
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>Eccezioni fisse di Pulisci (3b, quelle consigliate da Outlook più le mail da leggere): resta dov'è.</summary>
    private static bool Movable(MailFlags flags) =>
        flags.HasFlag(MailFlags.Seen) && !flags.HasFlag(MailFlags.Flagged) && (flags & MailFlags.Categories) == 0
        && !flags.HasFlag(MailFlags.Draft);

    private static IEnumerable<string> Keys(ThreadMember m) => m.MessageId is null ? m.Cited : m.Cited.Append(m.MessageId);

    private string? JunkFolder(IReadOnlyList<Models.MailFolderInfo> folders) =>
        Junk.JunkFolders.Resolve(folders, account.Junk?.Load().Folder);

    private async Task<IReadOnlyList<ThreadMember>> MembersAsync(string folder, IReadOnlyCollection<uint>? uids, CancellationToken ct)
    {
        var cache = Cache;
        await account.Reader.GetHeadersAsync(folder, 0, 1, ct: ct); // sincronizza la cartella
        if (cache.FindFolder(folder) is not { } cached)
            throw new MailNotFoundException($"Cartella '{folder}' non trovata.").WithCode("cartellaNonTrovata3", ("folder", folder));
        return cache.GetThreadMembers(cached.Id, uids);
    }

    private async Task<MimeMessage?> ReadAsync(Dictionary<(string, uint), MimeMessage?> read, ThreadMember m, CancellationToken ct)
    {
        if (read.TryGetValue((m.Folder, m.Uid), out var known))
            return known;
        MimeMessage? message;
        try
        {
            message = await account.Reader.GetMimeMessageAsync(m.Folder, m.Uid, ct); // BODY.PEEK o copia locale: resta com'è
        }
        catch (MailNotFoundException)
        {
            message = null; // non c'è più
        }
        read[(m.Folder, m.Uid)] = message;
        return message;
    }
}
