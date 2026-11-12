using PostinoVip.Core.Account;

namespace PostinoVip.Api;

/// <summary>
/// Manutenzione periodica della cache di ogni account: controllo d'integrità del database (se è
/// rovinato viene messo da parte e ricostruito dal server), pulizia (BodyCache.Sweep: corpi usciti dal
/// limite e file orfani) e recupero dello spazio libero nel database. La prima poco dopo l'avvio, poi
/// ogni 6 ore. Un errore viene registrato e non ferma il core: la cache è solo una copia del server.
/// </summary>
public sealed class CacheMaintenanceService(MailAccountRegistry accounts, ILoggerFactory loggers) : BackgroundService
{
    private static readonly TimeSpan FirstRun = TimeSpan.FromMinutes(1);
    private static readonly TimeSpan Interval = TimeSpan.FromHours(6);

    // Un file più recente può essere stato appena salvato e non ancora collegato alla sua riga.
    private static readonly TimeSpan Margin = TimeSpan.FromMinutes(10);

    private readonly ILogger _logger = loggers.CreateLogger("PostinoVip.Cache");

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await Task.Delay(FirstRun, stoppingToken);
            using var timer = new PeriodicTimer(Interval);
            do
            {
                foreach (var account in accounts.All)
                {
                    if (account.Bodies is not { } bodies)
                        continue;
                    try
                    {
                        await Task.Run(() => Maintain(account.Id, bodies), stoppingToken);
                    }
                    catch (Exception ex) when (ex is not OperationCanceledException)
                    {
                        _logger.LogWarning("[{Account}] cache: pulizia non riuscita ({Type}: {Message})",
                            account.Id, ex.GetType().Name, ex.Message);
                    }
                }
            } while (await timer.WaitForNextTickAsync(stoppingToken));
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Arresto del core.
        }
    }

    private void Maintain(string account, Core.Cache.BodyCache bodies)
    {
        // Prima l'integrità: su un database ricostruito la pulizia toglie i file non più collegati.
        if ((bodies.Cache.CheckIntegrity() ?? bodies.Cache.TakeInitializeNote()) is { } note)
            _logger.LogWarning("[{Account}] cache: {Note}", account, note);

        var sweep = bodies.Sweep(Margin);
        if (sweep.Changed)
            _logger.LogInformation("[{Account}] cache {Result}", account, sweep);

        var freed = bodies.Cache.ReclaimSpace();
        if (freed > 0)
            _logger.LogInformation("[{Account}] cache: {Freed:0.0} MB restituiti dal database", account, freed / 1024.0 / 1024.0);
    }
}
