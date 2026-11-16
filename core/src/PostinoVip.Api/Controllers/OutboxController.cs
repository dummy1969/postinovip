using Microsoft.AspNetCore.Mvc;
using PostinoVip.Api.Contracts;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Events;
using PostinoVip.Core.Outbox;

namespace PostinoVip.Api.Controllers;

/// <summary>Posta in uscita del computer (3.8): mail in attesa di invio, una coda per account.</summary>
[ApiController]
[Route("outbox")]
[Route("accounts/{accountId}/outbox")]
public sealed class OutboxController(MailAccountRegistry accounts, MailboxEventHub hub, OutboxSignal outboxSignal)
    : MailControllerBase(accounts)
{
    private OutboxStore Store =>
        CurrentAccount.Outbox ?? throw new NotSupportedException("La Posta in uscita richiede la cache locale (Cache:Enabled=false).").WithCode("laPostaInUscitaRichiede");

    /// <summary>GET — mail in attesa, dalla più vecchia; Error = l'ultimo invio non è riuscito.</summary>
    [HttpGet]
    public ActionResult<IReadOnlyList<OutboxEntry>> List() =>
        Ok(Store.List().Where(i => i.Kind == OutboxKind.Send)
            .Select(i => new OutboxEntry(i.Id, i.Subject, i.To, i.Created, i.SendAfter, i.Error)).ToList());

    /// <summary>DELETE {id} — la mail non verrà inviata (eliminata dal computer, non era sul server).</summary>
    [HttpDelete("{id}")]
    public IActionResult Delete(string id)
    {
        var store = Store;
        if (store.Get(id) is not { Kind: OutboxKind.Send } || !store.Remove(id))
            throw new MailNotFoundException("Mail non trovata nella Posta in uscita.").WithCode("mailNonTrovataNellaPosta");
        Changed(store);
        return NoContent();
    }

    /// <summary>POST {id}/send — "Invia ora": niente più attesa né errore precedente; parte al prossimo passaggio.</summary>
    [HttpPost("{id}/send")]
    public IActionResult SendNow(string id)
    {
        var store = Store;
        var item = store.Get(id) is { Kind: OutboxKind.Send } found ? found : throw new MailNotFoundException("Mail non trovata nella Posta in uscita.").WithCode("mailNonTrovataNellaPosta");
        store.Update(item with { SendAfter = null, Error = null });
        outboxSignal.Wake();
        Changed(store);
        return Accepted();
    }

    /// <summary>
    /// POST {id}/to-drafts — MODIFICA la casella: la mail torna in Bozze sul server (per modificarla) e non viene
    /// più inviata. Serve la connessione.
    /// </summary>
    [HttpPost("{id}/to-drafts")]
    public async Task<ActionResult<DraftResponse>> ToDrafts(string id, CancellationToken ct)
    {
        var store = Store;
        if (store.Get(id) is not { Kind: OutboxKind.Send } || store.LoadMessage(id) is not { } message)
            throw new MailNotFoundException("Mail non trovata nella Posta in uscita.").WithCode("mailNonTrovataNellaPosta");
        var saved = await CurrentAccount.Writer.SaveDraftAsync(message, null, ct);
        store.Remove(id);
        Changed(store);
        return Ok(new DraftResponse(saved.Folder, saved.Uid, Pending: false, LocalId: null));
    }

    private void Changed(OutboxStore store) => hub.Publish(MailboxEvent.OutboxChanged(CurrentAccount.Id, store.SendCount));
}
