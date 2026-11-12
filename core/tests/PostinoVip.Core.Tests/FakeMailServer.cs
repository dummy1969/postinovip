using System.Collections.Concurrent;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;

namespace PostinoVip.Core.Tests;

/// <summary>
/// Server IMAP o SMTP finto su 127.0.0.1 per le prove della crittografia (4.1): TLS dall'inizio, STARTTLS
/// offerto o no, certificato autofirmato creato al volo. Risponde il minimo che serve a MailKit per
/// collegarsi e fare il login, e registra i comandi ricevuti (per controllare che la password non parta).
/// </summary>
public sealed class FakeMailServer : IAsyncDisposable
{
    public enum Protocol { Imap, Smtp, Pop3 }

    /// <summary>Casella POP3 finta: (UIDL, messaggio). Le rimozioni (DELE) si applicano al QUIT, come sul server vero.</summary>
    public List<(string Uidl, string Message)> Pop3Mailbox { get; } = [];

    /// <summary>Login XOAUTH2 ricevuti: "utente token" (decodificati dal formato SASL).</summary>
    public ConcurrentQueue<string> OAuthLogins { get; } = new();

    /// <summary>Annunciare UIDL nella CAPA (per provare un server che non lo supporta).</summary>
    public bool Pop3OffersUidl { get; set; } = true;

    private readonly TcpListener _listener = new(IPAddress.Loopback, 0);
    private readonly CancellationTokenSource _stop = new();
    private readonly Task _loop;
    private readonly Protocol _protocol;
    private readonly bool _implicitTls;
    private readonly bool _offerStartTls;

    public X509Certificate2 Certificate { get; }
    public int Port { get; }
    public ConcurrentQueue<string> Commands { get; } = new();

    /// <summary>Messaggi ricevuti con DATA dal server SMTP finto (testo completo, intestazioni comprese).</summary>
    public ConcurrentQueue<string> SmtpMessages { get; } = new();

    /// <summary>Comandi ricevuti dopo il passaggio a TLS (o dall'inizio con TLS implicito).</summary>
    public ConcurrentQueue<string> EncryptedCommands { get; } = new();

    public FakeMailServer(Protocol protocol, bool implicitTls, bool offerStartTls, X509Certificate2? certificate = null)
    {
        _protocol = protocol;
        _implicitTls = implicitTls;
        _offerStartTls = offerStartTls;
        Certificate = certificate ?? CreateSelfSigned("fake.invalid");
        _listener.Start();
        Port = ((IPEndPoint)_listener.LocalEndpoint).Port;
        _loop = Task.Run(AcceptLoopAsync);
    }

    public static X509Certificate2 CreateSelfSigned(string name)
    {
        using var key = RSA.Create(2048);
        var request = new CertificateRequest($"CN={name}", key, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        using var cert = request.CreateSelfSigned(DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(30));
        // Ricaricato da PKCS#12: chiave privata utilizzabile da SslStream su tutti i sistemi.
        return X509CertificateLoader.LoadPkcs12(cert.Export(X509ContentType.Pkcs12), null);
    }

    private async Task AcceptLoopAsync()
    {
        while (!_stop.IsCancellationRequested)
        {
            TcpClient client;
            try { client = await _listener.AcceptTcpClientAsync(_stop.Token); }
            catch { return; }
            _ = Task.Run(() => ServeAsync(client));
        }
    }

    private async Task ServeAsync(TcpClient client)
    {
        using var _ = client;
        try
        {
            Stream stream = client.GetStream();
            var tls = false;
            if (_implicitTls)
            {
                stream = await UpgradeAsync(stream);
                tls = true;
            }
            var session = new Session(stream);
            await session.WriteAsync(_protocol switch
            {
                Protocol.Imap => $"* OK [CAPABILITY {ImapCaps(tls)}] finto pronto",
                Protocol.Pop3 => "+OK finto POP3 pronto",
                _ => "220 fake.invalid ESMTP finto",
            });
            var deleted = new HashSet<int>();

            while (await session.ReadLineAsync() is { } line)
            {
                Commands.Enqueue(line);
                if (tls) EncryptedCommands.Enqueue(line);
                var startTls = _protocol switch
                {
                    Protocol.Imap => await ImapAsync(session, line, tls),
                    Protocol.Pop3 => await Pop3Async(session, line, tls, deleted),
                    _ => await SmtpAsync(session, line, tls),
                };
                if (startTls is null)
                    return;
                if (startTls == true)
                {
                    session = new Session(await UpgradeAsync(stream));
                    tls = true;
                }
            }
        }
        catch (Exception ex) when (ex is IOException or ObjectDisposedException or SocketException)
        {
            // il client ha chiuso o rifiutato il certificato
        }
    }

    private async Task<Stream> UpgradeAsync(Stream inner)
    {
        var ssl = new SslStream(inner, leaveInnerStreamOpen: true);
        try
        {
            await ssl.AuthenticateAsServerAsync(Certificate);
        }
        catch (System.Security.Authentication.AuthenticationException)
        {
            throw new IOException("handshake rifiutato dal client");
        }
        return ssl;
    }

    private string ImapCaps(bool tls) => "IMAP4rev1 AUTH=XOAUTH2 SASL-IR" + (!tls && _offerStartTls ? " STARTTLS" : "");

    /// <summary>"user=…\x01auth=Bearer …\x01\x01" -> "utente token"; registrato in <see cref="OAuthLogins"/>.</summary>
    private void RecordXOAuth2(string base64)
    {
        var text = Encoding.UTF8.GetString(Convert.FromBase64String(base64.Trim()));
        var parts = text.Split('\x01', StringSplitOptions.RemoveEmptyEntries);
        var user = parts.FirstOrDefault(p => p.StartsWith("user="))?[5..];
        var token = parts.FirstOrDefault(p => p.StartsWith("auth=Bearer "))?[12..];
        OAuthLogins.Enqueue($"{user} {token}");
    }

    /// <summary>true = passare a TLS, false = continuare, null = chiudere.</summary>
    private async Task<bool?> ImapAsync(Session s, string line, bool tls)
    {
        var parts = line.Split(' ', 3);
        var tag = parts[0];
        var command = parts.Length > 1 ? parts[1].ToUpperInvariant() : "";
        switch (command)
        {
            case "CAPABILITY":
                await s.WriteAsync($"* CAPABILITY {ImapCaps(tls)}");
                await s.WriteAsync($"{tag} OK fatto");
                return false;
            case "STARTTLS" when !tls && _offerStartTls:
                await s.WriteAsync($"{tag} OK inizia TLS");
                return true;
            case "AUTHENTICATE" when parts.Length > 2 && parts[2].StartsWith("XOAUTH2 ", StringComparison.OrdinalIgnoreCase):
                RecordXOAuth2(parts[2][8..]);
                await s.WriteAsync($"{tag} OK accesso con token");
                return false;
            case "LIST":
                await s.WriteAsync(line.Contains("\"\" \"\"")
                    ? "* LIST (\\Noselect) \"/\" \"\""
                    : "* LIST (\\HasNoChildren) \"/\" INBOX");
                await s.WriteAsync($"{tag} OK fatto");
                return false;
            case "LOGOUT":
                await s.WriteAsync("* BYE ciao");
                await s.WriteAsync($"{tag} OK fatto");
                return null;
            default:
                await s.WriteAsync($"{tag} OK fatto");
                return false;
        }
    }

    private async Task<bool?> SmtpAsync(Session s, string line, bool tls)
    {
        var upper = line.ToUpperInvariant();
        if (upper.StartsWith("EHLO"))
        {
            await s.WriteAsync("250-fake.invalid");
            if (!tls && _offerStartTls) await s.WriteAsync("250-STARTTLS");
            await s.WriteAsync("250 AUTH PLAIN XOAUTH2");
            return false;
        }
        if (upper == "STARTTLS" && !tls && _offerStartTls)
        {
            await s.WriteAsync("220 inizia TLS");
            return true;
        }
        if (upper.StartsWith("AUTH XOAUTH2 "))
        {
            RecordXOAuth2(line[13..]);
            await s.WriteAsync("235 ok");
            return false;
        }
        if (upper == "AUTH XOAUTH2")
        {
            await s.WriteAsync("334 ");
            RecordXOAuth2(await s.ReadLineAsync() ?? "");
            await s.WriteAsync("235 ok");
            return false;
        }
        if (upper == "AUTH PLAIN")
        {
            await s.WriteAsync("334 ");
            Commands.Enqueue(await s.ReadLineAsync() ?? "");
            await s.WriteAsync("235 ok");
            return false;
        }
        if (upper.StartsWith("AUTH"))
        {
            await s.WriteAsync("235 ok");
            return false;
        }
        if (upper == "QUIT")
        {
            await s.WriteAsync("221 ciao");
            return null;
        }
        if (upper == "DATA")
        {
            // Il messaggio così come arriva al server, fino alla riga con il solo punto.
            await s.WriteAsync("354 avanti");
            var data = new System.Text.StringBuilder();
            while (await s.ReadLineAsync() is { } l && l != ".")
                data.Append(l.StartsWith("..") ? l[1..] : l).Append("\r\n");
            SmtpMessages.Enqueue(data.ToString());
            await s.WriteAsync("250 ok");
            return false;
        }
        await s.WriteAsync("250 ok");
        return false;
    }

    private async Task<bool?> Pop3Async(Session s, string line, bool tls, HashSet<int> deleted)
    {
        var parts = line.Split(' ');
        var command = parts[0].ToUpperInvariant();
        (string Uidl, string Message)[] box;
        lock (Pop3Mailbox)
            box = Pop3Mailbox.ToArray();
        int Arg() => int.Parse(parts[1]);
        switch (command)
        {
            case "CAPA":
                await s.WriteAsync("+OK elenco");
                await s.WriteAsync("USER");
                if (Pop3OffersUidl) await s.WriteAsync("UIDL");
                if (!tls && _offerStartTls) await s.WriteAsync("STLS");
                await s.WriteAsync("SASL XOAUTH2");
                await s.WriteAsync(".");
                return false;
            case "STLS" when !tls && _offerStartTls:
                await s.WriteAsync("+OK inizia TLS");
                return true;
            case "STAT":
                await s.WriteAsync($"+OK {box.Length} {box.Sum(m => m.Message.Length)}");
                return false;
            case "LIST":
                await s.WriteAsync("+OK elenco");
                for (var i = 0; i < box.Length; i++)
                    if (!deleted.Contains(i)) await s.WriteAsync($"{i + 1} {box[i].Message.Length}");
                await s.WriteAsync(".");
                return false;
            case "UIDL" when !Pop3OffersUidl:
                await s.WriteAsync("-ERR comando sconosciuto");
                return false;
            case "UIDL" when parts.Length > 1:
                await s.WriteAsync($"+OK {Arg()} {box[Arg() - 1].Uidl}");
                return false;
            case "UIDL":
                await s.WriteAsync("+OK elenco");
                for (var i = 0; i < box.Length; i++)
                    if (!deleted.Contains(i)) await s.WriteAsync($"{i + 1} {box[i].Uidl}");
                await s.WriteAsync(".");
                return false;
            case "RETR":
                await s.WriteAsync("+OK messaggio");
                foreach (var l in box[Arg() - 1].Message.Replace("\r\n", "\n").Split('\n'))
                    await s.WriteAsync(l.StartsWith('.') ? "." + l : l);
                await s.WriteAsync(".");
                return false;
            case "DELE":
                deleted.Add(Arg() - 1);
                await s.WriteAsync("+OK segnata");
                return false;
            case "QUIT":
                lock (Pop3Mailbox)
                {
                    foreach (var i in deleted.OrderDescending())
                        Pop3Mailbox.RemoveAt(i);
                }
                await s.WriteAsync("+OK ciao");
                return null;
            case "AUTH" when parts.Length > 1 && parts[1].Equals("XOAUTH2", StringComparison.OrdinalIgnoreCase):
                if (parts.Length > 2)
                    RecordXOAuth2(parts[2]);
                else
                {
                    await s.WriteAsync("+ ");
                    RecordXOAuth2(await s.ReadLineAsync() ?? "");
                }
                await s.WriteAsync("+OK accesso con token");
                return false;
            default: // USER, PASS, NOOP, RSET...
                await s.WriteAsync("+OK");
                return false;
        }
    }

    private sealed class Session(Stream stream)
    {
        private readonly StreamReader _reader = new(stream, Encoding.ASCII, false, 1024, leaveOpen: true);

        public Task<string?> ReadLineAsync() => _reader.ReadLineAsync();

        public async Task WriteAsync(string line)
        {
            var bytes = Encoding.ASCII.GetBytes(line + "\r\n");
            await stream.WriteAsync(bytes);
            await stream.FlushAsync();
        }
    }

    public async ValueTask DisposeAsync()
    {
        await _stop.CancelAsync();
        _listener.Stop();
        try { await _loop; } catch { /* chiuso */ }
        Certificate.Dispose();
    }
}
