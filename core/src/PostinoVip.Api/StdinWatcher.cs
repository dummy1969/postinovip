namespace PostinoVip.Api;

/// <summary>
/// In modalità gestita (core avviato dall'app) lo stdin del core è una pipe aperta dall'app:
/// quando l'app termina, anche per crash, il sistema chiude la pipe e qui si legge EOF.
/// A quel punto il core si ferma, così non restano processi orfani.
/// </summary>
public sealed class StdinWatcher(IHostApplicationLifetime lifetime, ILogger<StdinWatcher> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await using var stdin = Console.OpenStandardInput();
        var buffer = new byte[256];
        try
        {
            // Read restituisce 0 solo a fine flusso (pipe chiusa). L'app non scrive nulla sullo stdin.
            while (await stdin.ReadAsync(buffer, stoppingToken) > 0)
            {
            }
        }
        catch (OperationCanceledException)
        {
            return; // arresto già in corso
        }

        logger.LogInformation("Stdin chiuso: l'app è terminata, arresto del core.");
        lifetime.StopApplication();
    }
}
