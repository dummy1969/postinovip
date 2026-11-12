namespace PostinoVip.Api.Contracts;

/// <summary>
/// Corpo di PUT /messages/{folder}/{uid}/flags: i campi assenti restano come sono.
/// FollowUp: "none" | "flagged" | "completed"; Due: scadenza (aaaa-mm-gg) del contrassegno, solo con
/// "flagged" (salvata solo sul computer); Categories: l'insieme completo delle categorie (1–6).
/// </summary>
public sealed class FlagsRequest
{
    public string? FollowUp { get; set; }
    public DateOnly? Due { get; set; }
    public int[]? Categories { get; set; }
}

public sealed record FlagsResponse(bool Flagged, bool Completed, DateOnly? Due, int[] Categories);
