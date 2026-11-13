namespace PostinoVip.Core.Models;

/// <summary>
/// Esito di "Nuova cartella" e "Rinomina": nome completo della cartella dopo l'operazione e separatore
/// della gerarchia del server (serve ad aggiornare anche le sottocartelle nella copia locale e nell'app).
/// </summary>
public sealed record FolderChange(string FullName, char Separator);

/// <summary>
/// Esito di "Elimina cartella": spostata dentro Posta eliminata (<see cref="MovedTo"/> = nuovo nome completo)
/// oppure eliminata definitivamente (<see cref="Permanent"/>, solo se era già dentro Posta eliminata).
/// </summary>
public sealed record FolderDeletion(string? MovedTo, bool Permanent, char Separator);

/// <summary>
/// Esito di "Svuota cartella": mail eliminate definitivamente dalla cartella e sottocartelle eliminate (nomi completi,
/// solo per Posta eliminata), con il separatore della gerarchia.
/// </summary>
public sealed record FolderEmptied(int Messages, IReadOnlyList<string> RemovedFolders, char Separator);
