using Microsoft.AspNetCore.Mvc;
using PostinoVip.Core.Account;

namespace PostinoVip.Api;

/// <summary>
/// Base dei controller che lavorano su una casella. Ogni controller risponde a due percorsi:
/// /accounts/{accountId}/... (account indicato) e quello senza account (il primo configurato,
/// come quando l'app ne gestiva uno solo).
/// </summary>
public abstract class MailControllerBase(MailAccountRegistry accounts) : ControllerBase
{
    /// <summary>L'account della richiesta; 404 se l'id non esiste.</summary>
    protected MailAccount CurrentAccount =>
        accounts.Get(RouteData.Values.TryGetValue("accountId", out var id) ? id as string : null);

    /// <summary>Un altro account per id (es. origine degli allegati inoltrati); 404 se non esiste.</summary>
    protected MailAccount AccountById(string id) => accounts.Get(id);
}
