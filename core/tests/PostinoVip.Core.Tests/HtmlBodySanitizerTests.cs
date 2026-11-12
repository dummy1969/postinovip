using MimeKit;
using MimeKit.Utils;
using PostinoVip.Core.Html;

namespace PostinoVip.Core.Tests;

public class HtmlBodySanitizerTests
{
    [Theory]
    [InlineData("<p>ok</p><script>alert(1)</script>", "script")]
    [InlineData("<p onclick=\"alert(1)\">ok</p>", "onclick")]
    [InlineData("<iframe src=\"https://evil.example\"></iframe><p>ok</p>", "iframe")]
    [InlineData("<form action=\"https://evil.example\"><input name=\"pwd\"></form><p>ok</p>", "form")]
    [InlineData("<a href=\"javascript:alert(1)\">ok</a>", "javascript:")]
    public void RimuoveContenutoPericoloso(string html, string forbidden)
    {
        var result = HtmlBodySanitizer.Sanitize(html);

        Assert.DoesNotContain(forbidden, result.Html, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("ok", result.Html);
    }

    [Fact]
    public void MantieneLinkHttpEMailto()
    {
        var result = HtmlBodySanitizer.Sanitize("<a href=\"https://example.com\">a</a> <a href=\"mailto:x@example.com\">b</a>");

        Assert.Contains("href=\"https://example.com\"", result.Html);
        Assert.Contains("href=\"mailto:x@example.com\"", result.Html);
    }

    [Theory]
    [InlineData("<img src=\"https://tracker.example/p.gif\">", true)]
    [InlineData("<div style=\"background-image: url('http://tracker.example/bg.png')\">x</div>", true)]
    [InlineData("<p>solo testo</p>", false)]
    public void RilevaImmaginiRemote(string html, bool expected)
    {
        Assert.Equal(expected, HtmlBodySanitizer.Sanitize(html).HasRemoteImages);
    }

    [Fact]
    public void ConverteImmaginiInlineCidInData()
    {
        var builder = new BodyBuilder();
        var image = builder.LinkedResources.Add("logo.png", new byte[] { 0x89, 0x50, 0x4E, 0x47 }, new ContentType("image", "png"));
        image.ContentId = MimeUtils.GenerateMessageId();
        builder.HtmlBody = $"<p>Logo:</p><img src=\"cid:{image.ContentId}\">";
        var message = new MimeMessage { Body = builder.ToMessageBody() };

        var result = HtmlBodySanitizer.Sanitize(message.HtmlBody!, HtmlBodySanitizer.InlineImages(message));

        Assert.Contains("src=\"data:image/png;base64,iVBORw==\"", result.Html);
        Assert.DoesNotContain("cid:", result.Html);
        Assert.False(result.HasRemoteImages);
    }

    [Fact]
    public void DisplaySulleCelleTolto()
    {
        // Mail di benvenuto di IceWarp: con <td style="display: block"> l'app non mostrava nulla della mail.
        var html = "<table><tr><td style=\"font-size: 14px; display: block; max-width: 570px\">Ciao</td>" +
                   "<td style=\"display:block\">B</td></tr></table><div style=\"display: block\">D</div>";

        var clean = HtmlBodySanitizer.Sanitize(html).Html;

        Assert.Contains("Ciao", clean);
        Assert.DoesNotContain("<td style=\"display", clean);
        Assert.Contains("font-size: 14px", clean);
        Assert.Contains("max-width: 570px", clean);
        Assert.Contains("<td>B</td>", clean); // style rimasto vuoto: tolto
        Assert.Contains("display: block\">D", clean); // fuori dalle tabelle resta
    }
}
