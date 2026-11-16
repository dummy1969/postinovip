using System.Diagnostics;
using MailKit.Net.Pop3;
using MailKit.Security;
using PostinoVip.Core.Local;
using PostinoVip.Core.Security;

namespace PostinoVip.Core.Pop3;

/// <summary>Esito di un controllo della posta POP3 (diagnostica: solo numeri, mai contenuti).</summary>
public sealed record Pop3Result(int OnServer, int Downloaded, long Bytes, int Removed, TimeSpan Elapsed)
{
    public override string ToString() =>
        $"POP3: {OnServer} sul server, {Downloaded} scaricate ({Bytes / 1024.0:0} KB), {Removed} tolte dal server, {Elapsed.TotalSeconds:0.0} s";
}

/// <summary>
/// Un controllo della posta di un account POP3 (4.2): collegamento con la crittografia scelta (certificato come
/// per IMAP/SMTP, <see cref="TrustedCertificate"/>), elenco UIDL, scaricamento nella Posta in arrivo locale
/// delle mail non ancora scaricate (dalla più vecchia, così gli UID locali crescono con l'arrivo), poi le
/// rimozioni dal server secondo le regole dell'account. MODIFICA la casella solo con le rimozioni (DELE),
/// che il server applica alla chiusura (QUIT): se la connessione cade prima, non viene tolto nulla.
/// Ordine: prima il file della mail, poi la voce in <see cref="Pop3State"/>; un'interruzione in mezzo
/// porta al più a riscaricarla (un doppione), mai a perderla. Una mail si toglie dal server solo se è
/// stata scaricata.
/// </summary>
/// <param name="progress">Avanzamento (scaricate, da scaricare) ogni <see cref="ProgressEvery"/> mail: la prima volta possono essere migliaia.</param>
public sealed class Pop3Fetcher(Pop3Settings settings, LocalMailStore store, Pop3State state, Action<int, int>? progress = null)
{
    public const int ProgressEvery = 200;

    public static readonly TimeSpan ConnectTimeout = TimeSpan.FromSeconds(10);
    public static readonly TimeSpan OperationTimeout = TimeSpan.FromSeconds(30);

    /// <summary>Intestazione aggiunta in testa a ogni mail scaricata (come fa Thunderbird): serve a ritrovare la mail sul server.</summary>
    public const string UidlHeader = "X-UIDL";

    public async Task<Pop3Result> RunAsync(DateTimeOffset now, CancellationToken ct = default)
    {
        var watch = Stopwatch.StartNew();
        using var client = new Pop3Client { Timeout = (int)OperationTimeout.TotalMilliseconds };
        await ConnectAsync(client, settings, ct);

        if (!client.Capabilities.HasFlag(Pop3Capabilities.UIDL))
            throw new NotSupportedException("Il server POP3 non supporta UIDL: senza, non si può sapere quali mail sono già state scaricate.").WithCode("ilServerPop3NonSupporta");

        var uidls = await client.GetMessageUidsAsync(ct);
        var onServer = new Dictionary<string, int>(StringComparer.Ordinal);
        for (var i = 0; i < uidls.Count; i++)
            onServer.TryAdd(uidls[i], i);

        // Voci di mail non più sul server (tolte da un altro programma o scadute): dimenticate.
        state.Forget(state.Entries.Keys.Where(u => !onServer.ContainsKey(u)).ToList());

        store.EnsureDefaults();
        var pending = uidls.Count(u => !state.Contains(u));
        int downloaded = 0;
        long bytes = 0;
        for (var i = 0; i < uidls.Count; i++)
        {
            ct.ThrowIfCancellationRequested();
            var uidl = uidls[i];
            if (state.Contains(uidl))
                continue;
            await using (var stream = await client.GetStreamAsync(i, headersOnly: false, ct))
            {
                bytes += stream.CanSeek ? stream.Length : 0;
                await store.AddAsync(LocalMailStore.Inbox, stream, Prefix(uidl), ct);
            }
            state.MarkDownloaded(uidl, now);
            downloaded++;
            if (downloaded % ProgressEvery == 0)
                progress?.Invoke(downloaded, pending);
        }

        var toRemove = state.Entries
            .Where(e => onServer.ContainsKey(e.Key) && ShouldRemove(e.Value, settings, now))
            .Select(e => e.Key)
            .ToList();
        foreach (var uidl in toRemove)
            await client.DeleteMessageAsync(onServer[uidl], ct);

        // QUIT: solo ora il server applica le rimozioni.
        await client.DisconnectAsync(quit: true, ct);
        state.Forget(toRemove);
        return new Pop3Result(uidls.Count, downloaded, bytes, toRemove.Count, watch.Elapsed);
    }

    /// <summary>Regole di Outlook (scelta 2a) per una mail già scaricata.</summary>
    public static bool ShouldRemove(Pop3Entry entry, Pop3Settings settings, DateTimeOffset now) =>
        !settings.LeaveOnServer
        || (settings.RemoveAfterDays > 0 && entry.Downloaded <= now.AddDays(-settings.RemoveAfterDays))
        || (settings.RemoveWhenDeleted && entry.Remove);

    /// <summary>"X-UIDL: …" se l'UIDL è valido (RFC 1939: 1–70 caratteri stampabili), altrimenti niente.</summary>
    public static string? Prefix(string uidl) =>
        uidl.Length is > 0 and <= 70 && uidl.All(c => c is > ' ' and <= '~') ? $"{UidlHeader}: {uidl}\r\n" : null;

    /// <summary>Collegamento e login entro <see cref="ConnectTimeout"/>; certificato rifiutato -> UntrustedCertificateException.</summary>
    public static async Task ConnectAsync(Pop3Client client, Pop3Settings settings, CancellationToken ct)
    {
        var trust = new TrustedCertificate(settings.Host, settings.Port, settings.CertificateSha256);
        client.ServerCertificateValidationCallback = trust.Validate;
        using var limit = CancellationTokenSource.CreateLinkedTokenSource(ct);
        limit.CancelAfter(ConnectTimeout);
        try
        {
            await client.ConnectAsync(settings.Host, settings.Port, settings.EffectiveSecurity.ToMailKit(), limit.Token);
        }
        catch (SslHandshakeException ex) when (trust.Rejected is { } rejected && !limit.IsCancellationRequested)
        {
            throw new UntrustedCertificateException(rejected, ex);
        }
        catch (Exception ex) when (limit.IsCancellationRequested && !ct.IsCancellationRequested)
        {
            throw new MailOfflineException($"Server POP3 {settings.Host}:{settings.Port} non raggiungibile (nessuna risposta).", ex)
                .WithCode("pop3NoAnswer", ("address", $"{settings.Host}:{settings.Port}"));
        }
        catch (Exception ex) when (ex is System.Net.Sockets.SocketException or IOException && ex is not SslHandshakeException
                                   && !ct.IsCancellationRequested)
        {
            throw new MailOfflineException($"Server POP3 {settings.Host}:{settings.Port} non raggiungibile ({ex.GetType().Name}).", ex)
                .WithCode("pop3Unreachable", ("address", $"{settings.Host}:{settings.Port}"), ("reason", ex.GetType().Name));
        }
        await OAuth.MailAuth.AuthenticateAsync(client, settings.Username, settings.Password, settings.AccessToken, limit.Token);
    }
}
