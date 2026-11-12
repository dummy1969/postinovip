namespace PostinoVip.Core.Events;

/// <summary>
/// Evento verso l'app, sempre relativo a un account. Type: "mailbox-changed" (Folder e Count
/// valorizzati), "watch-status" (Connected: true se il controllo in tempo reale è attivo) oppure
/// "connection-status" (Online: false se il server non è raggiungibile e si usa la copia locale) oppure
/// "cache-rebuilt" (copia locale svuotata su richiesta e in ricostruzione) oppure
/// "outbox-changed" (Posta in uscita cambiata, Count = mail in attesa).
/// </summary>
/// "credentials-changed" (OAuth2): il fornitore ha dato un nuovo token di rinnovo (RefreshToken), da salvare nel
/// portachiavi. Solo sul canale locale e autenticato verso l'app; mai nei log.
/// "contacts-changed" (C4): la sincronizzazione CardDAV ha cambiato la rubrica dell'account sul computer (Count = contatti
/// scaricati o eliminati), l'app la rilegge; anche quando serve la conferma della prima volta.
/// "calendars-changed" (K2a): la sincronizzazione CalDAV ha cambiato i calendari dell'account sul computer (Count =
/// appuntamenti scaricati o eliminati), o serve la conferma della prima volta.
/// "headers-pending" (11/11/2026): la lista di Folder ha lasciato intestazioni nuove al download in background (per il
/// core; l'app lo ignora). "folder-synced": il download in background ha completato le intestazioni di Folder (prima
/// sincronizzazione o cartella completata a blocchi): l'app rilegge la lista se è aperta lì.
/// "login-status" (OAuth2, 2a): NeedsLogin true se il fornitore ha rifiutato il token di rinnovo (serve un nuovo accesso).
public sealed record MailboxEvent(string Type, string Account, string? Folder = null, int? Count = null, bool? Connected = null,
    bool? Online = null, string? RefreshToken = null, bool? NeedsLogin = null)
{
    public static MailboxEvent LoginStatus(string account, bool needsLogin) => new("login-status", account, NeedsLogin: needsLogin);

    public static MailboxEvent CredentialsChanged(string account, string refreshToken) =>
        new("credentials-changed", account, RefreshToken: refreshToken);

    public static MailboxEvent ContactsChanged(string account, int count) => new("contacts-changed", account, Count: count);

    public static MailboxEvent CalendarsChanged(string account, int count) => new("calendars-changed", account, Count: count);

    public static MailboxEvent Connection(string account, bool online) => new("connection-status", account, Online: online);

    /// <summary>Cache dell'account svuotata su richiesta: il download in background ricomincia.</summary>
    public static MailboxEvent CacheRebuilt(string account) => new("cache-rebuilt", account);

    /// <summary>Posta in uscita cambiata (3.8): Count = mail in attesa di invio.</summary>
    public static MailboxEvent OutboxChanged(string account, int count) => new("outbox-changed", account, Count: count);

    public static MailboxEvent HeadersPending(string account, string folder) => new("headers-pending", account, folder);

    public static MailboxEvent FolderSynced(string account, string folder) => new("folder-synced", account, folder);

    public static MailboxEvent Changed(string account, string folder, int count) => new("mailbox-changed", account, folder, count);
    public static MailboxEvent Status(string account, bool connected) => new("watch-status", account, Connected: connected);
}
