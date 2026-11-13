using MimeKit;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Imap;

/// <summary>
/// IMailWriter sulla connessione IMAP persistente condivisa. Nessuna ripetizione automatica:
/// se la connessione cade a metà, l'errore arriva all'utente invece di rischiare un doppione.
/// </summary>
public sealed class ImapMailWriter(ImapConnection connection) : IMailWriter
{
    public Task<bool> SetSeenAsync(string folder, uint uid, bool seen, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.SetSeenAsync(folder, uid, seen, ct), ct);

    public Task<Cache.MailFlags> UpdateFlagsAsync(string folder, uint uid, Cache.MailFlags add, Cache.MailFlags remove,
        CancellationToken ct = default) =>
        connection.WriteAsync(s => s.UpdateFlagsAsync(folder, uid, add, remove, ct), ct);

    public Task<string> AppendToSentAsync(MimeMessage message, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.AppendToSentAsync(message, ct), ct);

    public Task<DraftSaved> SaveDraftAsync(MimeMessage message, uint? replaceUid, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.SaveDraftAsync(message, replaceUid, ct), ct);

    public Task DeleteDraftAsync(uint uid, CancellationToken ct = default) =>
        connection.WriteAsync(async s => { await s.DeleteDraftAsync(uid, ct); return true; }, ct);

    public Task<string> MoveAsync(string folder, uint uid, string destination, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.MoveAsync(folder, uid, destination, ct), ct);

    public Task<string> MoveToTrashAsync(string folder, uint uid, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.MoveToTrashAsync(folder, uid, ct), ct);

    public Task DeletePermanentlyAsync(string folder, uint uid, CancellationToken ct = default) =>
        connection.WriteAsync(async s => { await s.DeletePermanentlyAsync(folder, uid, ct); return true; }, ct);

    public Task<FolderChange> CreateFolderAsync(string? parent, string name, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.CreateFolderAsync(parent, name, ct), ct);

    public Task<FolderChange> RenameFolderAsync(string folder, string newName, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.RenameFolderAsync(folder, newName, ct), ct);

    public Task<FolderDeletion> DeleteFolderAsync(string folder, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.DeleteFolderAsync(folder, ct), ct);

    public Task<IReadOnlyDictionary<uint, bool>> SetSeenAsync(string folder, IReadOnlyCollection<uint> uids, bool seen,
        CancellationToken ct = default) =>
        connection.WriteAsync(s => s.SetSeenAsync(folder, uids, seen, ct), ct);

    public Task<IReadOnlyDictionary<uint, Cache.MailFlags>> UpdateFlagsAsync(string folder, IReadOnlyCollection<uint> uids,
        Cache.MailFlags add, Cache.MailFlags remove, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.UpdateFlagsAsync(folder, uids, add, remove, ct), ct);

    public Task<BatchResult> MoveAsync(string folder, IReadOnlyCollection<uint> uids, string destination, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.MoveAsync(folder, uids, destination, ct), ct);

    public Task<BatchResult> CopyAsync(string folder, IReadOnlyCollection<uint> uids, string destination, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.CopyAsync(folder, uids, destination, ct), ct);

    public Task<FolderChange> MoveFolderAsync(string folder, string? newParent, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.MoveFolderAsync(folder, newParent, ct), ct);

    public Task<BatchResult> MoveToTrashAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.MoveToTrashAsync(folder, uids, ct), ct);

    public Task<BatchResult> DeletePermanentlyAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.DeletePermanentlyAsync(folder, uids, ct), ct);

    public Task<FolderEmptied> EmptyFolderAsync(string folder, bool subfolders, CancellationToken ct = default) =>
        connection.WriteAsync(s => s.EmptyFolderAsync(folder, subfolders, ct), ct);
}
