using System.Security.Cryptography;
using System.Text;
using MimeKit;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Contacts;

/// <summary>
/// Rubrica di un account (C1, scelta 6a): <c>accounts/&lt;id&gt;/contacts/&lt;id&gt;.vcf</c>, un vCard 3.0 per
/// contatto, scritto in modo atomico (.tmp + fsync + rename) con permessi privati. I file sono la fonte della
/// verità (per ora l'unica copia: 1c, CardDAV più avanti); restano anche con «Ricostruisci cache». Tenuti in
/// memoria dopo la prima lettura: li scrive solo il core. Con CardDAV (C4) li aggiorna anche la sincronizzazione
/// (<see cref="ApplyFromSync"/>, <see cref="RemoveFromSync"/>), che non fa scattare <see cref="LocalChanged"/>.
/// </summary>
public sealed class ContactStore(string directory)
{
    public const int MaxContacts = 20_000;
    public const int MaxValues = 20;
    public const int MaxTextLength = 200;
    public const int MaxNotesLength = 10_000;

    private static readonly ParserOptions Strict = new() { AddressParserComplianceMode = RfcComplianceMode.Strict };

    private readonly Lock _lock = new();
    private Dictionary<string, Contact>? _contacts;

    public string Directory { get; } = directory;

    /// <summary>Un contatto è cambiato per una richiesta dell'app (non per la sincronizzazione): CardDAV parte subito (4a).</summary>
    public event Action? LocalChanged;

    /// <summary>Tutti i contatti, in ordine di nome (senza maiuscole né accenti: «Élise» tra le E).</summary>
    public List<Contact> List()
    {
        lock (_lock)
            return Loaded().Values.OrderBy(c => TextFold.Fold(c.Name), StringComparer.Ordinal).ThenBy(c => c.Id).ToList();
    }

    public int Count
    {
        get
        {
            lock (_lock)
                return Loaded().Count;
        }
    }

    /// <summary>Il contatto; MailNotFoundException (404) se non c'è.</summary>
    public Contact Get(string id)
    {
        lock (_lock)
            return Loaded().TryGetValue(id, out var c) ? c : throw new MailNotFoundException("Contatto non trovato.").WithCode("contattoNonTrovato");
    }

    public Contact Create(Contact input)
    {
        var clean = Validate(input);
        lock (_lock)
        {
            if (Loaded().Count >= MaxContacts)
                throw new FieldValidationException("contact", $"La rubrica ha già {MaxContacts} contatti.").WithCode("laRubricaHaGiaContatti", ("maxContacts", MaxContacts));
            var created = Save(clean with { Id = NewId(), Updated = DateTimeOffset.UtcNow }, uid: "urn:uuid:" + Guid.NewGuid(), extra: []);
            Notify();
            return created;
        }
    }

    /// <summary>Sostituisce i campi del contatto; UID e proprietà vCard non gestite restano quelle di prima.</summary>
    public Contact Update(string id, Contact input)
    {
        var clean = Validate(input);
        lock (_lock)
        {
            var old = Loaded().TryGetValue(id, out var c) ? c : throw new MailNotFoundException("Contatto non trovato.").WithCode("contattoNonTrovato");
            var updated = Save(clean with { Id = id, Updated = DateTimeOffset.UtcNow }, old.VCardUid, old.Extra);
            Notify();
            return updated;
        }
    }

    public void Delete(string id)
    {
        lock (_lock)
        {
            if (!Loaded().Remove(id))
                throw new MailNotFoundException("Contatto non trovato.").WithCode("contattoNonTrovato");
            File.Delete(PathOf(id));
        }
        Notify();
    }

    /// <summary>
    /// Importa un file .vcf o .csv (byte così come sono: la codifica la riconosce <see cref="TextDecoding"/>).
    /// Un contatto con lo stesso nome e gli stessi indirizzi di uno presente non si aggiunge due volte.
    /// </summary>
    public ContactImportResult Import(byte[] data, string format)
    {
        var text = TextDecoding.Decode(data);
        var invalid = 0;
        var parsed = format.ToLowerInvariant() switch
        {
            "vcf" => VCard.Parse(text),
            "csv" => ContactCsv.Parse(text, out invalid),
            _ => throw new FieldValidationException("format", "Formato non riconosciuto: usare vcf o csv.").WithCode("formatoNonRiconosciutoUsareVcf"),
        };
        int imported = 0, duplicates = 0;
        lock (_lock)
        {
            var known = Loaded().Values.Select(Key).ToHashSet();
            foreach (var p in parsed)
            {
                Contact clean;
                try
                {
                    clean = Validate(p, lenient: true);
                }
                catch (FieldValidationException)
                {
                    invalid++;
                    continue;
                }
                if (!known.Add(Key(clean)))
                {
                    duplicates++;
                    continue;
                }
                if (Loaded().Count >= MaxContacts)
                {
                    invalid++;
                    continue;
                }
                Save(clean with { Id = NewId(), Updated = p.Updated ?? DateTimeOffset.UtcNow },
                    p.VCardUid ?? "urn:uuid:" + Guid.NewGuid(), p.Extra);
                imported++;
            }
        }
        if (imported > 0)
            Notify();
        return new ContactImportResult(imported, duplicates, invalid);
    }

    /// <summary>Tutta la rubrica come .vcf (vCard 3.0 uno dopo l'altro) o .csv (intestazioni di Outlook, UTF-8 con BOM).</summary>
    public byte[] Export(string format)
    {
        var contacts = List();
        return format.ToLowerInvariant() switch
        {
            "vcf" => Encoding.UTF8.GetBytes(string.Concat(contacts.Select(VCard.Write))),
            "csv" => [.. Encoding.UTF8.GetPreamble(), .. Encoding.UTF8.GetBytes(ContactCsv.Write(contacts))],
            _ => throw new FieldValidationException("format", "Formato non riconosciuto: usare vcf o csv.").WithCode("formatoNonRiconosciutoUsareVcf"),
        };
    }

    /// <summary>
    /// Controlli e pulizia (spazi, voci vuote). Almeno un nome, la società o un indirizzo; indirizzi validi
    /// (parser rigoroso, solo l'indirizzo); lunghezze limitate. <paramref name="lenient"/> (importazione):
    /// indirizzi non validi tolti invece di rifiutare il contatto.
    /// </summary>
    public static Contact Validate(Contact c, bool lenient = false)
    {
        string? Text(string? s, string field, int max = MaxTextLength)
        {
            if (string.IsNullOrWhiteSpace(s))
                return null;
            var t = s.Trim();
            if (t.Length > max)
            {
                if (!lenient)
                    throw new FieldValidationException(field, $"Al massimo {max} caratteri.");
                t = t[..max];
            }
            return t;
        }

        var emails = new List<ContactEmail>();
        foreach (var e in c.Emails ?? [])
        {
            if (string.IsNullOrWhiteSpace(e.Address))
                continue;
            var address = e.Address.Trim();
            if (!MailboxAddress.TryParse(Strict, address, out var parsed) || parsed.Address != address || !address.Contains('@'))
            {
                if (lenient)
                    continue;
                throw new FieldValidationException("emails", $"Indirizzo non valido: {address}").WithCode("indirizzoNonValido", ("address", address));
            }
            if (emails.Any(x => x.Address.Equals(address, StringComparison.OrdinalIgnoreCase)))
                continue;
            emails.Add(new ContactEmail(address, Label(e.Label, "work", "home", "other")));
        }
        var phones = new List<ContactPhone>();
        foreach (var p in c.Phones ?? [])
        {
            var number = Text(p.Number, "phones", 50);
            if (number is not null)
                phones.Add(new ContactPhone(number, Label(p.Label, "mobile", "work", "home", "other")));
        }
        if (emails.Count > MaxValues || phones.Count > MaxValues)
        {
            if (!lenient)
                throw new FieldValidationException(emails.Count > MaxValues ? "emails" : "phones", $"Al massimo {MaxValues} voci.");
            emails = emails.Take(MaxValues).ToList();
            phones = phones.Take(MaxValues).ToList();
        }
        var clean = new Contact(c.Id ?? "", Text(c.GivenName, "givenName"), Text(c.FamilyName, "familyName"),
            Text(c.DisplayName, "displayName"), emails, phones, Text(c.Company, "company"), Text(c.Notes, "notes", MaxNotesLength),
            c.Updated);
        if (clean.GivenName is null && clean.FamilyName is null && clean.DisplayName is null && clean.Company is null && emails.Count == 0)
            throw new FieldValidationException("contact", "Scrivere almeno un nome, la società o un indirizzo.").WithCode("scrivereAlmenoUnNomeLa");
        return clean;
    }

    /// <summary>Il contatto, null se non c'è.</summary>
    public Contact? Find(string id)
    {
        lock (_lock)
            return Loaded().GetValueOrDefault(id);
    }

    /// <summary>
    /// Impronta del contenuto (campi, proprietà vCard conservate e ora della modifica): diversa = contatto cambiato
    /// dall'ultima sincronizzazione. Indipendente dall'id e dal modo in cui il file è scritto.
    /// </summary>
    public static string Fingerprint(Contact c)
    {
        var text = System.Text.Json.JsonSerializer.Serialize(new object?[]
        {
            c.VCardUid, c.GivenName, c.FamilyName, c.DisplayName, c.Emails.Select(e => new[] { e.Address, e.Label }),
            c.Phones.Select(p => new[] { p.Number, p.Label }), c.Company, c.Notes, c.Extra, c.Updated?.ToUnixTimeSeconds(),
        });
        return Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(text)));
    }

    /// <summary>Chiave dei doppioni (stesso nome e stessi indirizzi), usata anche dalla prima sincronizzazione (2a).</summary>
    public static string DuplicateKey(Contact c) => Key(c);

    /// <summary>
    /// Scrive un contatto arrivato dal server (C4): con <paramref name="id"/> sostituisce quello (o lo ricrea con lo
    /// stesso id se è stato eliminato), altrimenti ne crea uno nuovo. UID, proprietà conservate e ora della modifica
    /// sono quelle di <paramref name="incoming"/>. Con <paramref name="expectedFingerprint"/> il contatto si sostituisce
    /// solo se nel frattempo non è stato cambiato dall'app. Non fa scattare <see cref="LocalChanged"/>.
    /// </summary>
    public SyncApply ApplyFromSync(string? id, Contact incoming, string? expectedFingerprint = null)
    {
        Contact clean;
        try
        {
            clean = Validate(incoming, lenient: true);
        }
        catch (FieldValidationException)
        {
            return new SyncApply(null, SyncApplyOutcome.Invalid);
        }
        lock (_lock)
        {
            var contacts = Loaded();
            if (id is not null && contacts.TryGetValue(id, out var current))
            {
                if (expectedFingerprint is not null && Fingerprint(current) != expectedFingerprint)
                    return new SyncApply(current, SyncApplyOutcome.ChangedMeanwhile);
            }
            else if (contacts.Count >= MaxContacts)
                return new SyncApply(null, SyncApplyOutcome.Full);
            var saved = Save(clean with { Id = id is not null && IsValidId(id) ? id : NewId() }, incoming.VCardUid, incoming.Extra);
            return new SyncApply(saved, SyncApplyOutcome.Saved);
        }
    }

    /// <summary>
    /// Elimina un contatto eliminato sul server (C4); false se nel frattempo l'app l'ha cambiato (si conserva, 3a)
    /// o se non c'è più. Non fa scattare <see cref="LocalChanged"/>.
    /// </summary>
    public bool RemoveFromSync(string id, string expectedFingerprint)
    {
        lock (_lock)
        {
            if (!Loaded().TryGetValue(id, out var current) || Fingerprint(current) != expectedFingerprint)
                return false;
            Loaded().Remove(id);
            File.Delete(PathOf(id));
            return true;
        }
    }

    private void Notify() => LocalChanged?.Invoke();

    private static string? Label(string? label, params string[] allowed) =>
        label is not null && allowed.Contains(label) ? label : null;

    /// <summary>Chiave dei doppioni: nome e indirizzi, senza distinzione di maiuscole.</summary>
    private static string Key(Contact c) =>
        (c.Name + "\n" + string.Join("\n", c.Emails.Select(e => e.Address).Order(StringComparer.OrdinalIgnoreCase))).ToLowerInvariant();

    private Contact Save(Contact contact, string? uid, IReadOnlyList<string> extra)
    {
        var stored = contact with { VCardUid = uid, Extra = extra };
        CachePermissions.CreatePrivateDirectory(Path.GetDirectoryName(Directory)!);
        CachePermissions.CreatePrivateDirectory(Directory);
        var path = PathOf(stored.Id);
        var temp = path + ".tmp";
        CachePermissions.CreatePrivateFile(temp);
        using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
        {
            file.Write(Encoding.UTF8.GetBytes(VCard.Write(stored)));
            file.Flush(flushToDisk: true);
        }
        File.Move(temp, path, overwrite: true);
        Loaded()[stored.Id] = stored;
        return stored;
    }

    private Dictionary<string, Contact> Loaded()
    {
        if (_contacts is not null)
            return _contacts;
        var contacts = new Dictionary<string, Contact>();
        if (System.IO.Directory.Exists(Directory))
        {
            foreach (var file in System.IO.Directory.EnumerateFiles(Directory, "*.vcf"))
            {
                var id = Path.GetFileNameWithoutExtension(file);
                if (!IsValidId(id))
                    continue;
                try
                {
                    // Un file = un contatto; un file illeggibile si salta (resta sul disco, non si perde).
                    if (VCard.Parse(TextDecoding.Decode(File.ReadAllBytes(file))).FirstOrDefault() is { } c)
                        contacts[id] = c with { Id = id };
                }
                catch (IOException)
                {
                }
            }
        }
        return _contacts = contacts;
    }

    private string PathOf(string id) =>
        IsValidId(id) ? Path.Combine(Directory, id + ".vcf") : throw new MailNotFoundException("Contatto non trovato.").WithCode("contattoNonTrovato");

    public static bool IsValidId(string id) => id.Length is > 0 and <= 32 && id.All(char.IsAsciiHexDigitLower);

    private static string NewId() => Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(8));
}

public enum SyncApplyOutcome { Saved, Invalid, ChangedMeanwhile, Full }

/// <summary>Esito di <see cref="ContactStore.ApplyFromSync"/>: il contatto scritto (o quello attuale, se cambiato nel frattempo).</summary>
public sealed record SyncApply(Contact? Contact, SyncApplyOutcome Outcome);
