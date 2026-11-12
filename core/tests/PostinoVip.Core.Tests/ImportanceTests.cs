using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using MailKit;
using MailKit.Net.Imap;
using MailKit.Security;
using Microsoft.Data.Sqlite;
using MimeKit;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Models;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Tests;

/// <summary>Importanza (P1): lettura delle tre intestazioni, scrittura all'invio, copia locale e FETCH IMAP vero di MailKit.</summary>
public sealed class ImportanceTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "postinovip-test-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_dir))
            Directory.Delete(_dir, recursive: true);
    }

    private static HeaderList Headers(string text)
    {
        using var stream = new MemoryStream(Encoding.ASCII.GetBytes(text + "Subject: x\r\n\r\ncorpo\r\n"));
        return MimeMessage.Load(stream).Headers;
    }

    [Theory]
    [InlineData("", MailImportance.Normal)]
    [InlineData("Importance: high\r\n", MailImportance.High)]
    [InlineData("Importance: High\r\n", MailImportance.High)]
    [InlineData("Importance: low\r\n", MailImportance.Low)]
    [InlineData("Importance: normal\r\nX-Priority: 1\r\n", MailImportance.Normal)] // Importance prevale
    [InlineData("X-Priority: 1 (Highest)\r\n", MailImportance.High)]
    [InlineData("X-Priority: 2\r\n", MailImportance.High)]
    [InlineData("X-Priority: 3 (Normal)\r\n", MailImportance.Normal)]
    [InlineData("X-Priority: 5 (Lowest)\r\n", MailImportance.Low)]
    [InlineData("Priority: urgent\r\n", MailImportance.High)]
    [InlineData("Priority: non-urgent\r\n", MailImportance.Low)]
    [InlineData("X-Priority: 4\r\nPriority: urgent\r\n", MailImportance.Low)] // X-Priority prima di Priority
    [InlineData("Importance: boh\r\n", MailImportance.Normal)]
    public void LeggeLeTreIntestazioniComeOutlook(string headers, MailImportance expected) =>
        Assert.Equal(expected, MailImportanceHeaders.From(Headers(headers)));

    [Fact]
    public void InvioConPrioritaAltaOBassaComeOutlookEBozzaRiaperta()
    {
        var high = MimeMessageBuilder.Build(new OutgoingMessage("io@example.com", ["tu@example.com"], [], "Urgente", "testo",
            Importance: MailImportance.High));
        Assert.Equal("high", high.Headers[HeaderId.Importance]);
        Assert.StartsWith("1", high.Headers[HeaderId.XPriority]);

        var low = MimeMessageBuilder.Build(new OutgoingMessage("io@example.com", ["tu@example.com"], [], "Quando puoi", "testo",
            Importance: MailImportance.Low), draft: true);
        Assert.Equal("low", low.Headers[HeaderId.Importance]);
        Assert.StartsWith("5", low.Headers[HeaderId.XPriority]);
        Assert.Equal(MailImportance.Low, ComposeReader.Read(low).Importance);

        var normal = MimeMessageBuilder.Build(new OutgoingMessage("io@example.com", ["tu@example.com"], [], "x", "testo"));
        Assert.False(normal.Headers.Contains(HeaderId.Importance));
        Assert.False(normal.Headers.Contains(HeaderId.XPriority));
        Assert.Equal(MailImportance.Normal, ComposeReader.Read(normal).Importance);
    }

    [Fact]
    public void InJsonMinuscolo()
    {
        Assert.Equal("\"high\"", JsonSerializer.Serialize(MailImportance.High));
        Assert.Equal(MailImportance.Low, JsonSerializer.Deserialize<MailImportance>("\"low\""));
        Assert.Equal(MailImportance.High, JsonSerializer.Deserialize<MailImportance>("\"High\""));
    }

    [Fact]
    public void CopiaLocaleSalvaLImportanzaEQuelleNonNoteVannoRichieste()
    {
        var cache = new AccountCache(Path.Combine(_dir, "accounts", "main"));
        var folder = cache.GetOrAddFolder("INBOX");
        var when = DateTimeOffset.UtcNow;
        HeaderRecord R(uint uid, MailImportance? i) =>
            new(uid, MailFlags.None, $"o{uid}", null, "a@example.com", null, null, when.AddMinutes(uid), when.AddMinutes(uid), 1, null, null,
                Importance: i);
        cache.UpsertHeaders(folder.Id, [R(1, MailImportance.High), R(2, null), R(3, MailImportance.Low)]);
        Assert.Equal([2u], cache.GetMissingImportance(folder.Id));

        // Una nuova sincronizzazione senza importanza (es. intestazioni rilette) non cancella quella già nota.
        cache.UpsertHeaders(folder.Id, [R(1, null)]);
        cache.SetImportance(folder.Id, [(2u, MailImportance.Normal)]);
        Assert.Empty(cache.GetMissingImportance(folder.Id));

        var page = cache.GetPage(folder.Id, 0, 10).Items.ToDictionary(r => r.Uid, r => r.Importance);
        Assert.Equal(MailImportance.High, page[1]);
        Assert.Equal(MailImportance.Normal, page[2]);
        Assert.Equal(MailImportance.Low, page[3]);
        Assert.Equal(MailImportance.High, MessageHeaderMapper.FromRecord(cache.GetPage(folder.Id, 0, 10).Items.Single(r => r.Uid == 1)).Importance);
    }

    /// <summary>
    /// Il FETCH che MailKit 4.18.2 manda davvero con References più le intestazioni dell'importanza, e la lettura della
    /// risposta: server IMAP finto minimo (senza TLS, solo su 127.0.0.1) che registra i comandi.
    /// </summary>
    [Fact]
    public async Task FetchImapChiedeImportanzaEReferencesInsiemeELeLegge()
    {
        var headers = "References: <a@x>\r\nImportance: high\r\n\r\n";
        await using var server = new TinyImapServer(headers);
        using var client = new ImapClient();
        await client.ConnectAsync("127.0.0.1", server.Port, SecureSocketOptions.None);
        await client.AuthenticateAsync("utente", "finta");
        await client.Inbox.OpenAsync(FolderAccess.ReadOnly);
        var source = new ImapFolderSource(client.Inbox);

        var record = (await source.FetchHeadersAsync([1], withPreview: false, CancellationToken.None)).Single();
        var fetch = server.Commands.Single(c => c.Contains("UID FETCH") && c.Contains("BODY.PEEK["));
        Assert.Contains("BODY.PEEK[HEADER.FIELDS (", fetch);
        foreach (var name in new[] { "REFERENCES", "IMPORTANCE", "X-PRIORITY", "PRIORITY" })
            Assert.Contains(name, fetch.ToUpperInvariant());
        Assert.Equal(MailImportance.High, record.Importance);
        Assert.Equal("a@x", record.References);

        var only = await source.FetchImportanceAsync([1], CancellationToken.None);
        Assert.Equal([(1u, MailImportance.High)], only);
        Assert.DoesNotContain(server.Commands, c => c.Contains("STORE") || c.Contains("SELECT")); // sola lettura (EXAMINE)
        await client.DisconnectAsync(true);
    }

    /// <summary>Risponde OK a tutto; EXAMINE con un messaggio; FETCH con le intestazioni indicate.</summary>
    private sealed class TinyImapServer : IAsyncDisposable
    {
        private readonly TcpListener _listener = new(IPAddress.Loopback, 0);
        private readonly string _headers;
        private readonly Task _loop;

        public ConcurrentQueue<string> Commands { get; } = new();
        public int Port { get; }

        public TinyImapServer(string headers)
        {
            _headers = headers;
            _listener.Start();
            Port = ((IPEndPoint)_listener.LocalEndpoint).Port;
            _loop = Task.Run(ServeAsync);
        }

        private async Task ServeAsync()
        {
            using var tcp = await _listener.AcceptTcpClientAsync();
            await using var stream = tcp.GetStream();
            using var reader = new StreamReader(stream, Encoding.ASCII);
            async Task Send(string text) => await stream.WriteAsync(Encoding.ASCII.GetBytes(text));
            await Send("* OK [CAPABILITY IMAP4rev1] pronto\r\n");
            while (await reader.ReadLineAsync() is { } line)
            {
                Commands.Enqueue(line);
                var tag = line.Split(' ')[0];
                var command = line.Length > tag.Length ? line[(tag.Length + 1)..].ToUpperInvariant() : "";
                if (command.StartsWith("LOGIN"))
                    await Send($"{tag} OK [CAPABILITY IMAP4rev1] fatto\r\n");
                else if (command.StartsWith("LIST"))
                    await Send($"* LIST () \"/\" INBOX\r\n{tag} OK fatto\r\n");
                else if (command.StartsWith("EXAMINE"))
                    await Send($"* 1 EXISTS\r\n* 0 RECENT\r\n* OK [UIDVALIDITY 7] v\r\n* OK [UIDNEXT 2] n\r\n* FLAGS ()\r\n{tag} OK [READ-ONLY] fatto\r\n");
                else if (command.StartsWith("UID FETCH") && !command.Contains("BODY.PEEK["))
                {
                    // Struttura chiesta a parte dalle intestazioni (StructureGuard, 12/11/2026).
                    await Send($"* 1 FETCH (UID 1 BODYSTRUCTURE (\"TEXT\" \"PLAIN\" (\"CHARSET\" \"utf-8\") NIL NIL \"7BIT\" 5 1 NIL NIL NIL NIL))\r\n{tag} OK fatto\r\n");
                }
                else if (command.StartsWith("UID FETCH"))
                {
                    var section = command[(command.IndexOf("BODY.PEEK[", StringComparison.Ordinal) + "BODY.PEEK".Length)..];
                    section = section[..(section.IndexOf(']') + 1)];
                    var bytes = Encoding.ASCII.GetByteCount(_headers);
                    var full = command.Contains("ENVELOPE");
                    var meta = full
                        ? "FLAGS () RFC822.SIZE 100 INTERNALDATE \"09-Nov-2026 10:00:00 +0000\" " +
                          "ENVELOPE (\"Mon, 9 Nov 2026 10:00:00 +0000\" \"Prova\" NIL NIL NIL NIL NIL NIL NIL \"<m@x>\") " +
                          "BODYSTRUCTURE (\"TEXT\" \"PLAIN\" (\"CHARSET\" \"utf-8\") NIL NIL \"7BIT\" 5 1 NIL NIL NIL NIL) "
                        : "";
                    await Send($"* 1 FETCH (UID 1 {meta}BODY{section} {{{bytes}}}\r\n{_headers})\r\n{tag} OK fatto\r\n");
                }
                else if (command.StartsWith("LOGOUT"))
                {
                    await Send($"* BYE ciao\r\n{tag} OK fatto\r\n");
                    return;
                }
                else
                    await Send($"{tag} OK fatto\r\n");
            }
        }

        public async ValueTask DisposeAsync()
        {
            _listener.Stop();
            try { await _loop; } catch (Exception) { /* connessione già chiusa */ }
        }
    }
}
