using MimeKit;
using PostinoVip.Core.Mime;
using PostinoVip.Core.Models;

namespace PostinoVip.Core.Tests;

public class AttachmentsTests
{
    private static MimeMessage MessageWithAttachments()
    {
        var builder = new BodyBuilder { TextBody = "vedi allegati" };
        builder.Attachments.Add("foto.jpg", new byte[] { 0xFF, 0xD8, 0xFF, 0xE0 }, new ContentType("image", "jpeg"));
        builder.Attachments.Add("note.txt", "ciao"u8.ToArray(), new ContentType("text", "plain"));
        return new MimeMessage { Body = builder.ToMessageBody() };
    }

    [Fact]
    public void ElencaConIndiceNomeETipo()
    {
        var list = Attachments.List(MessageWithAttachments());

        Assert.Equal(
            [new AttachmentInfo(0, "foto.jpg", "image/jpeg"), new AttachmentInfo(1, "note.txt", "text/plain")],
            list);
    }

    [Fact]
    public void EstraeByteDecodificati()
    {
        // BodyBuilder codifica in base64: Extract deve restituire i byte originali.
        var content = Attachments.Extract(MessageWithAttachments(), 0);

        Assert.NotNull(content);
        Assert.Equal("foto.jpg", content.FileName);
        Assert.Equal("image/jpeg", content.ContentType);
        Assert.Equal(new byte[] { 0xFF, 0xD8, 0xFF, 0xE0 }, content.Data);
    }

    [Fact]
    public void IndiceInesistenteRestituisceNull()
    {
        Assert.Null(Attachments.Extract(MessageWithAttachments(), 2));
    }

    [Theory]
    [InlineData("alm_snp0.jpg", "image/jpeg")]   // caso reale: telecamera IP
    [InlineData("FOTO.PNG", "image/png")]
    [InlineData("dati.bin", "application/octet-stream")]
    [InlineData("senza-estensione", "application/octet-stream")]
    public void TipoGenericoRicavatoDallEstensione(string fileName, string expected)
    {
        var builder = new BodyBuilder { TextBody = "x" };
        builder.Attachments.Add(fileName, new byte[] { 1 }, new ContentType("application", "octet-stream"));
        var message = new MimeMessage { Body = builder.ToMessageBody() };

        Assert.Equal(expected, Attachments.List(message).Single().ContentType);
        Assert.Equal(expected, Attachments.Extract(message, 0)!.ContentType);
    }

    [Fact]
    public void TipoDichiaratoSpecificoNonVieneCambiato()
    {
        // Nome .jpg ma tipo dichiarato PDF: si rispetta il tipo dichiarato.
        var builder = new BodyBuilder { TextBody = "x" };
        builder.Attachments.Add("strano.jpg", new byte[] { 1 }, new ContentType("application", "pdf"));
        var message = new MimeMessage { Body = builder.ToMessageBody() };

        Assert.Equal("application/pdf", Attachments.List(message).Single().ContentType);
    }
}
