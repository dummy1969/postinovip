namespace PostinoVip.Core.Models;

/// <summary>
/// Messaggio da inviare. To deve contenere almeno un indirizzo.
/// InReplyTo/References (Message-ID senza &lt; &gt;) collegano una risposta al thread originale.
/// HtmlBody (3.7b): testo formattato scritto nell'app; con esso la mail è multipart/alternative con Body
/// come versione in testo. Quote: citazione dell'originale aggiunta in fondo a entrambe le versioni.
/// Bcc (Ccn): destinatari nascosti; l'intestazione resta nella bozza e nella copia in Posta inviata, ma non parte
/// con la mail (MailKit la toglie inviando: verificato da SmtpBccTests).
/// Importance (P1): «Priorità alta» / «Priorità bassa», scritta come Outlook (Importance e X-Priority).
/// </summary>
public sealed record OutgoingMessage(
    string From,
    IReadOnlyList<string> To,
    IReadOnlyList<string> Cc,
    string Subject,
    string Body,
    string? InReplyTo = null,
    IReadOnlyList<string>? References = null,
    IReadOnlyList<OutgoingAttachment>? Attachments = null,
    string? HtmlBody = null,
    Compose.MessageQuote? Quote = null,
    IReadOnlyList<string>? Bcc = null,
    MailImportance Importance = MailImportance.Normal,
    bool ReadReceipt = false);
