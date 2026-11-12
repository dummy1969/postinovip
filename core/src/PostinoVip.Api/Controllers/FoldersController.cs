using Microsoft.AspNetCore.Mvc;
using PostinoVip.Api.Contracts;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Models;

namespace PostinoVip.Api.Controllers;

[ApiController]
[Route("folders")]
[Route("accounts/{accountId}/folders")]
public sealed class FoldersController(MailAccountRegistry accounts, ILogger<FoldersController> logger) : MailControllerBase(accounts)
{
    public const int MaxLimit = 200;

    /// <summary>
    /// GET [/accounts/{accountId}]/folders — ruolo "junk" sulla posta indesiderata in uso (J1) e "archive" solo sulla
    /// cartella di archiviazione scelta (A1).
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<MailFolderInfo>>> GetFolders(CancellationToken ct)
    {
        var folders = PostinoVip.Core.Junk.JunkFolders.WithRole(await CurrentAccount.Reader.GetFoldersAsync(ct), CurrentAccount.Junk?.Load().Folder);
        return Ok(PostinoVip.Core.Archive.ArchiveFolders.WithRole(folders, CurrentAccount.Archive?.Load().Folder));
    }

    /// <summary>
    /// GET [/accounts/{accountId}]/folders/{folder}/messages?offset=0&amp;limit=20&amp;unread=false&amp;order=desc
    /// (offset 0 = più recente; order=asc dal più vecchio; unread=true solo da leggere).
    /// </summary>
    [HttpGet("{folder}/messages")]
    public async Task<ActionResult<MessagePage>> GetMessages(
        string folder, [FromQuery] int offset = 0, [FromQuery] int limit = 20, [FromQuery] bool unread = false,
        [FromQuery] string order = "desc", [FromQuery] string sort = "date", CancellationToken ct = default)
    {
        if (order is not ("desc" or "asc"))
            ModelState.AddModelError(nameof(order), "order deve essere desc o asc.");
        // sort (3.9): colonna dell'ordinamento, come il clic sull'intestazione in Outlook.
        if (!Enum.TryParse<MessageSort>(sort, ignoreCase: true, out var sortBy) || !Enum.IsDefined(sortBy) || int.TryParse(sort, out _))
            ModelState.AddModelError(nameof(sort), "sort deve essere date, from, subject o size.");
        if (offset < 0)
            ModelState.AddModelError(nameof(offset), "offset deve essere >= 0.");
        if (limit < 1 || limit > MaxLimit)
            ModelState.AddModelError(nameof(limit), $"limit deve essere tra 1 e {MaxLimit}.");
        if (!ModelState.IsValid)
            return ValidationProblem(ModelState);

        return Ok(await CurrentAccount.Reader.GetHeadersAsync(FolderName.FromRoute(folder), offset, limit, unread, order == "asc", ct,
            sortBy));
    }

    /// <summary>
    /// GET [/accounts/{accountId}]/folders/{folder}/conversations?offset=0&amp;limit=20&amp;unread=false&amp;order=desc
    /// (3.6): conversazioni della cartella dalla più recente, con le mail anche delle altre cartelle.
    /// Senza cache 501.
    /// </summary>
    [HttpGet("{folder}/conversations")]
    public async Task<ActionResult<ConversationPage>> GetConversations(
        string folder, [FromQuery] int offset = 0, [FromQuery] int limit = 20, [FromQuery] bool unread = false,
        [FromQuery] string order = "desc", CancellationToken ct = default)
    {
        if (order is not ("desc" or "asc"))
            ModelState.AddModelError(nameof(order), "order deve essere desc o asc.");
        if (offset < 0)
            ModelState.AddModelError(nameof(offset), "offset deve essere >= 0.");
        if (limit < 1 || limit > MaxLimit)
            ModelState.AddModelError(nameof(limit), $"limit deve essere tra 1 e {MaxLimit}.");
        if (!ModelState.IsValid)
            return ValidationProblem(ModelState);

        return Ok(await CurrentAccount.Reader.GetConversationsAsync(FolderName.FromRoute(folder), offset, limit, unread, order == "asc", ct));
    }

    /// <summary>
    /// POST [/accounts/{accountId}]/folders {"parent"?, "name"} — MODIFICA la casella: crea la cartella
    /// (201). Nome non valido o già usato -> 400 sul campo "name".
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<FolderChangeResponse>> CreateFolder(CreateFolderRequest request, CancellationToken ct)
    {
        var parent = string.IsNullOrEmpty(request.Parent) ? null : request.Parent;
        var created = await CurrentAccount.Writer.CreateFolderAsync(parent, request.Name ?? "", ct);
        // Solo nomi di cartelle (nessun dato delle mail): per capire cosa ha fatto il server.
        logger.LogInformation("[{Account}] cartella creata: '{FullName}' (separatore '{Separator}')",
            CurrentAccount.Id, created.FullName, created.Separator);
        return StatusCode(StatusCodes.Status201Created, new FolderChangeResponse(created.FullName, created.Separator.ToString()));
    }

    /// <summary>
    /// POST [/accounts/{accountId}]/folders/{folder}/rename {"name"} — MODIFICA la casella: rinomina
    /// (sottocartelle comprese). Nella copia locale cambiano solo i nomi: niente da riscaricare.
    /// </summary>
    [HttpPost("{folder}/rename")]
    public async Task<ActionResult<FolderChangeResponse>> RenameFolder(string folder, RenameFolderRequest request, CancellationToken ct)
    {
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        var renamed = await account.Writer.RenameFolderAsync(name, request.Name ?? "", ct);
        if (renamed.FullName != name)
            account.Bodies?.Cache.RenameFolderTree(name, renamed.FullName, renamed.Separator);
        return Ok(new FolderChangeResponse(renamed.FullName, renamed.Separator.ToString()));
    }

    /// <summary>
    /// POST [/accounts/{accountId}]/folders/{folder}/move {"parent"?} — MODIFICA la casella: sposta la
    /// cartella (sottocartelle comprese) dentro "parent" (assente = in cima). Nome già usato lì -> 400 sul
    /// campo "parent" (in Posta eliminata nome libero " (2)"...); cartelle speciali o dentro sé stessa -> 409.
    /// </summary>
    [HttpPost("{folder}/move")]
    public async Task<ActionResult<FolderChangeResponse>> MoveFolder(string folder, MoveFolderRequest request, CancellationToken ct)
    {
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        var parent = string.IsNullOrEmpty(request.Parent) ? null : request.Parent;
        var moved = await account.Writer.MoveFolderAsync(name, parent, ct);
        if (moved.FullName != name)
            account.Bodies?.Cache.RenameFolderTree(name, moved.FullName, moved.Separator);
        return Ok(new FolderChangeResponse(moved.FullName, moved.Separator.ToString()));
    }

    /// <summary>
    /// DELETE [/accounts/{accountId}]/folders/{folder} — MODIFICA la casella: sposta la cartella in Posta
    /// eliminata; se è già lì dentro la elimina DEFINITIVAMENTE (non reversibile). Cartelle speciali -> 409.
    /// </summary>
    [HttpDelete("{folder}")]
    public async Task<ActionResult<FolderDeleteResponse>> DeleteFolder(string folder, CancellationToken ct)
    {
        var account = CurrentAccount;
        var name = FolderName.FromRoute(folder);
        var result = await account.Writer.DeleteFolderAsync(name, ct);
        if (account.Bodies?.Cache is { } cache)
        {
            if (result.MovedTo is { } movedTo)
                cache.RenameFolderTree(name, movedTo, result.Separator);
            else
                cache.RemoveFolderTree(name, result.Separator);
        }
        return Ok(new FolderDeleteResponse(result.MovedTo, result.Permanent, result.Separator.ToString()));
    }
}
