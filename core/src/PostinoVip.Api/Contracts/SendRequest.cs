using System.ComponentModel.DataAnnotations;

namespace PostinoVip.Api.Contracts;

/// <summary>
/// Contenuto di una mail scritta nell'app, comune all'invio e al salvataggio come bozza (3.8). Il mittente è
/// l'account del percorso. Per l'invio serve almeno un destinatario (errore sul campo "to").
/// </summary>
public class ComposeRequest
{
    public List<string> To { get; set; } = [];

    public List<string> Cc { get; set; } = [];

    /// <summary>Ccn: destinatari nascosti (non compaiono nella mail che ricevono gli altri).</summary>
    public List<string> Bcc { get; set; } = [];

    [Required(AllowEmptyStrings = true)] public string Subject { get; set; } = "";
    [Required(AllowEmptyStrings = true)] public string Body { get; set; } = "";

    /// <summary>
    /// Testo formattato (3.7b): con esso la mail è HTML + testo (Body = versione in testo). Il core lo
    /// ripulisce; le immagini "data:" diventano parti incorporate.
    /// </summary>
    public string? HtmlBody { get; set; }

    /// <summary>
    /// Risposta o inoltro: il core riprende l'originale e ne aggiunge in fondo la citazione (testo e HTML),
    /// come nell'anteprima della bozza. Body e HtmlBody contengono allora solo quello che si è scritto.
    /// </summary>
    public QuoteSource? Quote { get; set; }

    /// <summary>Solo per le risposte: Message-ID dell'originale e catena References (da GET .../draft).</summary>
    public string? InReplyTo { get; set; }
    public List<string> References { get; set; } = [];

    /// <summary>
    /// MODIFICA la casella: salva una copia in Posta inviata (APPEND). Falso se omesso,
    /// così una chiamata manuale (curl) non scrive nella casella senza volerlo.
    /// </summary>
    public bool SaveCopy { get; set; }

    /// <summary>File da allegare (in JSON il contenuto è base64).</summary>
    public List<AttachmentUpload> Attachments { get; set; } = [];

    /// <summary>Inoltro: allegati del messaggio originale da includere, ripresi dal server IMAP.</summary>
    public ForwardAttachments? ForwardAttachments { get; set; }

    /// <summary>Importanza (P1): "high", "low" o "normal" (anche assente).</summary>
    public PostinoVip.Core.Models.MailImportance Importance { get; set; }

    /// <summary>«Richiedi conferma di lettura» (R1): Disposition-Notification-To con il mittente.</summary>
    public bool ReadReceipt { get; set; }
}

/// <summary>Corpo di POST [/accounts/{accountId}]/send.</summary>
public sealed class SendRequest : ComposeRequest
{
    /// <summary>
    /// "Ritarda recapito" (3.8): prima di questo momento la mail resta nella Posta in uscita del computer e parte
    /// da sola dopo (con l'app aperta). Nel passato o assente: subito.
    /// </summary>
    public DateTimeOffset? SendAfter { get; set; }

    /// <summary>Bozza da eliminare una volta inviata la mail (quella che si stava scrivendo).</summary>
    public DraftRef? DeleteDraft { get; set; }
}

/// <summary>Corpo di POST [/accounts/{accountId}]/drafts: salva la bozza al posto di <see cref="Replace"/>.</summary>
public sealed class DraftRequest : ComposeRequest
{
    public DraftRef? Replace { get; set; }
}

/// <summary>Una bozza: in Bozze sul server (<see cref="Uid"/>) o ancora sul computer in attesa di connessione (<see cref="LocalId"/>).</summary>
public sealed class DraftRef
{
    public uint? Uid { get; set; }
    public string? LocalId { get; set; }
}

/// <summary>
/// Citazione: dall'originale (<see cref="Folder"/>, <see cref="Uid"/>, <see cref="Mode"/>) oppure già pronta
/// in <see cref="Html"/> (bozza riaperta, 3.8: l'originale può non esserci più).
/// </summary>
public sealed class QuoteSource
{
    /// <summary>Account del messaggio originale; se manca, lo stesso da cui si invia.</summary>
    public string? Account { get; set; }

    public string? Folder { get; set; }
    public uint Uid { get; set; }

    /// <summary>Oppure un file .eml aperto (E1): il suo id al posto di cartella e uid.</summary>
    public string? Eml { get; set; }

    /// <summary>reply, replyAll o forward (come ?mode= della bozza).</summary>
    public string? Mode { get; set; }

    public string? Html { get; set; }
}

public sealed class AttachmentUpload
{
    [Required(AllowEmptyStrings = false)] public string FileName { get; set; } = "";

    /// <summary>Facoltativo: se manca il core lo ricava dall'estensione.</summary>
    public string? ContentType { get; set; }

    [Required] public byte[] Data { get; set; } = [];
}

public sealed class ForwardAttachments
{
    /// <summary>
    /// Account in cui si trova il messaggio originale; se manca, lo stesso da cui si invia.
    /// Serve quando si inoltra cambiando il mittente.
    /// </summary>
    public string? Account { get; set; }

    /// <summary>Obbligatoria, tranne per un file .eml aperto (<see cref="Eml"/>).</summary>
    public string? Folder { get; set; }
    public uint Uid { get; set; }

    /// <summary>Id di un file .eml aperto (E1) al posto di cartella e uid.</summary>
    public string? Eml { get; set; }

    public List<int> Indexes { get; set; } = [];
}
