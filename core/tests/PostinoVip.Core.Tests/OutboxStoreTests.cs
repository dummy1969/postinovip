using MimeKit;
using PostinoVip.Core.Compose;
using PostinoVip.Core.Models;
using PostinoVip.Core.Outbox;
using PostinoVip.Core.Smtp;

namespace PostinoVip.Core.Tests;

public sealed class OutboxStoreTests : IDisposable
{
    private readonly string _dir = Path.Combine(Directory.CreateTempSubdirectory("postinovip-store").FullName, "outbox");

    public void Dispose() => Directory.Delete(Path.GetDirectoryName(_dir)!, recursive: true);

    private static MimeMessage Mail(string subject) => MimeMessageBuilder.Build(
        new OutgoingMessage("me@example.com", ["a@example.com"], [], subject, "testo", HtmlBody: "<p>testo</p>"));

    [Fact]
    public void SalvaRileggeAggiornaElimina()
    {
        var store = new OutboxStore(_dir);
        var item = new OutboxItem(OutboxStore.NewId(), OutboxKind.Send, DateTimeOffset.Now, "Uno", ["a@example.com"], SaveCopy: true);
        store.Save(item, Mail("Uno"));

        var read = Assert.Single(store.List());
        Assert.Equal(item, read with { To = item.To });
        Assert.Equal("Uno", store.LoadMessage(item.Id)!.Subject);
        Assert.Equal(1, store.SendCount);

        store.Update(item with { Error = "rifiutata" });
        Assert.Equal("rifiutata", store.Get(item.Id)!.Error);
        Assert.False(store.Get(item.Id)!.IsDue(DateTimeOffset.Now)); // con un errore non riparte da sola

        Assert.True(store.Remove(item.Id));
        Assert.Empty(store.List());
        Assert.Empty(Directory.GetFiles(_dir)); // niente file temporanei o orfani
    }

    [Fact]
    public void FilePrivatiEIdNonValidiRifiutati()
    {
        var store = new OutboxStore(_dir);
        var item = new OutboxItem(OutboxStore.NewId(), OutboxKind.Draft, DateTimeOffset.Now, "B", []);
        store.Save(item, Mail("B"));
        if (!OperatingSystem.IsWindows())
        {
            Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute, File.GetUnixFileMode(_dir));
            foreach (var f in Directory.GetFiles(_dir))
                Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite, File.GetUnixFileMode(f));
        }
        Assert.Throws<ArgumentException>(() => store.Save(item with { Id = "../x" }, Mail("x")));
        Assert.Null(store.LoadMessage("../x"));
        Assert.False(store.Remove("../../etc"));
    }

    [Fact]
    public void MessaggioSenzaDatiNonEUnElemento()
    {
        var store = new OutboxStore(_dir);
        var item = new OutboxItem(OutboxStore.NewId(), OutboxKind.Send, DateTimeOffset.Now, "C", []);
        store.Save(item, Mail("C"));
        File.Delete(Path.Combine(_dir, item.Id + ".json")); // interrotto a metà di un'eliminazione
        Assert.Empty(store.List());
        File.WriteAllText(Path.Combine(_dir, "abc.json"), "{ rovinato"); // dati illeggibili: ignorati
        Assert.Empty(store.List());
    }

    [Fact]
    public void RitardoEScadenza()
    {
        var now = DateTimeOffset.Now;
        var item = new OutboxItem("a1", OutboxKind.Send, now, "D", [], SendAfter: now.AddHours(1));
        Assert.False(item.IsDue(now));
        Assert.True(item.IsDue(now.AddHours(2)));
        Assert.True((item with { SendAfter = null }).IsDue(now));
    }
}

public class ComposeReaderTests
{
    [Fact]
    public void BozzaNostraTestoScrittoECitazioneSeparati()
    {
        var quote = new MessageQuote("\n\n> vecchio", "<div><b>Da:</b> Mario</div><p>vecchio</p>", []);
        var draft = MimeMessageBuilder.Build(new OutgoingMessage("me@example.com", ["mario"], ["Anna <anna@example.com>"], "Re: x",
            "Nuovo", "orig@x", ["root@x", "orig@x"], HtmlBody: "<p>Nuovo <strong>testo</strong></p>", Quote: quote,
            Bcc: ["nascosto@example.com"]), draft: true);

        var c = ComposeReader.Read(draft);
        Assert.Equal(["mario"], c.To); // indirizzo ancora da correggere: com'era
        Assert.Equal(["\"Anna\" <anna@example.com>"], c.Cc);
        Assert.Equal("Re: x", c.Subject);
        Assert.Contains("<strong>testo</strong>", c.Html);
        Assert.DoesNotContain("vecchio", c.Html);
        Assert.Contains("vecchio", c.QuoteHtml);
        Assert.Equal("orig@x", c.InReplyTo);
        Assert.Equal(["root@x", "orig@x"], c.References);
        Assert.Equal(["nascosto@example.com"], c.Bcc); // Ccn riaperto con la bozza
    }

    [Fact]
    public void BozzaDiUnAltroProgrammaInteraNellEditor()
    {
        var m = new MimeMessage { Subject = "Da webmail" };
        m.Body = new BodyBuilder { HtmlBody = "<p>tutto</p><blockquote>citato</blockquote>", TextBody = "tutto" }.ToMessageBody();
        var c = ComposeReader.Read(m);
        Assert.Contains("citato", c.Html);
        Assert.Null(c.QuoteHtml);

        var text = new MimeMessage { Subject = "Solo testo", Body = new TextPart("plain") { Text = "riga 1\nriga 2\n" } };
        var t = ComposeReader.Read(text);
        Assert.Null(t.Html);
        Assert.Equal("riga 1\nriga 2", t.Text);
    }

    [Fact]
    public void BozzaNostraInTestoNormaleRiapertaConLaCitazioneNelTesto()
    {
        // Testo normale (13/11/2026): niente HTML; la citazione è parte del testo, come in Outlook.
        var quote = new MessageQuote("\n\n> vecchio", "<p>vecchio</p>", []);
        var draft = MimeMessageBuilder.Build(new OutgoingMessage("me@example.com", ["mario@example.com"], [], "Re: x",
            "Nuovo", Quote: quote), draft: true);

        var c = ComposeReader.Read(draft);
        Assert.Null(c.Html); // l'app la riapre in testo normale
        Assert.Null(c.QuoteHtml);
        Assert.Equal("Nuovo\n\n> vecchio", c.Text);
    }

    [Fact]
    public void CitazioneGiaProntaInHtmlConLeSueImmagini()
    {
        const string png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";
        var quote = QuoteBuilder.FromHtml($"<p>originale <img src=\"data:image/png;base64,{png}\"></p><script>x()</script>");
        Assert.DoesNotContain("script", quote.Html);
        Assert.Contains("originale", quote.Text);
        var mime = MimeMessageBuilder.Build(new OutgoingMessage("me@example.com", ["a@example.com"], [], "S", "B",
            HtmlBody: "<p>B</p>", Quote: quote));
        Assert.DoesNotContain("data:image", mime.HtmlBody);
        Assert.Single(mime.BodyParts.OfType<MimePart>(), p => p.ContentType.MimeType == "image/png");
    }
}
