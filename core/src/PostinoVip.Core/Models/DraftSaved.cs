namespace PostinoVip.Core.Models;

/// <summary>Bozza salvata in Bozze: cartella e UID (null se il server non lo restituisce, senza UIDPLUS).</summary>
public sealed record DraftSaved(string Folder, uint? Uid);
