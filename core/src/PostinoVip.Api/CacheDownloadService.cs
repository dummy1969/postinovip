using PostinoVip.Core.Account;
using PostinoVip.Core.Cache;
using PostinoVip.Core.Events;
using PostinoVip.Core.Imap;

namespace PostinoVip.Api;

/// <summary>
/// Esegue un CacheDownloadWorker (download in background, connessione IMAP dedicata) per ogni account
/// configurato con la cache attiva, per tutta la vita del core.
/// </summary>
public sealed class CacheDownloadService(MailAccountRegistry accounts, MailboxEventHub hub, ILoggerFactory loggers) : BackgroundService
{
    private readonly ILogger _logger = loggers.CreateLogger("PostinoVip.Cache");

    protected override Task ExecuteAsync(CancellationToken stoppingToken) =>
        Task.WhenAll(accounts.All
            .Where(a => a.Bodies is not null && a.Configured && !a.IsPop3) // POP3: le mail sono già sul computer
            .Select(a =>
            {
                void Log(string message) => _logger.LogInformation("{Message}", message);
                var downloader = new BodyDownloader(a.Id, a.Bodies!.Cache, a.Bodies.Policy, Log);
                return new CacheDownloadWorker(a.Id, a.Settings.Imap, downloader, hub, Log).RunAsync(stoppingToken);
            }));
}
