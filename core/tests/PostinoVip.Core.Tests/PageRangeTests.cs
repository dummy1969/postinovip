using PostinoVip.Core.Imap;

namespace PostinoVip.Core.Tests;

public class PageRangeTests
{
    [Theory]
    [InlineData(100, 0, 20, 80, 99)]   // prima pagina: le 20 più recenti
    [InlineData(100, 20, 20, 60, 79)]  // seconda pagina
    [InlineData(100, 90, 20, 0, 9)]    // ultima pagina parziale
    [InlineData(5, 0, 20, 0, 4)]       // cartella più piccola del limite
    public void CalcolaIndici(int total, int offset, int limit, int first, int last)
    {
        Assert.Equal((first, last), PageRange.Compute(total, offset, limit));
    }

    [Theory]
    [InlineData(0, 0, 20)]     // cartella vuota
    [InlineData(100, 100, 20)] // offset oltre la fine
    public void PaginaVuotaRestituisceNull(int total, int offset, int limit)
    {
        Assert.Null(PageRange.Compute(total, offset, limit));
    }

    [Theory]
    [InlineData(-1, 20)]
    [InlineData(0, 0)]
    public void ParametriNonValidiLanciano(int offset, int limit)
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => PageRange.Compute(10, offset, limit));
    }
}
