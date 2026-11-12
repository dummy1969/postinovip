using MailKit;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Eml;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Mime;
using PostinoVip.Core.Models;

namespace PostinoVip.Api.Controllers;

/// <summary>Un file .eml aperto: id da usare negli altri endpoint e la mail come GET /messages/{folder}/{uid}.</summary>
public sealed record EmlOpened(string Id, MessageDetail Message);

/// <summary>
/// File .eml aperti nell'app (E1): sola lettura, in memoria, nessuna modifica alla casella. L'account della rotta
/// serve solo alla bozza di risposta (il proprio indirizzo, escluso da «Rispondi a tutti»).
/// </summary>
[ApiController]
[Route("eml")]
[Route("accounts/{accountId}/eml")]
public sealed class EmlController(MailAccountRegistry accounts, EmlStore store, ILogger<EmlController> logger)
    : MailControllerBase(accounts)
{
    /// <summary>Le mail con allegati grandi possono superare il limite predefinito di Kestrel (~28,6 MB).</summary>
    public const long MaxBytes = 100_000_000;

    /// <summary>Uid finto della mail aperta (MessageDetail ne vuole uno; l'app usa l'id).</summary>
    private static readonly UniqueId FileUid = new(1);

    /// <summary>POST /eml — corpo: i byte del file .eml. Risposta {id, message}; 400 se non è una mail.</summary>
    [HttpPost]
    [RequestSizeLimit(MaxBytes)]
    public async Task<ActionResult<EmlOpened>> Open(CancellationToken ct)
    {
        MimeKit.MimeMessage message;
        try
        {
            message = await EmlStore.ParseAsync(Request.Body, ct);
        }
        catch (InvalidEmlException ex)
        {
            throw new FieldValidationException("file", ex.Message);
        }
        var id = store.Open(message);
        // Solo numeri, mai contenuti.
        logger.LogInformation("eml aperto: {Attachments} allegati, {Open} file aperti", Attachments.List(message).Count, store.Count);
        return Ok(new EmlOpened(id, MessageHeaderMapper.FromMimeMessage(FileUid, message)));
    }

    /// <summary>GET /eml/{id} — la mail aperta (come alla prima apertura).</summary>
    [HttpGet("{id}")]
    public ActionResult<MessageDetail> Get(string id) => Ok(MessageHeaderMapper.FromMimeMessage(FileUid, store.Get(id)));

    /// <summary>GET /eml/{id}/attachments/{index} — un allegato, come per le mail della casella.</summary>
    [HttpGet("{id}/attachments/{index:int:min(0)}")]
    public IActionResult GetAttachment(string id, int index)
    {
        var attachment = Attachments.Extract(store.Get(id), index)
            ?? throw new MailNotFoundException($"Allegato {index} non trovato.");
        return File(attachment.Data, attachment.ContentType, attachment.FileName);
    }

    /// <summary>GET [/accounts/{accountId}]/eml/{id}/draft?mode=reply|replyAll|forward — bozza precompilata, non invia.</summary>
    [HttpGet("{id}/draft")]
    public ActionResult<ComposeDraft> GetDraft(string id, [FromQuery, BindRequired] DraftMode mode) =>
        Ok(DraftBuilder.Build(store.Get(id), mode, CurrentAccount.Address));

    /// <summary>DELETE /eml/{id} — chiude il file (finestra chiusa nell'app). 204 anche se era già chiuso.</summary>
    [HttpDelete("{id}")]
    public IActionResult Close(string id)
    {
        store.Close(id);
        return NoContent();
    }
}
