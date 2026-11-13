namespace PostinoVip.Core.Models;

public enum DraftMode { Reply, ReplyAll, Forward }

/// <summary>
/// Bozza precompilata per risposta/inoltro, da completare e inviare con POST /send.
/// ForwardAttachments: allegati dell'originale da includere nell'inoltro (solo modalità Forward).
/// </summary>
public sealed record ComposeDraft(
    IReadOnlyList<string> To,
    IReadOnlyList<string> Cc,
    string Subject,
    string Body,
    string? InReplyTo,
    IReadOnlyList<string> References,
    IReadOnlyList<AttachmentInfo>? ForwardAttachments = null)
{
    /// <summary>
    /// Anteprima formattata della citazione (intestazione Da/Inviato/A/Oggetto e originale ripulito, immagini
    /// incorporate come "data:"): l'app la mostra sotto l'editor; all'invio il core la ricostruisce dall'originale.
    /// </summary>
    public string? QuoteHtml { get; init; }

    /// <summary>
    /// L'originale è di solo testo (nessuna parte text/html): come Outlook, la risposta o l'inoltro si scrivono in
    /// testo normale (13/11/2026, scelta 3a).
    /// </summary>
    public bool PlainText { get; init; }
}
