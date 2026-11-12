using System.Text.Json.Serialization;

namespace PostinoVip.Core.Contacts;

/// <summary>Indirizzo email di un contatto; <paramref name="Label"/>: "work", "home", "other" o null.</summary>
public sealed record ContactEmail(string Address, string? Label = null);

/// <summary>Telefono di un contatto; <paramref name="Label"/>: "mobile", "work", "home", "other" o null.</summary>
public sealed record ContactPhone(string Number, string? Label = null);

/// <summary>
/// Contatto della rubrica di un account (C1, scelta 2a: nome, cognome, più indirizzi, telefoni, società, note).
/// Sul disco è un file vCard 3.0 (<see cref="VCard"/>), pronto per la sincronizzazione CardDAV (1c).
/// <paramref name="Id"/>: nome del file (esadecimale, dato dal core); <paramref name="DisplayName"/> vuoto =
/// calcolato da nome e cognome (<see cref="Name"/>).
/// </summary>
public sealed record Contact(
    string Id,
    string? GivenName,
    string? FamilyName,
    string? DisplayName,
    IReadOnlyList<ContactEmail> Emails,
    IReadOnlyList<ContactPhone> Phones,
    string? Company,
    string? Notes,
    DateTimeOffset? Updated = null)
{
    /// <summary>UID del vCard (stabile, serve a CardDAV): non passa dall'app.</summary>
    [JsonIgnore]
    public string? VCardUid { get; init; }

    /// <summary>Proprietà vCard non gestite (indirizzi postali, compleanno, foto…) conservate così come sono.</summary>
    [JsonIgnore]
    public IReadOnlyList<string> Extra { get; init; } = [];

    /// <summary>Nome mostrato: quello scritto, altrimenti "Nome Cognome", la società o il primo indirizzo.</summary>
    public string Name =>
        NonEmpty(DisplayName)
        ?? NonEmpty(string.Join(' ', new[] { GivenName, FamilyName }.Where(p => !string.IsNullOrWhiteSpace(p)).Select(p => p!.Trim())))
        ?? NonEmpty(Company)
        ?? Emails.FirstOrDefault()?.Address
        ?? "(senza nome)";

    private static string? NonEmpty(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}

/// <summary>Esito di un'importazione: aggiunti, già presenti (stesso nome e stessi indirizzi), scartati (vuoti o non validi).</summary>
public sealed record ContactImportResult(int Imported, int Duplicates, int Invalid);
