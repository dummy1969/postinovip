using MailKit;
using MimeKit;
using PostinoVip.Core.Imap;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

public class MessageHeaderMapperTests
{
    [Fact]
    public void UsaNomeVisualizzatoDelMittente()
    {
        var env = new Envelope { Subject = "Ciao", Date = new DateTimeOffset(2026, 10, 29, 10, 0, 0, TimeSpan.Zero) };
        env.From.Add(new MailboxAddress("Mario Rossi", "mario@example.com"));

        var h = MessageHeaderMapper.FromEnvelope(new UniqueId(42), env);

        Assert.Equal(42u, h.Uid);
        Assert.Equal("Ciao", h.Subject);
        Assert.Equal("Mario Rossi", h.From);
        Assert.Equal(env.Date, h.Date);
        Assert.False(h.Seen);
    }

    [Fact]
    public void SenzaNomeUsaIndirizzo()
    {
        var env = new Envelope { Subject = "x" };
        env.From.Add(new MailboxAddress("", "anonimo@example.com"));

        Assert.Equal("anonimo@example.com", MessageHeaderMapper.FromEnvelope(new UniqueId(1), env).From);
    }

    [Fact]
    public void EnvelopeMancanteDaValoriSegnaposto()
    {
        var h = MessageHeaderMapper.FromEnvelope(new UniqueId(7), null);

        Assert.Equal("(nessun oggetto)", h.Subject);
        Assert.Equal("(mittente sconosciuto)", h.From);
        Assert.Null(h.Date);
    }

    [Fact]
    public void FlagSeenRiportato()
    {
        var h = MessageHeaderMapper.FromEnvelope(new UniqueId(1), new Envelope(), MessageFlags.Seen | MessageFlags.Flagged);

        Assert.True(h.Seen);
    }

    [Fact]
    public void MimeMessageConTestoHtmlEAllegato()
    {
        var message = new MimeMessage();
        message.From.Add(new MailboxAddress("Mario", "mario@example.com"));
        message.To.Add(new MailboxAddress("Anna", "anna@example.com"));
        message.Subject = "Report";
        var body = new BodyBuilder { TextBody = "testo", HtmlBody = "<p>html</p>" };
        body.Attachments.Add("report.pdf", new byte[] { 1, 2, 3 }, new ContentType("application", "pdf"));
        message.Body = body.ToMessageBody();

        var d = MessageHeaderMapper.FromMimeMessage(new UniqueId(9), message);

        Assert.Equal(9u, d.Uid);
        Assert.Equal("Mario", d.From);
        Assert.Equal(["\"Anna\" <anna@example.com>"], d.To);
        Assert.Empty(d.Cc);
        Assert.Equal("testo", d.TextBody);
        Assert.Equal("<p>html</p>", d.HtmlBody);
        Assert.Equal([new AttachmentInfo(0, "report.pdf", "application/pdf")], d.Attachments);
    }
}
