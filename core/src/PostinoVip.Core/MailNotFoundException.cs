namespace PostinoVip.Core;

/// <summary>Cartella o messaggio inesistente. Nasconde le eccezioni specifiche di MailKit ai chiamanti.</summary>
public sealed class MailNotFoundException(string message, Exception? inner = null) : Exception(message, inner);
