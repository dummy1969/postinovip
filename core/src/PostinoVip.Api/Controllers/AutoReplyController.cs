using Microsoft.AspNetCore.Mvc;
using PostinoVip.Core.Account;
using PostinoVip.Core.AutoReply;

namespace PostinoVip.Api.Controllers;

/// <summary>Impostazioni delle risposte automatiche con lo stato attuale (Active: si inviano adesso).</summary>
public sealed record AutoReplyResponse(bool Enabled, DateTimeOffset? Start, DateTimeOffset? End, string Html, string Text,
    string? Document, bool Active);

/// <summary>
/// Risposte automatiche dell'account: le invia il core alle mail nuove della Posta in arrivo (con l'app aperta).
/// Salvare con Enabled = true MODIFICA il comportamento verso l'esterno: da quel momento partono risposte senza
/// conferma, con i filtri fissi di AutoReplyPolicy.
/// </summary>
[ApiController]
[Route("autoreply")]
[Route("accounts/{accountId}/autoreply")]
public sealed class AutoReplyController(MailAccountRegistry accounts) : MailControllerBase(accounts)
{
    private AutoReplyStore Store =>
        CurrentAccount.AutoReply ?? throw new NotSupportedException("Le risposte automatiche richiedono la copia locale.");

    [HttpGet]
    public ActionResult<AutoReplyResponse> Get() => Ok(ToResponse(Store.Load()));

    [HttpPut]
    public ActionResult<AutoReplyResponse> Put([FromBody] AutoReplySettings settings) => Ok(ToResponse(Store.Save(settings)));

    private static AutoReplyResponse ToResponse(AutoReplySettings s) =>
        new(s.Enabled, s.Start, s.End, s.Html, s.Text, s.Document, s.IsActive(DateTimeOffset.UtcNow));
}
