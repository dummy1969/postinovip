using PostinoVip.Core.Account;

namespace PostinoVip.Api;

/// <summary>Esegue le sincronizzazioni CardDAV e CalDAV (DavWorker) degli account che le attivano, per tutta la vita del core.</summary>
public sealed class CardDavService(MailAccountRegistry accounts) : BackgroundService
{
    protected override Task ExecuteAsync(CancellationToken stoppingToken) =>
        Task.WhenAll(accounts.All
            .Where(a => a.Configured)
            .SelectMany(a => new[] { a.CardDav, a.CalDav })
            .Where(w => w is not null)
            .Select(w => w!.RunAsync(stoppingToken)));
}
