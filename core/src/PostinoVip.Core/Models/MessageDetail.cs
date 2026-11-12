namespace PostinoVip.Core.Models;

/// <summary>
/// Messaggio completo: intestazioni, corpo testo/HTML (se presenti) e nomi degli allegati.
/// HtmlBody è già sanificato; HasRemoteImages indica immagini caricate da Internet.
/// Contrassegno e categorie come in <see cref="MessageHeader"/> (noti solo con la cache).
/// FromAddress: l'indirizzo del mittente (From mostra il nome, se c'è), per "Crea regola…" (R2).
/// ReceiptTo: il mittente chiede una conferma di lettura a questo indirizzo (R1, solo se uguale al mittente: vedi
/// ReadReceipts.RequestedBy); ReceiptHandled: già trattata ($MDNSent, o $MDNReceived del server; noto solo con la copia locale).
/// </summary>
public sealed record MessageDetail(
    uint Uid,
    string Subject,
    string From,
    IReadOnlyList<string> To,
    IReadOnlyList<string> Cc,
    DateTimeOffset? Date,
    string? TextBody,
    string? HtmlBody,
    bool HasRemoteImages,
    IReadOnlyList<AttachmentInfo> Attachments,
    bool Flagged = false,
    bool Completed = false,
    DateOnly? Due = null,
    int[]? Categories = null,
    string? FromAddress = null,
    MailImportance Importance = MailImportance.Normal,
    string? ReceiptTo = null,
    bool ReceiptHandled = false);
