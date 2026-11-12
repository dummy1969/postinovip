using PostinoVip.Core.Cache;
using PostinoVip.Core.Imap;

namespace PostinoVip.Core.Account;

/// <summary>
/// Una casella con i suoi servizi: ognuna ha la propria connessione IMAP.
/// <paramref name="bodies"/>: corpi nella cache locale (per la pulizia periodica), null senza cache.
/// <paramref name="connection"/>: la connessione IMAP dei comandi (stato "connesso"), null nei test.
/// </summary>
/// <paramref name="outbox"/>: coda locale di Posta in uscita e bozze in attesa (3.8), null senza cache.
/// <paramref name="pop3"/>: controllo periodico della posta degli account POP3 (4.2), null per IMAP.
public sealed class MailAccount(MailAccountSettings settings, IMailReader reader, IMailWriter writer, IMailSender sender,
    BodyCache? bodies = null, ImapConnection? connection = null, Outbox.OutboxStore? outbox = null, Pop3.Pop3Worker? pop3 = null,
    Rules.RuleStore? rules = null, AutoReply.AutoReplyStore? autoReply = null, Contacts.ContactStore? contacts = null,
    Contacts.RecentAddresses? recent = null, Dav.DavWorker? cardDav = null, Calendars.CalendarSet? calendars = null,
    Dav.DavWorker? calDav = null, Junk.JunkStore? junk = null, Archive.ArchiveStore? archive = null,
    Conversations.IgnoreStore? ignore = null)
{
    /// <summary>Conversazioni ignorate dell'account (C1), null senza copia locale.</summary>
    public Conversations.IgnoreStore? Ignore { get; } = ignore;

    /// <summary>Cartella di archiviazione dell'account (A1), null senza copia locale.</summary>
    public Archive.ArchiveStore? Archive { get; } = archive;

    /// <summary>Opzioni posta indesiderata dell'account (J1), null senza copia locale.</summary>
    public Junk.JunkStore? Junk { get; } = junk;

    /// <summary>Calendari dell'account (K2a), null senza copia locale.</summary>
    public Calendars.CalendarSet? Calendars { get; } = calendars;

    /// <summary>Sincronizzazione dei calendari con CalDAV (K2a), null se non attiva per l'account.</summary>
    public Dav.DavWorker? CalDav { get; } = calDav;

    /// <summary>Sincronizzazione della rubrica con CardDAV (C4), null se non attiva per l'account.</summary>
    public Dav.DavWorker? CardDav { get; } = cardDav;

    /// <summary>Rubrica dell'account (C1), null senza copia locale.</summary>
    public Contacts.ContactStore? Contacts { get; } = contacts;

    /// <summary>Indirizzi usati di recente (C1, 7a), null senza copia locale.</summary>
    public Contacts.RecentAddresses? Recent { get; } = recent;

    /// <summary>Risposte automatiche dell'account, null senza copia locale.</summary>
    public AutoReply.AutoReplyStore? AutoReply { get; } = autoReply;

    /// <summary>Regole dell'account (R1), null senza copia locale.</summary>
    public Rules.RuleStore? Rules { get; } = rules;

    public Pop3.Pop3Worker? Pop3 { get; } = pop3;

    public Outbox.OutboxStore? Outbox { get; } = outbox;

    public MailAccountSettings Settings { get; } = settings;
    public IMailReader Reader { get; } = reader;
    public IMailWriter Writer { get; } = writer;
    public IMailSender Sender { get; } = sender;
    public BodyCache? Bodies { get; } = bodies;
    public ImapConnection? Connection { get; } = connection;

    /// <summary>false se il server della casella non è raggiungibile (ultimo collegamento non riuscito).</summary>
    public bool Online => Connection?.IsOnline ?? Pop3?.IsOnline ?? true;

    public bool IsPop3 => Settings.IsPop3;

    /// <summary>OAuth2: il fornitore ha rifiutato il token di rinnovo, serve «Accedi di nuovo» (2a).</summary>
    public bool NeedsLogin => Settings.OAuth.Tokens?.NeedsLogin ?? false;

    public string Id => Settings.Id;
    public string Address => Settings.Address;
    public bool Configured => Settings.IsConfigured;
}
