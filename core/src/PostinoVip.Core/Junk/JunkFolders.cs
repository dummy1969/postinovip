using PostinoVip.Core.Models;

namespace PostinoVip.Core.Junk;

/// <summary>
/// Quale cartella è la posta indesiderata di un account: quella scelta dall'utente nelle Opzioni (3b), se esiste
/// ancora; altrimenti quella dichiarata dal server (SPECIAL-USE \Junk); altrimenti una riconosciuta dal nome, con
/// la stessa regola dell'app («spam», «junk», «indesiderat»). Null se non ce n'è nessuna: allora il filtro non
/// sposta niente e i comandi chiedono di sceglierla.
/// </summary>
public static class JunkFolders
{
    public static string? Resolve(IReadOnlyList<MailFolderInfo> folders, string? configured)
    {
        if (configured is not null && folders.Any(f => f.FullName == configured))
            return configured;
        if (folders.FirstOrDefault(f => f.SpecialUse == "junk") is { } declared)
            return declared.FullName;
        return folders.FirstOrDefault(f => f.SpecialUse is null && LooksLikeJunk(f.Name))?.FullName;
    }

    public static bool LooksLikeJunk(string name)
    {
        var n = name.ToLowerInvariant();
        return n.Contains("spam") || n.Contains("junk") || n.Contains("indesiderat");
    }

    /// <summary>
    /// L'elenco delle cartelle come lo vede l'app: la posta indesiderata dell'account ha il ruolo "junk" e
    /// nessun'altra lo ha (la cartella scelta prevale su quella dichiarata dal server).
    /// </summary>
    public static IReadOnlyList<MailFolderInfo> WithRole(IReadOnlyList<MailFolderInfo> folders, string? configured)
    {
        var junk = Resolve(folders, configured);
        return folders.Select(f => f.FullName == junk ? f with { SpecialUse = "junk" }
            : f.SpecialUse == "junk" ? f with { SpecialUse = null } : f).ToList();
    }
}
