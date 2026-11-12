namespace PostinoVip.Core.Models;

/// <summary>
/// Esito di un'operazione su più mail (3.5a): cartella di destinazione (null per l'eliminazione
/// definitiva) e UID effettivamente trattati; quelli che non esistevano più vengono ignorati.
/// </summary>
public sealed record BatchResult(string? Destination, IReadOnlyList<uint> Uids);
