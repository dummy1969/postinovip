using MimeKit;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Local;

/// <summary>
/// IMailWriter di un account POP3 (4.2): le modifiche restano sul computer, il server POP3 non ha cartelle
/// né flag. Stesse regole e stessi errori della versione IMAP (<see cref="Imap.ImapMailService"/>), così
/// l'app non distingue: cartelle con un ruolo non si rinominano né si eliminano, eliminazione definitiva solo
/// in Posta eliminata, "Elimina cartella" la sposta in Posta eliminata (definitiva solo da lì).
/// Letto, contrassegni e categorie stanno nell'indice: spostando o copiando una mail vengono riportati sulla
/// mail nella nuova cartella. Le mail eliminate definitivamente, se scaricate con POP3, si segnalano con
/// <paramref name="removedPermanently"/> (UIDL), per "Rimuovi dal server quando eliminata da Posta eliminata".
/// </summary>
public sealed class LocalMailWriter(LocalMailStore store, AccountCache cache, LocalMailReader reader,
    Action<IReadOnlyList<string>>? removedPermanently = null) : IMailWriter
{
    private const char Separator = LocalMailStore.Separator;

    // ---------------------------------------------------------------------------------------------
    // Letto, contrassegni, categorie (solo nell'indice)
    // ---------------------------------------------------------------------------------------------

    public async Task<bool> SetSeenAsync(string folder, uint uid, bool seen, CancellationToken ct = default) =>
        (await SetSeenAsync(folder, [uid], seen, ct)).TryGetValue(uid, out var result) ? result : throw NotFound(folder, uid);

    public async Task<MailFlags> UpdateFlagsAsync(string folder, uint uid, MailFlags add, MailFlags remove, CancellationToken ct = default) =>
        (await UpdateFlagsAsync(folder, [uid], add, remove, ct)).TryGetValue(uid, out var result) ? result : throw NotFound(folder, uid);

    public async Task<IReadOnlyDictionary<uint, bool>> SetSeenAsync(string folder, IReadOnlyCollection<uint> uids, bool seen,
        CancellationToken ct = default)
    {
        var flags = await UpdateFlagsAsync(folder, uids, seen ? MailFlags.Seen : MailFlags.None, seen ? MailFlags.None : MailFlags.Seen, ct);
        return flags.ToDictionary(f => f.Key, f => f.Value.HasFlag(MailFlags.Seen));
    }

    public async Task<IReadOnlyDictionary<uint, MailFlags>> UpdateFlagsAsync(string folder, IReadOnlyCollection<uint> uids,
        MailFlags add, MailFlags remove, CancellationToken ct = default)
    {
        var cached = await reader.SyncAsync(folder, ct);
        var result = new Dictionary<uint, MailFlags>();
        var changes = new List<(uint, MailFlags)>();
        foreach (var uid in uids.Distinct())
        {
            if (cache.GetFlags(cached.Id, uid) is not var (current, _))
                continue; // non c'è più: ignorato, come per l'IMAP
            var updated = (current | add) & ~remove;
            result[uid] = updated;
            changes.Add((uid, updated));
        }
        cache.UpdateFlags(cached.Id, changes);
        return result;
    }

    // ---------------------------------------------------------------------------------------------
    // Posta inviata e Bozze
    // ---------------------------------------------------------------------------------------------

    public async Task<string> AppendToSentAsync(MimeMessage message, CancellationToken ct = default)
    {
        var sent = FolderWithRole("sent");
        await AddMessageAsync(sent, message, ct); // già letta: flag iniziali del ruolo
        return sent;
    }

    /// <summary>Bozza in Bozze (come l'IMAP: prima la nuova, poi si toglie la precedente).</summary>
    public async Task<DraftSaved> SaveDraftAsync(MimeMessage message, uint? replaceUid, CancellationToken ct = default)
    {
        var drafts = FolderWithRole("drafts");
        var uid = await AddMessageAsync(drafts, message, ct);
        if (replaceUid is { } old && old != uid)
            store.Delete(drafts, old);
        await reader.SyncAsync(drafts, ct);
        return new DraftSaved(drafts, uid);
    }

    public async Task DeleteDraftAsync(uint uid, CancellationToken ct = default)
    {
        var drafts = FolderWithRole("drafts");
        if (store.Delete(drafts, uid))
            await reader.SyncAsync(drafts, ct);
    }

    private async Task<uint> AddMessageAsync(string folder, MimeMessage message, CancellationToken ct)
    {
        using var buffer = new MemoryStream();
        await message.WriteToAsync(buffer, ct);
        buffer.Position = 0;
        return await store.AddAsync(folder, buffer, ct: ct);
    }

    // ---------------------------------------------------------------------------------------------
    // Spostare, copiare, eliminare
    // ---------------------------------------------------------------------------------------------

    public async Task<string> MoveAsync(string folder, uint uid, string destination, CancellationToken ct = default) =>
        Single(await MoveAsync(folder, [uid], destination, ct), folder, uid).Destination!;

    public async Task<BatchResult> MoveAsync(string folder, IReadOnlyCollection<uint> uids, string destination, CancellationToken ct = default)
    {
        if (string.Equals(folder, destination, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Cartella di origine e destinazione coincidono.");
        return await TransferAsync(folder, uids, Resolve(destination), copy: false, ct);
    }

    public async Task<BatchResult> CopyAsync(string folder, IReadOnlyCollection<uint> uids, string destination, CancellationToken ct = default)
    {
        if (string.Equals(folder, destination, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Cartella di origine e destinazione coincidono.");
        return await TransferAsync(folder, uids, Resolve(destination), copy: true, ct);
    }

    public async Task<string> MoveToTrashAsync(string folder, uint uid, CancellationToken ct = default) =>
        Single(await MoveToTrashAsync(folder, [uid], ct), folder, uid).Destination!;

    public async Task<BatchResult> MoveToTrashAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default)
    {
        var trash = FolderWithRole("trash");
        if (string.Equals(trash, folder, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Il messaggio è già in Posta eliminata: usare l'eliminazione definitiva.");
        return await TransferAsync(folder, uids, trash, copy: false, ct);
    }

    public async Task DeletePermanentlyAsync(string folder, uint uid, CancellationToken ct = default) =>
        Single(await DeletePermanentlyAsync(folder, [uid], ct), folder, uid);

    /// <summary>Eliminazione DEFINITIVA dei file, solo in Posta eliminata. Non reversibile.</summary>
    public async Task<BatchResult> DeletePermanentlyAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default)
    {
        var trash = FolderWithRole("trash");
        if (!string.Equals(trash, folder, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("L'eliminazione definitiva è consentita solo in Posta eliminata.");

        var deleted = new List<uint>();
        var uidls = new List<string>();
        foreach (var uid in uids.Distinct())
        {
            var uidl = removedPermanently is null ? null : store.ReadHeader(trash, uid, Pop3.Pop3Fetcher.UidlHeader);
            if (!store.Delete(trash, uid))
                continue;
            deleted.Add(uid);
            if (uidl is not null)
                uidls.Add(uidl);
        }
        await reader.SyncAsync(trash, ct);
        if (uidls.Count > 0)
            removedPermanently?.Invoke(uidls);
        return new BatchResult(null, deleted);
    }

    /// <summary>
    /// Sposta o copia i file e riporta sulle mail nuove letto, contrassegni, categorie e scadenza (che stanno
    /// solo nell'indice). Prima la copia completa, poi la cancellazione: un'interruzione lascia al più un doppione.
    /// </summary>
    private async Task<BatchResult> TransferAsync(string folder, IReadOnlyCollection<uint> uids, string destination, bool copy,
        CancellationToken ct)
    {
        var source = await reader.SyncAsync(folder, ct);
        var moved = new List<uint>();
        var carried = new List<(uint NewUid, MailFlags Flags, DateOnly? Due)>();
        foreach (var uid in uids.Distinct())
        {
            ct.ThrowIfCancellationRequested();
            if (!store.Exists(folder, uid))
                continue;
            var (flags, due) = cache.GetFlags(source.Id, uid) ?? (MailFlags.None, null);
            var newUid = copy ? await store.CopyAsync(folder, uid, destination, ct) : await store.MoveAsync(folder, uid, destination, ct);
            moved.Add(uid);
            carried.Add((newUid, flags, due));
        }

        var target = await reader.SyncAsync(destination, ct);
        foreach (var (newUid, flags, due) in carried)
            cache.SetFlags(target.Id, newUid, flags, due);
        if (!copy && moved.Count > 0)
            await reader.SyncAsync(folder, ct);
        return new BatchResult(destination, moved);
    }

    // ---------------------------------------------------------------------------------------------
    // Cartelle
    // ---------------------------------------------------------------------------------------------

    public Task<FolderChange> CreateFolderAsync(string? parent, string name, CancellationToken ct = default)
    {
        if (parent is not null)
            parent = Resolve(parent);
        var clean = FolderNames.Validate(name, Separator, topLevel: parent is null);
        RequireFreeName(parent, clean, except: null);
        var full = parent is null ? clean : parent + Separator + clean;
        store.CreateFolder(full);
        return Task.FromResult(new FolderChange(full, Separator));
    }

    public Task<FolderChange> RenameFolderAsync(string folder, string newName, CancellationToken ct = default)
    {
        folder = Resolve(folder);
        RequireOrdinary(folder);
        var parent = LocalMailStore.ParentOf(folder);
        var clean = FolderNames.Validate(newName, Separator, topLevel: parent is null);
        var current = LocalMailStore.LastSegment(folder);
        if (clean == current)
            return Task.FromResult(new FolderChange(folder, Separator)); // nessun cambiamento

        RequireFreeName(parent, clean, except: current);
        var renamed = parent is null ? clean : parent + Separator + clean;
        store.RenameFolder(folder, renamed);
        return Task.FromResult(new FolderChange(renamed, Separator));
    }

    public Task<FolderDeletion> DeleteFolderAsync(string folder, CancellationToken ct = default)
    {
        folder = Resolve(folder);
        RequireOrdinary(folder);
        var trash = FolderWithRole("trash");

        if (folder.StartsWith(trash + Separator, StringComparison.Ordinal))
        {
            // Dentro Posta eliminata: definitiva, con tutte le mail delle sottocartelle.
            var uidls = removedPermanently is null ? [] : UidlsIn(folder);
            store.DeleteFolder(folder);
            if (uidls.Count > 0)
                removedPermanently?.Invoke(uidls);
            return Task.FromResult(new FolderDeletion(null, true, Separator));
        }

        var target = trash + Separator + FolderNames.FirstFree(LocalMailStore.LastSegment(folder), Children(trash));
        store.RenameFolder(folder, target);
        return Task.FromResult(new FolderDeletion(target, false, Separator));
    }

    public Task<FolderChange> MoveFolderAsync(string folder, string? newParent, CancellationToken ct = default)
    {
        folder = Resolve(folder);
        RequireOrdinary(folder);
        if (newParent is not null)
            newParent = Resolve(newParent);
        if (newParent == folder || (newParent?.StartsWith(folder + Separator, StringComparison.Ordinal) ?? false))
            throw new InvalidOperationException($"'{folder}' non può andare dentro sé stessa o una sua sottocartella.");
        if (LocalMailStore.ParentOf(folder) == newParent)
            return Task.FromResult(new FolderChange(folder, Separator)); // già lì: nessun cambiamento

        var name = LocalMailStore.LastSegment(folder);
        if (newParent is null && name.Equals("INBOX", StringComparison.OrdinalIgnoreCase))
            throw new FieldValidationException("parent", "\"INBOX\" è il nome riservato della Posta in arrivo.");

        var trash = FolderWithRole("trash");
        var target = name;
        if (newParent == trash)
            target = FolderNames.FirstFree(name, Children(trash));
        else
            RequireFreeName(newParent, name, except: null, field: "parent");

        var moved = newParent is null ? target : newParent + Separator + target;
        store.RenameFolder(folder, moved);
        return Task.FromResult(new FolderChange(moved, Separator));
    }

    /// <summary>Svuota: elimina DEFINITIVAMENTE i file delle mail e, con <paramref name="subfolders"/>, le sottocartelle.</summary>
    public async Task<FolderEmptied> EmptyFolderAsync(string folder, bool subfolders, CancellationToken ct = default)
    {
        folder = Resolve(folder);
        var removed = new List<string>();
        var uidls = new List<string>();
        if (subfolders)
        {
            var tree = store.FolderTree(folder).Where(n => n != folder).ToList();
            if (tree.FirstOrDefault(n => store.GetFolder(n).Role is not null) is { } special)
                throw new InvalidOperationException($"'{folder}' contiene la cartella speciale '{special}': non si svuota.");
            foreach (var child in tree.Where(n => LocalMailStore.ParentOf(n) == folder))
            {
                if (removedPermanently is not null)
                    uidls.AddRange(UidlsIn(child));
                store.DeleteFolder(child);
            }
            removed.AddRange(tree.OrderByDescending(n => n.Length));
        }

        var count = 0;
        foreach (var uid in store.GetUids(folder))
        {
            var uidl = removedPermanently is null ? null : store.ReadHeader(folder, uid, Pop3.Pop3Fetcher.UidlHeader);
            if (!store.Delete(folder, uid))
                continue;
            count++;
            if (uidl is not null)
                uidls.Add(uidl);
        }
        await reader.SyncAsync(folder, ct);
        if (uidls.Count > 0)
            removedPermanently?.Invoke(uidls);
        return new FolderEmptied(count, removed, Separator);
    }

    /// <summary>Cartelle con un ruolo (o che ne contengono una): non si rinominano, spostano né eliminano.</summary>
    private void RequireOrdinary(string folder)
    {
        var roles = store.ListFolders().ToDictionary(f => f.FullName, f => f.Info.Role);
        foreach (var name in store.FolderTree(folder))
        {
            if (roles.GetValueOrDefault(name) is null)
                continue;
            throw new InvalidOperationException(name == folder
                ? $"'{folder}' è una cartella speciale: non si può rinominare, spostare né eliminare."
                : $"'{folder}' contiene la cartella speciale '{name}': non si può rinominare, spostare né eliminare.");
        }
    }

    private void RequireFreeName(string? parent, string name, string? except, string field = "name")
    {
        if (Children(parent).Any(c => c != except && c.Equals(name, StringComparison.OrdinalIgnoreCase)))
            throw new FieldValidationException(field, $"Esiste già una cartella \"{name}\" qui.");
    }

    /// <summary>Nomi (ultimo livello) delle sottocartelle dirette di <paramref name="parent"/> (null = in cima).</summary>
    private IEnumerable<string> Children(string? parent) =>
        store.ListFolders().Select(f => f.FullName)
            .Where(n => LocalMailStore.ParentOf(n) == parent)
            .Select(LocalMailStore.LastSegment)
            .ToList();

    private List<string> UidlsIn(string folder)
    {
        var uidls = new List<string>();
        foreach (var name in store.FolderTree(folder))
            foreach (var uid in store.GetUids(name))
                if (store.ReadHeader(name, uid, Pop3.Pop3Fetcher.UidlHeader) is { } uidl)
                    uidls.Add(uidl);
        return uidls;
    }

    /// <summary>Nome della cartella com'è salvato ("inbox" vale per INBOX, come in IMAP); MailNotFoundException se non c'è.</summary>
    private string Resolve(string folder)
    {
        if (string.Equals(folder, LocalMailStore.Inbox, StringComparison.OrdinalIgnoreCase))
            return LocalMailStore.Inbox;
        return store.FolderExists(folder) ? folder : throw new MailNotFoundException($"Cartella '{folder}' non trovata.");
    }

    private string FolderWithRole(string role)
    {
        store.EnsureDefaults();
        return store.ListFolders().FirstOrDefault(f => f.Info.Role == role).FullName
            ?? throw new MailNotFoundException($"Nessuna cartella locale con ruolo {role}.");
    }

    private static BatchResult Single(BatchResult result, string folder, uint uid) =>
        result.Uids.Contains(uid) ? result : throw NotFound(folder, uid);

    private static MailNotFoundException NotFound(string folder, uint uid) => new($"Messaggio {uid} non trovato in '{folder}'.");
}
