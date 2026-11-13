using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using System.Text;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Security;

namespace PostinoVip.Core.Tests;

/// <summary>
/// «Svuota cartella» (12/11/2026) con IMAP: comandi mandati davvero da MailKit a un server finto (senza TLS, solo su
/// 127.0.0.1). Solo gli UID trovati (UID EXPUNGE, mai EXPUNGE di tutta la cartella), sottocartelle dalle più profonde,
/// niente toccato se dentro c'è una cartella speciale.
/// </summary>
public sealed class EmptyFolderImapTests
{
    [Fact]
    public async Task SvuotaMailESottocartelleConISoliUidTrovati()
    {
        await using var server = new FakeImap(["Trash/A", "Trash/A/B"]);
        await using var service = await ConnectAsync(server);

        var result = await service.EmptyFolderAsync("Trash", subfolders: true);

        Assert.Equal(3, result.Messages);
        Assert.Equal(["Trash/A/B", "Trash/A"], result.RemovedFolders);
        var commands = server.Commands.ToList();
        Assert.Contains(commands, c => c.StartsWith("SELECT Trash", StringComparison.Ordinal)); // lettura e scrittura
        Assert.Contains(commands, c => c.StartsWith("UID STORE 5,7,9 +FLAGS.SILENT (\\Deleted)", StringComparison.Ordinal));
        Assert.Contains("UID EXPUNGE 5,7,9", commands);
        Assert.DoesNotContain("EXPUNGE", commands); // mai l'EXPUNGE di tutta la cartella
        var deletes = commands.Where(c => c.StartsWith("DELETE", StringComparison.Ordinal)).ToList();
        Assert.Equal(["DELETE Trash/A/B", "DELETE Trash/A"], deletes);
    }

    [Fact]
    public async Task SenzaSottocartelleSoloLeMail()
    {
        await using var server = new FakeImap(["Trash/A"]);
        await using var service = await ConnectAsync(server);

        var result = await service.EmptyFolderAsync("Trash", subfolders: false);

        Assert.Equal(3, result.Messages);
        Assert.Empty(result.RemovedFolders);
        Assert.DoesNotContain(server.Commands, c => c.StartsWith("DELETE", StringComparison.Ordinal));
    }

    [Fact]
    public async Task UnaCartellaSpecialeDentroNonFaToccareNiente()
    {
        await using var server = new FakeImap(["Trash/A"], specialInside: "Trash/Sent");
        await using var service = await ConnectAsync(server);

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.EmptyFolderAsync("Trash", subfolders: true));
        Assert.DoesNotContain(server.Commands, c => c.Contains("STORE") || c.Contains("EXPUNGE") || c.StartsWith("DELETE"));
    }

    private static async Task<ImapMailService> ConnectAsync(FakeImap server)
    {
        var service = new ImapMailService(new ImapSettings
        {
            Host = "127.0.0.1", Port = server.Port, Username = "u", Password = "p", Security = ConnectionSecurity.None,
        });
        await service.ConnectAsync();
        return service;
    }

    /// <summary>Casella con Trash (\Trash, UID 5, 7, 9) e le sottocartelle indicate; registra i comandi (senza il tag).</summary>
    private sealed class FakeImap : IAsyncDisposable
    {
        private readonly TcpListener _listener = new(IPAddress.Loopback, 0);
        private readonly List<string> _folders;
        private readonly string? _special;
        private readonly Task _loop;

        public ConcurrentQueue<string> Commands { get; } = new();
        public int Port { get; }

        public FakeImap(List<string> subfolders, string? specialInside = null)
        {
            _folders = subfolders;
            _special = specialInside;
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
            try
            {
                await Send("* OK [CAPABILITY IMAP4rev1 UIDPLUS] pronto\r\n");
                while (await reader.ReadLineAsync() is { } line)
                {
                    var tag = line.Split(' ')[0];
                    var command = line[(tag.Length + 1)..];
                    Commands.Enqueue(command);
                    var upper = command.ToUpperInvariant();
                    if (upper.StartsWith("LOGIN"))
                        await Send($"{tag} OK [CAPABILITY IMAP4rev1 UIDPLUS] fatto\r\n");
                    else if (upper.StartsWith("LIST \"\" \"\""))
                        await Send($"* LIST (\\Noselect) \"/\" \"\"\r\n{tag} OK fatto\r\n");
                    else if (upper.StartsWith("LIST"))
                    {
                        var list = new StringBuilder("* LIST () \"/\" INBOX\r\n* LIST (\\Trash) \"/\" Trash\r\n");
                        foreach (var f in _folders)
                            list.Append($"* LIST () \"/\" \"{f}\"\r\n");
                        if (_special is not null)
                            list.Append($"* LIST (\\Sent) \"/\" \"{_special}\"\r\n");
                        await Send(list + $"{tag} OK fatto\r\n");
                    }
                    else if (upper.StartsWith("SELECT") || upper.StartsWith("EXAMINE"))
                        await Send($"* 3 EXISTS\r\n* OK [UIDVALIDITY 7] v\r\n* OK [UIDNEXT 10] n\r\n* FLAGS (\\Deleted \\Seen)\r\n" +
                                   $"* OK [PERMANENTFLAGS (\\Deleted \\Seen)] p\r\n{tag} OK [READ-WRITE] fatto\r\n");
                    else if (upper.StartsWith("UID SEARCH"))
                        await Send($"* SEARCH 5 7 9\r\n{tag} OK fatto\r\n");
                    else if (upper.StartsWith("UID EXPUNGE"))
                        await Send($"* 3 EXPUNGE\r\n* 2 EXPUNGE\r\n* 1 EXPUNGE\r\n{tag} OK fatto\r\n");
                    else if (upper.StartsWith("LOGOUT"))
                    {
                        await Send($"* BYE ciao\r\n{tag} OK fatto\r\n");
                        return;
                    }
                    else
                        await Send($"{tag} OK fatto\r\n");
                }
            }
            catch (IOException) { /* connessione chiusa dal client */ }
        }

        public async ValueTask DisposeAsync()
        {
            _listener.Stop();
            try { await _loop; } catch { /* già chiuso */ }
        }
    }
}
