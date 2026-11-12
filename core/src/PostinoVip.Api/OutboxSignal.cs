namespace PostinoVip.Api;

/// <summary>Sveglia il servizio della Posta in uscita (mail messa in coda, "Invia ora", server di nuovo raggiungibile).</summary>
public sealed class OutboxSignal
{
    private readonly SemaphoreSlim _wake = new(0, 1);

    public void Wake()
    {
        try
        {
            _wake.Release();
        }
        catch (SemaphoreFullException)
        {
            // già svegliato: un passaggio basta per tutte le richieste arrivate nel frattempo
        }
    }

    public Task<bool> WaitAsync(TimeSpan timeout, CancellationToken ct) => _wake.WaitAsync(timeout, ct);
}
