namespace PostinoVip.Core.Models;

/// <summary>
/// Allegato elencato nel dettaglio messaggio. Index è la posizione in MimeMessage.Attachments
/// e identifica l'allegato in GET /messages/{folder}/{uid}/attachments/{index}.
/// </summary>
public sealed record AttachmentInfo(int Index, string FileName, string ContentType);
