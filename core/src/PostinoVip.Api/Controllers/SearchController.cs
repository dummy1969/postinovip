using Microsoft.AspNetCore.Mvc;
using PostinoVip.Core.Account;
using PostinoVip.Core.Models;

namespace PostinoVip.Api.Controllers;

[ApiController]
[Route("search")]
[Route("accounts/{accountId}/search")]
public sealed class SearchController(MailAccountRegistry accounts) : MailControllerBase(accounts)
{
    public const int MaxLimit = 200;
    public const int MaxQueryLength = 500;

    /// <summary>
    /// GET [/accounts/{accountId}]/search?q=fattura da:anna&amp;folder=INBOX&amp;offset=0&amp;limit=50
    /// Cerca nella cache locale dell'account (tutte le cartelle, o solo <paramref name="folder"/>),
    /// dal più recente. Parole trovate nell'estratto racchiuse tra i caratteri U+0002 e U+0003.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<SearchResult>> Search(
        [FromQuery] string? q, [FromQuery] string? folder = null, [FromQuery] int offset = 0, [FromQuery] int limit = 50,
        CancellationToken ct = default) =>
        Validate(q, offset, limit) is { } invalid
            ? invalid
            : Ok(await CurrentAccount.Reader.SearchAsync(q!, NullIfEmpty(folder), offset, limit, ct));

    /// <summary>
    /// GET [/accounts/{accountId}]/search/server?q=...&amp;folder=...: ricerca sul server (IMAP SEARCH) per le
    /// mail il cui corpo non è nella cache locale. Più lenta: l'app la chiede solo su richiesta dell'utente.
    /// </summary>
    [HttpGet("server")]
    public async Task<ActionResult<SearchResult>> SearchServer(
        [FromQuery] string? q, [FromQuery] string? folder = null, [FromQuery] int offset = 0, [FromQuery] int limit = 50,
        CancellationToken ct = default) =>
        Validate(q, offset, limit) is { } invalid
            ? invalid
            : Ok(await CurrentAccount.Reader.SearchServerAsync(q!, NullIfEmpty(folder), offset, limit, ct));

    private static string? NullIfEmpty(string? s) => string.IsNullOrEmpty(s) ? null : s;

    private ActionResult? Validate(string? q, int offset, int limit)
    {
        if (string.IsNullOrWhiteSpace(q))
            ModelState.AddModelError(nameof(q), "Scrivere cosa cercare.");
        else if (q.Length > MaxQueryLength)
            ModelState.AddModelError(nameof(q), $"Ricerca troppo lunga (massimo {MaxQueryLength} caratteri).");
        if (offset < 0)
            ModelState.AddModelError(nameof(offset), "offset deve essere >= 0.");
        if (limit < 1 || limit > MaxLimit)
            ModelState.AddModelError(nameof(limit), $"limit deve essere tra 1 e {MaxLimit}.");
        return ModelState.IsValid ? null : ValidationProblem(ModelState);
    }
}
