namespace PostinoVip.Core;

/// <summary>
/// Server della casella non raggiungibile (rete assente, server spento, collegamento troppo lento).
/// Per un po' non si ritenta a ogni richiesta: chi la riceve può usare la copia locale.
/// </summary>
public sealed class MailOfflineException(string message, Exception? inner = null) : Exception(message, inner);
