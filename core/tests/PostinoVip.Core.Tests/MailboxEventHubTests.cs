using PostinoVip.Core.Events;

namespace PostinoVip.Core.Tests;

public class MailboxEventHubTests
{
    [Fact]
    public void OgniIscrittoRiceveGliEventi()
    {
        var hub = new MailboxEventHub();
        using var a = hub.Subscribe();
        using var b = hub.Subscribe();

        hub.Publish(MailboxEvent.Changed("a", "INBOX", 10));

        Assert.True(a.Reader.TryRead(out var ea));
        Assert.True(b.Reader.TryRead(out var eb));
        Assert.Equal(MailboxEvent.Changed("a", "INBOX", 10), ea);
        Assert.Equal(ea, eb);
    }

    [Fact]
    public void DisiscrittoNonRiceveERilasciaLaCoda()
    {
        var hub = new MailboxEventHub();
        var sub = hub.Subscribe();
        sub.Dispose();

        hub.Publish(MailboxEvent.Changed("a", "INBOX", 1));

        Assert.Equal(0, hub.SubscriberCount);
        Assert.True(sub.Reader.Completion.IsCompleted);
    }

    [Fact]
    public void NuovoIscrittoRiceveSubitoLUltimoStato()
    {
        var hub = new MailboxEventHub();
        hub.Publish(MailboxEvent.Status("a", true));
        hub.Publish(MailboxEvent.Changed("a", "INBOX", 3)); // i cambiamenti passati non vengono riproposti

        using var sub = hub.Subscribe();

        Assert.True(sub.Reader.TryRead(out var first));
        Assert.Equal(MailboxEvent.Status("a", true), first);
        Assert.False(sub.Reader.TryRead(out _));
    }

    [Fact]
    public void NuovoIscrittoRiceveLoStatoDiOgniAccount()
    {
        var hub = new MailboxEventHub();
        hub.Publish(MailboxEvent.Status("a", true));
        hub.Publish(MailboxEvent.Status("b", false));
        hub.Publish(MailboxEvent.Status("a", false)); // sostituisce il precedente di "a"

        using var sub = hub.Subscribe();

        var received = new List<MailboxEvent>();
        while (sub.Reader.TryRead(out var e))
            received.Add(e);
        Assert.Equal(2, received.Count);
        Assert.Contains(MailboxEvent.Status("a", false), received);
        Assert.Contains(MailboxEvent.Status("b", false), received);
    }

    [Fact]
    public void NuovoIscrittoRiceveAncheLoStatoDellaConnessione()
    {
        var hub = new MailboxEventHub();
        hub.Publish(MailboxEvent.Status("a", true));
        hub.Publish(MailboxEvent.Connection("a", false));
        hub.Publish(MailboxEvent.Connection("a", true)); // vale l'ultimo

        using var sub = hub.Subscribe();

        var received = new List<MailboxEvent>();
        while (sub.Reader.TryRead(out var e))
            received.Add(e);
        Assert.Equal(2, received.Count);
        Assert.Contains(MailboxEvent.Status("a", true), received);
        Assert.Contains(MailboxEvent.Connection("a", true), received);
    }

    [Fact]
    public void CodaPienaScartaIPiuVecchi()
    {
        var hub = new MailboxEventHub();
        using var sub = hub.Subscribe();

        for (var i = 1; i <= 100; i++)
            hub.Publish(MailboxEvent.Changed("a", "INBOX", i));

        var counts = new List<int>();
        while (sub.Reader.TryRead(out var e))
            counts.Add(e.Count!.Value);
        Assert.Equal(64, counts.Count);
        Assert.Equal(100, counts[^1]); // l'ultimo (il più utile) c'è sempre
    }
}
