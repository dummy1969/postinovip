using PostinoVip.Core.Account;

namespace PostinoVip.Core.AutoReply;

/// <summary>Esito di un giro delle risposte automatiche (diagnostica: solo numeri).</summary>
public sealed record AutoReplyResult(int Checked, int Sent, int Skipped)
{
    public override string ToString() => $"risposte automatiche: {Checked} mail nuove, {Sent} risposte inviate, {Skipped} senza risposta";
}

/// <summary>
/// Invia le risposte automatiche (scelta 1a: dal core, con l'app aperta) alle mail nuove della Posta in arrivo,
/// come le regole: UID oltre l'ultimo esaminato; a ogni attivazione si riparte dalla mail più recente. Le mail
/// arrivate con l'app chiusa ricevono la risposta alla riapertura, se arrivate dentro l'intervallo. INVIA DAVVERO:
/// l'attivazione fatta dall'utente vale come conferma; filtri fissi in <see cref="AutoReplyPolicy"/>; niente copia
/// in Posta inviata (4a). Senza rete si ferma e riprende dalla stessa mail. Nel log solo numeri e UID.
/// </summary>
public sealed class AutoReplyRunner(MailAccount account, AutoReplyStore store, Action<string>? log = null, TimeProvider? time = null)
{
    public const string Inbox = "INBOX";

    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly TimeProvider _time = time ?? TimeProvider.System;

    public async Task<AutoReplyResult> RunNewAsync(CancellationToken ct = default)
    {
        var settings = store.Load();
        if (!settings.Enabled || account.Bodies?.Cache is not { } cache)
            return new AutoReplyResult(0, 0, 0);
        await _gate.WaitAsync(ct);
        try
        {
            await account.Reader.GetHeadersAsync(Inbox, 0, 1, ct: ct); // sincronizza la Posta in arrivo
            if (cache.FindFolder(Inbox) is not { } folder)
                return new AutoReplyResult(0, 0, 0);
            var uids = cache.GetUids(folder.Id);
            var max = uids.Count == 0 ? 0u : uids.Max();
            var state = store.LoadState();
            IEnumerable<uint> pending;
            if (state.LastUid is null || state.UidValidity != folder.UidValidity)
            {
                // Primo giro dopo l'attivazione: solo le mail arrivate da quel momento (UIDVALIDITY cambiato: nessuna).
                var since = state.LastUid is null && state.ActivatedAt is { } at ? at : _time.GetUtcNow();
                pending = cache.GetUidsArrivedSince(folder.Id, since);
                state = state with { UidValidity = folder.UidValidity, LastUid = 0 };
            }
            else
            {
                pending = uids.Where(u => u > state.LastUid);
            }

            int checkedCount = 0, sent = 0, skipped = 0;
            var replied = state.Replied.ToList();
            foreach (var uid in pending.Order())
            {
                ct.ThrowIfCancellationRequested();
                checkedCount++;
                MimeKit.MimeMessage message;
                try
                {
                    message = await account.Reader.GetMimeMessageAsync(Inbox, uid, ct);
                }
                catch (MailNotFoundException)
                {
                    state = state with { LastUid = uid };
                    store.SaveState(state);
                    continue;
                }

                // Arrivo: il primo Received (il server della casella), altrimenti la data della mail. Dopo la fine
                // dell'intervallo ricevono ancora la risposta le mail arrivate prima (app chiusa), le altre no.
                var arrived = Local.LocalFolderSource.ArrivedAt(message)
                              ?? (message.Date == DateTimeOffset.MinValue ? _time.GetUtcNow() : message.Date);
                var to = settings.Covers(arrived)
                    ? AutoReplyPolicy.Recipient(message, account.Address, replied, out _)
                    : null;
                if (to is null)
                {
                    skipped++;
                }
                else
                {
                    try
                    {
                        await account.Sender.SendMimeAsync(AutoReplyPolicy.Build(message, account.Address, to, settings), ct);
                        replied.Add(to);
                        sent++;
                    }
                    catch (Exception ex) when (ex is not (OperationCanceledException or MailOfflineException))
                    {
                        // Es. destinatario rifiutato: non si riprova, per non insistere con chi non vuole risposte.
                        skipped++;
                        log?.Invoke($"[{account.Id}] risposta automatica alla mail {uid} non inviata ({ex.GetType().Name})");
                    }
                }
                state = state with { LastUid = uid, Replied = replied };
                store.SaveState(state);
            }
            if (state.LastUid < max)
                store.SaveState(state with { LastUid = max }); // le mail più vecchie dell'attivazione non si guardano più
            var result = new AutoReplyResult(checkedCount, sent, skipped);
            if (sent > 0)
                log?.Invoke($"[{account.Id}] {result}");
            return result;
        }
        finally
        {
            _gate.Release();
        }
    }
}
