using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Junk;

/// <summary>Esito di un giro del filtro (diagnostica: solo numeri).</summary>
public sealed record JunkRunResult(int Checked, int Moved, int Failed)
{
    public override string ToString() => $"posta indesiderata: {Checked} mail nuove controllate, {Moved} spostate, {Failed} non riuscite";
}

/// <summary>Cosa aggiungere agli attendibili con «Non bloccare mai…».</summary>
[System.Text.Json.Serialization.JsonConverter(typeof(System.Text.Json.Serialization.JsonStringEnumConverter<NeverBlockKind>))]
public enum NeverBlockKind { Sender, Domain, Group }

/// <summary>Esito di un comando: voci aggiunte agli elenchi, mail spostate e cartella di destinazione.</summary>
public sealed record JunkCommandResult(IReadOnlyList<string> Entries, IReadOnlyList<uint> Moved, string? Folder);

/// <summary>
/// Posta indesiderata di un account (J1). <see cref="RunNewAsync"/>: il filtro sulle mail nuove della Posta in arrivo
/// (2a: nel core, solo con l'app aperta, prima delle risposte automatiche e delle regole), con l'avanzamento come le
/// regole: la prima volta, o se cambia UIDVALIDITY, si parte dalla mail più recente senza toccare quelle già presenti.
/// Comandi dell'utente: <see cref="BlockAsync"/>, <see cref="NeverBlockAsync"/>, <see cref="NotJunkAsync"/>.
/// Spostamenti e parole chiave MODIFICANO la casella con lo stesso IMailWriter dei comandi; le parole chiave sono un
/// di più (4a): se il server non le accetta lo spostamento si fa lo stesso. Nel log solo numeri, UID, nomi delle
/// cartelle e il motivo: mai mittenti, oggetti o testi.
/// </summary>
public sealed class JunkFilter(MailAccount account, JunkStore store, Action<string>? log = null)
{
    public const string Inbox = "INBOX";

    private readonly SemaphoreSlim _gate = new(1, 1);

    /// <summary>La cartella della posta indesiderata dell'account (<see cref="JunkFolders.Resolve"/>), null se non c'è.</summary>
    public async Task<string?> JunkFolderAsync(CancellationToken ct = default) =>
        JunkFolders.Resolve(await account.Reader.GetFoldersAsync(ct), store.Load().Folder);

    public async Task<JunkRunResult> RunNewAsync(CancellationToken ct = default)
    {
        if (account.Bodies?.Cache is not { } cache)
            return new JunkRunResult(0, 0, 0); // senza copia locale niente filtro, come le regole
        await _gate.WaitAsync(ct);
        try
        {
            await account.Reader.GetHeadersAsync(Inbox, 0, 1, ct: ct); // sincronizza la Posta in arrivo
            if (cache.FindFolder(Inbox) is not { } folder)
                return new JunkRunResult(0, 0, 0);
            var uids = cache.GetUids(folder.Id);
            var max = uids.Count == 0 ? 0 : uids.Max();
            var settings = store.Load();
            var progress = store.LoadProgress();
            var idle = settings is { Level: JunkLevel.None, BlockedSenders.Count: 0 };
            var junk = idle ? null : await JunkFolderAsync(ct);

            // Prima volta, cartella rifatta, niente da filtrare o nessuna cartella: si parte da qui.
            if (progress is null || progress.UidValidity != folder.UidValidity || idle || junk is null)
            {
                if (!idle && junk is null && progress is not null && uids.Any(u => u > progress.LastUid))
                    log?.Invoke($"[{account.Id}] posta indesiderata: nessuna cartella scelta, mail nuove non filtrate");
                if (progress is null || progress.UidValidity != folder.UidValidity || progress.LastUid != max)
                    store.SaveProgress(new JunkProgress(folder.UidValidity, max));
                return new JunkRunResult(0, 0, 0);
            }

            var contacts = ContactAddresses(settings);
            int checkedCount = 0, moved = 0, failed = 0;
            foreach (var uid in uids.Where(u => u > progress.LastUid).Order())
            {
                ct.ThrowIfCancellationRequested();
                checkedCount++;
                try
                {
                    var message = await account.Reader.GetMimeMessageAsync(Inbox, uid, ct); // BODY.PEEK: resta da leggere
                    var verdict = JunkClassifier.Classify(message, settings, account.Address, contacts.Contains);
                    if (verdict.IsJunk)
                    {
                        await MarkAsync(Inbox, [uid], MailFlags.Junk, MailFlags.NotJunk, ct);
                        await account.Writer.MoveAsync(Inbox, uid, junk, ct);
                        moved++;
                        log?.Invoke($"[{account.Id}] posta indesiderata: mail {uid} -> {junk} ({verdict.Reason})");
                    }
                }
                catch (MailNotFoundException)
                {
                    // già spostata o eliminata
                }
                catch (Exception ex) when (ex is not (OperationCanceledException or MailOfflineException))
                {
                    failed++;
                    log?.Invoke($"[{account.Id}] posta indesiderata: mail {uid} non spostata ({ex.GetType().Name}: {ex.Message})");
                }
                store.SaveProgress(new JunkProgress(folder.UidValidity, uid)); // esaminata: non si ripete
            }
            var result = new JunkRunResult(checkedCount, moved, failed);
            if (moved > 0 || failed > 0)
                log?.Invoke($"[{account.Id}] {result}");
            return result;
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>
    /// «Blocca mittente»: aggiunge i mittenti delle mail ai bloccati (togliendoli dagli attendibili) e sposta le mail
    /// nella posta indesiderata con la parola chiave $Junk; nella posta indesiderata stessa solo la parola chiave.
    /// Senza cartella della posta indesiderata InvalidOperationException (409) prima di cambiare qualunque cosa.
    /// </summary>
    public async Task<JunkCommandResult> BlockAsync(string folder, IReadOnlyCollection<uint> uids, CancellationToken ct = default)
    {
        var junk = await JunkFolderAsync(ct)
                   ?? throw new InvalidOperationException("Nessuna cartella della posta indesiderata: sceglierla in «Opzioni posta indesiderata».").WithCode("nessunaCartellaDellaPostaIndesiderata");
        var messages = await ReadAsync(folder, uids, ct);
        var senders = messages.Select(m => JunkClassifier.SenderAddress(m.Message)).OfType<string>()
            .Where(s => !string.Equals(s, account.Address, StringComparison.OrdinalIgnoreCase)).Distinct().ToList();
        if (senders.Count == 0)
            throw new InvalidOperationException("Nessun mittente da bloccare (le mail sono state inviate da questo account o non hanno mittente).").WithCode("nessunMittenteDaBloccareLe");
        var entries = senders.Select(s => store.Add(JunkList.BlockedSenders, s)).ToList();

        var found = messages.Select(m => m.Uid).ToList();
        await MarkAsync(folder, found, MailFlags.Junk, MailFlags.NotJunk, ct);
        if (folder == junk)
            return new JunkCommandResult(entries, [], junk);
        var result = await account.Writer.MoveAsync(folder, found, junk, ct);
        log?.Invoke($"[{account.Id}] posta indesiderata: blocca mittente, {result.Uids.Count} mail -> {junk}");
        return new JunkCommandResult(entries, result.Uids, junk);
    }

    /// <summary>
    /// «Non bloccare mai il mittente / il dominio del mittente / questo gruppo o mailing list»: solo gli elenchi, la
    /// casella non cambia. Gruppo = indirizzo della lista (List-Post) o, se manca, il primo destinatario in A che non
    /// è questo account; va nei destinatari attendibili.
    /// </summary>
    public async Task<JunkCommandResult> NeverBlockAsync(string folder, IReadOnlyCollection<uint> uids, NeverBlockKind kind,
        CancellationToken ct = default)
    {
        var messages = await ReadAsync(folder, uids, ct);
        var values = messages.Select(m => kind switch
        {
            NeverBlockKind.Sender => JunkClassifier.SenderAddress(m.Message),
            NeverBlockKind.Domain => JunkClassifier.SenderAddress(m.Message) is { } s ? s[s.LastIndexOf('@')..] : null,
            _ => JunkClassifier.ListAddress(m.Message) ?? m.Message.To.Mailboxes.Select(a => a.Address.ToLowerInvariant())
                .FirstOrDefault(a => !string.Equals(a, account.Address, StringComparison.OrdinalIgnoreCase)),
        }).OfType<string>().Distinct().ToList();
        if (values.Count == 0)
            throw new InvalidOperationException(kind == NeverBlockKind.Group
                ? "La mail non è stata inviata a un gruppo o a una mailing list."
                : "La mail non ha un mittente.");
        var list = kind == NeverBlockKind.Group ? JunkList.SafeRecipients : JunkList.SafeSenders;
        return new JunkCommandResult(values.Select(v => store.Add(list, v)).ToList(), [], null);
    }

    /// <summary>
    /// «Non è posta indesiderata»: solo dalla cartella della posta indesiderata (altrimenti 409). Parola chiave
    /// $NotJunk, spostamento in Posta in arrivo e, con <paramref name="trustSenders"/>, mittenti tra gli attendibili.
    /// </summary>
    public async Task<JunkCommandResult> NotJunkAsync(string folder, IReadOnlyCollection<uint> uids, bool trustSenders,
        CancellationToken ct = default)
    {
        var junk = await JunkFolderAsync(ct);
        if (folder != junk)
            throw new InvalidOperationException("«Non è posta indesiderata» vale solo per le mail della cartella della posta indesiderata.").WithCode("nonPostaIndesiderataValeSolo");
        var messages = await ReadAsync(folder, uids, ct);
        var entries = new List<string>();
        if (trustSenders)
            entries.AddRange(messages.Select(m => JunkClassifier.SenderAddress(m.Message)).OfType<string>().Distinct()
                .Where(s => !string.Equals(s, account.Address, StringComparison.OrdinalIgnoreCase))
                .Select(s => store.Add(JunkList.SafeSenders, s)));
        var found = messages.Select(m => m.Uid).ToList();
        await MarkAsync(folder, found, MailFlags.NotJunk, MailFlags.Junk, ct);
        var result = await account.Writer.MoveAsync(folder, found, Inbox, ct);
        log?.Invoke($"[{account.Id}] posta indesiderata: non è posta indesiderata, {result.Uids.Count} mail -> {Inbox}");
        return new JunkCommandResult(entries, result.Uids, Inbox);
    }

    private async Task<List<(uint Uid, MimeKit.MimeMessage Message)>> ReadAsync(string folder, IReadOnlyCollection<uint> uids,
        CancellationToken ct)
    {
        var result = new List<(uint, MimeKit.MimeMessage)>();
        foreach (var uid in uids.Distinct())
        {
            try
            {
                result.Add((uid, await account.Reader.GetMimeMessageAsync(folder, uid, ct)));
            }
            catch (MailNotFoundException)
            {
                // non c'è più: ignorata, come negli altri comandi in blocco
            }
        }
        return result.Count > 0 ? result : throw new MailNotFoundException($"Nessuna delle mail indicate è in '{folder}'.").WithCode("nessunaDelleMailIndicateIn", ("folder", folder));
    }

    /// <summary>Parole chiave $Junk / $NotJunk: un di più, se il server non le accetta si va avanti.</summary>
    private async Task MarkAsync(string folder, IReadOnlyCollection<uint> uids, MailFlags add, MailFlags remove, CancellationToken ct)
    {
        try
        {
            await account.Writer.UpdateFlagsAsync(folder, uids, add, remove, ct);
        }
        catch (NotSupportedException ex)
        {
            log?.Invoke($"[{account.Id}] posta indesiderata: parole chiave non salvate in {folder} ({ex.Message})");
        }
    }

    private HashSet<string> ContactAddresses(JunkSettings settings) =>
        settings.TrustContacts && account.Contacts is { } contacts
            ? contacts.List().SelectMany(c => c.Emails).Select(e => e.Address.ToLowerInvariant()).ToHashSet()
            : [];
}
