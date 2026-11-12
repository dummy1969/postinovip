using System.Collections.Concurrent;
using MailKit;
using MailKit.Net.Imap;

namespace PostinoVip.Core.Imap;

/// <summary>
/// La struttura (BODYSTRUCTURE) di una mail che MailKit non riesce a leggere chiude la connessione: senza protezione una
/// sola mail blocca la sincronizzazione dell'intera cartella (trovato il 12/11/2026 con IceWarp: una parte di testo vuota
/// descritta con il numero di righe NIL, contro RFC 3501 <c>body-fld-lines = number</c>; MailKit 4.18.2 e 5.0.0 la
/// rifiutano). Scelta 1a del 12/11/2026: la struttura si chiede a parte dalle intestazioni, e un gruppo di mail che la fa
/// fallire diventa «sospetto»: le richieste normali lo saltano (la lista funziona subito, senza allegati e anteprima per
/// quelle mail); il download in background (<c>probe</c>) lo divide a metà a ogni tentativo, con una connessione nuova
/// ogni volta, finché la mail difettosa resta da sola: da lì è «illeggibile» e viene sempre saltata. Allegati e anteprima
/// di quella mail arrivano dal corpo scaricato. Tutto in memoria (per account, cartella e UIDVALIDITY): dopo un
/// riavvio del core la ricerca ricomincia.
/// </summary>
public sealed class StructureGuard
{
    private static readonly ConcurrentDictionary<string, StructureGuard> Guards = new(StringComparer.Ordinal);

    private readonly object _lock = new();
    private readonly HashSet<uint> _unreadable = [];
    private readonly List<uint[]> _suspect = [];

    /// <param name="account">Identità della casella (server, porta, utente).</param>
    public static StructureGuard For(string account, string folder, uint uidValidity) =>
        Guards.GetOrAdd($"{account}\n{folder}\n{uidValidity}", _ => new StructureGuard());

    /// <summary>Mail la cui struttura è illeggibile (diagnostica e test).</summary>
    public IReadOnlyCollection<uint> Unreadable
    {
        get { lock (_lock) return _unreadable.ToList(); }
    }

    /// <summary>Mail di gruppi sospetti non ancora divisi fino in fondo (diagnostica e test).</summary>
    public int SuspectCount
    {
        get { lock (_lock) return _suspect.Sum(g => g.Length); }
    }

    /// <summary>
    /// FETCH con la struttura delle mail indicate, saltando quelle illeggibili e sospette (che mancano dal risultato).
    /// Con <paramref name="probe"/> prova anche i gruppi sospetti tra quelle indicate, uno alla volta.
    /// </summary>
    /// <exception cref="UnreadableStructureException">Una struttura illeggibile: la connessione è chiusa (MailKit),
    /// il gruppo è stato registrato; il chiamante ripete con una connessione nuova.</exception>
    public async Task<IReadOnlyList<IMessageSummary>> FetchAsync(IMailFolder folder, IReadOnlyCollection<uint> uids,
        FetchRequest request, bool probe, CancellationToken ct)
    {
        var wanted = uids.ToHashSet();
        List<uint> clean;
        lock (_lock)
        {
            var skip = _unreadable.Concat(_suspect.SelectMany(g => g)).ToHashSet();
            clean = uids.Where(u => !skip.Contains(u)).ToList();
        }

        var result = new List<IMessageSummary>();
        if (clean.Count > 0)
        {
            try
            {
                result.AddRange(await Fetch(folder, clean, request, ct));
            }
            catch (ImapProtocolException ex)
            {
                lock (_lock)
                    _suspect.Add(clean.ToArray());
                throw new UnreadableStructureException(
                    $"struttura (BODYSTRUCTURE) illeggibile in un gruppo di {clean.Count} mail di {folder.FullName}: " +
                    $"saltate, la mail difettosa sarà cercata in background ({ex.Message})", ex);
            }
        }

        if (probe)
        {
            List<uint[]> groups;
            lock (_lock)
                groups = _suspect.Where(g => g.Any(wanted.Contains)).ToList();
            foreach (var group in groups)
            {
                try
                {
                    result.AddRange(await Fetch(folder, group, request, ct));
                    lock (_lock)
                        _suspect.Remove(group);
                }
                catch (ImapProtocolException ex)
                {
                    string found;
                    lock (_lock)
                    {
                        _suspect.Remove(group);
                        if (group.Length == 1)
                        {
                            _unreadable.Add(group[0]);
                            found = $"mail UID {group[0]} di {folder.FullName}: struttura (BODYSTRUCTURE) illeggibile, d'ora in poi saltata";
                        }
                        else
                        {
                            _suspect.Add(group[..(group.Length / 2)]);
                            _suspect.Add(group[(group.Length / 2)..]);
                            found = $"struttura illeggibile in un gruppo di {group.Length} mail di {folder.FullName}: diviso in due";
                        }
                    }
                    throw new UnreadableStructureException($"{found} ({ex.Message})", ex);
                }
            }
        }
        return result.Where(s => wanted.Contains(s.UniqueId.Id)).ToList();
    }

    private static async Task<IList<IMessageSummary>> Fetch(IMailFolder folder, IEnumerable<uint> uids, FetchRequest request,
        CancellationToken ct) =>
        await folder.FetchAsync(uids.Select(u => new UniqueId(u)).ToList(), request, ct);
}

/// <summary>
/// Struttura di una mail illeggibile per MailKit (vedi <see cref="StructureGuard"/>). Deriva da ImapProtocolException:
/// resta un errore di connessione (MailKit ha chiuso la connessione), quindi le letture vengono ripetute.
/// </summary>
public sealed class UnreadableStructureException(string message, Exception inner) : ImapProtocolException(message, inner);
