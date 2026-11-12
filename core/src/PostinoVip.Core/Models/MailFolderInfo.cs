namespace PostinoVip.Core.Models;

/// <summary>
/// Cartella della casella, indipendente dai tipi MailKit.
/// SpecialUse è il ruolo dichiarato dal server (RFC 6154 SPECIAL-USE: "sent", "trash", "drafts",
/// "junk", "archive", "all", "flagged") oppure null; "inbox" per INBOX.
/// Unread: messaggi non letti (STATUS UNSEEN; senza connessione dalla copia locale), null se non noto.
/// </summary>
public sealed record MailFolderInfo(string FullName, string Name, int? Count, string? SpecialUse = null, int? Unread = null);
