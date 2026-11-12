using MimeKit;

namespace PostinoVip.Core.Models;

/// <summary>Esito dell'invio: risposta SMTP e il messaggio esattamente come è stato inviato (per la copia in Posta inviata).</summary>
public sealed record SendResult(string ServerResponse, MimeMessage Message);
