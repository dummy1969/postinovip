using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;

namespace PostinoVip.Core.Rules;

/// <summary>"Esegui regole ora": su quali mail della cartella (come Outlook: tutte, lette, da leggere).</summary>
[System.Text.Json.Serialization.JsonConverter(typeof(System.Text.Json.Serialization.JsonStringEnumConverter<RuleRunFilter>))]
public enum RuleRunFilter { All, Read, Unread }

/// <summary>Esito di un'esecuzione delle regole (diagnostica: solo numeri).</summary>
public sealed record RuleRunResult(int Checked, int Applied, int Failed)
{
    public override string ToString() => $"regole: {Checked} mail nuove controllate, {Applied} con azioni, {Failed} azioni non riuscite";
}

/// <summary>
/// Applica le regole di un account alle mail nuove della Posta in arrivo (1a: sul computer, come le regole
/// "solo client" di Outlook). "Nuove" = UID più alto dell'ultimo già esaminato (<see cref="RuleProgress"/>):
/// la prima volta, o se cambia UIDVALIDITY, si parte dalla mail più recente senza toccare quelle già presenti.
/// Le mail arrivate con l'app chiusa vengono esaminate alla riapertura. Le azioni MODIFICANO la casella
/// (IMAP) o la casella locale (POP3) con gli stessi IMailWriter dei comandi dell'utente; un'azione non
/// riuscita viene scritta nel log e non ripetuta. Senza rete l'esecuzione si ferma e riprende dopo.
/// Nel log solo numeri, UID e nomi delle regole: mai mittenti, oggetti o testi.
/// </summary>
public sealed class RuleRunner(MailAccount account, RuleStore store, Action<string>? log = null)
{
    public const string Inbox = "INBOX";

    private readonly SemaphoreSlim _gate = new(1, 1);

    public async Task<RuleRunResult> RunNewAsync(CancellationToken ct = default)
    {
        if (account.Bodies?.Cache is not { } cache)
            return new RuleRunResult(0, 0, 0); // senza copia locale niente regole
        await _gate.WaitAsync(ct);
        try
        {
            // Lista della Posta in arrivo: sincronizza l'indice con il server (o con i file, per il POP3).
            await account.Reader.GetHeadersAsync(Inbox, 0, 1, ct: ct);
            var folder = cache.FindFolder(Inbox);
            if (folder is null)
                return new RuleRunResult(0, 0, 0);
            var uids = cache.GetUids(folder.Id);
            var max = uids.Count == 0 ? 0 : uids.Max();
            var rules = store.Load().Where(r => r.Enabled).ToList();
            var progress = store.LoadProgress();

            // Prima volta, cartella rifatta, o nessuna regola attiva: si parte da qui, senza toccare il passato.
            if (progress is null || progress.UidValidity != folder.UidValidity || rules.Count == 0)
            {
                if (progress is null || progress.UidValidity != folder.UidValidity || progress.LastUid != max)
                    store.SaveProgress(new RuleProgress(folder.UidValidity, max));
                return new RuleRunResult(0, 0, 0);
            }

            int checkedCount = 0, applied = 0, failed = 0;
            foreach (var uid in uids.Where(u => u > progress.LastUid).Order())
            {
                ct.ThrowIfCancellationRequested();
                var outcome = await ApplyAsync(rules, cache, Inbox, folder.Id, uid, ct);
                checkedCount++;
                if (outcome.Applied)
                    applied++;
                failed += outcome.Failed;
                store.SaveProgress(new RuleProgress(folder.UidValidity, uid)); // esaminata: non si ripete
            }
            var result = new RuleRunResult(checkedCount, applied, failed);
            if (applied > 0 || failed > 0)
                log?.Invoke($"[{account.Id}] {result}");
            return result;
        }
        finally
        {
            _gate.Release();
        }
    }

    /// <summary>
    /// "Esegui regole ora" (R3): le regole indicate (anche se disattivate, come in Outlook) sulle mail già presenti
    /// nelle cartelle, scelte secondo <paramref name="filter"/>. Gli elenchi delle mail si leggono tutti prima di
    /// cominciare: una mail spostata in una cartella che verrà esaminata dopo non viene valutata due volte.
    /// <paramref name="progress"/> riceve (esaminate, totale) dopo ogni mail. Stesse azioni e stesse cautele
    /// delle mail nuove; un'interruzione (<paramref name="ct"/>) lascia fatto ciò che è già stato fatto.
    /// </summary>
    public async Task<RuleRunResult> RunOnFoldersAsync(IReadOnlyList<MailRule> rules, IReadOnlyList<string> folders, RuleRunFilter filter,
        Action<int, int>? progress = null, CancellationToken ct = default)
    {
        if (account.Bodies?.Cache is not { } cache)
            throw new NotSupportedException("Le regole richiedono la copia locale.").WithCode("leRegoleRichiedonoLaCopia");
        var active = rules.Select(r => r with { Enabled = true }).ToList();
        await _gate.WaitAsync(ct);
        try
        {
            var work = new List<(string Folder, long FolderId, uint Uid)>();
            foreach (var name in folders)
            {
                await account.Reader.GetHeadersAsync(name, 0, 1, ct: ct); // sincronizza l'indice della cartella
                if (cache.FindFolder(name) is not { } folder)
                    continue;
                foreach (var uid in cache.GetUids(folder.Id).Order())
                {
                    if (filter != RuleRunFilter.All && cache.GetFlags(folder.Id, uid) is var (flags, _)
                        && flags.HasFlag(MailFlags.Seen) != (filter == RuleRunFilter.Read))
                        continue;
                    work.Add((name, folder.Id, uid));
                }
            }

            int checkedCount = 0, applied = 0, failed = 0;
            progress?.Invoke(0, work.Count);
            foreach (var (name, folderId, uid) in work)
            {
                ct.ThrowIfCancellationRequested();
                var outcome = await ApplyAsync(active, cache, name, folderId, uid, ct);
                checkedCount++;
                if (outcome.Applied)
                    applied++;
                failed += outcome.Failed;
                progress?.Invoke(checkedCount, work.Count);
            }
            var result = new RuleRunResult(checkedCount, applied, failed);
            log?.Invoke($"[{account.Id}] esegui regole ora: {result}");
            return result;
        }
        finally
        {
            _gate.Release();
        }
    }

    private string? TrashName() =>
        account.Bodies?.Cache.GetFolderList().FirstOrDefault(f => f.SpecialUse == "trash")?.FullName;

    private async Task<(bool Applied, int Failed)> ApplyAsync(IReadOnlyList<MailRule> rules, AccountCache cache, string folderName,
        long folderId, uint uid, CancellationToken ct)
    {
        MimeKit.MimeMessage message;
        try
        {
            message = await account.Reader.GetMimeMessageAsync(folderName, uid, ct); // BODY.PEEK: non diventa letta
        }
        catch (MailNotFoundException)
        {
            return (false, 0); // già spostata o eliminata
        }

        var plan = RuleMatcher.Plan(rules, RuleMessage.FromMime(message, cache.GetSize(folderId, uid)), account.Address);
        if (plan.IsEmpty)
            return (false, 0);

        var failed = 0;
        var writer = account.Writer;
        async Task Try(string what, Func<Task> action)
        {
            try
            {
                await action();
            }
            catch (Exception ex) when (ex is not (OperationCanceledException or MailOfflineException))
            {
                failed++;
                log?.Invoke($"[{account.Id}] regole: {what} della mail {uid} non riuscito ({ex.GetType().Name}: {ex.Message})");
            }
        }

        var add = (plan.Flag ? MailFlags.Flagged : MailFlags.None)
                  | plan.Categories.Aggregate(MailFlags.None, (f, c) => f | MailKeywords.Category(c));
        if (plan.MarkRead)
            await Try("segna come letta", () => writer.SetSeenAsync(folderName, uid, true, ct));
        if (add != MailFlags.None)
            await Try("contrassegno o categoria", () => writer.UpdateFlagsAsync(folderName, uid, add, MailFlags.None, ct));
        foreach (var copy in plan.CopyTo.Where(c => !string.Equals(c, folderName, StringComparison.OrdinalIgnoreCase)))
            await Try($"copia in {copy}", () => writer.CopyAsync(folderName, [uid], copy, ct));
        // Già nella cartella di destinazione (o in Posta eliminata): niente da spostare.
        if (plan.Delete && !string.Equals(folderName, TrashName(), StringComparison.OrdinalIgnoreCase))
            await Try("elimina", () => writer.MoveToTrashAsync(folderName, uid, ct));
        else if (!plan.Delete && plan.MoveTo is { } move && !string.Equals(move, folderName, StringComparison.OrdinalIgnoreCase))
            await Try($"sposta in {move}", () => writer.MoveAsync(folderName, uid, move, ct));

        log?.Invoke($"[{account.Id}] regole: mail {uid} -> {string.Join(", ", plan.Rules.Select(r => $"«{r}»"))}");
        return (true, failed);
    }
}
