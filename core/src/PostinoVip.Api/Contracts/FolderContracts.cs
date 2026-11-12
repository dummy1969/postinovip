namespace PostinoVip.Api.Contracts;

/// <summary>Corpo di POST /folders: <see cref="Parent"/> null = cartella in cima alla casella.</summary>
public sealed class CreateFolderRequest
{
    public string? Parent { get; set; }
    public string? Name { get; set; }
}

/// <summary>Corpo di POST /folders/{folder}/rename.</summary>
public sealed class RenameFolderRequest
{
    public string? Name { get; set; }
}

/// <summary>Corpo di POST /folders/{folder}/move: <see cref="Parent"/> null o vuoto = in cima alla casella.</summary>
public sealed class MoveFolderRequest
{
    public string? Parent { get; set; }
}

/// <summary>Esito di crea / rinomina: nome completo dopo l'operazione e separatore della gerarchia.</summary>
public sealed record FolderChangeResponse(string FullName, string Separator);

/// <summary>Esito di "Elimina cartella": MovedTo se spostata in Posta eliminata, Permanent se eliminata.</summary>
public sealed record FolderDeleteResponse(string? MovedTo, bool Permanent, string Separator);
