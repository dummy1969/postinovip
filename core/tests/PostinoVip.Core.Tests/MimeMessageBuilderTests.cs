using MimeKit;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Models;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Tests;

public class MimeMessageBuilderTests
{
    private static OutgoingMessage Msg(string[] to, string[]? cc = null) =>
        new("mittente@example.com", to, cc ?? [], "Prova", "Ciao, è un test.");

    [Fact]
    public void CostruisceMessaggioTestoSemplice()
    {
        var mime = MimeMessageBuilder.Build(Msg(["dest@example.com"]));

        Assert.Equal("mittente@example.com", mime.From.Mailboxes.Single().Address);
        Assert.Equal("dest@example.com", mime.To.Mailboxes.Single().Address);
        Assert.Empty(mime.Cc);
        Assert.Equal("Prova", mime.Subject);
        var part = Assert.IsType<TextPart>(mime.Body);
        Assert.True(part.IsPlain);
        Assert.Equal("Ciao, è un test.", part.Text);
    }

    [Fact]
    public void PiuDestinatariECc()
    {
        var mime = MimeMessageBuilder.Build(Msg(["a@example.com", "Bruno <b@example.com>"], ["c@example.com"]));

        Assert.Equal(["a@example.com", "b@example.com"], mime.To.Mailboxes.Select(m => m.Address));
        Assert.Equal("Bruno", mime.To.Mailboxes.Last().Name);
        Assert.Equal("c@example.com", mime.Cc.Mailboxes.Single().Address);
    }

    [Fact]
    public void NessunDestinatario()
    {
        var ex = Assert.Throws<InvalidAddressException>(() => MimeMessageBuilder.Build(Msg([])));

        Assert.Equal("to", ex.Field);
    }

    [Theory]
    [InlineData("non un <indirizzo")]
    [InlineData("mario")]
    [InlineData("")]
    public void IndirizzoNonValidoInTo(string to)
    {
        var ex = Assert.Throws<InvalidAddressException>(() => MimeMessageBuilder.Build(Msg(["ok@example.com", to])));

        Assert.Equal("to", ex.Field);
        Assert.IsAssignableFrom<FormatException>(ex);
    }

    [Fact]
    public void IndirizzoNonValidoInCcSegnalaIlCampoCc()
    {
        var ex = Assert.Throws<InvalidAddressException>(() => MimeMessageBuilder.Build(Msg(["ok@example.com"], ["mario"])));

        Assert.Equal("cc", ex.Field);
        Assert.Contains("mario", ex.Message);
    }

    [Fact]
    public void RispostaImpostaInReplyToEReferences()
    {
        var msg = new OutgoingMessage("mittente@example.com", ["dest@example.com"], [], "Re: x", "y",
            InReplyTo: "orig@example.com", References: ["root@example.com", "orig@example.com"]);

        var mime = MimeMessageBuilder.Build(msg);

        Assert.Equal("orig@example.com", mime.InReplyTo);
        Assert.Equal(["root@example.com", "orig@example.com"], mime.References);
    }

    [Fact]
    public void MessageIdConDominioDelMittenteNonDelPc()
    {
        var mime = MimeMessageBuilder.Build(Msg(["dest@example.com"]));

        Assert.EndsWith("@example.com", mime.MessageId);
        Assert.DoesNotContain(System.Net.Dns.GetHostName().ToLowerInvariant(), mime.MessageId!.ToLowerInvariant());
        Assert.NotEqual(mime.MessageId, MimeMessageBuilder.Build(Msg(["dest@example.com"])).MessageId); // univoco
    }

    private static OutgoingMessage WithAttachments(params OutgoingAttachment[] attachments) =>
        new("mittente@example.com", ["dest@example.com"], [], "Con allegati", "Vedi allegati.", Attachments: attachments);

    [Fact]
    public void AllegatiInMultipartConTipoENome()
    {
        var mime = MimeMessageBuilder.Build(WithAttachments(
            new("foto.jpg", null, [0xFF, 0xD8]),                    // tipo dall'estensione
            new("../../dati.csv", "text/csv", "a;b"u8.ToArray()),   // percorso tolto
            new("x.bin", "non un tipo", [1])));                     // tipo non valido -> estensione

        Assert.Equal("Vedi allegati.", mime.TextBody);
        var parts = mime.Attachments.OfType<MimePart>().ToList();
        Assert.Equal(["foto.jpg", "dati.csv", "x.bin"], parts.Select(p => p.FileName));
        Assert.Equal(["image/jpeg", "text/csv", "application/octet-stream"], parts.Select(p => p.ContentType.MimeType));

        using var ms = new MemoryStream();
        parts[0].Content!.DecodeTo(ms);
        Assert.Equal(new byte[] { 0xFF, 0xD8 }, ms.ToArray());
    }

    [Fact]
    public void AllegatiOltre25MbRifiutatiSulCampoAttachments()
    {
        var big = new byte[MimeMessageBuilder.MaxAttachmentBytes / 2 + 1];
        var ex = Assert.Throws<FieldValidationException>(() =>
            MimeMessageBuilder.Build(WithAttachments(new("a.bin", null, big), new("b.bin", null, big))));

        Assert.Equal("attachments", ex.Field);
        Assert.Contains("25 MB", ex.Message);
    }

    [Fact]
    public void Esattamente25MbAccettati()
    {
        var mime = MimeMessageBuilder.Build(WithAttachments(new OutgoingAttachment("a.bin", null, new byte[MimeMessageBuilder.MaxAttachmentBytes])));

        Assert.Single(mime.Attachments);
    }

    // 1x1 PNG trasparente.
    private const string Png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";

    [Fact]
    public void TestoFormattatoInMultipartAlternativeERipulito()
    {
        var mime = MimeMessageBuilder.Build(Msg(["dest@example.com"]) with
        {
            Body = "Ciao *grassetto*",
            HtmlBody = "<p>Ciao <strong>grassetto</strong></p><script>x()</script><p onclick=\"y()\">z</p>",
        });

        var alternative = Assert.IsType<MultipartAlternative>(mime.Body);
        Assert.Equal(2, alternative.Count);
        Assert.Equal("Ciao *grassetto*", mime.TextBody);
        Assert.Contains("<strong>grassetto</strong>", mime.HtmlBody);
        Assert.DoesNotContain("script", mime.HtmlBody);
        Assert.DoesNotContain("onclick", mime.HtmlBody);
    }

    [Fact]
    public void ImmagineIncollataDiventaParteIncorporata()
    {
        var mime = MimeMessageBuilder.Build(Msg(["dest@example.com"]) with
        {
            HtmlBody = $"<p>foto:</p><img src=\"data:image/png;base64,{Png}\">",
        });

        Assert.DoesNotContain("data:image", mime.HtmlBody);
        var image = Assert.Single(mime.BodyParts.OfType<MimePart>(), p => p.ContentType.MimeType == "image/png");
        Assert.False(string.IsNullOrEmpty(image.ContentId));
        Assert.Contains($"cid:{image.ContentId}", mime.HtmlBody);
        Assert.EndsWith("@example.com", image.ContentId); // dominio del mittente, non il nome del PC
        var mixed = Assert.IsAssignableFrom<Multipart>(mime.Body); // con le immagini incorporate: più parti
        Assert.Contains(mixed, p => p is MultipartRelated);
    }

    [Fact]
    public void CitazioneInFondoATestoEHtmlConLeSueImmagini()
    {
        var quote = new MessageQuote("\n\n> originale", "<div>originale <img src=\"cid:img1@x\"></div>",
            [new InlinePart("img1@x", "image/png", Convert.FromBase64String(Png))]);
        var mime = MimeMessageBuilder.Build(Msg(["dest@example.com"]) with
        {
            Body = "Risposta",
            HtmlBody = "<p>Risposta</p>",
            Quote = quote,
        });

        Assert.Equal("Risposta\n\n> originale", mime.TextBody);
        Assert.True(mime.HtmlBody!.IndexOf("Risposta", StringComparison.Ordinal) < mime.HtmlBody.IndexOf("originale", StringComparison.Ordinal));
        Assert.Contains(mime.BodyParts.OfType<MimePart>(), p => p.ContentId == "img1@x");
    }

    [Fact]
    public void TestoNormaleConAllegatoECitazioneConImmaginiSenzaParteHtml()
    {
        // Testo normale (13/11/2026): niente HtmlBody; le immagini della citazione restano fuori.
        var quote = new MessageQuote("\n\n> originale", "<div>originale <img src=\"cid:img1@x\"></div>",
            [new InlinePart("img1@x", "image/png", Convert.FromBase64String(Png))]);
        var mime = MimeMessageBuilder.Build(Msg(["dest@example.com"]) with
        {
            Body = "Risposta",
            Quote = quote,
            Attachments = [new OutgoingAttachment("a.txt", "text/plain", "x"u8.ToArray())],
        });

        Assert.Null(mime.HtmlBody);
        Assert.Equal("Risposta\n\n> originale", mime.TextBody);
        Assert.DoesNotContain(mime.BodyParts.OfType<MimePart>(), p => p.ContentId == "img1@x");
        Assert.DoesNotContain(mime.BodyParts, p => p.ContentType.MimeType == "text/html");
        Assert.Single(mime.Attachments);

        var alone = MimeMessageBuilder.Build(Msg(["dest@example.com"]) with { Body = "Solo", Quote = quote });
        Assert.Equal("text/plain", alone.Body.ContentType.MimeType); // senza allegati: una sola parte

        // Le immagini della citazione, che in testo normale non partono, non contano nel limite di 25 MB.
        var big = new InlinePart("big@x", "image/png", new byte[MimeMessageBuilder.MaxAttachmentBytes + 1]);
        var withBig = MimeMessageBuilder.Build(Msg(["dest@example.com"]) with
        {
            Body = "Risposta",
            Quote = new MessageQuote("\n\n> originale", "<img src=\"cid:big@x\">", [big]),
            Attachments = [new OutgoingAttachment("a.txt", "text/plain", "x"u8.ToArray())],
        });
        Assert.Null(withBig.HtmlBody);
    }

    [Fact]
    public void ImmaginiIncorporateContanoNelLimiteDegliAllegati()
    {
        var big = new InlinePart("big@x", "image/png", new byte[MimeMessageBuilder.MaxAttachmentBytes + 1]);
        var ex = Assert.Throws<FieldValidationException>(() => MimeMessageBuilder.Build(Msg(["dest@example.com"]) with
        {
            HtmlBody = "<p>x</p>",
            Quote = new MessageQuote("", "<img src=\"cid:big@x\">", [big]),
        }));
        Assert.Equal("attachments", ex.Field);
    }
}
