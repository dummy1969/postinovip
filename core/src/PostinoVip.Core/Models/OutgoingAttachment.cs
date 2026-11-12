namespace PostinoVip.Core.Models;

/// <summary>Allegato da inviare. ContentType null o vuoto: ricavato dall'estensione del nome.</summary>
public sealed record OutgoingAttachment(string FileName, string? ContentType, byte[] Data);
