using System.Text;
using PostinoVip.Core.Eml;

namespace PostinoVip.Core.Tests;

/// <summary>File .eml aperti (E1): lettura, mail non valide, limite dei file aperti.</summary>
public sealed class EmlStoreTests
{
    private static Stream Text(string s) => new MemoryStream(Encoding.UTF8.GetBytes(s));

    private static Task<MimeKit.MimeMessage> Mail(string subject) =>
        EmlStore.ParseAsync(Text($"From: a@example.com\r\nSubject: {subject}\r\n\r\nCorpo\r\n"), CancellationToken.None);

    [Fact]
    public async Task LeggeUnaMailERifiutaIFileCheNonLoSono()
    {
        Assert.Equal("Ciao", (await Mail("Ciao")).Subject);
        await Assert.ThrowsAsync<InvalidEmlException>(() => EmlStore.ParseAsync(Text("solo testo, nessuna intestazione\r\n"), CancellationToken.None));
        await Assert.ThrowsAsync<InvalidEmlException>(() => EmlStore.ParseAsync(new MemoryStream([0x89, 0x50, 0x4e, 0x47, 0, 1, 2]), CancellationToken.None));
        await Assert.ThrowsAsync<InvalidEmlException>(() => EmlStore.ParseAsync(new MemoryStream(), CancellationToken.None));
    }

    [Fact]
    public async Task TieneIFileApertiChiudeIlMenoUsatoOltreIlLimite()
    {
        var store = new EmlStore(capacity: 2);
        var a = store.Open(await Mail("A"));
        var b = store.Open(await Mail("B"));
        Assert.Matches("^[0-9a-f]{32}$", a);
        Assert.NotEqual(a, b);

        Assert.Equal("A", store.Get(a).Subject); // A usata: la meno recente ora è B
        var c = store.Open(await Mail("C"));
        Assert.Throws<MailNotFoundException>(() => store.Get(b));
        Assert.Equal("A", store.Get(a).Subject);
        Assert.Equal("C", store.Get(c).Subject);

        Assert.True(store.Close(a));
        Assert.False(store.Close(a));
        Assert.Equal(1, store.Count);
    }
}
