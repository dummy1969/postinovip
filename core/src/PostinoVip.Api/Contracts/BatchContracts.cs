namespace PostinoVip.Api.Contracts;

// Operazioni su più mail della stessa cartella (3.5a). "uids": da 1 a MessagesController.MaxBatch.

/// <summary>Corpo di PUT /messages/{folder}/seen.</summary>
public sealed class BatchSeenRequest
{
    public uint[]? Uids { get; set; }
    public bool? Seen { get; set; }
}

/// <summary>Esito di PUT /messages/{folder}/seen: le mail trovate e aggiornate.</summary>
public sealed record BatchSeenResponse(IReadOnlyList<uint> Uids, bool Seen);

/// <summary>
/// Corpo di PUT /messages/{folder}/flags: FollowUp e Due come nella versione per una mail; le categorie
/// si aggiungono o tolgono (come "Categorizza" di Outlook su più mail), non si sostituiscono.
/// </summary>
public sealed class BatchFlagsRequest
{
    public uint[]? Uids { get; set; }
    public string? FollowUp { get; set; }
    public DateOnly? Due { get; set; }
    public int[]? AddCategories { get; set; }
    public int[]? RemoveCategories { get; set; }
}

public sealed record BatchFlagsItem(uint Uid, bool Flagged, bool Completed, DateOnly? Due, int[] Categories);

/// <summary>Esito di PUT /messages/{folder}/flags: stato dopo la modifica delle mail trovate.</summary>
public sealed record BatchFlagsResponse(IReadOnlyList<BatchFlagsItem> Items);

/// <summary>Corpo di POST /messages/{folder}/move.</summary>
public sealed class BatchMoveRequest
{
    public uint[]? Uids { get; set; }
    public string? Destination { get; set; }
}

/// <summary>Esito di POST /messages/{folder}/copy: cartella di destinazione e mail copiate.</summary>
public sealed record BatchCopyResponse(string CopiedTo, IReadOnlyList<uint> Uids);

/// <summary>Corpo di POST /messages/{folder}/delete: Permanent solo dentro Posta eliminata.</summary>
public sealed class BatchDeleteRequest
{
    public uint[]? Uids { get; set; }
    public bool Permanent { get; set; }
}

/// <summary>Esito di sposta / elimina su più mail: destinazione (null se definitiva) e mail trattate.</summary>
public sealed record BatchMoveResponse(string? MovedTo, bool Permanent, IReadOnlyList<uint> Uids);
