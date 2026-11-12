using System.ComponentModel.DataAnnotations;

namespace PostinoVip.Api.Contracts;

/// <summary>Corpo di PUT /messages/{folder}/{uid}/seen e relativa risposta.</summary>
public sealed class SeenRequest
{
    [Required] public bool? Seen { get; set; }
}

public sealed record SeenResponse(bool Seen);
