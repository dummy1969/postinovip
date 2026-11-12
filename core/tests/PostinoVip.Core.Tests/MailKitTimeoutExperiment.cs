using System.Net;
using System.Net.Sockets;
using MailKit.Net.Imap;
using MailKit.Security;
using PostinoVip.Core.Imap;

namespace PostinoVip.Core.Tests;

/// <summary>
/// Comportamento di MailKit su cui conta il funzionamento senza rete (8d): se il server tace (rete
/// staccata a connessione aperta), allo scadere di ImapClient.Timeout arriva TimeoutException e la
/// connessione viene chiusa. Il valore di serie (2 minuti) è più lungo dei 30 s che l'app concede al core.
/// </summary>
public class MailKitTimeoutTests
{
    [Fact]
    public async Task ServerMutoTimeoutExceptionEConnessioneChiusa()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        using var accepted = await Task.Run(async () =>
        {
            var accept = listener.AcceptTcpClientAsync(); // accetta e non risponde mai
            using var client = new ImapClient { Timeout = 500 };
            var ex = await Record.ExceptionAsync(() => client.ConnectAsync("127.0.0.1", port, SecureSocketOptions.None));

            Assert.IsType<TimeoutException>(ex);
            Assert.False(client.IsConnected);
            Assert.True(ImapConnection.IsConnectionError(ex)); // -> connessione chiusa, nuovo collegamento, "non connesso"
            return await accept;
        });
        listener.Stop();
    }

    [Fact]
    public void TempoMassimoDiSerieTroppoLungoPerLApp()
    {
        Assert.Equal(120_000, new ImapClient().Timeout); // per questo ImapConnection usa OperationTimeout
        Assert.True(ImapConnection.OperationTimeout + ImapConnection.ConnectTimeout < TimeSpan.FromSeconds(30));
    }
}
