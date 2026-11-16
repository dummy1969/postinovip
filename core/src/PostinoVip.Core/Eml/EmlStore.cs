using MimeKit;

namespace PostinoVip.Core.Eml;

/// <summary>Il file aperto non è una mail leggibile (400).</summary>
public sealed class InvalidEmlException(string message, Exception? inner = null) : Exception(message, inner);

/// <summary>
/// File .eml aperti nell'app (E1, scelta 1a/2a): restano solo in memoria, in sola lettura, finché l'app li chiude
/// (o finché ne vengono aperti troppi: si chiude quello usato meno di recente). Nessuno tocca la casella.
/// </summary>
public sealed class EmlStore(int capacity = 20)
{
    private readonly Lock _lock = new();
    private readonly Dictionary<string, (MimeMessage Message, long Used)> _open = [];
    private long _clock;

    public int Count
    {
        get { lock (_lock) return _open.Count; }
    }

    /// <summary>Legge una mail da <paramref name="stream"/>; se non ha nessuna intestazione da mail, InvalidEmlException.</summary>
    public static async Task<MimeMessage> ParseAsync(Stream stream, CancellationToken ct)
    {
        MimeMessage message;
        try
        {
            message = await MimeMessage.LoadAsync(stream, ct);
        }
        catch (FormatException ex)
        {
            throw new InvalidEmlException("Il file non è una mail (.eml) leggibile.", ex).WithCode("ilFileNonUnaMail");
        }
        // MimeKit è permissivo: un file qualsiasi diventa una «mail» senza intestazioni. Serve almeno una di queste.
        HeaderId[] mail = [HeaderId.From, HeaderId.Date, HeaderId.Subject, HeaderId.To, HeaderId.MessageId];
        if (!mail.Any(message.Headers.Contains))
            throw new InvalidEmlException("Il file non è una mail (.eml): mancano mittente, data, oggetto e destinatari.").WithCode("ilFileNonUnaMail2");
        return message;
    }

    /// <summary>Tiene <paramref name="message"/> e restituisce il suo id (casuale, non indovinabile).</summary>
    public string Open(MimeMessage message)
    {
        var id = Convert.ToHexStringLower(System.Security.Cryptography.RandomNumberGenerator.GetBytes(16));
        lock (_lock)
        {
            while (_open.Count >= capacity)
                _open.Remove(_open.MinBy(p => p.Value.Used).Key);
            _open[id] = (message, ++_clock);
        }
        return id;
    }

    public MimeMessage Get(string id)
    {
        lock (_lock)
        {
            if (!_open.TryGetValue(id, out var entry))
                throw new MailNotFoundException("Il file .eml non è più aperto: riaprirlo.").WithCode("ilFileEmlNonPiu");
            _open[id] = (entry.Message, ++_clock);
            return entry.Message;
        }
    }

    public bool Close(string id)
    {
        lock (_lock) return _open.Remove(id);
    }
}
