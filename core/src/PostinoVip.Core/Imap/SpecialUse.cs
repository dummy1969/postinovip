using MailKit;

namespace PostinoVip.Core.Imap;

/// <summary>Ruolo speciale di una cartella a partire dagli attributi restituiti dal server nel LIST.</summary>
public static class SpecialUse
{
    private static readonly (FolderAttributes Flag, string Name)[] Map =
    [
        (FolderAttributes.Inbox, "inbox"),
        (FolderAttributes.Sent, "sent"),
        (FolderAttributes.Drafts, "drafts"),
        (FolderAttributes.Trash, "trash"),
        (FolderAttributes.Junk, "junk"),
        (FolderAttributes.Archive, "archive"),
        (FolderAttributes.All, "all"),
        (FolderAttributes.Flagged, "flagged"),
    ];

    public static string? FromAttributes(FolderAttributes attributes, string fullName)
    {
        foreach (var (flag, name) in Map)
            if (attributes.HasFlag(flag))
                return name;
        // INBOX è speciale per definizione (RFC 3501), anche senza attributo.
        return fullName.Equals("INBOX", StringComparison.OrdinalIgnoreCase) ? "inbox" : null;
    }
}
