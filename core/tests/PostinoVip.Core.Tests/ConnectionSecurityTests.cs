using MailKit.Security;
using PostinoVip.Core.Account;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Security;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Tests;

/// <summary>Crittografia delle connessioni e certificati di cui fidarsi (4.1), con server finti locali.</summary>
public class ConnectionSecurityTests
{
    private const string Password = "SEGRETA-4.1";

    private static ImapSettings Imap(FakeMailServer server, ConnectionSecurity security, string? pin = null) => new()
    {
        Host = "127.0.0.1", Port = server.Port, Username = "me@example.com", Password = Password,
        Security = security, CertificateSha256 = pin,
    };

    private static SmtpSettings Smtp(FakeMailServer server, ConnectionSecurity security, bool auth = true, string? pin = null) => new()
    {
        Host = "127.0.0.1", Port = server.Port, Username = "me@example.com", Password = Password,
        Security = security, RequireAuth = auth, CertificateSha256 = pin,
    };

    private static bool PasswordSent(FakeMailServer server) =>
        server.Commands.Any(c => c.Contains(Password) || c.Contains(Convert.ToBase64String("\0me@example.com\0"u8.ToArray().Concat(System.Text.Encoding.ASCII.GetBytes(Password)).ToArray())));

    [Theory]
    [InlineData(993, ConnectionSecurity.SslOnConnect)]
    [InlineData(143, ConnectionSecurity.StartTls)]
    [InlineData(1993, ConnectionSecurity.SslOnConnect)]
    public void ImapCrittografiaPropostaDallaPorta(int port, ConnectionSecurity expected) =>
        Assert.Equal(expected, new ImapSettings { Port = port }.EffectiveSecurity);

    [Theory]
    [InlineData(465, ConnectionSecurity.SslOnConnect)] // prima della 4.1 sulla 465 si tentava STARTTLS: non funzionava
    [InlineData(587, ConnectionSecurity.StartTls)]
    [InlineData(25, ConnectionSecurity.StartTls)]
    public void SmtpCrittografiaPropostaDallaPorta(int port, ConnectionSecurity expected) =>
        Assert.Equal(expected, new SmtpSettings { Port = port }.EffectiveSecurity);

    [Fact]
    public void SceltaEsplicitaPrevaleSullaPorta() =>
        Assert.Equal(ConnectionSecurity.None, new ImapSettings { Port = 993, Security = ConnectionSecurity.None }.EffectiveSecurity);

    [Fact]
    public void StartTlsMaiFacoltativo() =>
        Assert.Equal(SecureSocketOptions.StartTls, ConnectionSecurity.StartTls.ToMailKit()); // mai StartTlsWhenAvailable

    [Theory]
    [InlineData("ab:cd", null)]
    [InlineData("", null)]
    [InlineData(null, null)]
    public void ImprontaNonValidaIgnorata(string? value, string? expected) =>
        Assert.Equal(expected, TrustedCertificate.NormalizeFingerprint(value));

    [Fact]
    public void ImprontaConDuePuntiEMinuscole()
    {
        var hex = new string('a', 64);
        var colons = string.Join(":", Enumerable.Range(0, 32).Select(_ => "aa"));
        Assert.Equal(hex.ToUpperInvariant(), TrustedCertificate.NormalizeFingerprint(colons));
    }

    [Fact]
    public async Task ImapCertificatoAutofirmatoRifiutatoPrimaDellaPassword()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Imap, implicitTls: true, offerStartTls: false);
        await using var session = new ImapMailService(Imap(server, ConnectionSecurity.SslOnConnect));

        var ex = await Assert.ThrowsAsync<UntrustedCertificateException>(() => session.ConnectAsync());

        Assert.Equal(TrustedCertificate.Fingerprint(server.Certificate), ex.Certificate.Sha256);
        Assert.Equal("CN=fake.invalid", ex.Certificate.Subject);
        Assert.Equal(server.Port, ex.Certificate.Port);
        Assert.NotEmpty(ex.Certificate.Problems);
        Assert.NotNull(ex.Certificate.NotAfter);
        Assert.False(PasswordSent(server));
    }

    [Fact]
    public async Task ImapCertificatoDiCuiFidarsiAccettato()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Imap, implicitTls: true, offerStartTls: false);
        var pin = TrustedCertificate.Fingerprint(server.Certificate).ToLowerInvariant();
        await using var session = new ImapMailService(Imap(server, ConnectionSecurity.SslOnConnect, pin));

        await session.ConnectAsync();

        Assert.True(session.IsAlive);
        Assert.Contains(server.EncryptedCommands, c => c.Contains("LOGIN") && c.Contains(Password));
    }

    [Fact]
    public async Task ImapAltroCertificatoRifiutatoAncheConImprontaSalvata()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Imap, implicitTls: true, offerStartTls: false);
        using var other = FakeMailServer.CreateSelfSigned("altro.invalid");
        await using var session = new ImapMailService(Imap(server, ConnectionSecurity.SslOnConnect, TrustedCertificate.Fingerprint(other)));

        var ex = await Assert.ThrowsAsync<UntrustedCertificateException>(() => session.ConnectAsync());

        Assert.Equal(TrustedCertificate.Fingerprint(server.Certificate), ex.Certificate.Sha256);
        Assert.False(PasswordSent(server));
    }

    [Fact]
    public async Task ImapStartTlsPassaATlsPrimaDelLogin()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Imap, implicitTls: false, offerStartTls: true);
        var pin = TrustedCertificate.Fingerprint(server.Certificate);
        await using var session = new ImapMailService(Imap(server, ConnectionSecurity.StartTls, pin));

        await session.ConnectAsync();

        Assert.Contains(server.Commands, c => c.EndsWith("STARTTLS"));
        Assert.Contains(server.EncryptedCommands, c => c.Contains("LOGIN"));
    }

    [Fact]
    public async Task ImapStartTlsNonOffertoNessunLoginInChiaro()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Imap, implicitTls: false, offerStartTls: false);
        await using var session = new ImapMailService(Imap(server, ConnectionSecurity.StartTls));

        var ex = await Record.ExceptionAsync(() => session.ConnectAsync());

        Assert.IsType<NotSupportedException>(ex);
        Assert.False(PasswordSent(server));
        Assert.Contains("non offre STARTTLS", AccountTester.Describe(ex, "127.0.0.1", server.Port));
    }

    [Fact]
    public async Task ImapNessunaCrittografiaSceltaEsplicita()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Imap, implicitTls: false, offerStartTls: true);
        await using var session = new ImapMailService(Imap(server, ConnectionSecurity.None));

        await session.ConnectAsync();

        Assert.DoesNotContain(server.Commands, c => c.EndsWith("STARTTLS"));
        Assert.Contains(server.Commands, c => c.Contains("LOGIN")); // in chiaro: è la scelta "Nessuna"
    }

    [Fact]
    public async Task SmtpSenzaAutenticazioneNessunAuthNeServeLaPassword()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Smtp, implicitTls: false, offerStartTls: true);
        var settings = Smtp(server, ConnectionSecurity.StartTls, auth: false, pin: TrustedCertificate.Fingerprint(server.Certificate));
        settings.Password = "";

        await new SmtpMailService(settings).TestAsync();

        Assert.Contains(server.Commands, c => c == "STARTTLS");
        Assert.DoesNotContain(server.Commands, c => c.StartsWith("AUTH"));
    }

    [Fact]
    public void SmtpConAutenticazioneLaPasswordServe()
    {
        var settings = new SmtpSettings { Host = "h", Username = "me@example.com", Password = "" };
        Assert.Throws<ArgumentException>(() => new SmtpMailService(settings));
    }

    [Fact]
    public async Task Smtp465TlsDallInizioEAutenticazioneCifrata()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Smtp, implicitTls: true, offerStartTls: false);
        var settings = Smtp(server, ConnectionSecurity.SslOnConnect, pin: TrustedCertificate.Fingerprint(server.Certificate));

        await new SmtpMailService(settings).TestAsync();

        Assert.Contains(server.EncryptedCommands, c => c.StartsWith("AUTH"));
    }

    [Fact]
    public async Task ProvaAccountRestituisceIlCertificatoDaConfermare()
    {
        await using var imap = new FakeMailServer(FakeMailServer.Protocol.Imap, implicitTls: false, offerStartTls: true);
        await using var smtp = new FakeMailServer(FakeMailServer.Protocol.Smtp, implicitTls: true, offerStartTls: false);

        var imapCheck = await AccountTester.TestImapAsync(Imap(imap, ConnectionSecurity.StartTls));
        var smtpCheck = await AccountTester.TestSmtpAsync(Smtp(smtp, ConnectionSecurity.SslOnConnect));

        Assert.False(imapCheck.Ok);
        Assert.Equal(TrustedCertificate.Fingerprint(imap.Certificate), imapCheck.Certificate?.Sha256);
        Assert.Contains("certificato", imapCheck.Error);
        // L6: codice e valori per l'app, con i problemi del certificato come codici.
        Assert.Equal("testCertificateInvalid", imapCheck.ErrorCode);
        Assert.Equal($"127.0.0.1:{imap.Port}", imapCheck.ErrorArgs?["address"]);
        Assert.Equal(imapCheck.Certificate!.Problems.Count, imapCheck.Certificate.ProblemCodes.Count);
        Assert.Contains("untrustedRoot", imapCheck.ErrorArgs?["problems"]);
        Assert.False(smtpCheck.Ok);
        Assert.Equal(TrustedCertificate.Fingerprint(smtp.Certificate), smtpCheck.Certificate?.Sha256);
        Assert.False(PasswordSent(imap) || PasswordSent(smtp));

        // Dopo "Fidarsi": stessa prova con le impronte salvate.
        var imapOk = await AccountTester.TestImapAsync(Imap(imap, ConnectionSecurity.StartTls, imapCheck.Certificate!.Sha256));
        var smtpOk = await AccountTester.TestSmtpAsync(Smtp(smtp, ConnectionSecurity.SslOnConnect, pin: smtpCheck.Certificate!.Sha256));
        Assert.True(imapOk.Ok, imapOk.Error);
        Assert.True(smtpOk.Ok, smtpOk.Error);
    }
}
