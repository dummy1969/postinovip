using System.Text;

namespace PostinoVip.Core.Contacts;

/// <summary>
/// Lettura e scrittura dei vCard (RFC 2426 = 3.0; si leggono anche 2.1, quella di Outlook, e 4.0 = RFC 6350).
/// Si scrive sempre la 3.0, quella di Google CardDAV. Gestiti: FN, N, ORG, EMAIL, TEL, NOTE, UID, REV; le altre
/// proprietà restano in <see cref="Contact.Extra"/> e si riscrivono uguali (niente dati persi importando o
/// sincronizzando). Righe ripiegate, testo con escape e QUOTED-PRINTABLE della 2.1 compresi.
/// </summary>
public static class VCard
{
    private static readonly HashSet<string> Handled =
        ["BEGIN", "END", "VERSION", "FN", "N", "ORG", "EMAIL", "TEL", "NOTE", "UID", "REV", "PRODID"];

    /// <summary>Tutti i vCard del testo (un file .vcf può contenerne molti). L'id è vuoto: lo dà l'archivio.</summary>
    public static List<Contact> Parse(string text)
    {
        var result = new List<Contact>();
        List<Property>? current = null;
        foreach (var line in Unfold(text))
        {
            var p = Property.Parse(line);
            if (p is null)
                continue;
            if (p.Name == "BEGIN" && p.Value.Equals("VCARD", StringComparison.OrdinalIgnoreCase))
                current = [];
            else if (p.Name == "END" && p.Value.Equals("VCARD", StringComparison.OrdinalIgnoreCase))
            {
                if (current is not null)
                    result.Add(Build(current));
                current = null;
            }
            else
                current?.Add(p);
        }
        return result;
    }

    /// <summary>Un contatto come vCard 3.0, righe CRLF ripiegate a 75 byte.</summary>
    public static string Write(Contact c)
    {
        var sb = new StringBuilder();
        void Add(string line) => Fold(sb, line);
        Add("BEGIN:VCARD");
        Add("VERSION:3.0");
        Add("PRODID:-//PostinoVip//Contatti//IT");
        if (!string.IsNullOrEmpty(c.VCardUid))
            Add("UID:" + Escape(c.VCardUid));
        Add("FN:" + Escape(c.Name));
        Add($"N:{Escape(c.FamilyName ?? "")};{Escape(c.GivenName ?? "")};;;");
        if (!string.IsNullOrWhiteSpace(c.Company))
            Add("ORG:" + Escape(c.Company));
        foreach (var e in c.Emails)
            Add(e.Label is { } l && EmailType(l) is { } t ? $"EMAIL;TYPE=INTERNET,{t}:{Escape(e.Address)}" : "EMAIL;TYPE=INTERNET:" + Escape(e.Address));
        foreach (var p in c.Phones)
            Add(p.Label is { } l && PhoneType(l) is { } t ? $"TEL;TYPE={t}:{Escape(p.Number)}" : "TEL:" + Escape(p.Number));
        if (!string.IsNullOrWhiteSpace(c.Notes))
            Add("NOTE:" + Escape(c.Notes));
        if (c.Updated is { } u)
            Add("REV:" + u.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'"));
        foreach (var extra in c.Extra)
            Add(extra);
        Add("END:VCARD");
        return sb.ToString();
    }

    private static Contact Build(List<Property> props)
    {
        string? fn = null, given = null, family = null, org = null, notes = null, uid = null;
        DateTimeOffset? rev = null;
        var emails = new List<ContactEmail>();
        var phones = new List<ContactPhone>();
        var extra = new List<string>();
        foreach (var p in props)
        {
            switch (p.Name)
            {
                case "FN":
                    fn = p.Text();
                    break;
                case "N":
                    var parts = p.Components();
                    family = parts.ElementAtOrDefault(0);
                    given = parts.ElementAtOrDefault(1);
                    break;
                case "ORG":
                    org = p.Components().FirstOrDefault();
                    break;
                case "EMAIL":
                    if (Clean(p.Text()) is { } address)
                        emails.Add(new ContactEmail(address, p.Types.Contains("WORK") ? "work" : p.Types.Contains("HOME") ? "home" : null));
                    break;
                case "TEL":
                    if (Clean(p.Text()) is { } number)
                        phones.Add(new ContactPhone(number,
                            p.Types.Contains("CELL") ? "mobile" : p.Types.Contains("WORK") ? "work" : p.Types.Contains("HOME") ? "home" : null));
                    break;
                case "NOTE":
                    notes = notes is null ? p.Text() : notes + "\n" + p.Text();
                    break;
                case "UID":
                    uid = p.Text();
                    break;
                case "REV":
                    rev = ParseRev(p.Value) ?? rev;
                    break;
                default:
                    if (!Handled.Contains(p.Name))
                        extra.Add(p.Raw);
                    break;
            }
        }
        // FN uguale a "Nome Cognome" non va salvato come nome mostrato: resta calcolato.
        var display = Clean(fn);
        var computed = string.Join(' ', new[] { given, family }.Where(s => !string.IsNullOrWhiteSpace(s)).Select(s => s!.Trim()));
        if (display == computed || display == Clean(org))
            display = null;
        return new Contact("", Clean(given), Clean(family), display, emails, phones, Clean(org), Clean(notes), rev)
        {
            VCardUid = Clean(uid),
            Extra = extra,
        };
    }

    private static readonly string[] RevFormats =
    [
        "yyyyMMdd'T'HHmmss'Z'", "yyyyMMdd'T'HHmmss", "yyyyMMdd'T'HHmmsszzz", "yyyyMMdd'T'HHmmsszz",
        "yyyyMMdd'T'HHmmssfff'Z'", "yyyyMMdd",
    ];

    /// <summary>
    /// REV (ora dell'ultima modifica): forma estesa (2026-11-01T10:00:00Z) o compatta della ISO 8601 (20261101T100000Z,
    /// usata da molti server CardDAV e dalla vCard 4.0); senza fuso = UTC. Null se non leggibile.
    /// </summary>
    public static DateTimeOffset? ParseRev(string value)
    {
        var v = value.Trim();
        var inv = System.Globalization.CultureInfo.InvariantCulture;
        var utc = System.Globalization.DateTimeStyles.AssumeUniversal | System.Globalization.DateTimeStyles.AdjustToUniversal;
        if (DateTimeOffset.TryParseExact(v, RevFormats, inv, utc, out var compact))
            return compact;
        return DateTimeOffset.TryParse(v, inv, utc, out var r) ? r : null;
    }

    private static string? Clean(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

    private static string? EmailType(string label) => label switch { "work" => "WORK", "home" => "HOME", _ => null };

    private static string? PhoneType(string label) =>
        label switch { "mobile" => "CELL", "work" => "WORK,VOICE", "home" => "HOME,VOICE", _ => null };

    /// <summary>Escape del testo (RFC 2426 5.8.4): \\ , ; e a capo.</summary>
    public static string Escape(string s) =>
        s.Replace("\\", "\\\\").Replace(",", "\\,").Replace(";", "\\;").Replace("\r\n", "\\n").Replace("\n", "\\n").Replace("\r", "\\n");

    /// <summary>Righe logiche: una riga che comincia con spazio o tab continua la precedente; QP della 2.1 con "=" in fondo.</summary>
    private static IEnumerable<string> Unfold(string text)
    {
        var lines = text.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
        StringBuilder? current = null;
        var qpContinues = false;
        foreach (var line in lines)
        {
            if (current is not null && (qpContinues || line.StartsWith(' ') || line.StartsWith('\t')))
            {
                current.Append(qpContinues ? line : line[1..]);
            }
            else
            {
                if (current is not null)
                    yield return current.ToString();
                current = new StringBuilder(line);
            }
            var s = current.ToString();
            qpContinues = s.EndsWith('=') && s.Contains("QUOTED-PRINTABLE", StringComparison.OrdinalIgnoreCase);
            if (qpContinues)
                current.Length--; // "=" finale: a capo morbido del quoted-printable
        }
        if (current is not null)
            yield return current.ToString();
    }

    /// <summary>Riga ripiegata a 75 byte UTF-8 (RFC 2426 2.6), senza spezzare un carattere.</summary>
    private static void Fold(StringBuilder sb, string line)
    {
        const int limit = 75;
        var bytes = 0;
        foreach (var rune in line.EnumerateRunes())
        {
            var n = rune.Utf8SequenceLength;
            if (bytes + n > limit)
            {
                sb.Append("\r\n ");
                bytes = 1; // lo spazio iniziale della continuazione
            }
            sb.Append(rune.ToString());
            bytes += n;
        }
        sb.Append("\r\n");
    }

    private sealed class Property
    {
        public required string Name { get; init; }
        public required string Value { get; init; }
        public required string Raw { get; init; }
        public HashSet<string> Types { get; } = [];
        public string? Encoding { get; private set; }
        public string? Charset { get; private set; }

        public static Property? Parse(string line)
        {
            if (string.IsNullOrWhiteSpace(line))
                return null;
            // Due punti fuori dalle virgolette dei parametri.
            var colon = -1;
            var quoted = false;
            for (var i = 0; i < line.Length; i++)
            {
                if (line[i] == '"') quoted = !quoted;
                else if (line[i] == ':' && !quoted) { colon = i; break; }
            }
            if (colon <= 0)
                return null;
            var head = line[..colon].Split(';');
            var name = head[0];
            var dot = name.LastIndexOf('.');
            if (dot >= 0)
                name = name[(dot + 1)..]; // gruppo (item1.EMAIL)
            var p = new Property { Name = name.Trim().ToUpperInvariant(), Value = line[(colon + 1)..], Raw = line };
            foreach (var param in head.Skip(1))
            {
                var eq = param.IndexOf('=');
                var key = (eq < 0 ? "TYPE" : param[..eq]).Trim().ToUpperInvariant();
                var value = (eq < 0 ? param : param[(eq + 1)..]).Trim().Trim('"');
                switch (key)
                {
                    case "TYPE":
                        foreach (var t in value.Split(','))
                            p.Types.Add(t.Trim().ToUpperInvariant());
                        break;
                    case "ENCODING":
                        p.Encoding = value.ToUpperInvariant();
                        break;
                    case "CHARSET":
                        p.Charset = value;
                        break;
                    case "PREF":
                        break;
                    default:
                        // 2.1: "QUOTED-PRINTABLE" da solo; 4.0: PREF=1, ecc.
                        if (eq < 0 && value.Equals("QUOTED-PRINTABLE", StringComparison.OrdinalIgnoreCase))
                            p.Encoding = "QUOTED-PRINTABLE";
                        break;
                }
            }
            if (p.Types.Remove("QUOTED-PRINTABLE"))
                p.Encoding = "QUOTED-PRINTABLE";
            return p;
        }

        private string Decoded()
        {
            if (Encoding != "QUOTED-PRINTABLE")
                return Value;
            var bytes = new List<byte>();
            for (var i = 0; i < Value.Length; i++)
            {
                if (Value[i] == '=' && i + 2 < Value.Length && Uri.IsHexDigit(Value[i + 1]) && Uri.IsHexDigit(Value[i + 2]))
                {
                    bytes.Add(Convert.ToByte(Value.Substring(i + 1, 2), 16));
                    i += 2;
                }
                else
                    bytes.AddRange(System.Text.Encoding.UTF8.GetBytes(Value[i].ToString()));
            }
            var encoding = System.Text.Encoding.UTF8;
            if (Charset is { } cs)
            {
                try { encoding = TextDecoding.Get(cs); }
                catch (ArgumentException) { }
            }
            return encoding.GetString(bytes.ToArray());
        }

        /// <summary>Valore di testo senza escape.</summary>
        public string Text() => Unescape(Decoded());

        /// <summary>Valore strutturato (N, ORG): componenti separati da ";" senza escape.</summary>
        public List<string> Components()
        {
            var raw = Decoded();
            var parts = new List<string>();
            var sb = new StringBuilder();
            for (var i = 0; i < raw.Length; i++)
            {
                if (raw[i] == '\\' && i + 1 < raw.Length)
                {
                    sb.Append(raw[i]).Append(raw[i + 1]);
                    i++;
                }
                else if (raw[i] == ';')
                {
                    parts.Add(Unescape(sb.ToString()));
                    sb.Clear();
                }
                else
                    sb.Append(raw[i]);
            }
            parts.Add(Unescape(sb.ToString()));
            return parts;
        }

        private static string Unescape(string s)
        {
            if (!s.Contains('\\'))
                return s;
            var sb = new StringBuilder(s.Length);
            for (var i = 0; i < s.Length; i++)
            {
                if (s[i] == '\\' && i + 1 < s.Length)
                {
                    var c = s[++i];
                    sb.Append(c is 'n' or 'N' ? '\n' : c);
                }
                else
                    sb.Append(s[i]);
            }
            return sb.ToString();
        }
    }
}

/// <summary>Codifiche dei file importati: UTF-8/UTF-16 con BOM, UTF-8, altrimenti Windows-1252 (CSV di Outlook).</summary>
public static class TextDecoding
{
    static TextDecoding() => System.Text.Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

    public static System.Text.Encoding Get(string name) => System.Text.Encoding.GetEncoding(name);

    public static string Decode(byte[] data)
    {
        if (data.Length >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF)
            return System.Text.Encoding.UTF8.GetString(data, 3, data.Length - 3);
        if (data.Length >= 2 && data[0] == 0xFF && data[1] == 0xFE)
            return System.Text.Encoding.Unicode.GetString(data, 2, data.Length - 2);
        if (data.Length >= 2 && data[0] == 0xFE && data[1] == 0xFF)
            return System.Text.Encoding.BigEndianUnicode.GetString(data, 2, data.Length - 2);
        try
        {
            return new UTF8Encoding(false, throwOnInvalidBytes: true).GetString(data);
        }
        catch (DecoderFallbackException)
        {
            return Get("windows-1252").GetString(data);
        }
    }
}
