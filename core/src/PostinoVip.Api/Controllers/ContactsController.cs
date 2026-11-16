using Microsoft.AspNetCore.Mvc;
using PostinoVip.Core;
using PostinoVip.Core.Account;
using PostinoVip.Core.Contacts;
using PostinoVip.Core.Contacts.CardDav;
using PostinoVip.Core.Dav;

namespace PostinoVip.Api.Controllers;

/// <summary>Dati di un contatto mandati dall'app (l'id viene dal percorso, il resto lo calcola il core).</summary>
public sealed record ContactRequest(string? GivenName, string? FamilyName, string? DisplayName, List<ContactEmail>? Emails,
    List<ContactPhone>? Phones, string? Company, string? Notes)
{
    public Contact ToContact() => new("", GivenName, FamilyName, DisplayName, Emails ?? [], Phones ?? [], Company, Notes);
}

/// <summary>Importazione: file .vcf o .csv così com'è, in base64 (la codifica la riconosce il core).</summary>
public sealed record ContactImportRequest(string Format, string Data);

public sealed record ContactListResponse(IReadOnlyList<Contact> Items);

/// <summary>
/// Rubrica dell'account (C1): nella cartella della copia locale (6a). Queste richieste non toccano mai la casella;
/// con CardDAV attivo (C4b) le modifiche vanno poi sul server con la sincronizzazione, che parte subito dopo.
/// </summary>
[ApiController]
[Route("contacts")]
[Route("accounts/{accountId}/contacts")]
public sealed class ContactsController(MailAccountRegistry accounts) : MailControllerBase(accounts)
{
    public const long MaxImportBytes = 10 * 1024 * 1024;

    private ContactStore Store =>
        CurrentAccount.Contacts ?? throw new NotSupportedException("I contatti richiedono la copia locale (Cache:Enabled=false).").WithCode("contattiRichiedonoLaCopiaLocale");

    [HttpGet]
    public ActionResult<ContactListResponse> List() => Ok(new ContactListResponse(Store.List()));

    [HttpGet("{id}")]
    public ActionResult<Contact> Get(string id) => Ok(Store.Get(id));

    [HttpPost]
    public ActionResult<Contact> Create([FromBody] ContactRequest request)
    {
        var contact = Store.Create(request.ToContact());
        return StatusCode(StatusCodes.Status201Created, contact);
    }

    [HttpPut("{id}")]
    public ActionResult<Contact> Update(string id, [FromBody] ContactRequest request) => Ok(Store.Update(id, request.ToContact()));

    [HttpDelete("{id}")]
    public IActionResult Delete(string id)
    {
        Store.Delete(id);
        return NoContent();
    }

    /// <summary>POST …/contacts/import — aggiunge i contatti del file; quelli già presenti non si duplicano.</summary>
    [HttpPost("import")]
    [RequestSizeLimit(16 * 1024 * 1024)]
    public ActionResult<ContactImportResult> Import([FromBody] ContactImportRequest request)
    {
        byte[] data;
        try
        {
            data = Convert.FromBase64String(request.Data ?? "");
        }
        catch (FormatException)
        {
            throw new FieldValidationException("data", "Contenuto del file non valido.").WithCode("contenutoDelFileNonValido");
        }
        if (data.Length > MaxImportBytes)
            throw new FieldValidationException("data", "File troppo grande (al massimo 10 MB).").WithCode("fileTroppoGrandeAlMassimo");
        return Ok(Store.Import(data, request.Format ?? ""));
    }

    /// <summary>
    /// GET …/contacts/sync — stato della sincronizzazione CardDAV (C4b): spenta per l'account = Enabled false;
    /// NeedsConfirmation = ci sono PendingUpload contatti solo sul computer da caricare dopo la conferma (2a).
    /// </summary>
    [HttpGet("sync")]
    public ActionResult<DavStatus> SyncStatus() =>
        Ok(CurrentAccount.CardDav?.Status ?? new DavStatus(false, "off", null, null, false, 0, null));

    /// <summary>POST …/contacts/sync — sincronizza subito (202); 409 se non è attiva per l'account.</summary>
    [HttpPost("sync")]
    public IActionResult SyncNow()
    {
        Worker().Wake();
        return Accepted();
    }

    /// <summary>
    /// POST …/contacts/sync/confirm — **modifica la rubrica del server**: i contatti solo sul computer vengono caricati
    /// (scelta 2a, dopo la conferma nell'app). 202, la sincronizzazione parte subito.
    /// </summary>
    [HttpPost("sync/confirm")]
    public IActionResult ConfirmSync()
    {
        Worker().Confirm();
        return Accepted();
    }

    private DavWorker Worker() =>
        CurrentAccount.CardDav ?? throw new InvalidOperationException("La sincronizzazione dei contatti non è attiva per questo account.").WithCode("laSincronizzazioneDeiContattiNon2");

    /// <summary>GET …/contacts/export?format=vcf|csv — tutta la rubrica come file.</summary>
    [HttpGet("export")]
    public IActionResult Export([FromQuery] string format = "vcf")
    {
        var data = Store.Export(format);
        var csv = format.Equals("csv", StringComparison.OrdinalIgnoreCase);
        return File(data, csv ? "text/csv; charset=utf-8" : "text/vcard; charset=utf-8", csv ? "Contatti.csv" : "Contatti.vcf");
    }
}

public sealed record SuggestionsResponse(IReadOnlyList<AddressSuggestion> Items);

/// <summary>
/// Completamento degli indirizzi in composizione (3a): contatti e indirizzi usati di recente di tutti gli account.
/// </summary>
[ApiController]
[Route("addresses")]
public sealed class AddressesController(MailAccountRegistry accounts) : ControllerBase
{
    /// <summary>GET /addresses/suggest?q=&amp;limit= — al massimo 50, predefinito 10.</summary>
    [HttpGet("suggest")]
    public ActionResult<SuggestionsResponse> Suggest([FromQuery] string? q, [FromQuery] int limit = 10)
    {
        if (limit is < 1 or > 50)
            throw new FieldValidationException("limit", "Da 1 a 50.").WithCode("da50");
        var books = accounts.All.Select(a => (a.Id, a.Contacts, a.Recent));
        return Ok(new SuggestionsResponse(AddressSuggestions.Find(books, q ?? "", limit, DateTimeOffset.UtcNow)));
    }

    /// <summary>DELETE /addresses/recent?address= — la ✕: l'indirizzo non viene più suggerito (in tutti gli account).</summary>
    [HttpDelete("recent")]
    public IActionResult RemoveRecent([FromQuery] string? address)
    {
        if (string.IsNullOrWhiteSpace(address))
            throw new FieldValidationException("address", "Indirizzo mancante.").WithCode("indirizzoMancante");
        foreach (var a in accounts.All)
            a.Recent?.Remove(address.Trim());
        return NoContent();
    }
}
