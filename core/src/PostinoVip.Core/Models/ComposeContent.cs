namespace PostinoVip.Core.Models;

/// <summary>
/// Contenuto di una bozza (o di una mail della Posta in uscita) da riaprire nella composizione (3.8).
/// Html: quello che si era scritto, ripulito, immagini incorporate come "data:" (null se la mail è solo testo,
/// allora Text). QuoteHtml: la citazione che stava sotto (null se non c'era o se la bozza viene da un altro
/// programma: allora è tutta in Html). Attachments: gli allegati, da riprendere con GET .../attachments/{index}.
/// </summary>
public sealed record ComposeContent(
    IReadOnlyList<string> To,
    IReadOnlyList<string> Cc,
    string Subject,
    string? Html,
    string Text,
    string? InReplyTo,
    IReadOnlyList<string> References,
    string? QuoteHtml,
    IReadOnlyList<AttachmentInfo> Attachments,
    IReadOnlyList<string>? Bcc = null,
    MailImportance Importance = MailImportance.Normal,
    bool ReadReceipt = false);
