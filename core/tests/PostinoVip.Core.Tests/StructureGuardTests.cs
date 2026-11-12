using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;
using MailKit;
using MailKit.Net.Imap;
using Microsoft.Data.Sqlite;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Security;

namespace PostinoVip.Core.Tests;

/// <summary>
/// Struttura (BODYSTRUCTURE) illeggibile per MailKit (12/11/2026, IceWarp): una sola mail non deve bloccare la lista, e il
/// download in background la isola. Server IMAP finto (senza TLS, solo su 127.0.0.1) con 60 mail, la 40 come quella vera.
/// </summary>
public sealed partial class StructureGuardTests : IDisposable
{
    // Risposta vera di IceWarp (avviso di mancato recapito, testi oscurati in "x"): nell'ultima parte "7bit" 0 NIL il
    // numero di righe è NIL, contro RFC 3501 (body-fld-lines = number).
    private const string IceWarpStructure =
        "((\"text\" \"plain\" (\"charset\" \"utf-8\") NIL NIL \"8bit\" 147 6 NIL NIL NIL NIL)(\"message\" \"delivery-status\" NIL NIL NIL \"7bit\" 261 NIL NIL NIL NIL)(\"message\" \"rfc822\" NIL NIL NIL \"7bit\" 4381 (\"x\" \"x\" ((\"x\" NIL \"x\" \"x\")) ((\"x\" NIL \"x\" \"x\")) ((\"x\" NIL \"x\" \"x\")) ((\"x\" NIL \"x\" \"x\")) ((NIL NIL \"x\" \"x\")) NIL NIL \"x\") (((\"text\" \"plain\" (\"charset\" \"iso-8859-1\") NIL NIL \"quoted-printable\" 266 10 NIL NIL NIL NIL)(\"text\" \"html\" (\"charset\" \"iso-8859-1\") NIL NIL \"quoted-printable\" 2179 59 NIL NIL NIL NIL) \"alternative\" (\"boundary\" \"x\") NIL NIL NIL NIL)(\"message\" \"rfc822\" NIL NIL NIL \"7bit\" 275 (NIL NIL NIL NIL NIL NIL NIL NIL NIL NIL) (\"text\" \"plain\" NIL NIL NIL \"7bit\" 0 1 NIL NIL NIL NIL) 6 NIL (\"attachment\" NIL) NIL NIL)(\"text\" \"plain\" NIL NIL NIL \"7bit\" 0 NIL NIL NIL NIL NIL) \"mixed\" (\"boundary\" \"x\") NIL NIL NIL NIL) 119 NIL NIL NIL NIL) \"report\" (\"report-type\" \"delivery-status\" \"boundary\" \"x\") NIL NIL NIL NIL)";

    private const string TextStructure = "(\"TEXT\" \"PLAIN\" (\"CHARSET\" \"utf-8\") NIL NIL \"7BIT\" 5 1 NIL NIL NIL NIL)";
    private const string AttachmentStructure =
        "((\"TEXT\" \"PLAIN\" (\"CHARSET\" \"utf-8\") NIL NIL \"7BIT\" 5 1 NIL NIL NIL NIL)" +
        "(\"APPLICATION\" \"PDF\" (\"NAME\" \"a.pdf\") NIL NIL \"BASE64\" 100 NIL (\"ATTACHMENT\" (\"FILENAME\" \"a.pdf\")) NIL NIL)" +
        " \"MIXED\" (\"BOUNDARY\" \"b\") NIL NIL NIL)";

    private const uint Broken = 40;
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-test-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    /// <summary>La struttura vera fa fallire MailKit solo per il numero di righe NIL (se cambia, la protezione si può rivedere).</summary>
    [Fact]
    public async Task MailKitRifiutaSoloIlNumeroDiRigheNil()
    {
        await using var server = new FakeImap(Broken);
        Assert.IsType<ImapProtocolException>(await Record.ExceptionAsync(() => FetchStructure(server, Broken)));
        server.Structures[Broken] = IceWarpStructure.Replace("\"7bit\" 0 NIL NIL", "\"7bit\" 0 0 NIL");
        Assert.Null(await Record.ExceptionAsync(() => FetchStructure(server, Broken)));
    }

    [Fact]
    public async Task LaListaSiSincronizzaEIlBackgroundIsolaLaMailDifettosa()
    {
        await using var server = new FakeImap(Broken);
        var user = "utente-" + Guid.NewGuid().ToString("N");
        await using var connection = new ImapConnection(new ImapSettings
        {
            Host = "127.0.0.1", Port = server.Port, Username = user, Password = "finta", Security = ConnectionSecurity.None,
        });
        var cache = new AccountCache(Path.Combine(_dir, "accounts", "main"));

        // Lista: il primo tentativo cade sulla struttura, la ripetizione (connessione nuova) salta il gruppo sospetto.
        var sync = await connection.ReadAsync(s => s.ExamineAsync("INBOX", f => FolderSynchronizer.SyncAsync(f, cache)));
        Assert.Equal(60, sync.Added);
        Assert.Equal(2, connection.ConnectCount);
        var folder = cache.FindFolder("INBOX")!;
        Assert.Equal(60, cache.GetUids(folder.Id).Count);
        Assert.All(cache.GetPage(folder.Id, 0, 100).Items, r => Assert.Null(r.HasAttachments));

        // Background: ogni tentativo divide a metà il gruppo sospetto, finché resta la sola mail difettosa.
        var guard = StructureGuard.For($"127.0.0.1:{server.Port}:{user}", "INBOX", FakeImap.UidValidity);
        var all = Enumerable.Range(1, 60).Select(u => (uint)u).ToList();
        IReadOnlyList<PreviewRecord>? previews = null;
        for (var attempt = 0; attempt < 20 && previews is null; attempt++)
        {
            try
            {
                previews = await connection.ReadAsync(s => s.ExamineAsync("INBOX", f => f.FetchPreviewsAsync(all, default)));
            }
            catch (UnreadableStructureException)
            {
                // Come CacheDownloadWorker: si riprova più tardi.
            }
        }
        Assert.NotNull(previews);
        Assert.Equal([Broken], guard.Unreadable);
        Assert.Equal(0, guard.SuspectCount);
        Assert.Equal(59, previews.Count);
        Assert.DoesNotContain(previews, p => p.Uid == Broken);
        Assert.All(previews, p => Assert.Equal(p.Uid % 10 == 0, p.HasAttachments));

        // Da qui la struttura della mail difettosa non si chiede più: le richieste normali passano al primo colpo.
        var connects = connection.ConnectCount;
        var has = await connection.ReadAsync(s => s.ExamineAsync("INBOX", f => f.FetchHasAttachmentsAsync(all, default)));
        Assert.Equal(59, has.Count);
        Assert.Equal(connects, connection.ConnectCount);
        Assert.DoesNotContain(server.Commands, c => c.Contains("STORE") || c.Contains("SELECT")); // sola lettura
    }

    private static async Task FetchStructure(FakeImap server, uint uid)
    {
        using var client = new ImapClient();
        await client.ConnectAsync("127.0.0.1", server.Port, MailKit.Security.SecureSocketOptions.None);
        await client.AuthenticateAsync("u", "p");
        await client.Inbox.OpenAsync(FolderAccess.ReadOnly);
        await client.Inbox.FetchAsync([new UniqueId(uid)], MessageSummaryItems.UniqueId | MessageSummaryItems.BodyStructure);
    }

    /// <summary>60 mail (UID = numero di sequenza), una con la struttura di IceWarp; ogni decima con un allegato.</summary>
    private sealed partial class FakeImap : IAsyncDisposable
    {
        public const uint UidValidity = 7;
        private const int Count = 60;
        private const string Headers = "Importance: normal\r\n\r\n";
        private readonly TcpListener _listener = new(IPAddress.Loopback, 0);
        private readonly CancellationTokenSource _stop = new();
        private readonly Task _loop;

        public ConcurrentQueue<string> Commands { get; } = new();
        public ConcurrentDictionary<uint, string> Structures { get; } = new();
        public int Port { get; }

        public FakeImap(uint broken)
        {
            for (uint u = 1; u <= Count; u++)
                Structures[u] = u == broken ? IceWarpStructure : u % 10 == 0 ? AttachmentStructure : TextStructure;
            _listener.Start();
            Port = ((IPEndPoint)_listener.LocalEndpoint).Port;
            _loop = Task.Run(AcceptAsync);
        }

        private async Task AcceptAsync()
        {
            var sessions = new List<Task>();
            try
            {
                while (true)
                {
                    var tcp = await _listener.AcceptTcpClientAsync(_stop.Token);
                    sessions.Add(Task.Run(() => ServeAsync(tcp)));
                }
            }
            catch (OperationCanceledException) { }
            catch (SocketException) { }
            try { await Task.WhenAll(sessions); } catch { /* connessioni chiuse dal client */ }
        }

        private async Task ServeAsync(TcpClient tcp)
        {
            using var _ = tcp;
            await using var stream = tcp.GetStream();
            using var reader = new StreamReader(stream, Encoding.ASCII);
            async Task Send(string text) => await stream.WriteAsync(Encoding.ASCII.GetBytes(text));
            try
            {
                await Send("* OK [CAPABILITY IMAP4rev1] pronto\r\n");
                while (await reader.ReadLineAsync() is { } line)
                {
                    Commands.Enqueue(line);
                    var tag = line.Split(' ')[0];
                    var command = line.Length > tag.Length ? line[(tag.Length + 1)..] : "";
                    var upper = command.ToUpperInvariant();
                    if (upper.StartsWith("LOGIN"))
                        await Send($"{tag} OK [CAPABILITY IMAP4rev1] fatto\r\n");
                    else if (upper.StartsWith("LIST"))
                        await Send($"* LIST () \"/\" INBOX\r\n{tag} OK fatto\r\n");
                    else if (upper.StartsWith("EXAMINE"))
                        await Send($"* {Count} EXISTS\r\n* 0 RECENT\r\n* OK [UIDVALIDITY {UidValidity}] v\r\n* OK [UIDNEXT {Count + 1}] n\r\n" +
                                   $"* FLAGS ()\r\n{tag} OK [READ-ONLY] fatto\r\n");
                    else if (upper.StartsWith("UID SEARCH"))
                        await Send($"* SEARCH {string.Join(' ', Enumerable.Range(1, Count))}\r\n{tag} OK fatto\r\n");
                    else if (upper.StartsWith("UID FETCH"))
                        await Send(Fetch(command) + $"{tag} OK fatto\r\n");
                    else if (upper.StartsWith("LOGOUT"))
                    {
                        await Send($"* BYE ciao\r\n{tag} OK fatto\r\n");
                        return;
                    }
                    else
                        await Send($"{tag} OK fatto\r\n");
                }
            }
            catch (IOException) { /* MailKit chiude la connessione dopo l'errore di struttura */ }
        }

        private string Fetch(string command)
        {
            var parts = command.Split(' ', 4);
            var items = parts[3].ToUpperInvariant();
            var section = SectionRegex().Match(parts[3]);
            var reply = new StringBuilder();
            foreach (var uid in ParseSet(parts[2]))
            {
                var data = new List<string> { $"UID {uid}" };
                if (items.Contains("ENVELOPE"))
                    data.Add($"FLAGS () RFC822.SIZE 100 INTERNALDATE \"09-Nov-2026 10:00:00 +0000\" " +
                             $"ENVELOPE (\"Mon, 9 Nov 2026 10:00:00 +0000\" \"Prova {uid}\" NIL NIL NIL NIL NIL NIL NIL \"<{uid}@x>\")");
                if (items.Contains("BODYSTRUCTURE"))
                    data.Add($"BODYSTRUCTURE {Structures[uid]}");
                if (section.Success)
                {
                    // BODY.PEEK[HEADER.FIELDS (...)] -> le intestazioni; BODY.PEEK[1]<0.512> (anteprima) -> un testo breve.
                    var name = section.Groups[1].Value;
                    var text = name.StartsWith("HEADER", StringComparison.OrdinalIgnoreCase) ? Headers : "ciao!";
                    var origin = section.Groups[2].Success ? $"<{section.Groups[2].Value}>" : "";
                    data.Add($"BODY[{name}]{origin} {{{Encoding.ASCII.GetByteCount(text)}}}\r\n{text}");
                }
                reply.Append($"* {uid} FETCH ({string.Join(' ', data)})\r\n");
            }
            return reply.ToString();
        }

        private static IEnumerable<uint> ParseSet(string set) =>
            set.Split(',').SelectMany(r =>
            {
                var ends = r.Split(':');
                var from = uint.Parse(ends[0]);
                var to = ends.Length > 1 ? (ends[1] == "*" ? Count : uint.Parse(ends[1])) : from;
                return Enumerable.Range((int)Math.Min(from, to), (int)(Math.Max(from, to) - Math.Min(from, to) + 1)).Select(u => (uint)u);
            }).Where(u => u is >= 1 and <= Count);

        [GeneratedRegex(@"BODY\.PEEK\[([^\]]*)\](?:<(\d+)(?:\.\d+)?>)?", RegexOptions.IgnoreCase)]
        private static partial Regex SectionRegex();

        public async ValueTask DisposeAsync()
        {
            _stop.Cancel();
            _listener.Stop();
            try { await _loop; } catch { /* già chiuso */ }
        }
    }
}
