using System.ComponentModel.DataAnnotations;

namespace PostinoVip.Api.Contracts;

/// <summary>Corpo di POST /messages/{folder}/{uid}/move.</summary>
public sealed class MoveRequest
{
    [Required(AllowEmptyStrings = false)] public string Destination { get; set; } = "";
}

/// <summary>Esito di sposta / elimina: MovedTo per gli spostamenti, Permanent per l'eliminazione definitiva.</summary>
public sealed record MoveResponse(string? MovedTo, bool Permanent = false);
