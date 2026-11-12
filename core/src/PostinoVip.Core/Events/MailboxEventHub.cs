using System.Collections.Concurrent;
using System.Threading.Channels;

namespace PostinoVip.Core.Events;

/// <summary>
/// Smista gli eventi a tutti gli iscritti (una connessione SSE ciascuno). Ogni iscritto ha una coda
/// limitata: se l'app non legge, si scartano gli eventi più vecchi invece di accumulare memoria.
/// L'ultimo stato di ogni account (controllo in tempo reale, connessione) viene inviato subito a chi si iscrive.
/// </summary>
public sealed class MailboxEventHub
{
    private const int QueueSize = 64;
    private readonly ConcurrentDictionary<Guid, Channel<MailboxEvent>> _subscribers = new();
    private readonly ConcurrentDictionary<(string Type, string Account), MailboxEvent> _lastStatus = new();

    public int SubscriberCount => _subscribers.Count;

    public Subscription Subscribe()
    {
        var channel = Channel.CreateBounded<MailboxEvent>(new BoundedChannelOptions(QueueSize)
        {
            FullMode = BoundedChannelFullMode.DropOldest,
            SingleReader = true,
        });
        foreach (var status in _lastStatus.Values)
            channel.Writer.TryWrite(status);

        var id = Guid.NewGuid();
        _subscribers[id] = channel;
        return new Subscription(channel.Reader, () =>
        {
            if (_subscribers.TryRemove(id, out var removed))
                removed.Writer.TryComplete();
        });
    }

    public void Publish(MailboxEvent e)
    {
        // credentials-changed: anche all'app che si iscrive dopo (non deve perdere il token nuovo).
        if (e.Type is "watch-status" or "connection-status" or "credentials-changed" or "login-status")
            _lastStatus[(e.Type, e.Account)] = e;
        foreach (var channel in _subscribers.Values)
            channel.Writer.TryWrite(e);
    }

    public sealed class Subscription(ChannelReader<MailboxEvent> reader, Action unsubscribe) : IDisposable
    {
        public ChannelReader<MailboxEvent> Reader { get; } = reader;
        public void Dispose() => unsubscribe();
    }
}
