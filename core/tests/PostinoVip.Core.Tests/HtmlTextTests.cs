using PostinoVip.Core.Html;

namespace PostinoVip.Core.Tests;

public class HtmlTextTests
{
    [Fact]
    public void BlocchiEInterruzioni()
    {
        var text = HtmlText.ToPlainText("<html><head><style>p{}</style></head><body>" +
            "<p>Ciao&nbsp;Mario,</p><div>riga1<br>riga2</div><ul><li>uno</li><li>due</li></ul></body></html>");

        Assert.Equal("Ciao Mario,\n\nriga1\nriga2\n\nuno\n\ndue", text);
    }
}
