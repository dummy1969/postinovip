using PostinoVip.Core.Models;

namespace PostinoVip.Core.Archive;

/// <summary>
/// Quale cartella è l'archivio di un account (A1). In uso c'è solo quella scelta dall'utente (1a, come Outlook per
/// IMAP e POP3: «Imposta cartella di archiviazione»), se esiste ancora; finché non c'è, Archivia chiede di sceglierla
/// e propone <see cref="Suggest"/>.
/// </summary>
public static class ArchiveFolders
{
    /// <summary>Nomi riconosciuti come archivio (senza distinguere maiuscole), per la proposta.</summary>
    private static readonly string[] Names = ["Archivio", "Archive", "Archives", "Archivi", "Archiv"];

    /// <summary>Ruoli delle cartelle che non possono essere l'archivio (oltre alla posta indesiderata in uso).</summary>
    private static readonly string[] Forbidden = ["inbox", "sent", "drafts", "trash", "junk"];

    /// <summary>La cartella scelta, se c'è ancora; altrimenti null.</summary>
    public static string? InUse(IReadOnlyList<MailFolderInfo> folders, string? configured) =>
        configured is not null && folders.Any(f => f.FullName == configured) ? configured : null;

    /// <summary>
    /// Cartella da proporre la prima volta: quella dichiarata dal server (SPECIAL-USE \Archive), poi una con il nome
    /// di un archivio (prima quelle in cima all'account), poi «tutta la posta» (\All, Gmail: archiviare = togliere
    /// dalla Posta in arrivo). Null se nessuna: allora si propone di crearne una.
    /// </summary>
    public static string? Suggest(IReadOnlyList<MailFolderInfo> folders)
    {
        if (folders.FirstOrDefault(f => f.SpecialUse == "archive") is { } declared)
            return declared.FullName;
        var named = folders.Where(f => f.SpecialUse is null && Names.Contains(f.Name, StringComparer.OrdinalIgnoreCase))
            .OrderBy(f => f.FullName == f.Name ? 0 : 1).ThenBy(f => f.FullName.Length).FirstOrDefault();
        if (named is not null)
            return named.FullName;
        return folders.FirstOrDefault(f => f.SpecialUse == "all")?.FullName;
    }

    /// <summary>Motivo per cui <paramref name="folder"/> non può essere l'archivio, null se va bene.</summary>
    public static string? Refusal(IReadOnlyList<MailFolderInfo> folders, string folder, string? junkFolder)
    {
        var info = folders.FirstOrDefault(f => f.FullName == folder);
        if (info is null)
            return "La cartella scelta non esiste.";
        if (folder == junkFolder || Forbidden.Contains(info.SpecialUse))
            return "Scegliere una cartella diversa da Posta in arrivo, Posta inviata, Bozze, Posta eliminata e posta indesiderata.";
        return null;
    }

    /// <summary>
    /// L'elenco delle cartelle come lo vede l'app: l'archivio in uso ha il ruolo "archive" e nessun'altra lo ha
    /// (anche quella dichiarata dal server, finché non è scelta, resta senza ruolo, come la posta indesiderata).
    /// </summary>
    public static IReadOnlyList<MailFolderInfo> WithRole(IReadOnlyList<MailFolderInfo> folders, string? configured)
    {
        var archive = InUse(folders, configured);
        return folders.Select(f => f.FullName == archive ? f with { SpecialUse = "archive" }
            : f.SpecialUse == "archive" ? f with { SpecialUse = null } : f).ToList();
    }
}
