using PostinoVip.Core.Models;

namespace PostinoVip.Core.Cache;

/// <summary>
/// Flag IMAP salvati nella cache (bit propri, indipendenti dai tipi MailKit). Dal bit 32 sono
/// parole chiave IMAP (<see cref="MailKeywords"/>): contrassegno completato e categorie (3.3).
/// </summary>
[Flags]
public enum MailFlags
{
    None = 0,
    Seen = 1,
    Answered = 2,
    Flagged = 4,
    Deleted = 8,
    Draft = 16,
    Completed = 32,
    Category1 = 64,
    Category2 = 128,
    Category3 = 256,
    Category4 = 512,
    Category5 = 1024,
    Category6 = 2048,
    Categories = Category1 | Category2 | Category3 | Category4 | Category5 | Category6,

    /// <summary>«$MDNSent» (RFC 3503, R1): alla richiesta di conferma di lettura si è già risposto (inviata o no).</summary>
    MdnSent = 4096,

    /// <summary>
    /// «$MDNReceived»: la conferma di lettura di questa mail è arrivata. Lo scrive il server di prova (IceWarp) sulla
    /// mail originale quando riceve la conferma nella stessa casella, togliendo $MDNSent (verificato il 09/11/2026
    /// con tools/diagnosi-mdnsent.sh). Solo letto, mai scritto dal core.
    /// </summary>
    MdnReceived = 8192,

    /// <summary>Alla richiesta di conferma non si deve più rispondere.</summary>
    ReceiptHandled = MdnSent | MdnReceived,

    /// <summary>
    /// Posta indesiderata (J1): parole chiave «$Junk» (registro IANA, RFC 5788) e «Junk» (Thunderbird), scritte
    /// insieme da «Blocca mittente» e dal filtro; aiutano i server che imparano dalle scelte dell'utente.
    /// </summary>
    Junk = 16384,

    /// <summary>Non è posta indesiderata: «$NotJunk» (RFC 5788) e «NonJunk» (Thunderbird).</summary>
    NotJunk = 32768,
}

/// <summary>
/// Parole chiave IMAP dei flag che non sono di sistema. "$Completed" è già conosciuta dal server di
/// prova (IceWarp la elenca in FLAGS); le categorie hanno una parola fissa per colore, il nome
/// mostrato lo decide l'app.
/// </summary>
public static class MailKeywords
{
    public const string Completed = "$Completed";

    /// <summary>Conferma di lettura già trattata (RFC 3503).</summary>
    public const string MdnSent = "$MDNSent";

    /// <summary>Conferma di lettura arrivata (parola chiave del server, non standard).</summary>
    public const string MdnReceived = "$MDNReceived";

    /// <summary>Posta indesiderata: la parola registrata e quella di Thunderbird (il server di prova conosce la seconda).</summary>
    public static readonly string[] Junk = ["$Junk", "Junk"];

    /// <summary>Non è posta indesiderata: la parola registrata e quella di Thunderbird.</summary>
    public static readonly string[] NotJunk = ["$NotJunk", "NonJunk"];

    /// <summary>Categoria n (1–6) -> parola chiave; l'ordine segue i colori dell'app.</summary>
    public static readonly string[] Categories = ["$CatRossa", "$CatArancione", "$CatGialla", "$CatVerde", "$CatBlu", "$CatViola"];

    public static MailFlags Category(int number) =>
        number is >= 1 and <= 6 ? (MailFlags)((int)MailFlags.Category1 << (number - 1)) : throw new ArgumentOutOfRangeException(nameof(number));

    /// <summary>Numeri (1–6) delle categorie presenti in <paramref name="flags"/>.</summary>
    public static int[] CategoryNumbers(MailFlags flags) =>
        Enumerable.Range(1, 6).Where(n => flags.HasFlag(Category(n))).ToArray();

    /// <summary>Flag con parola chiave -> parole chiave; gli altri bit sono ignorati.</summary>
    public static IEnumerable<string> ToKeywords(MailFlags flags)
    {
        if (flags.HasFlag(MailFlags.Completed))
            yield return Completed;
        if (flags.HasFlag(MailFlags.MdnSent))
            yield return MdnSent;
        if (flags.HasFlag(MailFlags.Junk))
            foreach (var k in Junk)
                yield return k;
        if (flags.HasFlag(MailFlags.NotJunk))
            foreach (var k in NotJunk)
                yield return k;
        foreach (var n in CategoryNumbers(flags))
            yield return Categories[n - 1];
    }

    /// <summary>Parole chiave lette dal server -> flag (maiuscole e minuscole non contano, come in IMAP).</summary>
    public static MailFlags FromKeywords(IEnumerable<string>? keywords)
    {
        var result = MailFlags.None;
        foreach (var k in keywords ?? [])
        {
            if (string.Equals(k, Completed, StringComparison.OrdinalIgnoreCase))
                result |= MailFlags.Completed;
            if (string.Equals(k, MdnSent, StringComparison.OrdinalIgnoreCase))
                result |= MailFlags.MdnSent;
            if (string.Equals(k, MdnReceived, StringComparison.OrdinalIgnoreCase))
                result |= MailFlags.MdnReceived;
            if (Junk.Contains(k, StringComparer.OrdinalIgnoreCase))
                result |= MailFlags.Junk;
            if (NotJunk.Contains(k, StringComparer.OrdinalIgnoreCase))
                result |= MailFlags.NotJunk;
            var i = Array.FindIndex(Categories, c => string.Equals(c, k, StringComparison.OrdinalIgnoreCase));
            if (i >= 0)
                result |= Category(i + 1);
        }
        return result;
    }
}

/// <summary>
/// Intestazione di un messaggio come la salva la cache: dati grezzi dell'ENVELOPE (null se assenti),
/// i valori mostrati ("(nessun oggetto)"...) si ricavano alla lettura.
/// </summary>
public sealed record HeaderRecord(
    uint Uid,
    MailFlags Flags,
    string? Subject,
    string? FromName,
    string? FromAddress,
    string? To,
    string? Cc,
    DateTimeOffset? Date,
    DateTimeOffset? InternalDate,
    long? Size,
    string? MessageId,
    string? InReplyTo,
    string? Preview = null,
    bool? HasAttachments = null,
    DateOnly? FlagDue = null,
    string? References = null,
    MailImportance? Importance = null);

/// <summary>Anteprima del testo e presenza di allegati di un messaggio, letti dal server.</summary>
public sealed record PreviewRecord(uint Uid, string Preview, bool? HasAttachments);

/// <summary>
/// Una cartella del server già aperta in sola lettura, vista dalla sincronizzazione della cache.
/// Astratta da MailKit per poter provare l'algoritmo con una cartella finta.
/// </summary>
public interface IFolderSource
{
    /// <summary>Nome completo come lo restituisce il server (es. "INBOX", "Posta inviata").</summary>
    string FullName { get; }

    /// <summary>UIDVALIDITY: se cambia, gli UID salvati non valgono più.</summary>
    uint UidValidity { get; }

    /// <summary>Tutti gli UID presenti sul server (UID SEARCH ALL).</summary>
    Task<IReadOnlyList<uint>> GetUidsAsync(CancellationToken ct);

    /// <summary>
    /// Intestazioni, flag e struttura (allegati) dei messaggi indicati (quelli già spariti vengono ignorati).
    /// Con <paramref name="withPreview"/> anche l'anteprima del testo, che costa: il server di solito non
    /// la conosce e MailKit scarica l'inizio di ogni messaggio (512 byte di testo o fino a 16 KB di HTML).
    /// </summary>
    Task<IReadOnlyList<HeaderRecord>> FetchHeadersAsync(IReadOnlyList<uint> uids, bool withPreview, CancellationToken ct);

    /// <summary>Anteprima e presenza di allegati dei messaggi indicati (riempimento in background).</summary>
    Task<IReadOnlyList<PreviewRecord>> FetchPreviewsAsync(IReadOnlyList<uint> uids, CancellationToken ct);

    /// <summary>
    /// Intestazione References dei messaggi indicati (Message-ID separati da spazi, '' se assente):
    /// riempimento in background per i messaggi salvati prima delle conversazioni (3.6).
    /// </summary>
    Task<IReadOnlyList<(uint Uid, string References)>> FetchReferencesAsync(IReadOnlyList<uint> uids, CancellationToken ct);

    /// <summary>
    /// Importanza dei messaggi indicati (P1, intestazioni Importance / X-Priority / Priority): riempimento in background
    /// per i messaggi salvati prima dell'importanza.
    /// </summary>
    Task<IReadOnlyList<(uint Uid, MailImportance Importance)>> FetchImportanceAsync(IReadOnlyList<uint> uids, CancellationToken ct);

    /// <summary>Flag di tutti i messaggi della cartella.</summary>
    Task<IReadOnlyList<(uint Uid, MailFlags Flags)>> FetchFlagsAsync(CancellationToken ct);

    /// <summary>
    /// Il messaggio grezzo, passato a <paramref name="consume"/>; MailNotFoundException se non c'è più.
    /// </summary>
    Task ReadRawAsync(uint uid, Func<Stream, CancellationToken, Task> consume, CancellationToken ct);

    /// <summary>
    /// Ricerca sul server (IMAP SEARCH) nella cartella: UID dei messaggi che soddisfano i termini di
    /// <paramref name="query"/> (il filtro sugli allegati no: vedi <see cref="FetchHasAttachmentsAsync"/>).
    /// </summary>
    Task<IReadOnlyList<uint>> SearchAsync(MailSearchQuery query, CancellationToken ct);

    /// <summary>Se i messaggi indicati hanno allegati, dalla loro struttura (BODYSTRUCTURE).</summary>
    Task<IReadOnlyDictionary<uint, bool>> FetchHasAttachmentsAsync(IReadOnlyList<uint> uids, CancellationToken ct);
}

/// <summary>Una casella vista dal download in background: elenco cartelle e apertura in sola lettura.</summary>
public interface IMailboxSource
{
    Task<IReadOnlyList<MailFolderInfo>> GetFoldersAsync(CancellationToken ct = default);

    Task<T> ExamineAsync<T>(string folderName, Func<IFolderSource, Task<T>> action, CancellationToken ct = default);
}
