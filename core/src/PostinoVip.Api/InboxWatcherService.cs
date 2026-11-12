using PostinoVip.Core.Account;
using PostinoVip.Core.Events;
using PostinoVip.Core.Imap;

namespace PostinoVip.Api;

/// <summary>Esegue un InboxWatcher (IDLE su INBOX) per ogni account IMAP, per tutta la vita del core.</summary>
public sealed class InboxWatcherService(MailAccountRegistry accounts, MailboxEventHub hub, ILogger<InboxWatcherService> logger)
    : BackgroundService
{
    protected override Task ExecuteAsync(CancellationToken stoppingToken) =>
        Task.WhenAll(accounts.All.Where(a => !a.IsPop3).Select(a =>
            new InboxWatcher(a.Id, a.Settings.Imap, hub, message => logger.LogInformation("{Message}", message)).RunAsync(stoppingToken)));
}
