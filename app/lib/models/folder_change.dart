/// Esito di "Nuova cartella" / "Rinomina": nome completo dopo l'operazione e separatore della
/// gerarchia del server (serve ad aggiornare anche le sottocartelle).
class FolderChange {
  const FolderChange(this.fullName, this.separator);

  final String fullName;
  final String separator;

  factory FolderChange.fromJson(Map<String, dynamic> json) =>
      FolderChange(json['fullName'] as String, json['separator'] as String? ?? '/');
}

/// Esito di "Elimina cartella": spostata in Posta eliminata ([movedTo]) o eliminata definitivamente.
class FolderDeletion {
  const FolderDeletion(this.movedTo, this.permanent, this.separator);

  final String? movedTo;
  final bool permanent;
  final String separator;

  factory FolderDeletion.fromJson(Map<String, dynamic> json) => FolderDeletion(
    json['movedTo'] as String?,
    json['permanent'] as bool? ?? false,
    json['separator'] as String? ?? '/',
  );
}

/// Esito di "Svuota cartella": mail eliminate definitivamente e sottocartelle eliminate (solo Posta eliminata).
class FolderEmptied {
  const FolderEmptied(this.messages, this.removedFolders, this.separator);

  final int messages;
  final List<String> removedFolders;
  final String separator;

  factory FolderEmptied.fromJson(Map<String, dynamic> json) => FolderEmptied(
    json['messages'] as int? ?? 0,
    [for (final f in json['removedFolders'] as List<dynamic>? ?? const []) f as String],
    json['separator'] as String? ?? '/',
  );
}

/// Nome [name] dopo che la cartella [from] è diventata [to]: la cartella stessa e le sottocartelle
/// cambiano, le altre no (null). Confronto sul prefisso con il separatore: "Clienti2" non è dentro "Clienti".
String? renamedPath(String name, String from, String to, String separator) {
  if (name == from) return to;
  if (name.startsWith('$from$separator')) return to + name.substring(from.length);
  return null;
}
