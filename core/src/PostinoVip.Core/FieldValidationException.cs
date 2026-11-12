namespace PostinoVip.Core;

/// <summary>
/// Dato non valido in un campo specifico ("to", "cc", "attachments"...), così la UI può segnalare
/// l'errore sul campo giusto (l'Api risponde 400 ValidationProblemDetails). È una FormatException
/// per chi non ha bisogno di distinguere.
/// </summary>
public class FieldValidationException(string field, string message, Exception? inner = null)
    : FormatException(message, inner)
{
    public string Field { get; } = field;
}
