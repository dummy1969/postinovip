using MimeKit;
using PostinoVip.Core.Models;
using PostinoVip.Core.Security;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Tests;

// Ccn: i destinatari nascosti ricevono la mail (RCPT TO) ma l'intestazione Bcc non parte con il messaggio;
// resta invece nel MimeMessage (bozza e copia in Posta inviata), come in Outlook.
public class SmtpBccTests
{
    private static OutgoingMessage Msg(string[] to, string[] cc, string[] bcc) =>
        new("me@example.com", to, cc, "Prova", "Testo", Bcc: bcc);

    [Fact]
    public async Task CcnRicevutiMaNascostiNellaMailInviata()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Smtp, implicitTls: false, offerStartTls: true);
        var settings = new SmtpSettings
        {
            Host = "127.0.0.1", Port = server.Port, Username = "me@example.com", Password = "x",
            Security = ConnectionSecurity.StartTls, CertificateSha256 = TrustedCertificate.Fingerprint(server.Certificate),
        };
        var message = MimeMessageBuilder.Build(Msg(["anna@example.com"], [], ["nascosto@example.com", "Bob <bob@example.com>"]));
        Assert.Equal(2, message.Bcc.Count); // nel messaggio (bozza, Posta inviata) l'intestazione c'è

        await new SmtpMailService(settings).SendMimeAsync(message);

        Assert.Contains(server.Commands, c => c.Contains("RCPT TO:<anna@example.com>"));
        Assert.Contains(server.Commands, c => c.Contains("RCPT TO:<nascosto@example.com>"));
        Assert.Contains(server.Commands, c => c.Contains("RCPT TO:<bob@example.com>"));
        var sent = Assert.Single(server.SmtpMessages);
        Assert.Contains("To: anna@example.com", sent);
        Assert.DoesNotContain("Bcc:", sent, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("nascosto@example.com", sent);
        Assert.Equal(2, message.Bcc.Count); // l'invio non tocca il messaggio
    }

    /// <summary>
    /// EHLO senza il nome del PC (scelta 3a del 09/11/2026): MailKit usava il nome del computer, che il server scrive
    /// nella riga Received: di ogni mail inviata (visto nelle intestazioni in Outlook). Ora un indirizzo letterale.
    /// </summary>
    [Fact]
    public async Task EhloSenzaIlNomeDelPc()
    {
        await using var server = new FakeMailServer(FakeMailServer.Protocol.Smtp, implicitTls: false, offerStartTls: true);
        var settings = new SmtpSettings
        {
            Host = "127.0.0.1", Port = server.Port, Username = "me@example.com", Password = "x",
            Security = ConnectionSecurity.StartTls, CertificateSha256 = TrustedCertificate.Fingerprint(server.Certificate),
        };

        await new SmtpMailService(settings).SendMimeAsync(MimeMessageBuilder.Build(Msg(["anna@example.com"], [], [])));

        var ehlo = server.Commands.Where(c => c.StartsWith("EHLO", StringComparison.OrdinalIgnoreCase)).ToList();
        Assert.NotEmpty(ehlo); // prima e dopo STARTTLS
        Assert.All(ehlo, c => Assert.Equal($"EHLO {SmtpMailService.HeloName}", c));
        Assert.DoesNotContain(server.Commands, c => c.Contains(System.Net.Dns.GetHostName(), StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void BastaUnDestinatarioInCcnOCcIndirizziControllati()
    {
        Assert.Single(MimeMessageBuilder.Build(Msg([], [], ["solo@example.com"])).Bcc);
        Assert.Single(MimeMessageBuilder.Build(Msg([], ["cc@example.com"], [])).Cc);
        Assert.Equal("to", Assert.Throws<InvalidAddressException>(() => MimeMessageBuilder.Build(Msg([], [], []))).Field);
        Assert.Equal("bcc", Assert.Throws<InvalidAddressException>(() => MimeMessageBuilder.Build(Msg(["a@example.com"], [], ["rotto"]))).Field);
        // Bozza: Ccn scritto male resta com'è, da correggere prima dell'invio.
        Assert.Equal("rotto", MimeMessageBuilder.Build(Msg([], [], ["rotto"]), draft: true).Bcc.Mailboxes.Single().Address);
    }
}
