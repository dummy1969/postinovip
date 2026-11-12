using PostinoVip.Core.Account;

namespace PostinoVip.Api;

/// <summary>
/// Ogni <see cref="Interval"/> riprova a collegarsi agli account il cui server non era raggiungibile,
/// così l'app torna "connessa" da sola (evento connection-status) anche se l'utente non fa nulla.
/// Gli account connessi non vengono toccati.
/// </summary>
public sealed class ConnectivityService(MailAccountRegistry accounts) : BackgroundService
{
    public static readonly TimeSpan Interval = TimeSpan.FromSeconds(30);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(Interval);
        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                foreach (var a in accounts.All)
                {
                    if (a.Connection is { IsOnline: false } connection)
                    {
                        try
                        {
                            await connection.ProbeAsync(stoppingToken);
                        }
                        catch (Exception ex) when (ex is not OperationCanceledException)
                        {
                            // Es. credenziali rifiutate: non è un problema di rete, lo dirà la prossima richiesta.
                        }
                    }
                }
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Arresto del core.
        }
    }
}
