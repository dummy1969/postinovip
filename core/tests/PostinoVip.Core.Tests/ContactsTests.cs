using System.Text;
using Microsoft.Data.Sqlite;
using MimeKit;
using PostinoVip.Core;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Contacts;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

// Contatti (C1): vCard, CSV di Outlook e Google, rubrica su file, indirizzi recenti e suggerimenti.
public class ContactsTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-contacts-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private ContactStore NewStore() => new(Path.Combine(_dir, "accounts", "a1", "contacts"));

    private static Contact Mario => new("", "Mario", "Rossi", null,
        [new ContactEmail("mario.rossi@example.com", "work"), new ContactEmail("mario@casa.example", "home")],
        [new ContactPhone("+39 333 1234567", "mobile"), new ContactPhone("02 1234567", "work")],
        "Rossi; Figli, S.r.l.", "Prima riga\nSeconda, con virgola");

    // ---------------------------------------------------------------------------------------------
    // vCard
    // ---------------------------------------------------------------------------------------------

    [Fact]
    public void VCardScrittoERilettoUguale()
    {
        var text = VCard.Write(Mario with { VCardUid = "urn:uuid:1" });
        Assert.Contains("VERSION:3.0\r\n", text);
        Assert.Contains("N:Rossi;Mario;;;\r\n", text);
        Assert.Contains("ORG:Rossi\\; Figli\\, S.r.l.\r\n", text);
        Assert.Contains("EMAIL;TYPE=INTERNET,WORK:mario.rossi@example.com\r\n", text);
        Assert.Contains("TEL;TYPE=CELL:+39 333 1234567\r\n", text);
        Assert.Contains("NOTE:Prima riga\\nSeconda\\, con virgola\r\n", text);

        var back = Assert.Single(VCard.Parse(text));
        Assert.Equal("Mario", back.GivenName);
        Assert.Equal("Rossi", back.FamilyName);
        Assert.Null(back.DisplayName); // FN = "Mario Rossi": resta calcolato
        Assert.Equal("Mario Rossi", back.Name);
        Assert.Equal(Mario.Emails, back.Emails);
        Assert.Equal(Mario.Phones, back.Phones);
        Assert.Equal(Mario.Company, back.Company);
        Assert.Equal(Mario.Notes, back.Notes);
        Assert.Equal("urn:uuid:1", back.VCardUid);
    }

    [Fact]
    public void RigheLungheRipiegateSenzaSpezzareICaratteri()
    {
        var notes = string.Concat(Enumerable.Repeat("àèìòù€ ", 40));
        var text = VCard.Write(Mario with { Notes = notes });
        foreach (var line in text.Split("\r\n"))
            Assert.True(Encoding.UTF8.GetByteCount(line) <= 75, line);
        Assert.Equal(notes.Trim(), Assert.Single(VCard.Parse(text)).Notes!.Trim());
    }

    [Fact]
    public void VCard21DiOutlookConQuotedPrintableEPiuSchede()
    {
        const string text = """
            BEGIN:VCARD
            VERSION:2.1
            N;CHARSET=Windows-1252;ENCODING=QUOTED-PRINTABLE:Nicol=F2;Luca
            FN;CHARSET=Windows-1252;ENCODING=QUOTED-PRINTABLE:Luca Nicol=F2
            ORG:Officina
            TEL;WORK;VOICE:02 555
            TEL;CELL;VOICE:333 555
            EMAIL;PREF;INTERNET:luca@officina.example
            NOTE;ENCODING=QUOTED-PRINTABLE:Riga uno=0D=0ARiga =
            due
            ADR;WORK:;;Via Roma 1;Milano;;20100;Italia
            END:VCARD
            BEGIN:VCARD
            VERSION:4.0
            FN:Anna Bianchi
            item1.EMAIL;TYPE=home;PREF=1:anna@example.org
            BDAY:19800101
            END:VCARD
            """;
        var cards = VCard.Parse(text);
        Assert.Equal(2, cards.Count);
        var luca = cards[0];
        Assert.Equal("Luca", luca.GivenName);
        Assert.Equal("Nicolò", luca.FamilyName);
        Assert.Equal("Luca Nicolò", luca.Name);
        Assert.Equal([new ContactPhone("02 555", "work"), new ContactPhone("333 555", "mobile")], luca.Phones);
        Assert.Equal("luca@officina.example", Assert.Single(luca.Emails).Address);
        Assert.Equal("Riga uno\r\nRiga due", luca.Notes);
        Assert.Equal("ADR;WORK:;;Via Roma 1;Milano;;20100;Italia", Assert.Single(luca.Extra)); // conservata

        var anna = cards[1];
        Assert.Equal("Anna Bianchi", anna.DisplayName); // senza N: il nome è FN
        Assert.Equal(new ContactEmail("anna@example.org", "home"), Assert.Single(anna.Emails));
        Assert.Contains("BDAY:19800101", VCard.Write(anna));
    }

    // ---------------------------------------------------------------------------------------------
    // CSV
    // ---------------------------------------------------------------------------------------------

    [Fact]
    public void CsvDiOutlookInIngleseConVirgoletteEACapo()
    {
        const string csv = "First Name,Middle Name,Last Name,Company,E-mail Address,E-mail Type,E-mail Display Name,"
            + "E-mail 2 Address,Mobile Phone,Business Phone,Business Fax,Notes\r\n"
            + "Mario,,Rossi,\"Rossi, Figli\",mario@example.com,SMTP,Mario Rossi (mario@example.com),m2@example.com,333,02 1,02 9,\"due\r\nrighe\"\r\n"
            + ",,,,,,,,,,,\r\n";
        var list = ContactCsv.Parse(csv, out var invalid);
        Assert.Equal(0, invalid); // la riga vuota si salta
        var m = Assert.Single(list);
        Assert.Equal(("Mario", "Rossi", "Rossi, Figli"), (m.GivenName, m.FamilyName, m.Company));
        Assert.Equal(["mario@example.com", "m2@example.com"], m.Emails.Select(e => e.Address));
        Assert.All(m.Emails, e => Assert.Null(e.Label)); // "SMTP" non è un tipo d'indirizzo
        Assert.Equal([new ContactPhone("333", "mobile"), new ContactPhone("02 1", "work")], m.Phones); // il fax no
        Assert.Equal("due\r\nrighe", m.Notes);
    }

    [Fact]
    public void CsvDiGoogleConEtichetteEPiuValori()
    {
        const string csv = "First Name,Last Name,Organization Name,E-mail 1 - Label,E-mail 1 - Value,E-mail 2 - Label,E-mail 2 - Value,"
            + "Phone 1 - Label,Phone 1 - Value,Notes\n"
            + "Anna,Bianchi,ACME,* Work,anna@acme.example ::: a.bianchi@acme.example,Home,anna@casa.example,Mobile,+39 347 1,Nota\n";
        var a = Assert.Single(ContactCsv.Parse(csv, out _));
        Assert.Equal([new ContactEmail("anna@acme.example", "work"), new ContactEmail("a.bianchi@acme.example", "work"),
            new ContactEmail("anna@casa.example", "home")], a.Emails);
        Assert.Equal(new ContactPhone("+39 347 1", "mobile"), Assert.Single(a.Phones));
        Assert.Equal("ACME", a.Company);
    }

    [Fact]
    public void CsvInItalianoConPuntoEVirgolaEWindows1252()
    {
        // Ipotesi sulle intestazioni di Outlook in italiano, da provare con un file vero.
        var text = "Nome;Cognome;Società;Indirizzo posta elettronica;Cellulare;Telefono ufficio;Note\r\n"
            + "Niccolò;Verdi;Caffè Srl;nv@example.it;333 2;02 3;è così\r\n";
        var bytes = TextDecoding.Get("windows-1252").GetBytes(text);
        var decoded = TextDecoding.Decode(bytes);
        var c = Assert.Single(ContactCsv.Parse(decoded, out _));
        Assert.Equal(("Niccolò", "Verdi", "Caffè Srl", "è così"), (c.GivenName, c.FamilyName, c.Company, c.Notes));
        Assert.Equal("nv@example.it", Assert.Single(c.Emails).Address);
        Assert.Equal([new ContactPhone("333 2", "mobile"), new ContactPhone("02 3", "work")], c.Phones);
    }

    [Fact]
    public void AccentiTolteConLaTabella()
    {
        Assert.Equal("nicolo societa perche ss lodz", TextFold.Fold("Nicolò Società PERCHÉ ß Łódź"));
    }

    [Fact]
    public void CodificheRiconosciute()
    {
        Assert.Equal("è", TextDecoding.Decode([0xEF, 0xBB, 0xBF, 0xC3, 0xA8]));
        Assert.Equal("è", TextDecoding.Decode([0xC3, 0xA8]));
        Assert.Equal("è", TextDecoding.Decode([0xE8])); // non UTF-8 -> Windows-1252
        Assert.Equal("è", TextDecoding.Decode([0xFF, 0xFE, 0xE8, 0x00]));
        Assert.Equal("€", TextDecoding.Decode([0x80]));
    }

    // ---------------------------------------------------------------------------------------------
    // Rubrica su file
    // ---------------------------------------------------------------------------------------------

    [Fact]
    public void CreaModificaEliminaSuFileERiletti()
    {
        var store = NewStore();
        var created = store.Create(Mario);
        Assert.True(ContactStore.IsValidId(created.Id));
        var path = Path.Combine(store.Directory, created.Id + ".vcf");
        Assert.True(File.Exists(path));
        if (!OperatingSystem.IsWindows())
        {
            Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite, File.GetUnixFileMode(path));
            Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute, File.GetUnixFileMode(store.Directory));
        }
        var uid = Assert.Single(File.ReadAllLines(path), l => l.StartsWith("UID:"));

        // Una proprietà sconosciuta scritta da un altro programma resta dopo la modifica, con lo stesso UID.
        File.WriteAllText(path, File.ReadAllText(path).Replace("END:VCARD", "BDAY:19700101\r\nEND:VCARD"));
        var store2 = NewStore();
        var updated = store2.Update(created.Id, Mario with { Company = "Altra", Phones = [] });
        Assert.Equal("Altra", updated.Company);
        var text = File.ReadAllText(path);
        Assert.Contains("BDAY:19700101", text);
        Assert.Contains(uid, text);

        var reread = NewStore().Get(created.Id);
        Assert.Equal("Altra", reread.Company);
        Assert.Empty(reread.Phones);
        Assert.Equal(2, reread.Emails.Count);

        store2.Delete(created.Id);
        Assert.False(File.Exists(path));
        Assert.Throws<MailNotFoundException>(() => NewStore().Get(created.Id));
        Assert.Throws<MailNotFoundException>(() => store2.Delete(created.Id));
        Assert.Throws<MailNotFoundException>(() => store2.Get("../x"));
    }

    [Fact]
    public void ControlliSuiDati()
    {
        var store = NewStore();
        Assert.Equal("contact", Assert.Throws<FieldValidationException>(() =>
            store.Create(new Contact("", " ", null, null, [], [new ContactPhone("1")], null, "solo note"))).Field);
        Assert.Equal("emails", Assert.Throws<FieldValidationException>(() =>
            store.Create(Mario with { Emails = [new ContactEmail("non valido")] })).Field);
        Assert.Equal("emails", Assert.Throws<FieldValidationException>(() =>
            store.Create(Mario with { Emails = [new ContactEmail("Mario <m@example.com>")] })).Field);
        Assert.Equal("givenName", Assert.Throws<FieldValidationException>(() =>
            store.Create(Mario with { GivenName = new string('x', 201) })).Field);
        // Pulizia: spazi, voci vuote e indirizzi doppi tolti, etichette sconosciute azzerate.
        var c = store.Create(new Contact("", "  Ugo ", null, null,
            [new ContactEmail(" ugo@example.com "), new ContactEmail("UGO@example.com"), new ContactEmail("")],
            [new ContactPhone(" ", "mobile"), new ContactPhone("1", "fax")], null, null));
        Assert.Equal("Ugo", c.GivenName);
        Assert.Equal(new ContactEmail("ugo@example.com"), Assert.Single(c.Emails));
        Assert.Equal(new ContactPhone("1"), Assert.Single(c.Phones));
        Assert.DoesNotContain(store.List(), x => x.Id != c.Id);
    }

    [Fact]
    public void FileRovinatoSaltatoEOrdinePerNome()
    {
        var store = NewStore();
        store.Create(Mario with { GivenName = "zeta", FamilyName = null });
        store.Create(Mario with { GivenName = "Alfa", FamilyName = null });
        File.WriteAllText(Path.Combine(store.Directory, "0123abcd.vcf"), "non è un vcard");
        File.WriteAllText(Path.Combine(store.Directory, "NON-VALIDO.vcf"), VCard.Write(Mario));
        store.Create(Mario with { GivenName = "Élise", FamilyName = null });
        Assert.Equal(["Alfa", "Élise", "zeta"], NewStore().List().Select(c => c.Name));
    }

    [Fact]
    public void ImportazioneSenzaDoppioniEdEsportazione()
    {
        var store = NewStore();
        store.Create(Mario);
        var vcf = VCard.Write(Mario) + VCard.Write(Mario with { GivenName = "Luigi" })
            + "BEGIN:VCARD\r\nVERSION:3.0\r\nNOTE:vuoto\r\nEND:VCARD\r\n"
            + "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Indirizzo rotto\r\nEMAIL:rotto\r\nEND:VCARD\r\n";
        var result = store.Import(Encoding.UTF8.GetBytes(vcf), "vcf");
        Assert.Equal(new ContactImportResult(2, 1, 1), result); // Luigi e "Indirizzo rotto" (senza indirizzo), Mario già c'era
        Assert.Empty(Assert.Single(store.List(), c => c.Name == "Indirizzo rotto").Emails);

        // Esportazione e reimportazione in un'altra rubrica: stessi contatti.
        var other = new ContactStore(Path.Combine(_dir, "accounts", "a2", "contacts"));
        Assert.Equal(3, other.Import(store.Export("vcf"), "vcf").Imported);
        Assert.Equal(store.List().Select(c => (c.Name, c.Emails.Count)), other.List().Select(c => (c.Name, c.Emails.Count)));
        var csv = store.Export("csv");
        Assert.Equal(Encoding.UTF8.GetPreamble(), csv[..3]);
        var third = new ContactStore(Path.Combine(_dir, "accounts", "a3", "contacts"));
        Assert.Equal(3, third.Import(csv, "csv").Imported);
        Assert.Equal(Mario.Phones, third.List().Single(c => c.Name == "Mario Rossi").Phones);
        Assert.Equal("format", Assert.Throws<FieldValidationException>(() => store.Import([], "xls")).Field);
    }

    // ---------------------------------------------------------------------------------------------
    // Indirizzi recenti e suggerimenti
    // ---------------------------------------------------------------------------------------------

    private AccountCache CacheWithSent(params (string To, string? Cc, int DaysAgo)[] sent)
    {
        var cache = new AccountCache(Path.Combine(_dir, "accounts", "a1"));
        cache.SetFolderInfo([new MailFolderInfo("INBOX", "INBOX", 0), new MailFolderInfo("Posta inviata", "Posta inviata", 0, "sent")]);
        var inbox = cache.GetOrAddFolder("INBOX");
        cache.UpsertHeaders(inbox.Id, [new HeaderRecord(1, MailFlags.None, "ricevuta", null, "x@example.com",
            "Ricevente <ricevuta@example.com>", null, DateTimeOffset.Now, DateTimeOffset.Now, 10, "r1", null)]);
        var folder = cache.GetOrAddFolder("Posta inviata");
        uint uid = 1;
        cache.UpsertHeaders(folder.Id, sent.Select(s => new HeaderRecord(uid++, MailFlags.Seen, "inviata", null, "me@example.com",
            s.To, s.Cc, DateTimeOffset.Now.AddDays(-s.DaysAgo), DateTimeOffset.Now.AddDays(-s.DaysAgo), 10, $"m{uid}", null)).ToList());
        return cache;
    }

    [Fact]
    public void RecentiDallaPostaInviataPoiDagliInvii()
    {
        var cache = CacheWithSent(("Anna Bianchi <anna@example.org>, bob@example.org", null, 30), ("anna@example.org", "Carla <carla@example.org>", 1));
        var path = Path.Combine(_dir, "accounts", "a1", "recent-addresses.json");
        var recent = new RecentAddresses(path, cache);
        var items = recent.Items();
        Assert.Equal(3, items.Count); // non "ricevuta@": viene dalla Posta in arrivo
        var anna = items.Single(i => i.Address == "anna@example.org");
        Assert.Equal((2, "Anna Bianchi"), (anna.Count, anna.Name));
        Assert.True(anna.LastUsed > DateTimeOffset.Now.AddDays(-2));

        // Tolto con la ✕: non torna dalla Posta inviata (nuovo oggetto, stesso file), sì scrivendogli di nuovo.
        Assert.True(recent.Remove("BOB@example.org"));
        Assert.DoesNotContain(new RecentAddresses(path, cache).Items(), i => i.Address == "bob@example.org");
        var again = new RecentAddresses(path, cache);
        var message = new MimeMessage();
        message.To.Add(new MailboxAddress("Bob", "bob@example.org"));
        message.Bcc.Add(MailboxAddress.Parse("nascosto@example.org"));
        again.RecordSent(message);
        var after = new RecentAddresses(path, cache).Items();
        Assert.Contains(after, i => i.Address == "bob@example.org" && i.Name == "Bob" && i.Count == 1);
        Assert.Contains(after, i => i.Address == "nascosto@example.org");
        if (!OperatingSystem.IsWindows())
            Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite, File.GetUnixFileMode(path));
    }

    [Fact]
    public void SenzaPostaInviataSiRiprovaDopo()
    {
        var cache = CacheWithSent();
        var path = Path.Combine(_dir, "accounts", "a1", "recent-addresses.json");
        Assert.Empty(new RecentAddresses(path, cache).Items());
        Assert.False(File.Exists(path)); // niente "fatto" con la copia locale vuota
        var folder = cache.GetOrAddFolder("Posta inviata");
        cache.UpsertHeaders(folder.Id, [new HeaderRecord(9, MailFlags.Seen, "x", null, "me@example.com", "zz@example.org", null,
            DateTimeOffset.Now, DateTimeOffset.Now, 1, "z", null)]);
        Assert.Single(new RecentAddresses(path, cache).Items());
    }

    [Fact]
    public void SuggerimentiDaContattiERecentiDiTuttiGliAccount()
    {
        var store = NewStore();
        var mario = store.Create(Mario);
        store.Create(new Contact("", "Nicolò", "Neri", null, [new ContactEmail("nn@example.com")], [], null, null));
        var other = new ContactStore(Path.Combine(_dir, "accounts", "a2", "contacts"));
        var recent = new RecentAddresses(Path.Combine(_dir, "accounts", "a2", "recent-addresses.json"));
        var now = DateTimeOffset.UtcNow;
        recent.Record([new MailboxAddress("Mario R.", "mario.rossi@example.com")], now);
        recent.Record([new MailboxAddress("Marta", "marta@example.net")], now.AddDays(-200));
        recent.Record([MailboxAddress.Parse("marta@example.net")], now.AddDays(-200));
        var books = new (string, ContactStore?, RecentAddresses?)[] { ("a1", store, null), ("a2", other, recent) };

        var mar = AddressSuggestions.Find(books, "mar", 10, now);
        // Mario: contatto e usato di recente, una sola voce con il nome del contatto, in cima.
        Assert.Equal(["mario.rossi@example.com", "marta@example.net", "mario@casa.example"], mar.Select(s => s.Address));
        Assert.Equal(("Mario Rossi", "contact", "a1", mario.Id), (mar[0].Name, mar[0].Source, mar[0].AccountId, mar[0].ContactId));
        Assert.Equal("recent", mar[1].Source);

        Assert.Equal(["nn@example.com"], AddressSuggestions.Find(books, "nicolo", 10, now).Select(s => s.Address)); // senza accento
        Assert.Equal(["mario@casa.example"], AddressSuggestions.Find(books, "mario casa", 10, now).Select(s => s.Address));
        // Parti dell'indirizzo: anche l'altro indirizzo di Mario corrisponde (nome del contatto + "example").
        Assert.Equal("mario.rossi@example.com", AddressSuggestions.Find(books, "rossi@ex", 10, now)[0].Address);
        Assert.Equal(["marta@example.net"], AddressSuggestions.Find(books, "marta@example.net", 10, now).Select(s => s.Address));
        Assert.Single(AddressSuggestions.Find(books, "m", 1, now));
        Assert.Empty(AddressSuggestions.Find(books, "  ", 10, now));
        Assert.Empty(AddressSuggestions.Find(books, "zzz", 10, now));
    }
}
