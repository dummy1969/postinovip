using MimeKit;
using PostinoVip.Core.Models;

namespace PostinoVip.Core;

/// <summary>
/// Operazioni che MODIFICANO la casella. Separate da IMailReader per renderle evidenti:
/// ognuna va dichiarata e confermata prima di essere introdotta (vedi CLAUDE.md).
/// </summary>
public interface IMailWriter
{
    /// <summary>Imposta o toglie il flag \Seen; restituisce lo stato effettivo dopo la modifica.</summary>
    Task<bool> SetSeenAsync(string folder, uint uid, bool seen, CancellationToken ct = default);

    /// <summary>
    /// Aggiunge e toglie contrassegno, "completato" e categorie (solo <see cref="Cache.MailFlags.Flagged"/>,
    /// <see cref="Cache.MailFlags.Completed"/> e le categorie); restituisce i flag letti dal server dopo la modifica.
    /// </summary>
    Task<Cache.MailFlags> UpdateFlagsAsync(string folder, uint uid, Cache.MailFlags add, Cache.MailFlags remove,
        CancellationToken ct = default);

    /// <summary>
    /// Aggiunge (APPEND) il messaggio, già segnato come letto, alla cartella con ruolo \Sent.
    /// Restituisce il nome della cartella. MailNotFoundException se il server non ne dichiara una.
    /// </summary>
    Task<string> AppendToSentAsync(MimeMessage message, CancellationToken ct = default);

    /// <summary>
    /// MODIFICA la casella (3.8): salva la bozza in Bozze (\Drafts, flag \Draft) e, con <paramref name="replaceUid"/>,
    /// elimina definitivamente la bozza precedente, solo dopo che la nuova è stata salvata.
    /// </summary>
    Task<DraftSaved> SaveDraftAsync(MimeKit.MimeMessage message, uint? replaceUid, CancellationToken ct = default);

    /// <summary>MODIFICA la casella: elimina definitivamente una bozza di Bozze (dopo l'invio); non trovata = niente.</summary>
    Task DeleteDraftAsync(uint uid, CancellationToken ct = default);

    /// <summary>Sposta il messaggio in un'altra cartella; restituisce il nome della destinazione.</summary>
    Task<string> MoveAsync(string folder, uint uid, string destination, CancellationToken ct = default);

    /// <summary>"Elimina": sposta nella cartella con ruolo \Trash; restituisce il suo nome.</summary>
    Task<string> MoveToTrashAsync(string folder, uint uid, CancellationToken ct = default);

    /// <summary>Eliminazione DEFINITIVA, consentita solo nella cartella con ruolo \Trash. Non reversibile.</summary>
    Task DeletePermanentlyAsync(string folder, uint uid, CancellationToken ct = default);

    // In blocco (3.5a): un solo comando IMAP per l'insieme degli UID. Le mail che non esistono più
    // (eliminate da un altro programma) vengono ignorate: il risultato dice quali sono state trattate.

    /// <summary>\Seen su più mail; stato letto dal server dopo la modifica, solo per le mail trovate.</summary>
    Task<IReadOnlyDictionary<uint, bool>> SetSeenAsync(string folder, IReadOnlyCollection<uint> uids, bool seen,
        CancellationToken ct = default);

    /// <summary>Contrassegno, completato e categorie su più mail; flag dopo la modifica, solo per le mail trovate.</summary>
    Task<IReadOnlyDictionary<uint, Cache.MailFlags>> UpdateFlagsAsync(string folder, IReadOnlyCollection<uint> uids,
        Cache.MailFlags add, Cache.MailFlags remove, CancellationToken ct = default);

    /// <summary>Sposta più mail in un'altra cartella dello stesso account.</summary>
    Task<BatchResult> MoveAsync(string folder, IReadOnlyCollection<uint> uids, string destination, CancellationToken ct = default);

    /// <summary>
    /// Copia più mail in un'altra cartella dello stesso account (UID COPY); gli originali restano.
    /// Stessa cartella -> InvalidOperationException.
    /// </summary>
    Task<BatchResult> CopyAsync(string folder, IReadOnlyCollection<uint> uids, string destination, CancellationToken ct = default);

    /// <summary>"Elimina" più mail: le sposta nella cartella con ruolo \Trash.</summary>
    Task<BatchResult> MoveToTrashAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default);

    /// <summary>Eliminazione DEFINITIVA di più mail, solo dentro la cartella con ruolo \Trash. Non reversibile.</summary>
    Task<BatchResult> DeletePermanentlyAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default);

    /// <summary>
    /// Crea la cartella <paramref name="name"/> dentro <paramref name="parent"/> (null = in cima alla casella).
    /// Nome non valido o già usato lì -> FieldValidationException("name").
    /// </summary>
    Task<FolderChange> CreateFolderAsync(string? parent, string name, CancellationToken ct = default);

    /// <summary>
    /// Rinomina la cartella restando nella stessa cartella madre; le sottocartelle la seguono.
    /// Cartelle con un ruolo (o che ne contengono una) -> InvalidOperationException.
    /// </summary>
    Task<FolderChange> RenameFolderAsync(string folder, string newName, CancellationToken ct = default);

    /// <summary>
    /// "Elimina cartella" come Outlook: la sposta (con mail e sottocartelle) dentro la cartella \Trash;
    /// se è già lì dentro la elimina DEFINITIVAMENTE (non reversibile). Cartelle con un ruolo -> InvalidOperationException.
    /// </summary>
    Task<FolderDeletion> DeleteFolderAsync(string folder, CancellationToken ct = default);

    /// <summary>
    /// Sposta la cartella (con mail e sottocartelle) dentro <paramref name="newParent"/> (null = in cima
    /// alla casella), con lo stesso nome. Nome già usato lì -> FieldValidationException("parent"), tranne
    /// in Posta eliminata, dove si prende un nome libero (" (2)"...). Cartelle con un ruolo, destinazione
    /// dentro la cartella stessa o che non ammette sottocartelle -> InvalidOperationException.
    /// </summary>
    Task<FolderChange> MoveFolderAsync(string folder, string? newParent, CancellationToken ct = default);

    /// <summary>
    /// "Svuota cartella" come Outlook: elimina DEFINITIVAMENTE tutte le mail della cartella (solo gli UID trovati, mai
    /// EXPUNGE dell'intera cartella) e, con <paramref name="subfolders"/>, le sue sottocartelle con le loro mail. Non
    /// reversibile. Ammessa solo per Posta eliminata (con le sottocartelle) e Posta indesiderata: lo controlla chi chiama,
    /// che conosce la cartella della posta indesiderata scelta per l'account.
    /// </summary>
    Task<FolderEmptied> EmptyFolderAsync(string folder, bool subfolders, CancellationToken ct = default);
}
