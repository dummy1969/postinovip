using System.Text.Json;
using PostinoVip.Core.Account;

namespace PostinoVip.Core.Cache;

/// <summary>Dati locali di un account non più configurato (rimosso dall'app): restano finché l'utente non li elimina.</summary>
/// <param name="Address">Indirizzo della casella, null se la cartella è precedente al file account.json.</param>
/// <param name="LocalOnly">
/// Contiene mail di un account POP3 (4.2): sono l'unica copia, eliminarle le perde per sempre (l'app chiede
/// una conferma più forte).
/// </param>
/// <param name="Contacts">Contatti della rubrica dell'account (C1): anche questi sono solo sul computer.</param>
public sealed record OrphanCache(string Id, string? Name, string? Address, long SizeBytes, bool LocalOnly = false, int Contacts = 0);

/// <summary>
/// Le cartelle della cache degli account (<c>{root}/accounts/{id}</c>). Ognuna contiene un file
/// <see cref="InfoFileName"/> con id, nome e indirizzo (mai la password), così dopo la rimozione
/// dell'account dall'app si sa ancora di chi sono i dati.
/// Regola del punto 7b: rimuovere un account non cancella i suoi dati locali; li cancella solo una
/// richiesta esplicita dell'utente (<see cref="DeleteOrphan"/>).
/// </summary>
public static class CacheAccounts
{
    public const string InfoFileName = "account.json";

    private sealed record Info(string Id, string? Name, string? Address);

    /// <summary>Scrive (o aggiorna) account.json nella cartella della cache dell'account.</summary>
    public static void WriteInfo(string cacheRoot, MailAccountSettings settings)
    {
        var dir = MailAccountRegistry.CacheDirectory(cacheRoot, settings.Id);
        CachePermissions.CreatePrivateDirectory(dir);
        var path = Path.Combine(dir, InfoFileName);
        var json = JsonSerializer.Serialize(new Info(settings.Id, settings.Name, settings.Address));
        if (File.Exists(path) && File.ReadAllText(path) == json)
            return;
        CachePermissions.CreatePrivateFile(path);
        File.WriteAllText(path, json);
    }

    /// <summary>Le cartelle di account non configurati, con lo spazio occupato.</summary>
    public static IReadOnlyList<OrphanCache> ListOrphans(string cacheRoot, IReadOnlyCollection<string> configuredIds)
    {
        var accounts = Path.Combine(cacheRoot, "accounts");
        if (!Directory.Exists(accounts))
            return [];
        var result = new List<OrphanCache>();
        foreach (var dir in new DirectoryInfo(accounts).EnumerateDirectories())
        {
            if (configuredIds.Contains(dir.Name) || !MailAccountRegistry.IsValidId(dir.Name) || IsLink(dir))
                continue;
            var info = ReadInfo(dir.FullName);
            var size = dir.EnumerateFiles("*", SearchOption.AllDirectories).Sum(f => f.Length);
            var mail = new DirectoryInfo(Path.Combine(dir.FullName, "mail"));
            var localOnly = mail.Exists && mail.EnumerateFiles("*.eml", SearchOption.AllDirectories).Any();
            var contactsDir = new DirectoryInfo(Path.Combine(dir.FullName, "contacts"));
            var contacts = contactsDir.Exists ? contactsDir.EnumerateFiles("*.vcf").Count() : 0;
            result.Add(new OrphanCache(dir.Name, info?.Name, info?.Address, size, localOnly, contacts));
        }
        return result.OrderBy(o => o.Address ?? o.Id, StringComparer.OrdinalIgnoreCase).ToList();
    }

    /// <summary>
    /// Cancella i dati locali di un account non configurato (richiesta esplicita dell'utente).
    /// Sul server non viene toccato nulla.
    /// </summary>
    /// <exception cref="MailNotFoundException">Nessuna cartella con questo id.</exception>
    /// <exception cref="InvalidOperationException">L'account è ancora configurato: non sono dati "rimossi".</exception>
    public static void DeleteOrphan(string cacheRoot, string id, IReadOnlyCollection<string> configuredIds)
    {
        if (configuredIds.Contains(id))
            throw new InvalidOperationException($"L'account '{id}' è ancora configurato: per svuotarne la cache usare \"Ricostruisci cache\".");
        // L'id finisce in un percorso: solo caratteri ammessi, niente "..", niente collegamenti simbolici.
        var dir = MailAccountRegistry.IsValidId(id) ? new DirectoryInfo(MailAccountRegistry.CacheDirectory(cacheRoot, id)) : null;
        if (dir is null || !dir.Exists || IsLink(dir))
            throw new MailNotFoundException($"Nessun dato locale per l'account '{id}'.");
        dir.Delete(recursive: true);
    }

    private static Info? ReadInfo(string dir)
    {
        try
        {
            var path = Path.Combine(dir, InfoFileName);
            return File.Exists(path) ? JsonSerializer.Deserialize<Info>(File.ReadAllText(path)) : null;
        }
        catch (Exception ex) when (ex is JsonException or IOException)
        {
            return null; // file rovinato: si mostra l'id
        }
    }

    private static bool IsLink(FileSystemInfo f) => f.Attributes.HasFlag(FileAttributes.ReparsePoint);
}
