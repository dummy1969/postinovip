namespace PostinoVip.Core.Models;

/// <summary>
/// Intestazione sintetica di un messaggio (per la lista). Seen = flag \Seen sul server.
/// Preview: inizio del testo (null = non ancora noto, "" = senza testo). HasAttachments: null = non noto.
/// Received: arrivo sul server (INTERNALDATE), usato dalla lista per ordine e gruppi.
/// Flagged/Completed: contrassegno (\Flagged, parola chiave $Completed); Due: scadenza, solo locale;
/// Categories: numeri 1–6 delle categorie (parole chiave IMAP). Size: dimensione in byte (RFC822.SIZE), null se non nota.
/// Importance (P1): priorità alta o bassa indicata dal mittente; Normal anche se non ancora letta.
/// </summary>
public sealed record MessageHeader(uint Uid, string Subject, string From, DateTimeOffset? Date, bool Seen,
    string? Preview = null, bool? HasAttachments = null, DateTimeOffset? Received = null,
    bool Flagged = false, bool Completed = false, DateOnly? Due = null, int[]? Categories = null, long? Size = null,
    MailImportance Importance = MailImportance.Normal);
