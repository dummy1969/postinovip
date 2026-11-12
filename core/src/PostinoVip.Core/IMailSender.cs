using PostinoVip.Core.Models;

namespace PostinoVip.Core;

public interface IMailSender
{
    /// <summary>Invia il messaggio; restituisce la risposta del server SMTP e il messaggio inviato.</summary>
    Task<SendResult> SendAsync(OutgoingMessage msg, CancellationToken ct = default);

    /// <summary>Invia un messaggio già costruito (Posta in uscita, 3.8); restituisce la risposta del server SMTP.</summary>
    Task<string> SendMimeAsync(MimeKit.MimeMessage message, CancellationToken ct = default);
}
