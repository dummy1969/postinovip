using MimeKit;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

public class DraftBuilderTests
{
    private const string Me = "me@example.com";

    private static MimeMessage Original(string subject = "Riunione")
    {
        var m = new MimeMessage
        {
            Subject = subject,
            MessageId = "orig-123@example.com",
            Date = new DateTimeOffset(2026, 10, 24, 9, 25, 0, TimeSpan.Zero),
        };
        m.References.Add("root-1@example.com");
        m.From.Add(new MailboxAddress("Mario Rossi", "mario@example.com"));
        m.To.Add(new MailboxAddress("Io", Me));
        m.To.Add(new MailboxAddress("Anna", "anna@example.com"));
        m.Cc.Add(new MailboxAddress("", "bruno@example.com"));
        m.Cc.Add(new MailboxAddress("", "ANNA@example.com")); // doppione con maiuscole diverse
        m.Body = new TextPart("plain") { Text = "Ciao,\n\nci vediamo alle 10." };
        return m;
    }

    [Fact]
    public void RispondiAlMittenteConCitazioneEThread()
    {
        var d = DraftBuilder.Build(Original(), DraftMode.Reply, Me);

        Assert.Equal(["\"Mario Rossi\" <mario@example.com>"], d.To);
        Assert.Empty(d.Cc);
        Assert.Equal("R: Riunione", d.Subject); // come Outlook in italiano (L6b, scelta 3a)
        Assert.Equal("orig-123@example.com", d.InReplyTo);
        Assert.Equal(["root-1@example.com", "orig-123@example.com"], d.References);
        Assert.StartsWith("\n\nIl ", d.Body);
        Assert.Contains("Mario Rossi", d.Body);
        Assert.Contains("ha scritto:\n> Ciao,\n>\n> ci vediamo alle 10.", d.Body);
    }

    [Fact]
    public void RispondiATuttiEscludeMeEDoppioni()
    {
        var d = DraftBuilder.Build(Original(), DraftMode.ReplyAll, Me);

        Assert.Equal(["mario@example.com", "anna@example.com"], d.To.Select(a => MailboxAddress.Parse(a).Address));
        Assert.Equal(["bruno@example.com"], d.Cc.Select(a => MailboxAddress.Parse(a).Address));
    }

    [Fact]
    public void ReplyToHaPrecedenzaSuFrom()
    {
        var m = Original();
        m.ReplyTo.Add(new MailboxAddress("Lista", "lista@example.com"));

        Assert.Equal(["\"Lista\" <lista@example.com>"], DraftBuilder.Build(m, DraftMode.Reply, Me).To);
    }

    [Fact]
    public void RispostaAMessaggioMioVaAiDestinatariOriginali()
    {
        var m = new MimeMessage { Subject = "x", Body = new TextPart("plain") { Text = "t" } };
        m.From.Add(new MailboxAddress("Io", Me));
        m.To.Add(new MailboxAddress("", "cliente@example.com"));

        Assert.Equal(["cliente@example.com"], DraftBuilder.Build(m, DraftMode.Reply, Me).To);
    }

    [Theory]
    [InlineData("Re: Riunione", DraftMode.Reply, "Re: Riunione")]
    [InlineData("R: Riunione", DraftMode.Reply, "R: Riunione")]       // Outlook in italiano
    [InlineData("RE:Riunione", DraftMode.ReplyAll, "RE:Riunione")]
    [InlineData("Riunione", DraftMode.Forward, "I: Riunione")]
    [InlineData("Fwd: Riunione", DraftMode.Forward, "Fwd: Riunione")]
    [InlineData("FW: Riunione", DraftMode.Forward, "FW: Riunione")]
    [InlineData("I: Riunione", DraftMode.Forward, "I: Riunione")]
    [InlineData("Fw: Riunione", DraftMode.Forward, "Fw: Riunione")]
    public void PrefissiNonRaddoppiati(string subject, DraftMode mode, string expected)
    {
        Assert.Equal(expected, DraftBuilder.Build(Original(subject), mode, Me).Subject);
    }

    [Fact]
    public void RispostaEInoltroInIngleseConLaLinguaDellApp()
    {
        // Tappa «Lingua», L6b (scelta 3a): prefissi, intestazioni e data nella lingua dell'app, come Outlook in inglese.
        using var english = PostinoVip.Core.Texts.CoreTexts.Use("en");
        var reply = DraftBuilder.Build(Original(), DraftMode.Reply, Me);
        var forward = DraftBuilder.Build(Original(), DraftMode.Forward, Me);

        Assert.Equal("RE: Riunione", reply.Subject);
        Assert.Contains(" wrote:\n> Ciao,", reply.Body);
        Assert.StartsWith("\n\nOn ", reply.Body);
        Assert.Contains("<b>From:</b>", reply.QuoteHtml);
        Assert.Contains("<b>Subject:</b>", reply.QuoteHtml);
        Assert.Equal("FW: Riunione", forward.Subject);
        Assert.Contains("---------- Forwarded message ----------", forward.Body);
        Assert.Contains("Subject: Riunione", forward.Body);
        Assert.Matches(@"Date: \d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2} (AM|PM)", forward.Body);
        Assert.Equal("RE: Riunione", DraftBuilder.Build(Original(), DraftMode.ReplyAll, Me).Subject);
    }

    [Fact]
    public void InoltroSenzaDestinatariConIntestazioniOriginali()
    {
        var d = DraftBuilder.Build(Original(), DraftMode.Forward, Me);

        Assert.Empty(d.To);
        Assert.Empty(d.Cc);
        Assert.Null(d.InReplyTo);
        Assert.Empty(d.References);
        Assert.Contains("---------- Messaggio inoltrato ----------", d.Body);
        Assert.Contains("Oggetto: Riunione", d.Body);
        Assert.Contains("ci vediamo alle 10.", d.Body);
        Assert.DoesNotContain("> ", d.Body); // nessuna citazione con ">"
        Assert.Empty(d.ForwardAttachments!); // l'originale di prova non ha allegati
    }

    [Fact]
    public void InoltroElencaGliAllegatiDellOriginale()
    {
        var m = Original();
        var builder = new BodyBuilder { TextBody = "vedi" };
        builder.Attachments.Add("report.pdf", new byte[] { 1 }, new ContentType("application", "pdf"));
        m.Body = builder.ToMessageBody();

        var d = DraftBuilder.Build(m, DraftMode.Forward, Me);

        Assert.Equal([new AttachmentInfo(0, "report.pdf", "application/pdf")], d.ForwardAttachments);
        Assert.Null(DraftBuilder.Build(m, DraftMode.Reply, Me).ForwardAttachments); // in risposta no
    }

    [Fact]
    public void OriginaleSoloHtmlCitatoComeTesto()
    {
        var m = Original();
        m.Body = new TextPart("html") { Text = "<p>Prima riga</p><p>Seconda <b>riga</b></p><script>x()</script>" };

        var d = DraftBuilder.Build(m, DraftMode.Reply, Me);

        Assert.Contains("> Prima riga\n>\n> Seconda riga", d.Body);
        Assert.DoesNotContain("x()", d.Body);
    }

    private static MimeMessage HtmlOriginal()
    {
        var m = Original();
        var builder = new BodyBuilder { TextBody = "Testo", HtmlBody = "<p>Ciao <b>Mario</b></p><img src=\"cid:logo@x\"><script>x()</script>" };
        var logo = builder.LinkedResources.Add("logo.png", Convert.FromBase64String(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="),
            ContentType.Parse("image/png"));
        logo.ContentId = "logo@x";
        m.Body = builder.ToMessageBody();
        return m;
    }

    [Fact]
    public void AnteprimaDellaCitazioneFormattataComeOutlook()
    {
        var d = DraftBuilder.Build(HtmlOriginal(), DraftMode.Reply, Me);

        Assert.NotNull(d.QuoteHtml);
        Assert.Contains("<b>Da:</b>", d.QuoteHtml);
        Assert.Contains("<b>Oggetto:</b> Riunione", d.QuoteHtml);
        Assert.Contains("<b>Mario</b>", d.QuoteHtml);
        Assert.Contains("data:image/png;base64,", d.QuoteHtml); // immagine incorporata visibile nell'app
        Assert.DoesNotContain("script", d.QuoteHtml);
    }

    [Fact]
    public void CitazionePerLInvioTieneCidEImmagini()
    {
        var q = QuoteBuilder.ForSending(HtmlOriginal(), DraftMode.Forward);

        Assert.Contains("cid:logo@x", q.Html);
        Assert.DoesNotContain("script", q.Html);
        var image = Assert.Single(q.Inline);
        Assert.Equal("logo@x", image.ContentId);
        Assert.Contains("Messaggio inoltrato", q.Text);
    }

    [Fact]
    public void CitazioneDiUnaMailSoloTestoConGliACapo()
    {
        var q = QuoteBuilder.ForSending(Original(), DraftMode.Reply);

        Assert.Contains("Ciao,<br><br>ci vediamo alle 10.", q.Html);
        Assert.StartsWith("\n\nIl ", q.Text);
        Assert.Empty(q.Inline);
    }

    [Fact]
    public void RispostaInTestoNormaleSeLOriginaleNonHaHtml()
    {
        Assert.True(DraftBuilder.Build(Original(), DraftMode.Reply, Me).PlainText);
        Assert.True(DraftBuilder.Build(Original(), DraftMode.Forward, Me).PlainText);
        Assert.False(DraftBuilder.Build(HtmlOriginal(), DraftMode.Reply, Me).PlainText);
        var htmlOnly = Original();
        htmlOnly.Body = new TextPart("html") { Text = "<p>x</p>" };
        Assert.False(DraftBuilder.Build(htmlOnly, DraftMode.ReplyAll, Me).PlainText);
    }
}
