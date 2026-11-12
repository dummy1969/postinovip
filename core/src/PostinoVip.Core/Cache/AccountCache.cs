using System.Collections.Concurrent;
using System.Globalization;
using Microsoft.Data.Sqlite;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Cache;

/// <summary>
/// Una mail di una conversazione vista da Ignora e Pulisci conversazione: cartella (e suo ruolo), Message-ID e
/// riferimenti già ripuliti, arrivo in secondi Unix (0 se sconosciuto).
/// </summary>
public sealed record ThreadMember(long Thread, string Folder, string? FolderRole, uint Uid, MailFlags Flags, string? MessageId,
    string? InReplyTo, IReadOnlyList<string> References, long Arrived)
{
    /// <summary>Message-ID che questa mail cita (risposta e riferimenti).</summary>
    public IEnumerable<string> Cited => InReplyTo is null ? References : References.Append(InReplyTo);
}

/// <summary>Stato di sincronizzazione di una cartella nella cache.</summary>
/// <param name="Role">Ruolo SPECIAL-USE ("inbox", "trash", "junk"...), null se nessuno o non ancora noto.</param>
public sealed record CachedFolder(long Id, string FullName, uint? UidValidity, DateTimeOffset? SyncedAt, string? Role);

/// <summary>Un risultato della ricerca come sta nella cache (dati grezzi, i valori mostrati si ricavano dopo).</summary>
public sealed record SearchRow(string Folder, uint Uid, MailFlags Flags, string? Subject, string? FromName, string? FromAddress,
    DateTimeOffset? Date, bool BodyIndexed, string? Snippet);

/// <summary>Corpo di un messaggio nella cache: impronta del file (null = non salvato) e data di arrivo.</summary>
public sealed record BodyRow(string? Sha256, DateTimeOffset? Arrived);

/// <summary>
/// Cache locale di un account: il file <c>index.db</c> (SQLite) nella cartella dell'account.
/// Contiene cartelle, intestazioni e flag, e collega i corpi salvati come file in <see cref="Bodies"/>;
/// è uno specchio del server e può essere ricostruita
/// in qualsiasi momento (il server è la fonte della verità).
/// Un solo processo scrittore (il core); le scritture di una cartella sono in serie perché
/// avvengono dentro la connessione IMAP dell'account.
/// </summary>
public sealed class AccountCache
{
    public const string FileName = "index.db";

    private readonly string _connectionString;
    // Sostituito dopo una ricostruzione: la prossima apertura rifà creazione, controllo e migrazioni.
    private volatile Lazy<bool> _ready;

    public AccountCache(string directory)
    {
        Directory = directory;
        Path = System.IO.Path.Combine(directory, FileName);
        Bodies = new BodyStore(System.IO.Path.Combine(directory, "bodies"));
        _connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = Path,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Pooling = true,
        }.ToString();
        // Creazione e migrazione al primo uso, una sola volta (se fallisce si ritenta alla richiesta successiva).
        _ready = NewReady();
    }

    public string Directory { get; }
    public string Path { get; }

    /// <summary>I file .eml dei messaggi, collegati alle righe con <c>messages.body_sha256</c>.</summary>
    public BodyStore Bodies { get; }

    private string? _initializeNote;
    private readonly ConcurrentDictionary<string, SemaphoreSlim> _folderLocks = new(StringComparer.Ordinal);

    /// <summary>
    /// Messaggio diagnostico dell'inizializzazione (es. database ricreato), restituito una sola volta;
    /// null se non c'è nulla da dire.
    /// </summary>
    public string? TakeInitializeNote() => Interlocked.Exchange(ref _initializeNote, null);

    // ---------------------------------------------------------------------------------------------
    // Cartelle
    // ---------------------------------------------------------------------------------------------

    /// <summary>La cartella con questo nome, creata se non esiste ancora.</summary>
    public CachedFolder GetOrAddFolder(string fullName)
    {
        using var db = Open();
        using (var insert = db.CreateCommand())
        {
            insert.CommandText = "INSERT INTO folders(full_name) VALUES ($name) ON CONFLICT(full_name) DO NOTHING";
            insert.Parameters.AddWithValue("$name", fullName);
            insert.ExecuteNonQuery();
        }
        return FindFolder(db, fullName)!;
    }

    public CachedFolder? FindFolder(string fullName)
    {
        using var db = Open();
        return FindFolder(db, fullName);
    }

    /// <summary>
    /// Elimina le cartelle che il server non ha più (con i loro messaggi): la cache è uno specchio.
    /// </summary>
    /// <returns>Numero di cartelle eliminate.</returns>
    public int RemoveFoldersNotIn(IReadOnlyCollection<string> serverFolders)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        var existing = new List<string>();
        using (var select = db.CreateCommand())
        {
            select.CommandText = "SELECT full_name FROM folders";
            using var r = select.ExecuteReader();
            while (r.Read())
                existing.Add(r.GetString(0));
        }

        var keep = new HashSet<string>(serverFolders, StringComparer.Ordinal);
        var removed = 0;
        using var delete = db.CreateCommand();
        delete.CommandText = "DELETE FROM folders WHERE full_name = $name";
        var name = delete.Parameters.Add("$name", SqliteType.Text);
        foreach (var f in existing.Where(f => !keep.Contains(f)))
        {
            name.Value = f;
            removed += delete.ExecuteNonQuery();
        }
        tx.Commit();
        if (removed > 0)
            MarkThreadsDirty();
        return removed;
    }

    /// <summary>
    /// Cartella rinominata o spostata sul server (anche dentro Posta eliminata): nella cache cambiano solo
    /// i nomi, della cartella e delle sottocartelle, così mail e corpi già scaricati restano (stesso id).
    /// Righe che avessero già il nuovo nome (viste nel frattempo da una sincronizzazione) vengono tolte.
    /// </summary>
    /// <returns>Numero di cartelle rinominate (0 se la cartella non era in cache).</returns>
    public int RenameFolderTree(string oldName, string newName, char separator)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        Execute(db, $"DELETE FROM folders WHERE {TreeCondition("$new", "$newPrefix")}",
            ("$new", newName), ("$newPrefix", newName + separator));
        int renamed;
        using (var cmd = db.CreateCommand())
        {
            // substr e length contano caratteri, non byte: i nomi non ASCII restano corretti.
            cmd.CommandText = $"UPDATE folders SET full_name = $new || substr(full_name, length($old) + 1) WHERE {TreeCondition("$old", "$oldPrefix")}";
            cmd.Parameters.AddWithValue("$new", newName);
            cmd.Parameters.AddWithValue("$old", oldName);
            cmd.Parameters.AddWithValue("$oldPrefix", oldName + separator);
            renamed = cmd.ExecuteNonQuery();
        }
        var cut = newName.LastIndexOf(separator);
        Execute(db, "UPDATE folders SET name = $name WHERE full_name = $new",
            ("$name", cut < 0 ? newName : newName[(cut + 1)..]), ("$new", newName));
        tx.Commit();
        return renamed;
    }

    /// <summary>Cartella eliminata definitivamente sul server: via dalla cache con le sottocartelle e le loro mail.</summary>
    /// <returns>Numero di cartelle tolte.</returns>
    public int RemoveFolderTree(string fullName, char separator)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = $"DELETE FROM folders WHERE {TreeCondition("$name", "$prefix")}";
        cmd.Parameters.AddWithValue("$name", fullName);
        cmd.Parameters.AddWithValue("$prefix", fullName + separator);
        var removed = cmd.ExecuteNonQuery();
        MarkThreadsDirty();
        return removed;
    }

    /// <summary>La cartella stessa o una sua discendente (confronto esatto sul prefisso, niente LIKE e caratteri jolly).</summary>
    private static string TreeCondition(string name, string prefix) =>
        $"(full_name = {name} OR substr(full_name, 1, length({prefix})) = {prefix})";

    /// <summary>
    /// Una sola sincronizzazione alla volta per cartella: la lista dell'app (connessione dei comandi) e il
    /// download in background (connessione dedicata) possono lavorare sulla stessa cartella.
    /// </summary>
    /// <summary>Il blocco della cartella se è libero adesso, altrimenti null (senza aspettare).</summary>
    public IDisposable? TryLockFolder(string fullName)
    {
        var gate = _folderLocks.GetOrAdd(fullName, _ => new SemaphoreSlim(1, 1));
        return gate.Wait(0) ? new Releaser(gate) : null;
    }

    public async Task<IDisposable> LockFolderAsync(string fullName, CancellationToken ct = default)
    {
        var gate = _folderLocks.GetOrAdd(fullName, _ => new SemaphoreSlim(1, 1));
        await gate.WaitAsync(ct);
        return new Releaser(gate);
    }

    private sealed class Releaser(SemaphoreSlim gate) : IDisposable
    {
        private int _released;

        public void Dispose()
        {
            if (Interlocked.Exchange(ref _released, 1) == 0)
                gate.Release();
        }
    }

    /// <summary>
    /// Nome mostrato e ruolo SPECIAL-USE delle cartelle come le elenca il server (il ruolo decide quali
    /// corpi conservare; il nome serve all'elenco senza connessione); crea quelle non ancora in cache.
    /// </summary>
    public void SetFolderInfo(IReadOnlyList<MailFolderInfo> folders)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            INSERT INTO folders(full_name, name, role) VALUES ($fullName, $name, $role)
            ON CONFLICT(full_name) DO UPDATE SET name = excluded.name, role = excluded.role
            WHERE name IS NOT excluded.name OR role IS NOT excluded.role
            """;
        var fullName = cmd.Parameters.Add("$fullName", SqliteType.Text);
        var name = cmd.Parameters.Add("$name", SqliteType.Text);
        var role = cmd.Parameters.Add("$role", SqliteType.Text);
        foreach (var f in folders)
        {
            fullName.Value = f.FullName;
            name.Value = f.Name;
            role.Value = (object?)f.SpecialUse ?? DBNull.Value;
            cmd.ExecuteNonQuery();
        }
        tx.Commit();
    }

    /// <summary>
    /// Le cartelle come le conosce la cache (senza connessione): nome, ruolo e numero di messaggi
    /// (null se la cartella non è mai stata sincronizzata), in ordine di nome come il server.
    /// </summary>
    public IReadOnlyList<MailFolderInfo> GetFolderList()
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            SELECT f.full_name, coalesce(f.name, f.full_name), f.role,
                   CASE WHEN f.synced_at IS NULL THEN NULL ELSE (SELECT count(*) FROM messages m WHERE m.folder_id = f.id) END,
                   CASE WHEN f.synced_at IS NULL THEN NULL
                        ELSE (SELECT count(*) FROM messages m WHERE m.folder_id = f.id AND (m.flags & 1) = 0) END
            FROM folders f
            """;
        var result = new List<MailFolderInfo>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
        {
            result.Add(new MailFolderInfo(r.GetString(0), r.GetString(1), r.IsDBNull(3) ? null : r.GetInt32(3), Text(r, 2),
                r.IsDBNull(4) ? null : r.GetInt32(4)));
        }
        return result.OrderBy(f => f.FullName, StringComparer.OrdinalIgnoreCase).ToList();
    }

    /// <summary>UIDVALIDITY cambiato: tutti i messaggi salvati della cartella vanno buttati.</summary>
    public void ResetFolder(long folderId, uint uidValidity)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        Execute(db, "DELETE FROM messages WHERE folder_id = $f", ("$f", folderId));
        Execute(db, "UPDATE folders SET uid_validity = $v, synced_at = NULL WHERE id = $f", ("$v", (long)uidValidity), ("$f", folderId));
        tx.Commit();
        MarkThreadsDirty();
    }

    public void MarkSynced(long folderId, DateTimeOffset when)
    {
        using var db = Open();
        Execute(db, "UPDATE folders SET synced_at = $t WHERE id = $f", ("$t", FormatDate(when)), ("$f", folderId));
    }

    // ---------------------------------------------------------------------------------------------
    // Messaggi
    // ---------------------------------------------------------------------------------------------

    public HashSet<uint> GetUids(long folderId)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT uid FROM messages WHERE folder_id = $f";
        cmd.Parameters.AddWithValue("$f", folderId);
        var uids = new HashSet<uint>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            uids.Add((uint)r.GetInt64(0));
        return uids;
    }

    /// <summary>Inserisce (o sostituisce) le intestazioni, in una sola transazione.</summary>
    public void UpsertHeaders(long folderId, IReadOnlyList<HeaderRecord> headers)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            INSERT INTO messages(folder_id, uid, flags, subject, from_name, from_address, to_list, cc_list,
                                 date, internal_date, size, message_id, in_reply_to, arrived, indexed, preview, has_attachments, refs, importance)
            VALUES ($f, $uid, $flags, $subject, $fromName, $fromAddress, $to, $cc, $date, $internalDate, $size, $messageId, $inReplyTo,
                    unixepoch(coalesce($internalDate, $date)), 1, $preview, $hasAttachments, $refs, $importance)
            ON CONFLICT(folder_id, uid) DO UPDATE SET
                flags = excluded.flags, subject = excluded.subject, from_name = excluded.from_name,
                from_address = excluded.from_address, to_list = excluded.to_list, cc_list = excluded.cc_list,
                date = excluded.date, internal_date = excluded.internal_date, size = excluded.size,
                message_id = excluded.message_id, in_reply_to = excluded.in_reply_to, arrived = excluded.arrived,
                preview = coalesce(excluded.preview, preview), refs = coalesce(excluded.refs, refs), importance = coalesce(excluded.importance, importance), has_attachments = coalesce(excluded.has_attachments, has_attachments),
                flag_due = CASE WHEN excluded.flags & 4 THEN flag_due END, -- contrassegno tolto altrove: niente scadenza
                indexed = 1 -- intestazioni reindicizzate qui sotto; il corpo, se c'è, lo riaggiunge l'indicizzazione dei corpi
            RETURNING id
            """;
        // Indice di ricerca: intestazioni subito, corpo vuoto (aggiunto quando il corpo è in cache).
        using var index = db.CreateCommand();
        index.CommandText = """
            DELETE FROM messages_fts WHERE rowid = $id;
            INSERT INTO messages_fts(rowid, subject, sender, recipients, body, attachments)
            VALUES ($id, coalesce($subject, ''), trim(coalesce($fromName, '') || ' ' || coalesce($fromAddress, '')),
                    trim(coalesce($to, '') || ' ' || coalesce($cc, '')), '', '');
            """;
        var indexId = index.Parameters.Add("$id", SqliteType.Integer);
        string[] indexed = ["$subject", "$fromName", "$fromAddress", "$to", "$cc"];
        foreach (var name in indexed)
            index.Parameters.Add(name, SqliteType.Text);
        cmd.Parameters.AddWithValue("$f", folderId);
        var p = new Dictionary<string, SqliteParameter>();
        foreach (var name in new[] { "$uid", "$flags", "$size", "$hasAttachments", "$importance" })
            p[name] = cmd.Parameters.Add(name, SqliteType.Integer);
        foreach (var name in new[] { "$subject", "$fromName", "$fromAddress", "$to", "$cc", "$date", "$internalDate",
                     "$messageId", "$inReplyTo", "$preview", "$refs" })
            p[name] = cmd.Parameters.Add(name, SqliteType.Text);

        foreach (var h in headers)
        {
            p["$uid"].Value = (long)h.Uid;
            p["$flags"].Value = (long)h.Flags;
            p["$subject"].Value = (object?)h.Subject ?? DBNull.Value;
            p["$fromName"].Value = (object?)h.FromName ?? DBNull.Value;
            p["$fromAddress"].Value = (object?)h.FromAddress ?? DBNull.Value;
            p["$to"].Value = (object?)h.To ?? DBNull.Value;
            p["$cc"].Value = (object?)h.Cc ?? DBNull.Value;
            p["$date"].Value = h.Date is { } d ? FormatDate(d) : DBNull.Value;
            p["$internalDate"].Value = h.InternalDate is { } i ? FormatDate(i) : DBNull.Value;
            p["$size"].Value = (object?)h.Size ?? DBNull.Value;
            p["$messageId"].Value = (object?)h.MessageId ?? DBNull.Value;
            p["$inReplyTo"].Value = (object?)h.InReplyTo ?? DBNull.Value;
            p["$preview"].Value = (object?)h.Preview ?? DBNull.Value;
            p["$refs"].Value = (object?)h.References ?? DBNull.Value;
            p["$hasAttachments"].Value = h.HasAttachments is { } has ? (has ? 1L : 0L) : DBNull.Value;
            p["$importance"].Value = h.Importance is { } imp ? (long)imp : DBNull.Value;
            indexId.Value = cmd.ExecuteScalar();
            foreach (var name in indexed)
                index.Parameters[name].Value = p[name].Value;
            index.ExecuteNonQuery();
        }
        tx.Commit();
        MarkThreadsDirty();
    }

    /// <summary>Aggiorna i flag dei messaggi già salvati; restituisce quanti sono cambiati davvero.</summary>
    public int UpdateFlags(long folderId, IReadOnlyList<(uint Uid, MailFlags Flags)> flags)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        using var cmd = db.CreateCommand();
        // "flags <> $flags": le righe invariate non contano (e non vengono riscritte). Contrassegno tolto
        // (anche da un altro programma): la scadenza locale non vale più.
        cmd.CommandText = """
            UPDATE messages SET flags = $flags, flag_due = CASE WHEN $flags & 4 THEN flag_due END
            WHERE folder_id = $f AND uid = $uid AND flags <> $flags
            """;
        cmd.Parameters.AddWithValue("$f", folderId);
        var uid = cmd.Parameters.Add("$uid", SqliteType.Integer);
        var value = cmd.Parameters.Add("$flags", SqliteType.Integer);
        var changed = 0;
        foreach (var (u, f) in flags)
        {
            uid.Value = (long)u;
            value.Value = (long)f;
            changed += cmd.ExecuteNonQuery();
        }
        tx.Commit();
        return changed;
    }

    /// <summary>
    /// Flag appena scritti sul server e scadenza del contrassegno (solo locale: IMAP non ha un posto
    /// standard dove salvarla). <paramref name="keepDue"/>: la scadenza resta quella salvata.
    /// Restituisce la scadenza risultante (null se il messaggio non è contrassegnato o non è in cache).
    /// </summary>
    public DateOnly? SetFlags(long folderId, uint uid, MailFlags flags, DateOnly? due, bool keepDue = false)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = $"""
            UPDATE messages SET flags = $flags, flag_due = CASE WHEN $flags & 4 THEN {(keepDue ? "flag_due" : "$due")} END
            WHERE folder_id = $f AND uid = $uid
            RETURNING flag_due
            """;
        cmd.Parameters.AddWithValue("$f", folderId);
        cmd.Parameters.AddWithValue("$uid", (long)uid);
        cmd.Parameters.AddWithValue("$flags", (long)flags);
        cmd.Parameters.AddWithValue("$due", due is { } d ? d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : DBNull.Value);
        return ParseDay(cmd.ExecuteScalar() as string);
    }

    /// <summary>Flag e scadenza del contrassegno di un messaggio; null se non è in cache.</summary>
    public (MailFlags Flags, DateOnly? Due)? GetFlags(long folderId, uint uid)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT flags, flag_due FROM messages WHERE folder_id = $f AND uid = $uid";
        cmd.Parameters.AddWithValue("$f", folderId);
        cmd.Parameters.AddWithValue("$uid", (long)uid);
        using var r = cmd.ExecuteReader();
        return r.Read() ? ((MailFlags)r.GetInt64(0), ParseDay(Text(r, 1))) : null;
    }

    private static DateOnly? ParseDay(string? value) =>
        value is null ? null : DateOnly.ParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture);

    /// <summary>UID dei messaggi arrivati (INTERNALDATE, altrimenti Date) da <paramref name="since"/> in poi.</summary>
    public HashSet<uint> GetUidsArrivedSince(long folderId, DateTimeOffset since)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT uid FROM messages WHERE folder_id = $f AND arrived >= $since";
        cmd.Parameters.AddWithValue("$f", folderId);
        cmd.Parameters.AddWithValue("$since", since.ToUnixTimeSeconds());
        var result = new HashSet<uint>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add((uint)r.GetInt64(0));
        return result;
    }

    /// <summary>
    /// Destinatari (A e Cc, come li ha salvati la sincronizzazione) delle mail della Posta inviata, dalla più
    /// recente, con la data d'arrivo: punto di partenza degli indirizzi usati di recente (contatti, 7a).
    /// </summary>
    public List<(string? To, string? Cc, DateTimeOffset? When)> GetSentRecipients(int limit)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            SELECT m.to_list, m.cc_list, m.arrived FROM messages m JOIN folders f ON f.id = m.folder_id
            WHERE f.role = 'sent' ORDER BY m.arrived DESC, m.uid DESC LIMIT $limit
            """;
        cmd.Parameters.AddWithValue("$limit", limit);
        var result = new List<(string?, string?, DateTimeOffset?)>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add((r.IsDBNull(0) ? null : r.GetString(0), r.IsDBNull(1) ? null : r.GetString(1),
                r.IsDBNull(2) ? null : DateTimeOffset.FromUnixTimeSeconds(r.GetInt64(2))));
        return result;
    }

    /// <summary>Dimensione del messaggio (RFC822.SIZE o del file); null se non nota o non in cache.</summary>
    public long? GetSize(long folderId, uint uid)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT size FROM messages WHERE folder_id = $f AND uid = $uid";
        cmd.Parameters.AddWithValue("$f", folderId);
        cmd.Parameters.AddWithValue("$uid", (long)uid);
        return cmd.ExecuteScalar() is long size ? size : null;
    }

    public int DeleteMessages(long folderId, IEnumerable<uint> uids)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "DELETE FROM messages WHERE folder_id = $f AND uid = $uid";
        cmd.Parameters.AddWithValue("$f", folderId);
        var uid = cmd.Parameters.Add("$uid", SqliteType.Integer);
        var removed = 0;
        foreach (var u in uids)
        {
            uid.Value = (long)u;
            removed += cmd.ExecuteNonQuery();
        }
        tx.Commit();
        if (removed > 0)
            MarkThreadsDirty();
        return removed;
    }

    // ---------------------------------------------------------------------------------------------
    // Corpi (file .eml in Bodies)
    // ---------------------------------------------------------------------------------------------

    /// <summary>Il corpo del messaggio; null se il messaggio non è (ancora) in cache.</summary>
    public BodyRow? GetBodyRow(long folderId, uint uid)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT body_sha256, internal_date, date FROM messages WHERE folder_id = $f AND uid = $uid";
        cmd.Parameters.AddWithValue("$f", folderId);
        cmd.Parameters.AddWithValue("$uid", (long)uid);
        using var r = cmd.ExecuteReader();
        return r.Read() ? new BodyRow(Text(r, 0), ParseDate(Text(r, 1)) ?? ParseDate(Text(r, 2))) : null;
    }

    /// <summary>Messaggi della cartella senza corpo in cache, dal più recente (UID decrescente).</summary>
    public IReadOnlyList<(uint Uid, DateTimeOffset? Arrived)> GetMissingBodies(long folderId)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            SELECT uid, internal_date, date FROM messages
            WHERE folder_id = $f AND body_sha256 IS NULL ORDER BY uid DESC
            """;
        cmd.Parameters.AddWithValue("$f", folderId);
        var result = new List<(uint, DateTimeOffset?)>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add(((uint)r.GetInt64(0), ParseDate(Text(r, 1)) ?? ParseDate(Text(r, 2))));
        return result;
    }

    /// <summary>
    /// Messaggi senza anteprima o senza informazione sugli allegati e senza corpo nell'indice (quelli col
    /// corpo li completa l'indicizzazione): da chiedere al server, dal più recente.
    /// </summary>
    public IReadOnlyList<uint> GetMissingPreviews(long folderId)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            SELECT uid FROM messages
            WHERE folder_id = $f AND (preview IS NULL OR has_attachments IS NULL) AND indexed < 2
            ORDER BY coalesce(arrived, 0) DESC, uid DESC
            """;
        cmd.Parameters.AddWithValue("$f", folderId);
        var result = new List<uint>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add((uint)r.GetInt64(0));
        return result;
    }

    /// <summary>
    /// Anteprima per i messaggi il cui corpo è già nell'indice di ricerca ma che non l'hanno ancora
    /// (indicizzati prima che esistesse l'anteprima): ricavata dal testo salvato, senza rete.
    /// </summary>
    /// <returns>Quante anteprime sono state scritte.</returns>
    public int FillPreviewsFromIndex(long folderId)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        var found = new List<(long Id, string Body)>();
        using (var select = db.CreateCommand())
        {
            select.CommandText = """
                SELECT m.id, f.body FROM messages m JOIN messages_fts f ON f.rowid = m.id
                WHERE m.folder_id = $f AND m.indexed = 2 AND m.preview IS NULL
                """;
            select.Parameters.AddWithValue("$f", folderId);
            using var r = select.ExecuteReader();
            while (r.Read())
                found.Add((r.GetInt64(0), r.IsDBNull(1) ? "" : r.GetString(1)));
        }
        using var update = db.CreateCommand();
        update.CommandText = "UPDATE messages SET preview = $preview WHERE id = $id";
        var id = update.Parameters.Add("$id", SqliteType.Integer);
        var preview = update.Parameters.Add("$preview", SqliteType.Text);
        foreach (var (i, body) in found)
        {
            id.Value = i;
            preview.Value = PostinoVip.Core.Imap.MessageHeaderMapper.CleanPreview(body);
            update.ExecuteNonQuery();
        }
        tx.Commit();
        return found.Count;
    }

    /// <summary>Salva anteprime e presenza di allegati lette dal server.</summary>
    public void SetPreviews(long folderId, IReadOnlyList<PreviewRecord> previews)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            UPDATE messages SET preview = $preview, has_attachments = coalesce($has, has_attachments)
            WHERE folder_id = $f AND uid = $uid
            """;
        cmd.Parameters.AddWithValue("$f", folderId);
        var uid = cmd.Parameters.Add("$uid", SqliteType.Integer);
        var preview = cmd.Parameters.Add("$preview", SqliteType.Text);
        var has = cmd.Parameters.Add("$has", SqliteType.Integer);
        foreach (var p in previews)
        {
            uid.Value = (long)p.Uid;
            preview.Value = p.Preview;
            has.Value = p.HasAttachments is { } h ? (h ? 1L : 0L) : DBNull.Value;
            cmd.ExecuteNonQuery();
        }
        tx.Commit();
    }

    /// <summary>Collega (o con null scollega) il file del corpo; false se il messaggio non c'è più.</summary>
    /// <remarks>
    /// Con <paramref name="text"/> il corpo entra anche nell'indice di ricerca; senza file
    /// (<paramref name="sha256"/> null) l'indice torna alle sole intestazioni.
    /// </remarks>
    public bool SetBody(long folderId, uint uid, string? sha256, SearchText? text = null)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        long id;
        using (var select = db.CreateCommand())
        {
            select.CommandText = "SELECT id FROM messages WHERE folder_id = $f AND uid = $uid";
            select.Parameters.AddWithValue("$f", folderId);
            select.Parameters.AddWithValue("$uid", (long)uid);
            if (select.ExecuteScalar() is not long found)
                return false;
            id = found;
        }

        Execute(db, "UPDATE messages SET body_sha256 = $sha WHERE id = $id", ("$sha", (object?)sha256 ?? DBNull.Value), ("$id", id));
        if (sha256 is null)
            SetIndexedBody(db, id, null);
        else if (text is not null)
            SetIndexedBody(db, id, text);
        tx.Commit();
        return true;
    }

    /// <summary>Corpi in cache non ancora nell'indice di ricerca (es. salvati prima dell'8c, o scaricati in background).</summary>
    public IReadOnlyList<(uint Uid, string Sha256)> GetBodiesToIndex(long folderId)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            SELECT uid, body_sha256 FROM messages
            WHERE folder_id = $f AND body_sha256 IS NOT NULL AND indexed < 2 ORDER BY uid DESC
            """;
        cmd.Parameters.AddWithValue("$f", folderId);
        var result = new List<(uint, string)>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add(((uint)r.GetInt64(0), r.GetString(1)));
        return result;
    }

    /// <summary>
    /// Messaggi senza corpo nell'indice di ricerca (indexed &lt; 2), dal più recente: per le caselle locali
    /// (POP3), dove il corpo è già sul disco e va solo indicizzato.
    /// </summary>
    public IReadOnlyList<uint> GetUnindexedBodies(long folderId)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT uid FROM messages WHERE folder_id = $f AND indexed < 2 ORDER BY uid DESC";
        cmd.Parameters.AddWithValue("$f", folderId);
        var result = new List<uint>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add((uint)r.GetInt64(0));
        return result;
    }

    /// <summary>Corpo di un messaggio locale nell'indice di ricerca, senza file nella cache dei corpi (POP3).</summary>
    public bool SetLocalBodyIndexed(long folderId, uint uid, SearchText text)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        using var select = db.CreateCommand();
        select.CommandText = "SELECT id FROM messages WHERE folder_id = $f AND uid = $uid";
        select.Parameters.AddWithValue("$f", folderId);
        select.Parameters.AddWithValue("$uid", (long)uid);
        if (select.ExecuteScalar() is not long id)
            return false;
        SetIndexedBody(db, id, text);
        tx.Commit();
        return true;
    }

    /// <summary>Corpo e allegati nell'indice (indexed = 2), oppure con null tolti (indexed = 1, solo intestazioni).</summary>
    private static void SetIndexedBody(SqliteConnection db, long id, SearchText? text)
    {
        Execute(db, "UPDATE messages_fts SET body = $body, attachments = $att WHERE rowid = $id",
            ("$body", text?.Body ?? ""), ("$att", text is null ? "" : string.Join(" ", text.AttachmentNames)), ("$id", id));
        // Senza corpo la presenza di allegati resta quella già nota: non dipende dalla cache.
        if (text is null)
            Execute(db, "UPDATE messages SET indexed = 1 WHERE id = $id", ("$id", id));
        else
            Execute(db, "UPDATE messages SET indexed = 2, has_attachments = $has, preview = coalesce(preview, $preview) WHERE id = $id",
                ("$has", text.HasAttachments ? 1L : 0L), ("$preview", PostinoVip.Core.Imap.MessageHeaderMapper.CleanPreview(text.Body)), ("$id", id));
    }

    /// <summary>Impronte dei file collegati ad almeno un messaggio (gli altri file sono orfani).</summary>
    public HashSet<string> GetReferencedBodies()
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT DISTINCT body_sha256 FROM messages WHERE body_sha256 IS NOT NULL";
        var result = new HashSet<string>(StringComparer.Ordinal);
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add(r.GetString(0));
        return result;
    }

    /// <summary>
    /// Scollega i corpi per cui <paramref name="keep"/> (ruolo della cartella, data di arrivo) è falso.
    /// I file restano: li elimina la pulizia se non servono ad altri messaggi.
    /// </summary>
    /// <returns>Numero di corpi scollegati.</returns>
    public int DropBodies(Func<string?, DateTimeOffset?, bool> keep)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        var drop = new List<long>();
        using (var select = db.CreateCommand())
        {
            // Date confrontate in C#: le stringhe ISO hanno fusi orari diversi e non si ordinano come testo.
            select.CommandText = """
                SELECT m.id, f.role, m.internal_date, m.date
                FROM messages m JOIN folders f ON f.id = m.folder_id
                WHERE m.body_sha256 IS NOT NULL
                """;
            using var r = select.ExecuteReader();
            while (r.Read())
            {
                if (!keep(Text(r, 1), ParseDate(Text(r, 2)) ?? ParseDate(Text(r, 3))))
                    drop.Add(r.GetInt64(0));
            }
        }

        foreach (var d in drop)
        {
            Execute(db, "UPDATE messages SET body_sha256 = NULL WHERE id = $id", ("$id", d));
            SetIndexedBody(db, d, null); // fuori dal limite: si cercano solo le intestazioni
        }
        tx.Commit();
        return drop.Count;
    }

    /// <summary>
    /// Una pagina di intestazioni dalla più recente (UID più alto: gli UID crescono con l'ordine di
    /// arrivo, come gli indici IMAP usati prima della cache). Total = messaggi della cartella.
    /// </summary>
    /// <param name="unreadOnly">Solo i messaggi da leggere (filtro "Da leggere"); Total è allora il loro numero.</param>
    /// <param name="oldestFirst">In ordine crescente (dal più vecchio, A→Z, dal più piccolo).</param>
    /// <param name="sort">Colonna (3.9): data di arrivo, mittente (nome, altrimenti indirizzo), oggetto, dimensione;
    /// a parità sempre dalla più recente. Testo senza distinzione di maiuscole (solo lettere senza accenti).</param>
    public (int Total, IReadOnlyList<HeaderRecord> Items) GetPage(long folderId, int offset, int limit,
        bool unreadOnly = false, bool oldestFirst = false, MessageSort sort = MessageSort.Date)
    {
        var filter = unreadOnly ? " AND (flags & 1) = 0" : "";
        var direction = oldestFirst ? "ASC" : "DESC";
        using var db = Open();
        int total;
        using (var count = db.CreateCommand())
        {
            count.CommandText = "SELECT count(*) FROM messages WHERE folder_id = $f" + filter;
            count.Parameters.AddWithValue("$f", folderId);
            total = Convert.ToInt32(count.ExecuteScalar(), CultureInfo.InvariantCulture);
        }

        using var cmd = db.CreateCommand();
        // Per data di arrivo (come "Ricevuto" in Outlook), a parità per UID.
        cmd.CommandText = $"""
            SELECT {HeaderColumns("")}
            FROM messages WHERE folder_id = $f{filter}
            ORDER BY {sort switch
            {
                MessageSort.From => $"lower(coalesce(nullif(from_name, ''), from_address, '')) {direction}, coalesce(arrived, 0) DESC, uid DESC",
                MessageSort.Subject => $"lower(coalesce(subject, '')) {direction}, coalesce(arrived, 0) DESC, uid DESC",
                MessageSort.Size => $"coalesce(size, 0) {direction}, coalesce(arrived, 0) DESC, uid DESC",
                _ => $"coalesce(arrived, 0) {direction}, uid {direction}",
            }} LIMIT $limit OFFSET $offset
            """;
        cmd.Parameters.AddWithValue("$f", folderId);
        cmd.Parameters.AddWithValue("$limit", limit);
        cmd.Parameters.AddWithValue("$offset", offset);
        var items = new List<HeaderRecord>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            items.Add(ReadHeader(r, 0));
        return (total, items);
    }

    /// <summary>Colonne lette da <see cref="ReadHeader"/>, nell'ordine (con <paramref name="alias"/> "m." se serve).</summary>
    private static string HeaderColumns(string alias) => string.Join(", ",
        new[] { "uid", "flags", "subject", "from_name", "from_address", "to_list", "cc_list", "date", "internal_date", "size",
                "message_id", "in_reply_to", "preview", "has_attachments", "flag_due", "importance" }.Select(c => alias + c));

    private static HeaderRecord ReadHeader(SqliteDataReader r, int o) => new(
        (uint)r.GetInt64(o),
        (MailFlags)r.GetInt64(o + 1),
        Text(r, o + 2), Text(r, o + 3), Text(r, o + 4), Text(r, o + 5), Text(r, o + 6),
        ParseDate(Text(r, o + 7)), ParseDate(Text(r, o + 8)),
        r.IsDBNull(o + 9) ? null : r.GetInt64(o + 9),
        Text(r, o + 10), Text(r, o + 11), Text(r, o + 12), r.IsDBNull(o + 13) ? null : r.GetInt64(o + 13) == 1,
        ParseDay(Text(r, o + 14)),
        Importance: r.IsDBNull(o + 15) ? null : (MailImportance)r.GetInt64(o + 15));

    // ---------------------------------------------------------------------------------------------
    // Conversazioni (3.6): mail legate da Message-ID, In-Reply-To e References, in tutto l'account
    // ---------------------------------------------------------------------------------------------

    /// <summary>1 = le conversazioni vanno ricalcolate (all'apertura e dopo ogni cambiamento delle mail).</summary>
    private int _threadsDirty = 1;
    private readonly Lock _threadsLock = new();

    private void MarkThreadsDirty() => Volatile.Write(ref _threadsDirty, 1);

    /// <summary>Messaggi di cui non si conosce ancora References (salvati prima dello schema 7), dal più recente.</summary>
    public IReadOnlyList<uint> GetMissingReferences(long folderId)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT uid FROM messages WHERE folder_id = $f AND refs IS NULL ORDER BY coalesce(arrived, 0) DESC, uid DESC";
        cmd.Parameters.AddWithValue("$f", folderId);
        var result = new List<uint>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add((uint)r.GetInt64(0));
        return result;
    }

    /// <summary>Salva References letta dal server ('' = intestazione assente).</summary>
    public void SetReferences(long folderId, IReadOnlyList<(uint Uid, string References)> refs)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "UPDATE messages SET refs = $refs WHERE folder_id = $f AND uid = $uid";
        cmd.Parameters.AddWithValue("$f", folderId);
        var uid = cmd.Parameters.Add("$uid", SqliteType.Integer);
        var value = cmd.Parameters.Add("$refs", SqliteType.Text);
        foreach (var (u, v) in refs)
        {
            uid.Value = (long)u;
            value.Value = v;
            cmd.ExecuteNonQuery();
        }
        tx.Commit();
        MarkThreadsDirty();
    }

    /// <summary>Messaggi di cui non si conosce ancora l'importanza (salvati prima dello schema 8, P1), dal più recente.</summary>
    public IReadOnlyList<uint> GetMissingImportance(long folderId)
    {
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT uid FROM messages WHERE folder_id = $f AND importance IS NULL ORDER BY coalesce(arrived, 0) DESC, uid DESC";
        cmd.Parameters.AddWithValue("$f", folderId);
        var result = new List<uint>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add((uint)r.GetInt64(0));
        return result;
    }

    /// <summary>Salva l'importanza letta dal server.</summary>
    public void SetImportance(long folderId, IReadOnlyList<(uint Uid, MailImportance Importance)> values)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "UPDATE messages SET importance = $v WHERE folder_id = $f AND uid = $uid";
        cmd.Parameters.AddWithValue("$f", folderId);
        var uid = cmd.Parameters.Add("$uid", SqliteType.Integer);
        var value = cmd.Parameters.Add("$v", SqliteType.Integer);
        foreach (var (u, v) in values)
        {
            uid.Value = (long)u;
            value.Value = (long)v;
            cmd.ExecuteNonQuery();
        }
        tx.Commit();
    }

    /// <summary>
    /// Ricalcola le conversazioni di tutto l'account, solo se qualcosa è cambiato dall'ultima volta.
    /// Due messaggi stanno nella stessa conversazione se uno cita l'altro (In-Reply-To o References), anche
    /// attraverso messaggi che non abbiamo (citati da entrambi), o se hanno lo stesso Message-ID (copie
    /// in cartelle diverse). Niente legame per oggetto (scelta 3.6-2a). thread_id = id più piccolo del gruppo.
    /// </summary>
    /// <returns>Messaggi la cui conversazione è cambiata (0 anche se non c'era niente da fare).</returns>
    public int RecomputeThreadsIfDirty()
    {
        lock (_threadsLock)
        {
            if (Interlocked.Exchange(ref _threadsDirty, 0) == 0)
                return 0;
            try
            {
                return RecomputeThreads();
            }
            catch
            {
                MarkThreadsDirty(); // si riprova alla prossima richiesta
                throw;
            }
        }
    }

    private int RecomputeThreads()
    {
        using var db = Open();
        using var tx = db.BeginTransaction(); // IMMEDIATE: nessuna scrittura in mezzo tra lettura e aggiornamento
        var rows = new List<(long Id, string Key, string? InReplyTo, string? Refs, long? Thread)>();
        using (var select = db.CreateCommand())
        {
            select.CommandText = "SELECT id, message_id, in_reply_to, refs, thread_id FROM messages";
            using var r = select.ExecuteReader();
            while (r.Read())
            {
                var id = r.GetInt64(0);
                var messageId = ConversationIds.Normalize(Text(r, 1));
                // Senza Message-ID il messaggio è un nodo a sé (chiave che nessun riferimento può avere).
                rows.Add((id, messageId ?? "\0" + id, Text(r, 2), Text(r, 3), r.IsDBNull(4) ? null : r.GetInt64(4)));
            }
        }

        var groups = new UnionFind();
        foreach (var row in rows)
        {
            groups.Add(row.Key);
            if (ConversationIds.Normalize(row.InReplyTo) is { } parent)
                groups.Union(row.Key, parent);
            foreach (var reference in ConversationIds.Split(row.Refs))
                groups.Union(row.Key, reference);
        }

        var first = new Dictionary<string, long>(StringComparer.Ordinal);
        foreach (var row in rows)
        {
            var root = groups.Find(row.Key);
            if (!first.TryGetValue(root, out var min) || row.Id < min)
                first[root] = row.Id;
        }

        using var update = db.CreateCommand();
        update.CommandText = "UPDATE messages SET thread_id = $t WHERE id = $id";
        var idParam = update.Parameters.Add("$id", SqliteType.Integer);
        var threadParam = update.Parameters.Add("$t", SqliteType.Integer);
        var changed = 0;
        foreach (var row in rows)
        {
            var thread = first[groups.Find(row.Key)];
            if (row.Thread == thread)
                continue;
            idParam.Value = row.Id;
            threadParam.Value = thread;
            update.ExecuteNonQuery();
            changed++;
        }
        tx.Commit();
        return changed;
    }

    /// <summary>Insiemi disgiunti sulle stringhe (Message-ID), con compressione dei percorsi.</summary>
    private sealed class UnionFind
    {
        private readonly Dictionary<string, string> _parent = new(StringComparer.Ordinal);

        public void Add(string key) => _parent.TryAdd(key, key);

        public string Find(string key)
        {
            Add(key);
            var root = key;
            while (_parent[root] != root)
                root = _parent[root];
            while (_parent[key] != root)
                (key, _parent[key]) = (_parent[key], root);
            return root;
        }

        public void Union(string a, string b)
        {
            var ra = Find(a);
            var rb = Find(b);
            if (ra != rb)
                _parent[ra] = rb;
        }
    }

    /// <summary>
    /// Una pagina di conversazioni della cartella, dalla più recente (arrivo dell'ultima mail della
    /// conversazione in questa cartella). Ogni conversazione ha le sue mail dalla più recente: quelle della
    /// cartella e, scelta 3.6-1a, quelle delle altre cartelle dell'account, tranne Posta eliminata e
    /// Indesiderata (che, aperte, mostrano solo le proprie). Total = conversazioni della cartella.
    /// </summary>
    /// <param name="unreadOnly">Solo le conversazioni con almeno una mail da leggere in questa cartella.</param>
    public (int Total, IReadOnlyList<(long Thread, IReadOnlyList<(string Folder, HeaderRecord Header)> Messages)> Items)
        GetConversations(CachedFolder folder, int offset, int limit, bool unreadOnly = false, bool oldestFirst = false)
    {
        RecomputeThreadsIfDirty();
        var direction = oldestFirst ? "ASC" : "DESC";
        var having = unreadOnly ? " HAVING sum((flags & 1) = 0) > 0" : "";
        var conversations = $"SELECT thread_id AS t, max(coalesce(arrived, 0)) AS last, max(uid) AS u FROM messages WHERE folder_id = $f GROUP BY thread_id{having}";

        using var db = Open();
        int total;
        using (var count = db.CreateCommand())
        {
            count.CommandText = $"SELECT count(*) FROM ({conversations})";
            count.Parameters.AddWithValue("$f", folder.Id);
            total = Convert.ToInt32(count.ExecuteScalar(), CultureInfo.InvariantCulture);
        }

        var threads = new List<long>();
        using (var page = db.CreateCommand())
        {
            page.CommandText = $"{conversations} ORDER BY last {direction}, u {direction} LIMIT $limit OFFSET $offset";
            page.Parameters.AddWithValue("$f", folder.Id);
            page.Parameters.AddWithValue("$limit", limit);
            page.Parameters.AddWithValue("$offset", offset);
            using var r = page.ExecuteReader();
            while (r.Read())
                threads.Add(r.GetInt64(0));
        }
        if (threads.Count == 0)
            return (total, []);

        var members = threads.ToDictionary(t => t, _ => new List<(string, HeaderRecord)>());
        using (var cmd = db.CreateCommand())
        {
            var names = threads.Select((_, i) => "$t" + i).ToList();
            var others = folder.Role is "trash" or "junk"
                ? "m.folder_id = $f"
                : "(m.folder_id = $f OR coalesce(f.role, '') NOT IN ('trash', 'junk'))";
            cmd.CommandText = $"""
                SELECT m.thread_id, f.full_name, {HeaderColumns("m.")}
                FROM messages m JOIN folders f ON f.id = m.folder_id
                WHERE m.thread_id IN ({string.Join(", ", names)}) AND {others}
                ORDER BY coalesce(m.arrived, 0) DESC, m.uid DESC
                """;
            cmd.Parameters.AddWithValue("$f", folder.Id);
            for (var i = 0; i < threads.Count; i++)
                cmd.Parameters.AddWithValue(names[i], threads[i]);
            using var r = cmd.ExecuteReader();
            while (r.Read())
                members[r.GetInt64(0)].Add((r.GetString(1), ReadHeader(r, 2)));
        }
        return (total, threads.Select(t => (t, (IReadOnlyList<(string, HeaderRecord)>)members[t])).ToList());
    }

    /// <summary>
    /// Ignora e Pulisci conversazione: tutte le mail delle conversazioni a cui appartengono le mail indicate della
    /// cartella (tutte quelle della cartella se <paramref name="uids"/> è null), in qualunque cartella dell'account,
    /// con i dati che servono a riconoscerle (Message-ID, risposte, riferimenti). Dalla più vecchia.
    /// </summary>
    public IReadOnlyList<ThreadMember> GetThreadMembers(long folderId, IReadOnlyCollection<uint>? uids)
    {
        RecomputeThreadsIfDirty();
        using var db = Open();
        using var cmd = db.CreateCommand();
        var selected = "SELECT thread_id FROM messages WHERE folder_id = $f";
        if (uids is not null)
        {
            if (uids.Count == 0)
                return [];
            var names = uids.Select((_, i) => "$u" + i).ToList();
            selected += $" AND uid IN ({string.Join(", ", names)})";
            var i = 0;
            foreach (var uid in uids)
                cmd.Parameters.AddWithValue(names[i++], (long)uid);
        }
        cmd.CommandText = $"""
            SELECT m.thread_id, f.full_name, f.role, m.uid, m.flags, m.message_id, m.in_reply_to, m.refs, coalesce(m.arrived, 0)
            FROM messages m JOIN folders f ON f.id = m.folder_id
            WHERE m.thread_id IN ({selected})
            ORDER BY coalesce(m.arrived, 0), m.uid
            """;
        cmd.Parameters.AddWithValue("$f", folderId);
        var result = new List<ThreadMember>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result.Add(new ThreadMember(r.GetInt64(0), r.GetString(1), Text(r, 2), (uint)r.GetInt64(3), (MailFlags)r.GetInt64(4),
                ConversationIds.Normalize(Text(r, 5)), ConversationIds.Normalize(Text(r, 6)), ConversationIds.Split(Text(r, 7)).ToList(),
                r.GetInt64(8)));
        return result;
    }

    // ---------------------------------------------------------------------------------------------
    // Ricerca (indice FTS5 messages_fts, rowid = messages.id)
    // ---------------------------------------------------------------------------------------------

    /// <summary>
    /// Messaggi che soddisfano <paramref name="query"/>, in tutta la casella o solo nella cartella
    /// <paramref name="folder"/>, dal più recente (data di arrivo).
    /// </summary>
    public (int Total, IReadOnlyList<SearchRow> Items) Search(MailSearchQuery query, string? folder, int offset, int limit)
    {
        if (query.IsEmpty)
            return (0, []);

        var where = new List<string>();
        if (query.Match is not null)
            where.Add("messages_fts MATCH $match");
        if (folder is not null)
            where.Add("f.full_name = $folder");
        if (query.HasAttachments is { } has)
            where.Add(has ? "m.has_attachments = 1" : "m.has_attachments = 0");
        var from = query.Match is null
            ? "messages m JOIN folders f ON f.id = m.folder_id"
            : "messages_fts JOIN messages m ON m.id = messages_fts.rowid JOIN folders f ON f.id = m.folder_id";
        var filter = " WHERE " + string.Join(" AND ", where);

        using var db = Open();
        void Bind(SqliteCommand c)
        {
            if (query.Match is not null)
                c.Parameters.AddWithValue("$match", query.Match);
            if (folder is not null)
                c.Parameters.AddWithValue("$folder", folder);
        }

        int total;
        using (var count = db.CreateCommand())
        {
            count.CommandText = "SELECT count(*) FROM " + from + filter;
            Bind(count);
            total = Convert.ToInt32(count.ExecuteScalar(), CultureInfo.InvariantCulture);
        }

        using var cmd = db.CreateCommand();
        // snippet(..., -1, ...): l'estratto dalla colonna in cui la corrispondenza è migliore.
        var snippet = query.Match is null ? "NULL" : "snippet(messages_fts, -1, char(2), char(3), '…', 12)";
        cmd.CommandText = $"""
            SELECT f.full_name, m.uid, m.flags, m.subject, m.from_name, m.from_address, m.date, m.indexed, {snippet}
            FROM {from}{filter}
            ORDER BY m.arrived DESC, m.uid DESC LIMIT $limit OFFSET $offset
            """;
        Bind(cmd);
        cmd.Parameters.AddWithValue("$limit", limit);
        cmd.Parameters.AddWithValue("$offset", offset);
        var items = new List<SearchRow>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
        {
            items.Add(new SearchRow(r.GetString(0), (uint)r.GetInt64(1), (MailFlags)r.GetInt64(2), Text(r, 3), Text(r, 4),
                Text(r, 5), ParseDate(Text(r, 6)), r.GetInt64(7) == 2, Text(r, 8)));
        }
        return (total, items);
    }

    /// <summary>
    /// Righe dei messaggi indicati di una cartella il cui corpo NON è nell'indice locale (la ricerca
    /// locale li ha visti solo dalle intestazioni): sono quelli che la ricerca sul server può aggiungere.
    /// </summary>
    public IReadOnlyList<(SearchRow Row, long Arrived)> GetRowsWithoutIndexedBody(long folderId, IReadOnlyCollection<uint> uids)
    {
        if (uids.Count == 0)
            return [];
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            SELECT f.full_name, m.uid, m.flags, m.subject, m.from_name, m.from_address, m.date, coalesce(m.arrived, 0)
            FROM messages m JOIN folders f ON f.id = m.folder_id
            WHERE m.folder_id = $f AND m.indexed < 2 AND m.uid IN (SELECT value FROM json_each($uids))
            """;
        cmd.Parameters.AddWithValue("$f", folderId);
        cmd.Parameters.AddWithValue("$uids", "[" + string.Join(",", uids) + "]");
        var result = new List<(SearchRow, long)>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
        {
            result.Add((new SearchRow(r.GetString(0), (uint)r.GetInt64(1), (MailFlags)r.GetInt64(2), Text(r, 3), Text(r, 4),
                Text(r, 5), ParseDate(Text(r, 6)), false, null), r.GetInt64(7)));
        }
        return result;
    }

    /// <summary>Presenza di allegati già nota (dal corpo o dalla struttura) per i messaggi indicati.</summary>
    public Dictionary<uint, bool> GetHasAttachments(long folderId, IReadOnlyCollection<uint> uids)
    {
        var result = new Dictionary<uint, bool>();
        if (uids.Count == 0)
            return result;
        using var db = Open();
        using var cmd = db.CreateCommand();
        cmd.CommandText = """
            SELECT uid, has_attachments FROM messages
            WHERE folder_id = $f AND has_attachments IS NOT NULL AND uid IN (SELECT value FROM json_each($uids))
            """;
        cmd.Parameters.AddWithValue("$f", folderId);
        cmd.Parameters.AddWithValue("$uids", "[" + string.Join(",", uids) + "]");
        using var r = cmd.ExecuteReader();
        while (r.Read())
            result[(uint)r.GetInt64(0)] = r.GetInt64(1) == 1;
        return result;
    }

    /// <summary>Salva la presenza di allegati letta dalla struttura (BODYSTRUCTURE) sul server.</summary>
    public void SetHasAttachments(long folderId, IReadOnlyDictionary<uint, bool> values)
    {
        using var db = Open();
        using var tx = db.BeginTransaction();
        using var cmd = db.CreateCommand();
        cmd.CommandText = "UPDATE messages SET has_attachments = $has WHERE folder_id = $f AND uid = $uid";
        cmd.Parameters.AddWithValue("$f", folderId);
        var uid = cmd.Parameters.Add("$uid", SqliteType.Integer);
        var has = cmd.Parameters.Add("$has", SqliteType.Integer);
        foreach (var (u, h) in values)
        {
            uid.Value = (long)u;
            has.Value = h ? 1L : 0L;
            cmd.ExecuteNonQuery();
        }
        tx.Commit();
    }

    // ---------------------------------------------------------------------------------------------
    // Apertura, schema e migrazioni
    // ---------------------------------------------------------------------------------------------

    /// <summary>
    /// Schema per versione (PRAGMA user_version): la migrazione i porta il database dalla versione i
    /// alla i+1. Non modificare quelle già rilasciate: aggiungerne di nuove in coda.
    /// </summary>
    private static readonly string[] Migrations =
    [
        """
        CREATE TABLE folders (
            id           INTEGER PRIMARY KEY,
            full_name    TEXT NOT NULL UNIQUE,
            uid_validity INTEGER,          -- NULL: mai sincronizzata
            synced_at    TEXT              -- ultima sincronizzazione completa (ISO 8601 UTC)
        );
        CREATE TABLE messages (
            id            INTEGER PRIMARY KEY,  -- rowid: servirà all'indice di ricerca FTS5
            folder_id     INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
            uid           INTEGER NOT NULL,
            flags         INTEGER NOT NULL,     -- MailFlags: 1 Seen, 2 Answered, 4 Flagged, 8 Deleted, 16 Draft (dal 6: anche parole chiave)
            subject       TEXT,
            from_name     TEXT,
            from_address  TEXT,
            to_list       TEXT,
            cc_list       TEXT,
            date          TEXT,                 -- intestazione Date, ISO 8601 con fuso orario
            internal_date TEXT,                 -- arrivo sul server
            size          INTEGER,              -- RFC822.SIZE in byte
            message_id    TEXT,
            in_reply_to   TEXT,
            UNIQUE (folder_id, uid)
        );
        """,
        // 2: corpi come file .eml (8b).
        """
        ALTER TABLE folders ADD COLUMN role TEXT;          -- SPECIAL-USE ("inbox", "trash"...), NULL se nessuno
        ALTER TABLE messages ADD COLUMN body_sha256 TEXT;  -- impronta del file in bodies/, NULL: corpo non in cache
        CREATE INDEX messages_body ON messages(body_sha256) WHERE body_sha256 IS NOT NULL;
        """,
        // 3: ricerca (8c).
        """
        ALTER TABLE messages ADD COLUMN arrived INTEGER;                   -- arrivo in secondi Unix (INTERNALDATE, altrimenti Date)
        ALTER TABLE messages ADD COLUMN indexed INTEGER NOT NULL DEFAULT 0; -- ricerca: 0 niente, 1 intestazioni, 2 anche corpo
        ALTER TABLE messages ADD COLUMN has_attachments INTEGER;           -- NULL: sconosciuto (corpo mai letto)
        UPDATE messages SET arrived = unixepoch(coalesce(internal_date, date));
        CREATE INDEX messages_arrived ON messages(arrived);
        -- Testo salvato nell'indice (non "external content"): servono estratti ed evidenziazione.
        CREATE VIRTUAL TABLE messages_fts USING fts5(subject, sender, recipients, body, attachments,
            tokenize = 'unicode61 remove_diacritics 2', prefix = '2 3');
        INSERT INTO messages_fts(rowid, subject, sender, recipients, body, attachments)
            SELECT id, coalesce(subject, ''), trim(coalesce(from_name, '') || ' ' || coalesce(from_address, '')),
                   trim(coalesce(to_list, '') || ' ' || coalesce(cc_list, '')), '', ''
            FROM messages;
        UPDATE messages SET indexed = 1;
        -- Anche le eliminazioni a cascata (cartella tolta) passano da qui.
        CREATE TRIGGER messages_fts_delete AFTER DELETE ON messages BEGIN
            DELETE FROM messages_fts WHERE rowid = old.id;
        END;
        """,
        // 4: elenco delle cartelle senza connessione (8d).
        """
        ALTER TABLE folders ADD COLUMN name TEXT; -- nome mostrato (ultimo pezzo del percorso), NULL = mai elencata
        """,
        // 5: anteprima del testo nella lista (3.2).
        """
        ALTER TABLE messages ADD COLUMN preview TEXT; -- inizio del testo su una riga; NULL = non ancora noto, '' = senza testo
        """,
        // 6: contrassegni e categorie (3.3). Le categorie e "completato" stanno nei bit di flags (parole
        // chiave IMAP, rilette alla prossima sincronizzazione); la scadenza esiste solo qui.
        """
        ALTER TABLE messages ADD COLUMN flag_due TEXT; -- scadenza del contrassegno (aaaa-mm-gg), NULL = nessuna
        """,
        // 7: conversazioni (3.6). refs = intestazione References (Message-ID separati da spazi; NULL = non
        // ancora chiesta, '' = assente); thread_id = id del primo messaggio della conversazione, ricalcolato
        // da RecomputeThreads su tutto l'account (anche tra cartelle diverse).
        """
        ALTER TABLE messages ADD COLUMN refs TEXT;
        ALTER TABLE messages ADD COLUMN thread_id INTEGER;
        UPDATE messages SET thread_id = id;
        CREATE INDEX messages_thread ON messages(thread_id);
        """,
        // 8: importanza (P1): 0 normale, 1 alta, 2 bassa (MailImportance); NULL = non ancora letta, chiesta al server
        // in background (FillImportanceAsync).
        """
        ALTER TABLE messages ADD COLUMN importance INTEGER;
        """,
    ];

    public static int SchemaVersion => Migrations.Length;

    private SqliteConnection Open()
    {
        _ = _ready.Value;
        return OpenRaw();
    }

    private Lazy<bool> NewReady() =>
        new(() => { Initialize(); return true; }, LazyThreadSafetyMode.PublicationOnly);

    private SqliteConnection OpenRaw()
    {
        var db = new SqliteConnection(_connectionString);
        try
        {
            db.Open();
            // Per connessione: vincoli tra tabelle attivi; NORMAL con WAL non rischia la corruzione
            // (al massimo perde le ultime transazioni dopo un blackout: la cache si riallinea dal server).
            Execute(db, "PRAGMA foreign_keys = ON; PRAGMA synchronous = NORMAL;");
            return db;
        }
        catch
        {
            // Su un file che non è un database l'errore arriva già qui: senza Dispose la connessione resta
            // aperta, fuori dal pool (ClearPool non la chiude) e su Windows il file non si può rinominare.
            db.Dispose();
            throw;
        }
    }

    /// <summary>
    /// Creazione, controllo d'integrità (quick_check), migrazioni e recupero incrementale dello spazio.
    /// Database rovinato o illeggibile: messo da parte (<see cref="Quarantine"/>) e ricreato vuoto; la
    /// cache si riempie di nuovo dal server.
    /// </summary>
    private void Initialize()
    {
        CachePermissions.CreatePrivateDirectory(Directory);
        if (!File.Exists(Path))
            CachePermissions.CreatePrivateFile(Path);

        try
        {
            InitializeDatabase();
        }
        catch (SqliteException ex) when (IsCorruption(ex))
        {
            // Il file non è nemmeno un database leggibile (es. sovrascritto).
            Quarantine($"errore SQLite {ex.SqliteErrorCode}: {ex.Message}");
            InitializeDatabase();
        }
    }

    private void InitializeDatabase()
    {
        using var db = OpenRaw();
        var version = Convert.ToInt32(Scalar(db, "PRAGMA user_version"), CultureInfo.InvariantCulture);
        if (version > Migrations.Length)
        {
            // Creato da una versione più recente di PostinoVip: il formato è sconosciuto.
            // È solo una cache: la si ricrea vuota invece di rischiare letture sbagliate.
            db.Close();
            SqliteConnection.ClearPool(db);
            DeleteDatabaseFiles();
            CachePermissions.CreatePrivateFile(Path);
            _initializeNote = $"cache creata da una versione più recente (schema {version}, questa usa {Migrations.Length}): ricreata vuota";
            InitializeDatabase();
            return;
        }

        if (QuickCheck(db) is { } problem)
        {
            db.Close();
            Quarantine(problem);
            InitializeDatabase();
            return;
        }

        // WAL: le letture non bloccano le scritture; impostazione salvata nel file.
        Execute(db, "PRAGMA journal_mode = WAL;");
        for (var v = version; v < Migrations.Length; v++)
        {
            using var tx = db.BeginTransaction();
            Execute(db, Migrations[v]);
            Execute(db, $"PRAGMA user_version = {v + 1}");
            tx.Commit();
        }

        // Recupero incrementale dello spazio (le pagine liberate dalle mail cancellate tornano al
        // sistema con incremental_vacuum). Su un database esistente si attiva solo riscrivendolo
        // (VACUUM, fuori da transazioni): una volta, qui, prima che altri lo usino.
        if (Convert.ToInt32(Scalar(db, "PRAGMA auto_vacuum"), CultureInfo.InvariantCulture) != 2)
        {
            Execute(db, "PRAGMA auto_vacuum = INCREMENTAL;");
            Execute(db, "VACUUM;");
        }
    }

    /// <summary>Esito di PRAGMA quick_check: null se il database è integro, altrimenti i primi problemi trovati.</summary>
    private static string? QuickCheck(SqliteConnection db)
    {
        using var cmd = db.CreateCommand();
        cmd.CommandText = "PRAGMA quick_check(5)";
        var problems = new List<string>();
        using var r = cmd.ExecuteReader();
        while (r.Read())
            problems.Add(r.GetString(0));
        // Una riga sola (finisce nel log): quick_check va a capo dentro i messaggi.
        return problems is ["ok"] ? null : string.Join("; ", problems).ReplaceLineEndings(" ");
    }

    /// <summary>SQLITE_CORRUPT (11) o SQLITE_NOTADB (26): il file non è un database integro.</summary>
    private static bool IsCorruption(SqliteException ex) => ex.SqliteErrorCode is 11 or 26;

    /// <summary>Prefisso dei file messi da parte: <c>index.db.rovinato-AAAAMMGG-HHMMSS</c> (più -wal, -shm).</summary>
    public const string QuarantineInfix = ".rovinato-";

    /// <summary>
    /// Mette da parte il database rovinato (rinominato, per eventuali analisi; si tiene solo l'ultimo)
    /// e crea al suo posto un file vuoto. Le connessioni nel pool vengono chiuse.
    /// </summary>
    private void Quarantine(string problem)
    {
        SqliteConnection.ClearPool(new SqliteConnection(_connectionString));
        foreach (var old in System.IO.Directory.EnumerateFiles(Directory, FileName + QuarantineInfix + "*"))
            File.Delete(old);

        var name = FileName + QuarantineInfix + DateTime.Now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
        foreach (var suffix in new[] { "", "-wal", "-shm" })
        {
            // Stessi suffissi: la copia messa da parte resta apribile con il suo -wal.
            if (File.Exists(Path + suffix))
                File.Move(Path + suffix, System.IO.Path.Combine(Directory, name + suffix));
        }
        CachePermissions.CreatePrivateFile(Path);
        _initializeNote = $"database rovinato ({problem}): messo da parte come {name}, la cache viene ricostruita dal server";
    }

    /// <summary>
    /// Controllo d'integrità periodico (quick_check). Se il database è rovinato lo mette da parte e
    /// la prossima apertura ne crea uno nuovo.
    /// </summary>
    /// <returns>null se è integro, altrimenti la descrizione di cosa è stato fatto.</returns>
    public string? CheckIntegrity()
    {
        string? problem;
        try
        {
            using var db = Open();
            problem = QuickCheck(db);
        }
        catch (SqliteException ex) when (IsCorruption(ex))
        {
            problem = $"errore SQLite {ex.SqliteErrorCode}: {ex.Message}";
        }
        if (problem is null)
            return null;

        Quarantine(problem);
        _ready = NewReady();
        return TakeInitializeNote();
    }

    /// <summary>
    /// Restituisce al sistema le pagine libere del database (incremental_vacuum) e svuota il file WAL
    /// (checkpoint). Non blocca le letture.
    /// </summary>
    /// <returns>Byte liberati nel file del database.</returns>
    public long ReclaimSpace()
    {
        using var db = Open();
        var pageSize = Convert.ToInt64(Scalar(db, "PRAGMA page_size"), CultureInfo.InvariantCulture);
        var free = Convert.ToInt64(Scalar(db, "PRAGMA freelist_count"), CultureInfo.InvariantCulture);
        if (free > 0)
            Execute(db, "PRAGMA incremental_vacuum;");
        Execute(db, "PRAGMA wal_checkpoint(TRUNCATE);");
        return (free - Convert.ToInt64(Scalar(db, "PRAGMA freelist_count"), CultureInfo.InvariantCulture)) * pageSize;
    }

    /// <summary>
    /// "Ricostruisci cache" (richiesta dell'utente): cancella database e corpi; la prossima apertura
    /// crea un database vuoto, che si riempie di nuovo dal server. Il server non viene toccato.
    /// Un'operazione in corso in quel momento può fallire o scrivere nei file appena cancellati: si
    /// recupera da sola alla sincronizzazione successiva.
    /// </summary>
    public void Reset()
    {
        SqliteConnection.ClearPool(new SqliteConnection(_connectionString));
        DeleteDatabaseFiles();
        // Il download in background può creare file nel frattempo (cartella "non vuota"): fino a 3 tentativi.
        var attempt = 0;
        while (System.IO.Directory.Exists(Bodies.Root))
        {
            try
            {
                System.IO.Directory.Delete(Bodies.Root, recursive: true);
            }
            catch (IOException) when (++attempt < 3)
            {
                Thread.Sleep(100);
            }
        }
        _ready = NewReady();
        MarkThreadsDirty();
        _initializeNote = "cache ricostruita su richiesta: si riempie di nuovo dal server";
    }

    private void DeleteDatabaseFiles()
    {
        foreach (var suffix in new[] { "", "-wal", "-shm" })
        {
            if (File.Exists(Path + suffix))
                File.Delete(Path + suffix);
        }
    }

    private static CachedFolder? FindFolder(SqliteConnection db, string fullName)
    {
        using var cmd = db.CreateCommand();
        cmd.CommandText = "SELECT id, full_name, uid_validity, synced_at, role FROM folders WHERE full_name = $name";
        cmd.Parameters.AddWithValue("$name", fullName);
        using var r = cmd.ExecuteReader();
        if (!r.Read())
            return null;
        return new CachedFolder(r.GetInt64(0), r.GetString(1), r.IsDBNull(2) ? null : (uint)r.GetInt64(2), ParseDate(Text(r, 3)), Text(r, 4));
    }

    private static void Execute(SqliteConnection db, string sql, params (string Name, object Value)[] args)
    {
        using var cmd = db.CreateCommand();
        cmd.CommandText = sql;
        foreach (var (name, value) in args)
            cmd.Parameters.AddWithValue(name, value);
        cmd.ExecuteNonQuery();
    }

    private static object? Scalar(SqliteConnection db, string sql)
    {
        using var cmd = db.CreateCommand();
        cmd.CommandText = sql;
        return cmd.ExecuteScalar();
    }

    private static string? Text(SqliteDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);

    private static string FormatDate(DateTimeOffset d) => d.ToString("o", CultureInfo.InvariantCulture);

    private static DateTimeOffset? ParseDate(string? s) =>
        s is null ? null : DateTimeOffset.Parse(s, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
}
