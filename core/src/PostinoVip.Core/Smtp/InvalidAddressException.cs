namespace PostinoVip.Core.Smtp;

/// <summary>Indirizzo non valido in un campo ("from", "to", "cc").</summary>
public sealed class InvalidAddressException(string field, string message, Exception? inner = null)
    : FieldValidationException(field, message, inner);
