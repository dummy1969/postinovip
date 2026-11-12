using MimeKit;

namespace PostinoVip.Core.Cache;

/// <summary>
/// Scarica dal server il messaggio grezzo e lo passa a <paramref name="consume"/>. Se la connessione
/// cade e la lettura viene ripetuta, <paramref name="consume"/> può essere chiamato più volte.
/// </summary>
public delegate Task RawMessageDownload(Func<Stream, CancellationToken, Task> consume, CancellationToken ct);

/// <summary>Esito di una pulizia (diagnostica: solo numeri).</summary>
public sealed record SweepResult(int BodiesDropped, int FilesDeleted, long BytesDeleted)
{
    public bool Changed => BodiesDropped > 0 || FilesDeleted > 0;

    public override string ToString() =>
        $"pulizia: {BodiesDropped} corpi fuori dal limite, {FilesDeleted} file eliminati ({BytesDeleted / 1024.0 / 1024.0:0.0} MB)";
}

/// <summary>
/// Corpi dei messaggi nella cache: apertura, bozze e allegati leggono il file .eml se c'è,
/// altrimenti lo scaricano e, se la regola (<see cref="BodyPolicy"/>) lo consente, lo salvano.
/// File mancante o danneggiato = non in cache: viene riscaricato senza errori.
/// Ordine delle operazioni: prima il file, poi la riga; la pulizia toglie prima la riga, poi il file.
/// </summary>
public sealed class BodyCache(string account, AccountCache cache, BodyPolicy policy, Action<string>? log = null)
{
    public BodyPolicy Policy => policy;
    public AccountCache Cache => cache;

    public async Task<MimeMessage> LoadAsync(string folderName, uint uid, RawMessageDownload download, CancellationToken ct = default)
    {
        var folder = cache.FindFolder(folderName);
        var row = folder is null ? null : cache.GetBodyRow(folder.Id, uid);
        if (row?.Sha256 is { } stored)
        {
            if (cache.Bodies.TryRead(stored) is { } cached)
                return await MimeMessage.LoadAsync(new MemoryStream(cached, writable: false), ct);
            log?.Invoke($"[{account}] cache: corpo {folderName}/{uid} mancante o danneggiato, lo riscarico");
        }

        // Senza riga (messaggio non ancora sincronizzato) il file non avrebbe a cosa essere collegato.
        var keep = folder is not null && row is not null && policy.Keeps(folder.Role, row.Arrived, DateTimeOffset.UtcNow);
        string? saved = null;
        MimeMessage? parsed = null;
        await download(async (stream, c) =>
        {
            if (keep)
                saved = await cache.Bodies.SaveAsync(stream, c);
            else
                parsed = await MimeMessage.LoadAsync(stream, c);
        }, ct);

        if (saved is null)
        {
            // Toglie un collegamento rimasto (messaggio uscito dalla regola).
            if (folder is not null && row?.Sha256 is not null)
                cache.SetBody(folder.Id, uid, null);
            log?.Invoke($"[{account}] cache: corpo {folderName}/{uid} scaricato, non salvato " +
                        (row is null ? "(intestazione non ancora in cache)" : "(fuori dal limite o cartella solo intestazioni)"));
            return parsed!;
        }

        var bytes = cache.Bodies.TryRead(saved)
            ?? throw new IOException($"Corpo {folderName}/{uid} appena salvato e non rileggibile.");
        var message = await MimeMessage.LoadAsync(new MemoryStream(bytes, writable: false), ct);
        // Prima il file, poi la riga: collegato e già cercabile.
        cache.SetBody(folder!.Id, uid, saved, SearchText.From(message));
        log?.Invoke($"[{account}] cache: corpo {folderName}/{uid} scaricato e salvato ({bytes.Length / 1024.0:0} KB)");
        return message;
    }

    /// <summary>
    /// I byte originali (E1, «Salva con nome»): il file della copia locale se c'è e l'impronta corrisponde,
    /// altrimenti scaricati (senza salvarli: li salva l'apertura normale della mail).
    /// </summary>
    public async Task<byte[]> LoadRawAsync(string folderName, uint uid, RawMessageDownload download, CancellationToken ct = default)
    {
        var folder = cache.FindFolder(folderName);
        if (folder is not null && cache.GetBodyRow(folder.Id, uid)?.Sha256 is { } stored && cache.Bodies.TryRead(stored) is { } cached)
            return cached;
        byte[] bytes = [];
        await download(async (stream, c) =>
        {
            // Una lettura ripetuta dopo una caduta della connessione riparte da capo.
            using var copy = new MemoryStream();
            await stream.CopyToAsync(copy, c);
            bytes = copy.ToArray();
        }, ct);
        return bytes;
    }

    /// <summary>
    /// Pulizia: scollega i corpi fuori dalla regola, poi elimina i file non più collegati, purché più
    /// vecchi di <paramref name="margin"/> (un file più recente può essere stato appena salvato).
    /// </summary>
    public SweepResult Sweep(TimeSpan margin)
    {
        var now = DateTimeOffset.UtcNow;
        var dropped = cache.DropBodies((role, arrived) => policy.Keeps(role, arrived, now));
        var (files, bytes) = cache.Bodies.DeleteUnreferenced(cache.GetReferencedBodies(), now - margin);
        return new SweepResult(dropped, files, bytes);
    }
}
