using System.Text;
using MimeKit;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Mime;
using PostinoVip.Core.Models;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Tests;

/// <summary>R1: richiesta (Disposition-Notification-To), regole di RFC 8098, conferma costruita, $MDNSent.</summary>
public sealed class ReadReceiptsTests
{
    private static MimeMessage Mail(string extra, string from = "Anna <anna@example.com>") =>
        MimeMessage.Load(new MemoryStream(Encoding.UTF8.GetBytes(
            $"From: {from}\r\nTo: io@example.com, luca@example.com\r\nSubject: Riunione\r\nDate: Mon, 9 Nov 2026 10:05:00 +0100\r\n" +
            $"Message-ID: <riunione@example.com>\r\n{extra}\r\nCiao\r\n")));

    [Theory]
    [InlineData("", null)]
    [InlineData("Disposition-Notification-To: anna@example.com\r\n", "anna@example.com")]
    [InlineData("Disposition-Notification-To: Anna B <ANNA@example.com>\r\n", "ANNA@example.com")] // maiuscole non contano
    [InlineData("Disposition-Notification-To: altro@example.com\r\n", null)] // diverso dal mittente
    [InlineData("Disposition-Notification-To: anna@example.com, altro@example.com\r\n", null)] // più indirizzi
    [InlineData("Disposition-Notification-To: non un indirizzo\r\n", null)]
    public void ChiedeLaConfermaSoloAlMittente(string header, string? expected) =>
        Assert.Equal(expected, ReadReceipts.RequestedBy(Mail(header))?.Address);

    [Fact]
    public void ConfermaComeRfc8098EMaiUnaConfermaDiUnaConferma()
    {
        var original = Mail("Disposition-Notification-To: anna@example.com\r\nOriginal-Recipient: rfc822;io@example.com\r\n");
        var receipt = ReadReceipts.Build(original, new MailboxAddress("", "io@example.com"), automatic: false, "0.0.1",
            new DateTimeOffset(2026, 11, 9, 11, 0, 0, TimeSpan.FromHours(1)));

        Assert.Equal("anna@example.com", receipt.To.Mailboxes.Single().Address);
        Assert.Equal("Letto: Riunione", receipt.Subject);
        Assert.Equal("riunione@example.com", receipt.InReplyTo);
        Assert.EndsWith("@example.com", receipt.MessageId); // dominio del mittente, non il nome del PC
        Assert.False(receipt.Headers.Contains(HeaderId.DispositionNotificationTo));

        // Riletta dopo l'invio: tipo, parte leggibile e campi della notifica.
        using var stream = new MemoryStream();
        receipt.WriteTo(stream);
        stream.Position = 0;
        var parsed = MimeMessage.Load(stream);
        var report = Assert.IsType<MultipartReport>(parsed.Body);
        Assert.Equal("disposition-notification", report.ReportType);
        Assert.Contains("è stato letto il", report.OfType<TextPart>().Single().Text);
        Assert.Contains("Oggetto: Riunione", report.OfType<TextPart>().Single().Text);
        var fields = report.OfType<MessageDispositionNotification>().Single().Fields;
        Assert.Equal("PostinoVip; PostinoVip 0.0.1", fields["Reporting-UA"]);
        Assert.Equal("rfc822;io@example.com", fields["Original-Recipient"]);
        Assert.Equal("rfc822;io@example.com", fields["Final-Recipient"]);
        Assert.Equal("<riunione@example.com>", fields["Original-Message-ID"]);
        Assert.Equal("manual-action/MDN-sent-manually; displayed", fields["Disposition"]);

        // Una conferma che chiedesse a sua volta la conferma: niente.
        parsed.Headers[HeaderId.DispositionNotificationTo] = "io@example.com";
        Assert.Null(ReadReceipts.RequestedBy(parsed));
        Assert.Throws<InvalidOperationException>(() =>
            ReadReceipts.Build(Mail(""), new MailboxAddress("", "io@example.com"), false, "0.0.1", DateTimeOffset.Now));
    }

    [Fact]
    public void RichiestaAllInvioRilettaNellaBozzaENelDettaglio()
    {
        var sent = MimeMessageBuilder.Build(new OutgoingMessage("io@example.com", ["anna@example.com"], [], "S", "testo", ReadReceipt: true));
        Assert.Equal("io@example.com", sent.Headers[HeaderId.DispositionNotificationTo]);
        Assert.True(ComposeReader.Read(sent).ReadReceipt);
        Assert.Equal("io@example.com", MessageHeaderMapper.FromMimeMessage(new MailKit.UniqueId(1), sent).ReceiptTo);

        var plain = MimeMessageBuilder.Build(new OutgoingMessage("io@example.com", ["anna@example.com"], [], "S", "testo"));
        Assert.False(plain.Headers.Contains(HeaderId.DispositionNotificationTo));
        Assert.False(ComposeReader.Read(plain).ReadReceipt);
        Assert.Null(MessageHeaderMapper.FromMimeMessage(new MailKit.UniqueId(1), plain).ReceiptTo);
    }

    [Fact]
    public void ParolaChiaveMdnSent()
    {
        Assert.Equal(["$MDNSent"], MailKeywords.ToKeywords(MailFlags.MdnSent));
        Assert.Equal(MailFlags.MdnSent | MailFlags.Completed, MailKeywords.FromKeywords(["$mdnsent", "$Completed"]));
        // Quella del server dopo l'arrivo della conferma nella stessa casella: letta, mai scritta.
        Assert.Equal(MailFlags.MdnReceived, MailKeywords.FromKeywords(["$MDNReceived"]));
        Assert.Empty(MailKeywords.ToKeywords(MailFlags.MdnReceived));
        Assert.True((MailFlags.MdnReceived & MailFlags.ReceiptHandled) != 0);
    }
}
