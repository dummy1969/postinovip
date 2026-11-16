using Microsoft.AspNetCore.Mvc;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Events;

namespace PostinoVip.Api.Controllers;

/// <summary>
/// Gestione della copia locale, su richiesta dell'utente (pagina Account dell'app). Non tocca mai il server.
/// </summary>
[ApiController]
public sealed class CacheController(MailAccountRegistry accounts, CacheSettings cache, MailboxEventHub hub) : ControllerBase
{
    private string Root => cache.Root ?? throw new NotSupportedException("Cache locale disattivata (Cache:Enabled=false).");

    private IReadOnlyCollection<string> ConfiguredIds => accounts.All.Select(a => a.Id).ToHashSet();

    /// <summary>GET /cache/orphans — dati locali di account non più configurati (rimossi dall'app).</summary>
    [HttpGet("cache/orphans")]
    public ActionResult<IReadOnlyList<OrphanCache>> GetOrphans() => Ok(CacheAccounts.ListOrphans(Root, ConfiguredIds));

    /// <summary>DELETE /cache/orphans/{id} — elimina quei dati (richiesta esplicita, con conferma nell'app).</summary>
    [HttpDelete("cache/orphans/{id}")]
    public IActionResult DeleteOrphan(string id)
    {
        CacheAccounts.DeleteOrphan(Root, id, ConfiguredIds);
        return NoContent();
    }

    /// <summary>
    /// POST /accounts/{accountId}/cache/rebuild — svuota la copia locale dell'account e la fa riscaricare
    /// dal download in background (evento "cache-rebuilt").
    /// </summary>
    [HttpPost("accounts/{accountId}/cache/rebuild")]
    public IActionResult Rebuild(string accountId)
    {
        var account = accounts.Get(accountId);
        // POP3 (4.2, scelta 5a): non c'è un server da cui ricostruire, le mail sono solo sul computer.
        if (account.IsPop3)
            throw new InvalidOperationException("Account POP3: le mail sono solo sul computer, non c'è una copia da ricostruire dal server.").WithCode("accountPop3LeMailSono");
        var bodies = account.Bodies ?? throw new NotSupportedException("Cache locale disattivata (Cache:Enabled=false).");
        bodies.Cache.Reset();
        hub.Publish(MailboxEvent.CacheRebuilt(account.Id));
        return Accepted();
    }
}
