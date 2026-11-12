namespace PostinoVip.Core.Models;

/// <summary>Contenuto decodificato di un allegato.</summary>
public sealed record AttachmentContent(string FileName, string ContentType, byte[] Data);
