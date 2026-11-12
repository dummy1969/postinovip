using System.Text;

namespace PostinoVip.Core.Contacts;

/// <summary>
/// CSV dei contatti (5a). Lettura: colonne riconosciute per parole chiave nelle intestazioni (inglese e italiano),
/// così vanno sia l'esportazione di Outlook ("First Name", "E-mail Address", "Mobile Phone"…, anche tradotta) sia
/// quella di Google Contatti ("E-mail 1 - Label", "E-mail 1 - Value"…); separatore "," o ";" (Excel in italiano).
/// Le intestazioni di Outlook in italiano sono un'ipotesi da provare con un file vero.
/// Scrittura: intestazioni di Outlook in inglese, che Outlook e Google importano.
/// </summary>
public static class ContactCsv
{
    private static readonly string[] Header =
        ["First Name", "Last Name", "Display Name", "Company", "E-mail Address", "E-mail 2 Address", "E-mail 3 Address",
         "Mobile Phone", "Business Phone", "Home Phone", "Other Phone", "Notes"];

    public static string Write(IEnumerable<Contact> contacts)
    {
        var sb = new StringBuilder();
        Row(sb, Header);
        foreach (var c in contacts)
        {
            string Phone(string label) => string.Join(" ; ", c.Phones.Where(p => (p.Label ?? "other") == label).Select(p => p.Number));
            Row(sb,
            [
                c.GivenName ?? "", c.FamilyName ?? "", c.DisplayName ?? "", c.Company ?? "",
                c.Emails.ElementAtOrDefault(0)?.Address ?? "", c.Emails.ElementAtOrDefault(1)?.Address ?? "",
                c.Emails.ElementAtOrDefault(2)?.Address ?? "",
                Phone("mobile"), Phone("work"), Phone("home"), Phone("other"), c.Notes ?? "",
            ]);
        }
        return sb.ToString();
    }

    private static void Row(StringBuilder sb, IEnumerable<string> cells)
    {
        sb.Append(string.Join(',', cells.Select(Quote))).Append("\r\n");
    }

    private static string Quote(string s) =>
        s.IndexOfAny([',', '"', '\r', '\n', ';']) >= 0 ? "\"" + s.Replace("\"", "\"\"") + "\"" : s;

    /// <summary>I contatti del CSV (id vuoto: lo dà l'archivio). Righe senza nome né indirizzo restano fuori.</summary>
    public static List<Contact> Parse(string text, out int invalid)
    {
        invalid = 0;
        var rows = Rows(text, DetectSeparator(text));
        var result = new List<Contact>();
        if (rows.Count == 0)
            return result;
        var map = Columns(rows[0]);
        foreach (var row in rows.Skip(1))
        {
            if (row.All(string.IsNullOrWhiteSpace))
                continue;
            string? Cell(int? i) => i is { } n && n < row.Count && !string.IsNullOrWhiteSpace(row[n]) ? row[n].Trim() : null;
            var emails = new List<ContactEmail>();
            foreach (var (value, label) in map.Emails)
                foreach (var address in Split(Cell(value)))
                    emails.Add(new ContactEmail(address, EmailLabel(Cell(label))));
            var phones = new List<ContactPhone>();
            foreach (var (value, label, fixedLabel) in map.Phones)
                foreach (var number in Split(Cell(value)))
                    phones.Add(new ContactPhone(number, fixedLabel ?? PhoneLabel(Cell(label))));
            var contact = new Contact("", Cell(map.Given), Cell(map.Family), Cell(map.Display), emails, phones,
                Cell(map.Company), Cell(map.Notes));
            if (contact.GivenName is null && contact.FamilyName is null && contact.DisplayName is null && contact.Company is null
                && emails.Count == 0)
                invalid++;
            else
                result.Add(contact);
        }
        return result;
    }

    // Google mette più valori nella stessa cella separati da " ::: ".
    private static IEnumerable<string> Split(string? cell) =>
        cell is null ? [] : cell.Split(":::", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static string? EmailLabel(string? label) => Normalize(label ?? "") switch
    {
        var l when l.Contains("work") || l.Contains("lavoro") || l.Contains("ufficio") => "work",
        var l when l.Contains("home") || l.Contains("casa") || l.Contains("personal") => "home",
        "" => null,
        _ => "other",
    };

    private static string? PhoneLabel(string? label) => Normalize(label ?? "") switch
    {
        var l when l.Contains("mobile") || l.Contains("cell") => "mobile",
        var l when l.Contains("work") || l.Contains("lavoro") || l.Contains("ufficio") || l.Contains("business") => "work",
        var l when l.Contains("home") || l.Contains("casa") || l.Contains("abitazione") => "home",
        "" => null,
        _ => "other",
    };

    private sealed class ColumnMap
    {
        public int? Given, Family, Display, Company, Notes;
        public readonly List<(int Value, int? Label)> Emails = [];
        public readonly List<(int Value, int? Label, string? FixedLabel)> Phones = [];
    }

    private static ColumnMap Columns(List<string> header)
    {
        var map = new ColumnMap();
        var names = header.Select(Normalize).ToList();
        int? Label(string kind, string number) =>
            // Solo le colonne "Label" di Google: "E-mail Type" di Outlook dice "SMTP", non il tipo d'indirizzo.
            names.FindIndex(n => n.Contains(kind) && Number(n) == number && n.Contains("label"))
                is var i and >= 0 ? i : null;
        for (var i = 0; i < names.Count; i++)
        {
            var n = names[i];
            if (n.Length == 0)
                continue;
            var isLabel = n.Contains("label") || n.Contains("type") || n.Contains("tipo") || n.Contains("display name")
                || n.Contains("visualizzato");
            if (n.Contains("mail") || n.Contains("posta elettronica"))
            {
                if (!isLabel)
                    map.Emails.Add((i, Label("mail", Number(n))));
            }
            else if (n.Contains("phone") || n.Contains("telefono") || n.Contains("cellulare") || n.Contains("mobile"))
            {
                if (n.Contains("fax") || n.Contains("label") || n.Contains("type") || n.Contains("tipo"))
                    continue;
                string? fixedLabel = n.Contains("mobile") || n.Contains("cellulare") ? "mobile"
                    : n.Contains("business") || n.Contains("ufficio") || n.Contains("lavoro") ? "work"
                    : n.Contains("home") || n.Contains("abitazione") || n.Contains("casa") ? "home"
                    : n.Contains("other") || n.Contains("altro") ? "other" : null;
                map.Phones.Add((i, fixedLabel is null ? Label("phone", Number(n)) : null, fixedLabel));
            }
            else if (n is "first name" or "given name" or "nome")
                map.Given ??= i;
            else if (n is "last name" or "family name" or "cognome")
                map.Family ??= i;
            else if (n is "name" or "display name" or "full name" or "nome visualizzato" or "nome completo")
                map.Display ??= i;
            else if (n is "company" or "organization name" or "organization 1 name" or "societa" or "azienda" or "organizzazione")
                map.Company ??= i;
            else if (n is "notes" or "note")
                map.Notes ??= i;
        }
        return map;
    }

    /// <summary>Numero nell'intestazione ("e mail 2 value" -> "2"; nessuno = "1").</summary>
    private static string Number(string n) => n.Split(' ').FirstOrDefault(w => w.All(char.IsAsciiDigit) && w.Length > 0) ?? "1";

    /// <summary>Minuscolo, senza accenti, solo lettere e numeri separati da uno spazio.</summary>
    private static string Normalize(string s)
    {
        var sb = new StringBuilder();
        foreach (var ch in TextFold.Fold(s))
            sb.Append(char.IsLetterOrDigit(ch) ? ch : ' ');
        return string.Join(' ', sb.ToString().Split(' ', StringSplitOptions.RemoveEmptyEntries));
    }

    private static char DetectSeparator(string text)
    {
        var end = text.IndexOfAny(['\r', '\n']);
        var first = end < 0 ? text : text[..end];
        return first.Count(c => c == ';') > first.Count(c => c == ',') ? ';' : ',';
    }

    /// <summary>RFC 4180: campi tra virgolette con virgolette doppie e a capo dentro.</summary>
    private static List<List<string>> Rows(string text, char separator)
    {
        var rows = new List<List<string>>();
        var row = new List<string>();
        var cell = new StringBuilder();
        var quoted = false;
        for (var i = 0; i < text.Length; i++)
        {
            var c = text[i];
            if (quoted)
            {
                if (c == '"')
                {
                    if (i + 1 < text.Length && text[i + 1] == '"') { cell.Append('"'); i++; }
                    else quoted = false;
                }
                else
                    cell.Append(c);
            }
            else if (c == '"')
                quoted = true;
            else if (c == separator)
            {
                row.Add(cell.ToString());
                cell.Clear();
            }
            else if (c is '\r' or '\n')
            {
                if (c == '\r' && i + 1 < text.Length && text[i + 1] == '\n')
                    i++;
                row.Add(cell.ToString());
                cell.Clear();
                rows.Add(row);
                row = [];
            }
            else
                cell.Append(c);
        }
        if (cell.Length > 0 || row.Count > 0)
        {
            row.Add(cell.ToString());
            rows.Add(row);
        }
        return rows;
    }
}
