using System.Text.Json.Serialization;

namespace PostinoVip.Core.Junk;

/// <summary>
/// Livello del filtro automatico, come in Outlook classico (Opzioni posta indesiderata). Outlook ha un filtro suo
/// sul contenuto; qui (scelta 2a) i livelli usano il giudizio che il server scrive nella mail (SpamAssassin e simili).
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter<JunkLevel>))]
public enum JunkLevel
{
    /// <summary>Nessun filtro automatico: si spostano solo le mail dei mittenti bloccati.</summary>
    None,

    /// <summary>Bassa: anche le mail che il server segna come spam (X-Spam-Flag: YES e simili).</summary>
    Low,

    /// <summary>Alta: anche quelle con un punteggio vicino alla soglia del server (<see cref="JunkClassifier.HighMargin"/>).</summary>
    High,

    /// <summary>Solo elenchi attendibili: tutto ciò che non viene da mittenti o verso destinatari attendibili.</summary>
    SafeListsOnly,
}

/// <summary>
/// Opzioni posta indesiderata di un account (5a: per account, nel core). Voci degli elenchi: un indirizzo
/// ("anna@esempio.it") o un dominio ("@esempio.it"), in minuscolo. <see cref="Folder"/>: la cartella della posta
/// indesiderata scelta dall'utente (3b); null = quella dichiarata dal server o riconosciuta dal nome
/// (<see cref="JunkFolders"/>).
/// </summary>
public sealed record JunkSettings
{
    public JunkLevel Level { get; init; } = JunkLevel.None;
    public string? Folder { get; init; }

    /// <summary>«Considera attendibili anche i miei contatti» (Outlook la ha attiva di serie).</summary>
    public bool TrustContacts { get; init; } = true;

    public IReadOnlyList<string> SafeSenders { get; init; } = [];

    /// <summary>Destinatari attendibili: mail inviate a questi indirizzi (es. una mailing list) mai indesiderate.</summary>
    public IReadOnlyList<string> SafeRecipients { get; init; } = [];

    public IReadOnlyList<string> BlockedSenders { get; init; } = [];
}

/// <summary>Fin dove il filtro ha già esaminato la Posta in arrivo (UIDVALIDITY e ultimo UID), come le regole.</summary>
public sealed record JunkProgress(uint? UidValidity, uint LastUid);
