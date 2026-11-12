using Microsoft.AspNetCore.Mvc;
using PostinoVip.Core.Account;
using PostinoVip.Core.Calendars;
using PostinoVip.Core.Dav;

namespace PostinoVip.Api.Controllers;

/// <summary>Un calendario dell'account: id, nome, se è collegato a un calendario del server (CalDAV), numero di appuntamenti.</summary>
/// <summary><see cref="ReadOnly"/> (G2): calendario di sola lettura sul server (es. festività): niente scritture.</summary>
public sealed record CalendarResponse(string Id, string Name, bool Synced, int Count, bool ReadOnly = false);

public sealed record CalendarListResponse(IReadOnlyList<CalendarResponse> Items);

/// <summary>Un appuntamento scritto dall'app (K2b): vedi <see cref="EventInput"/>.</summary>
public sealed record EventRequest(string? Summary, string? Location, string? Description, string? Start, string? End, bool AllDay,
    string? TimeZone, int? ReminderMinutes, EventRecurrence? Recurrence, bool KeepRecurrence)
{
    public EventInput ToInput() =>
        new(Summary, Location, Description, Start ?? "", End ?? "", AllDay, TimeZone, ReminderMinutes, Recurrence, KeepRecurrence);
}

/// <summary>
/// Calendari dell'account (K2a): sul computer, nella cartella della copia locale; con CalDAV attivo collegati ai calendari
/// del server che accettano appuntamenti. Queste richieste non toccano mai la casella; le modifiche (K2b) vanno poi sul
/// server con la sincronizzazione.
/// </summary>
[ApiController]
[Route("calendars")]
[Route("accounts/{accountId}/calendars")]
public sealed class CalendarsController(MailAccountRegistry accounts) : MailControllerBase(accounts)
{
    private CalendarSet Set =>
        CurrentAccount.Calendars ?? throw new NotSupportedException("I calendari richiedono la copia locale (Cache:Enabled=false).");

    /// <summary>GET …/calendars — i calendari nell'ordine in cui si mostrano (il primo è quello predefinito).</summary>
    [HttpGet]
    public ActionResult<CalendarListResponse> List() =>
        Ok(new CalendarListResponse(Set.List().Select(c => new CalendarResponse(c.Id, c.Name, c.Href is not null, Set.Store(c.Id).Count, c.ReadOnly)).ToList()));

    /// <summary>
    /// GET …/calendars/sync — stato della sincronizzazione CalDAV: spenta = Enabled false; NeedsConfirmation = ci sono
    /// PendingUpload appuntamenti solo sul computer da caricare dopo la conferma (2a); AddressBook = nome del calendario
    /// (o «N calendari»).
    /// </summary>
    [HttpGet("sync")]
    public ActionResult<DavStatus> SyncStatus() =>
        Ok(CurrentAccount.CalDav?.Status ?? new DavStatus(false, "off", null, null, false, 0, null));

    /// <summary>POST …/calendars/sync — sincronizza subito (202); 409 se non è attiva per l'account.</summary>
    [HttpPost("sync")]
    public IActionResult SyncNow()
    {
        Worker().Wake();
        return Accepted();
    }

    /// <summary>
    /// POST …/calendars/sync/confirm — **modifica i calendari del server**: gli appuntamenti solo sul computer vengono
    /// caricati (scelta 2a, dopo la conferma nell'app). 202, la sincronizzazione parte subito.
    /// </summary>
    [HttpPost("sync/confirm")]
    public IActionResult ConfirmSync()
    {
        Worker().Confirm();
        return Accepted();
    }

    /// <summary>
    /// GET …/calendars/events?from=&amp;to=&amp;calendars= — le occorrenze del periodo [from, to) (istanti ISO 8601 con fuso,
    /// al massimo 400 giorni) nei calendari indicati (id separati da virgole; assente = tutti), ricorrenze espanse.
    /// </summary>
    [HttpGet("events")]
    public ActionResult<OccurrencePage> Events([FromQuery] string? from, [FromQuery] string? to, [FromQuery] string? calendars)
    {
        var start = ParseInstant(from, "from");
        var end = ParseInstant(to, "to");
        var ids = string.IsNullOrWhiteSpace(calendars)
            ? Set.List().Select(c => c.Id).ToList()
            : calendars.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();
        foreach (var id in ids)
            Set.Get(id); // calendario sconosciuto -> 404
        return Ok(CalendarEvents.Occurrences(Set, ids, start, end));
    }

    /// <summary>GET …/calendars/{calendarId}/events/{eventId} — la serie (dettaglio per la finestra Appuntamento).</summary>
    [HttpGet("{calendarId}/events/{eventId}")]
    public ActionResult<EventDetail> GetEvent(string calendarId, string eventId) =>
        Ok(CalendarEvents.Detail(calendarId, Item(calendarId, eventId)));

    /// <summary>POST …/calendars/{calendarId}/events — nuovo appuntamento (201); con CalDAV va poi sul server.</summary>
    [HttpPost("{calendarId}/events")]
    public ActionResult<EventDetail> CreateEvent(string calendarId, [FromBody] EventRequest request)
    {
        var store = Writable(calendarId);
        var item = store.SaveLocal(null, CalendarEvents.Create(request.ToInput()));
        return StatusCode(StatusCodes.Status201Created, CalendarEvents.Detail(calendarId, item));
    }

    /// <summary>
    /// PUT …/calendars/{calendarId}/events/{eventId} — modifica la serie (solo i campi indicati; il resto del testo resta).
    /// Con keepRecurrence la ricorrenza non si tocca.
    /// </summary>
    [HttpPut("{calendarId}/events/{eventId}")]
    public ActionResult<EventDetail> UpdateEvent(string calendarId, string eventId, [FromBody] EventRequest request)
    {
        var current = Item(calendarId, eventId);
        var item = Writable(calendarId).SaveLocal(eventId, CalendarEvents.Update(current.Text, request.ToInput()));
        return Ok(CalendarEvents.Detail(calendarId, item));
    }

    /// <summary>DELETE …/calendars/{calendarId}/events/{eventId} — elimina la serie (204); con CalDAV anche dal server.</summary>
    [HttpDelete("{calendarId}/events/{eventId}")]
    public IActionResult DeleteEvent(string calendarId, string eventId)
    {
        Writable(calendarId).DeleteLocal(eventId);
        return NoContent();
    }

    /// <summary>
    /// GET …/calendars/{calendarId}/events/{eventId}/occurrence?recurrenceId= — una sola occorrenza di una serie (K4a):
    /// quella modificata, o i dati della serie con la sua ora. recurrenceId come nelle occorrenze del periodo.
    /// </summary>
    [HttpGet("{calendarId}/events/{eventId}/occurrence")]
    public ActionResult<EventDetail> GetOccurrence(string calendarId, string eventId, [FromQuery] string? recurrenceId) =>
        Ok(CalendarEvents.OccurrenceDetail(calendarId, Item(calendarId, eventId), Required(recurrenceId)));

    /// <summary>PUT …/occurrence?recurrenceId= — modifica solo questa occorrenza (eccezione nella serie); la serie non cambia.</summary>
    [HttpPut("{calendarId}/events/{eventId}/occurrence")]
    public ActionResult<EventDetail> UpdateOccurrence(string calendarId, string eventId, [FromQuery] string? recurrenceId,
        [FromBody] EventRequest request)
    {
        var id = Required(recurrenceId);
        var current = Item(calendarId, eventId);
        var item = Writable(calendarId).SaveLocal(eventId, CalendarEvents.UpdateOccurrence(current.Text, id, request.ToInput()));
        return Ok(CalendarEvents.OccurrenceDetail(calendarId, item, id));
    }

    /// <summary>DELETE …/occurrence?recurrenceId= — elimina solo questa occorrenza (EXDATE nella serie), 204.</summary>
    [HttpDelete("{calendarId}/events/{eventId}/occurrence")]
    public IActionResult DeleteOccurrence(string calendarId, string eventId, [FromQuery] string? recurrenceId)
    {
        var current = Item(calendarId, eventId);
        Writable(calendarId).SaveLocal(eventId, CalendarEvents.DeleteOccurrence(current.Text, Required(recurrenceId)));
        return NoContent();
    }

    /// <summary>L'archivio di un calendario in cui si può scrivere; di sola lettura sul server (G2, 1a) -> 409.</summary>
    private CalendarStore Writable(string calendarId)
    {
        var info = Set.Get(calendarId);
        if (info.ReadOnly)
            throw new InvalidOperationException($"Il calendario «{info.Name}» è di sola lettura: non si possono creare, modificare o eliminare appuntamenti.");
        return Set.Store(calendarId);
    }

    private static string Required(string? recurrenceId) =>
        string.IsNullOrWhiteSpace(recurrenceId)
            ? throw new PostinoVip.Core.FieldValidationException("recurrenceId", "Occorrenza mancante.") : recurrenceId;

    private CalendarItem Item(string calendarId, string eventId) =>
        Set.Store(calendarId).Find(eventId) ?? throw new PostinoVip.Core.MailNotFoundException("Appuntamento non trovato.");

    private static DateTimeOffset ParseInstant(string? value, string field) =>
        DateTimeOffset.TryParse(value, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.AssumeUniversal, out var t)
            ? t : throw new PostinoVip.Core.FieldValidationException(field, "Istante non valido (ISO 8601, es. 2026-11-10T00:00:00+01:00).");

    private DavWorker Worker() =>
        CurrentAccount.CalDav ?? throw new InvalidOperationException("La sincronizzazione del calendario non è attiva per questo account.");
}
