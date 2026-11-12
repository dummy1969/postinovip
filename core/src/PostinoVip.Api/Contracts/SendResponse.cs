namespace PostinoVip.Api.Contracts;

/// <summary>
/// Esito di POST /send. Inviata: ServerResponse è la risposta SMTP, SavedTo la cartella della copia, SaveError il
/// motivo se la copia era richiesta ma non è riuscita. In coda (3.8): Queued, con OutboxId e SendAfter (null =
/// appena il server risponde: OfflineQueued). Altrimenti la risposta è un errore.
/// </summary>
public sealed record SendResponse(
    string? ServerResponse,
    string? SavedTo = null,
    string? SaveError = null,
    bool Queued = false,
    string? OutboxId = null,
    DateTimeOffset? SendAfter = null,
    bool OfflineQueued = false);

/// <summary>Esito di POST /drafts: in Bozze sul server (Folder, Uid) o sul computer in attesa (Pending, LocalId).</summary>
public sealed record DraftResponse(string? Folder, uint? Uid, bool Pending, string? LocalId);

/// <summary>Una mail della Posta in uscita (GET .../outbox).</summary>
public sealed record OutboxEntry(string Id, string Subject, IReadOnlyList<string> To, DateTimeOffset Created,
    DateTimeOffset? SendAfter, string? Error);
