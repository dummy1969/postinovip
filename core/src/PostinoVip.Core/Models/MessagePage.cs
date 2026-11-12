namespace PostinoVip.Core.Models;

/// <summary>Una pagina di intestazioni; Total è il numero di messaggi nella cartella.</summary>
public sealed record MessagePage(int Total, int Offset, int Limit, IReadOnlyList<MessageHeader> Items);
