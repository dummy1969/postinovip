using System.Text.Json;
using MimeKit;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Contacts;

/// <summary>Indirizzo a cui si è scritto: quante volte e l'ultima.</summary>
public sealed record RecentAddress(string Address, string? Name, int Count, DateTimeOffset LastUsed);

/// <summary>
/// Indirizzi usati di recente di un account (C1, scelta 7a: quelli a cui si scrive, come Outlook), in
/// <c>accounts/&lt;id&gt;/recent-addresses.json</c>. La prima volta si riempie dai destinatari della Posta inviata
/// nella copia locale; poi da ogni invio. Quelli tolti dai suggerimenti (la ✕) non tornano dalla Posta inviata,
/// ma sì scrivendo di nuovo a quell'indirizzo.
/// </summary>
public sealed class RecentAddresses(string path, AccountCache? cache = null)
{
    public const int MaxItems = 2000;

    /// <summary>Mail della Posta inviata lette per il punto di partenza.</summary>
    public const int SeedMessages = 2000;

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private readonly Lock _lock = new();
    private State? _state;

    public string Path { get; } = path;

    private sealed record State(bool Seeded, List<RecentAddress> Items, List<string> Removed);

    public List<RecentAddress> Items()
    {
        lock (_lock)
            return [.. Loaded().Items];
    }

    /// <summary>Dopo un invio riuscito: i destinatari (A, Cc, Ccn) diventano recenti.</summary>
    public void Record(IEnumerable<MailboxAddress> recipients, DateTimeOffset when)
    {
        lock (_lock)
        {
            var s = Loaded();
            var changed = false;
            foreach (var m in recipients)
            {
                if (string.IsNullOrWhiteSpace(m.Address))
                    continue;
                s.Removed.RemoveAll(a => a.Equals(m.Address, StringComparison.OrdinalIgnoreCase));
                Add(s.Items, m.Address, m.Name, when);
                changed = true;
            }
            if (changed)
                Save(s);
        }
    }

    /// <summary>Destinatari di una mail appena inviata (non le risposte automatiche: quelle non passano di qui).</summary>
    public void RecordSent(MimeMessage message) =>
        Record(message.To.Mailboxes.Concat(message.Cc.Mailboxes).Concat(message.Bcc.Mailboxes), DateTimeOffset.UtcNow);

    /// <summary>La ✕ dei suggerimenti: true se l'indirizzo c'era.</summary>
    public bool Remove(string address)
    {
        lock (_lock)
        {
            var s = Loaded();
            var removed = s.Items.RemoveAll(i => i.Address.Equals(address, StringComparison.OrdinalIgnoreCase)) > 0;
            if (!s.Removed.Contains(address, StringComparer.OrdinalIgnoreCase))
                s.Removed.Add(address);
            Save(s);
            return removed;
        }
    }

    private static void Add(List<RecentAddress> items, string address, string? name, DateTimeOffset when)
    {
        var i = items.FindIndex(x => x.Address.Equals(address, StringComparison.OrdinalIgnoreCase));
        var clean = string.IsNullOrWhiteSpace(name) ? null : name.Trim();
        if (i < 0)
            items.Add(new RecentAddress(address, clean, 1, when));
        else
        {
            var old = items[i];
            items[i] = new RecentAddress(old.Address, clean ?? old.Name, old.Count + 1, when > old.LastUsed ? when : old.LastUsed);
        }
    }

    private State Loaded()
    {
        if (_state is null)
        {
            try
            {
                using var stream = File.OpenRead(Path);
                _state = JsonSerializer.Deserialize<State>(stream, Json);
            }
            catch (Exception ex) when (ex is FileNotFoundException or DirectoryNotFoundException or JsonException)
            {
            }
            _state ??= new State(false, [], []);
        }
        if (!_state.Seeded && cache is not null)
            Seed(_state);
        return _state;
    }

    /// <summary>Dai destinatari della Posta inviata. Con la copia locale ancora vuota si riprova la volta dopo.</summary>
    private void Seed(State s)
    {
        List<(string? To, string? Cc, DateTimeOffset? When)> sent;
        try
        {
            sent = cache!.GetSentRecipients(SeedMessages);
        }
        catch (Microsoft.Data.Sqlite.SqliteException)
        {
            return;
        }
        if (sent.Count == 0)
            return;
        // Dalla più vecchia, così l'ultima data è quella dell'invio più recente.
        foreach (var (to, cc, when) in Enumerable.Reverse(sent))
            foreach (var list in new[] { to, cc })
                if (list is not null && InternetAddressList.TryParse(list, out var parsed))
                    foreach (var m in parsed.Mailboxes)
                        if (!s.Removed.Contains(m.Address, StringComparer.OrdinalIgnoreCase))
                            Add(s.Items, m.Address, m.Name, when ?? DateTimeOffset.UnixEpoch);
        _state = s with { Seeded = true };
        Save(_state);
    }

    private void Save(State s)
    {
        if (s.Items.Count > MaxItems)
        {
            s.Items.Sort((a, b) => b.LastUsed.CompareTo(a.LastUsed));
            s.Items.RemoveRange(MaxItems, s.Items.Count - MaxItems);
        }
        _state = s;
        CachePermissions.CreatePrivateDirectory(System.IO.Path.GetDirectoryName(Path)!);
        var temp = Path + ".tmp";
        CachePermissions.CreatePrivateFile(temp);
        using (var file = new FileStream(temp, FileMode.Truncate, FileAccess.Write, FileShare.None))
        {
            JsonSerializer.Serialize(file, s, Json);
            file.Flush(flushToDisk: true);
        }
        File.Move(temp, Path, overwrite: true);
    }
}

/// <summary>Suggerimento per il completamento degli indirizzi: da un contatto o dagli indirizzi usati di recente.</summary>
public sealed record AddressSuggestion(string Address, string? Name, string Source, string AccountId, string? ContactId);

/// <summary>
/// Completamento degli indirizzi (3a) su tutte le rubriche e gli indirizzi recenti di tutti gli account (6a):
/// ogni parola scritta deve essere l'inizio di una parola del nome o dell'indirizzo. In cima gli indirizzi usati
/// più spesso e di recente, poi i contatti; un indirizzo compare una volta sola (con il nome del contatto, se c'è).
/// </summary>
public static class AddressSuggestions
{
    public static List<AddressSuggestion> Find(IEnumerable<(string AccountId, ContactStore? Contacts, RecentAddresses? Recent)> books,
        string query, int limit, DateTimeOffset now)
    {
        var words = Words(Separate(query));
        if (words.Count == 0)
            return [];
        var best = new Dictionary<string, (AddressSuggestion S, double Score)>(StringComparer.OrdinalIgnoreCase);

        void Offer(AddressSuggestion s, double score)
        {
            if (!Matches(words, s.Name, s.Address))
                return;
            if (best.TryGetValue(s.Address, out var old))
            {
                // Stesso indirizzo: i punteggi si sommano, il nome del contatto vince su quello della mail.
                var keep = old.S.Source == "contact" ? old.S : s.Source == "contact" ? s : old.S;
                best[s.Address] = (keep, old.Score + score);
            }
            else
                best[s.Address] = (s, score);
        }

        foreach (var (accountId, contacts, recent) in books)
        {
            foreach (var c in contacts?.List() ?? [])
                foreach (var e in c.Emails)
                    Offer(new AddressSuggestion(e.Address, c.Name, "contact", accountId, c.Id), 10);
            foreach (var r in recent?.Items() ?? [])
            {
                var days = Math.Max(0, (now - r.LastUsed).TotalDays);
                Offer(new AddressSuggestion(r.Address, r.Name, "recent", accountId, null),
                    20 + Math.Min(r.Count, 50) + 30 / (1 + days / 7));
            }
        }
        return best.Values.OrderByDescending(v => v.Score)
            .ThenBy(v => TextFold.Fold(v.S.Name ?? v.S.Address), StringComparer.Ordinal)
            .Take(limit).Select(v => v.S).ToList();
    }

    private static bool Matches(List<string> words, string? name, string address)
    {
        var parts = Words((name ?? "") + " " + Separate(address));
        return words.All(w => parts.Any(p => p.StartsWith(w, StringComparison.Ordinal)));
    }

    /// <summary>Indirizzi divisi nelle loro parti ("mario.rossi@ex" -> "mario rossi ex"), sia nella ricerca sia nei candidati.</summary>
    private static string Separate(string s) => s.Replace('@', ' ').Replace('.', ' ').Replace('-', ' ').Replace('_', ' ').Replace('+', ' ');

    private static List<string> Words(string s) =>
        Fold(s).Split([' ', ',', ';', '<', '>', '"', '(', ')'], StringSplitOptions.RemoveEmptyEntries).ToList();

    /// <summary>Minuscolo e senza accenti ("Nicolò" si trova con "nicolo").</summary>
    private static string Fold(string s) => TextFold.Fold(s);
}
