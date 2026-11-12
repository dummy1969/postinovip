using PostinoVip.Core.Account;

namespace PostinoVip.Api;

/// <summary>Esegue il controllo periodico della posta (Pop3Worker) per ogni account POP3 configurato, per tutta la vita del core.</summary>
public sealed class Pop3Service(MailAccountRegistry accounts) : BackgroundService
{
    protected override Task ExecuteAsync(CancellationToken stoppingToken) =>
        Task.WhenAll(accounts.All
            .Where(a => a.Pop3 is not null && a.Configured)
            .Select(a => a.Pop3!.RunAsync(stoppingToken)));
}
