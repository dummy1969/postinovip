using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;
using PostinoVip.Core.Events;

namespace PostinoVip.Api.Controllers;

/// <summary>
/// GET /events — Server-Sent Events: la risposta resta aperta e il core vi scrive una riga
/// "data: {json}" per ogni evento (cambiamenti di INBOX, stato del controllo in tempo reale).
/// Ogni 30 s senza eventi invia un commento ": ping" per tenere viva la connessione.
/// La risposta finisce quando l'app chiude la connessione o quando il core si arresta (ApplicationStopping):
/// senza il secondo caso Kestrel aspettava la fine della richiesta fino al tempo massimo di arresto (30 s) e
/// l'app, che aspetta il core 5 s, si chiudeva lentamente (misurato il 12/11/2026: core uscito dopo 30,1 s).
/// </summary>
[ApiController]
[Route("events")]
public sealed class EventsController(MailboxEventHub hub, IHostApplicationLifetime lifetime) : ControllerBase
{
    private static readonly TimeSpan Heartbeat = TimeSpan.FromSeconds(30);

    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    [HttpGet]
    public async Task Get(CancellationToken requestAborted)
    {
        using var stop = CancellationTokenSource.CreateLinkedTokenSource(requestAborted, lifetime.ApplicationStopping);
        var ct = stop.Token;
        Response.ContentType = "text/event-stream";
        Response.Headers.CacheControl = "no-cache";

        using var subscription = hub.Subscribe();
        try
        {
            await WriteAsync(": connesso\n\n", ct);
            while (true)
            {
                using var wait = CancellationTokenSource.CreateLinkedTokenSource(ct);
                wait.CancelAfter(Heartbeat);
                try
                {
                    if (!await subscription.Reader.WaitToReadAsync(wait.Token))
                        return; // hub chiuso
                }
                catch (OperationCanceledException) when (!ct.IsCancellationRequested)
                {
                    await WriteAsync(": ping\n\n", ct);
                    continue;
                }

                while (subscription.Reader.TryRead(out var e))
                    await Response.WriteAsync($"data: {JsonSerializer.Serialize(e, Json)}\n\n", ct);
                await Response.Body.FlushAsync(ct);
            }
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            // L'app ha chiuso la connessione o il core si sta arrestando: normale, niente da registrare.
        }
    }

    private async Task WriteAsync(string text, CancellationToken ct)
    {
        await Response.WriteAsync(text, ct);
        await Response.Body.FlushAsync(ct);
    }
}
