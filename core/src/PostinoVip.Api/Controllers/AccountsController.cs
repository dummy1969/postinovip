using Microsoft.AspNetCore.Mvc;
using PostinoVip.Api.Contracts;
using PostinoVip.Core.Account;

namespace PostinoVip.Api.Controllers;

[ApiController]
[Route("accounts")]
public sealed class AccountsController(MailAccountRegistry accounts) : ControllerBase
{
    /// <summary>GET /accounts — le caselle nell'ordine di configurazione; mai le password.</summary>
    [HttpGet]
    public ActionResult<IReadOnlyList<AccountInfo>> Get() =>
        Ok(accounts.All.Select(a => new AccountInfo(a.Id, a.Settings.DisplayName, a.Address, a.Configured, a.Online, a.Settings.Type, a.NeedsLogin,
            a.CardDav is not null, a.CalDav is not null)).ToList());

    /// <summary>
    /// POST /accounts/{accountId}/receive — "Invia/ricevi" (F9) per un account POP3 (4.2c): controlla subito il
    /// server (202; le mail nuove arrivano con l'evento mailbox-changed). Per gli account IMAP non serve
    /// (l'IDLE avvisa da solo): 202 senza fare nulla. Con CardDAV attivo sincronizza anche la rubrica (C4b).
    /// </summary>
    [HttpPost("{accountId}/receive")]
    public IActionResult Receive(string accountId)
    {
        var account = accounts.Get(accountId);
        account.Pop3?.Wake();
        account.CardDav?.Wake(); // anche i contatti (C4, 4a)
        account.CalDav?.Wake(); // e i calendari (K2a)
        return Accepted();
    }
}
