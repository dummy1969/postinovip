using Microsoft.AspNetCore.Mvc;
using PostinoVip.Api.Contracts;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Archive;
using PostinoVip.Core.Junk;

namespace PostinoVip.Api.Controllers;

/// <summary>Cartella di archiviazione: scelta (null = non ancora), proposta per la prima volta (null = nessuna adatta).</summary>
public sealed record ArchiveOptionsResponse(string? Folder, string? Suggested);

/// <summary>Corpo di Archivia: mail della cartella (da 1 a MessagesController.MaxBatch).</summary>
public sealed class ArchiveRequest
{
    public uint[]? Uids { get; set; }
}

/// <summary>
/// Archivia (A1). La scelta della cartella (GET/PUT …/archive) non modifica la casella. «Archivia» (POST
/// …/messages/{folder}/archive) la MODIFICA: sposta le mail nella cartella di archiviazione, come Sposta (nessuna
/// parola chiave, lo stato letto/non letto resta com'è).
/// </summary>
[ApiController]
public sealed class ArchiveController(MailAccountRegistry accounts, ILogger<ArchiveController> logger) : MailControllerBase(accounts)
{
    private ArchiveStore Store =>
        CurrentAccount.Archive ?? throw new NotSupportedException("Archivia richiede la copia locale (Cache:Enabled=false).");

    [HttpGet("archive")]
    [HttpGet("accounts/{accountId}/archive")]
    public async Task<ActionResult<ArchiveOptionsResponse>> Get(CancellationToken ct)
    {
        var store = Store;
        var folders = await CurrentAccount.Reader.GetFoldersAsync(ct);
        return Ok(new ArchiveOptionsResponse(ArchiveFolders.InUse(folders, store.Load().Folder), Suggest(folders)));
    }

    /// <summary>PUT {"folder"} — sceglie la cartella (null la toglie): deve esistere e non essere una cartella speciale (400 su "folder").</summary>
    [HttpPut("archive")]
    [HttpPut("accounts/{accountId}/archive")]
    public async Task<ActionResult<ArchiveOptionsResponse>> Put([FromBody] ArchiveSettings settings, CancellationToken ct)
    {
        var store = Store;
        var clean = ArchiveStore.Validate(settings);
        var folders = await CurrentAccount.Reader.GetFoldersAsync(ct);
        if (clean.Folder is { } folder && ArchiveFolders.Refusal(folders, folder, JunkFolder(folders)) is { } refusal)
            throw new FieldValidationException("folder", refusal);
        var saved = store.Save(clean);
        logger.LogInformation("[{Account}] cartella di archiviazione: '{Folder}'", CurrentAccount.Id, saved.Folder ?? "(nessuna)");
        return Ok(new ArchiveOptionsResponse(saved.Folder, Suggest(folders)));
    }

    /// <summary>
    /// POST …/messages/{folder}/archive {"uids"} — MODIFICA la casella: sposta le mail nella cartella di
    /// archiviazione. Senza cartella scelta, o con le mail già lì, 409 prima di ogni modifica.
    /// </summary>
    [HttpPost("messages/{folder}/archive")]
    [HttpPost("accounts/{accountId}/messages/{folder}/archive")]
    public async Task<ActionResult<BatchMoveResponse>> Archive(string folder, [FromBody] ArchiveRequest request, CancellationToken ct)
    {
        var uids = RequireUids(request.Uids);
        var account = CurrentAccount;
        var configured = Store.Load().Folder;
        var archive = ArchiveFolders.InUse(await account.Reader.GetFoldersAsync(ct), configured)
                      ?? throw new InvalidOperationException("Nessuna cartella di archiviazione: sceglierla con «Imposta cartella di archiviazione».");
        var name = FolderName.FromRoute(folder);
        if (name == archive)
            throw new InvalidOperationException("Le mail sono già nella cartella di archiviazione.");
        var result = await account.Writer.MoveAsync(name, uids, archive, ct);
        logger.LogInformation("[{Account}] ARCHIVIA {Folder} {Count} mail -> {Destination}", account.Id, name, result.Uids.Count, result.Destination);
        return Ok(new BatchMoveResponse(result.Destination, false, result.Uids));
    }

    private string? JunkFolder(IReadOnlyList<PostinoVip.Core.Models.MailFolderInfo> folders) =>
        JunkFolders.Resolve(folders, CurrentAccount.Junk?.Load().Folder);

    /// <summary>La proposta, solo se si può scegliere (mai una cartella speciale né la posta indesiderata in uso).</summary>
    private string? Suggest(IReadOnlyList<PostinoVip.Core.Models.MailFolderInfo> folders) =>
        ArchiveFolders.Suggest(folders) is { } s && ArchiveFolders.Refusal(folders, s, JunkFolder(folders)) is null ? s : null;

    private static IReadOnlyCollection<uint> RequireUids(uint[]? uids)
    {
        if (uids is null || uids.Length == 0)
            throw new FieldValidationException("uids", "Indicare almeno una mail.");
        if (uids.Length > MessagesController.MaxBatch)
            throw new FieldValidationException("uids", $"Al massimo {MessagesController.MaxBatch} mail per volta.");
        return uids.Distinct().ToList();
    }
}
