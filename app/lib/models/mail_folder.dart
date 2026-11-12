/// Cartella della casella, come restituita da GET /folders.
class MailFolder {
  const MailFolder({required this.fullName, required this.name, this.count, this.specialUse, this.unread});

  final String fullName;
  final String name;
  final int? count;

  /// Ruolo dichiarato dal server (SPECIAL-USE): "inbox", "sent", "trash", "drafts", "junk"... o null.
  final String? specialUse;

  /// Messaggi non letti (null se il core non lo sa).
  final int? unread;

  MailFolder withCount(int? count) =>
      MailFolder(fullName: fullName, name: name, count: count, specialUse: specialUse, unread: unread);

  MailFolder withUnread(int? unread) =>
      MailFolder(fullName: fullName, name: name, count: count, specialUse: specialUse, unread: unread);

  factory MailFolder.fromJson(Map<String, dynamic> json) => MailFolder(
    fullName: json['fullName'] as String,
    name: json['name'] as String,
    count: json['count'] as int?,
    specialUse: json['specialUse'] as String?,
    unread: json['unread'] as int?,
  );

  /// Ruolo della cartella: quello dichiarato dal server (SPECIAL-USE) e, se manca, ricavato dal
  /// nome come ripiego ("INBOX" è sempre la posta in arrivo). Null per le cartelle normali.
  /// La posta indesiderata no (J2): il core dà il ruolo "junk" alla sola cartella in uso (scelta nelle Opzioni, del
  /// server o riconosciuta dal nome), quindi l'app non lo indovina.
  String? get role {
    if (specialUse != null) return specialUse;
    if (fullName.toUpperCase() == 'INBOX') return 'inbox';
    final n = name.toLowerCase();
    if (n.contains('sent') || n.contains('inviat')) return 'sent';
    if (n.contains('draft') || n.contains('bozz')) return 'drafts';
    if (n.contains('trash') || n.contains('cestin') || n.contains('deleted') || n.contains('eliminat')) return 'trash';
    return null;
  }

  /// Nome mostrato nell'app (tappa «Aspetto», V4): la Posta in arrivo, che IMAP chiama sempre «INBOX», si chiama
  /// «Posta in arrivo» come in Outlook; le altre cartelle tengono il nome del server.
  String get displayName => fullName.toUpperCase() == 'INBOX' ? 'Posta in arrivo' : name;

  /// Separatore della gerarchia ricavato dal nome completo (es. "/" in "INBOX/Clienti"); null per le
  /// cartelle in cima, dove non si vede.
  String? get separator =>
      fullName == name || !fullName.endsWith(name) ? null : fullName[fullName.length - name.length - 1];

  /// Livello di annidamento, ricavato dal separatore che precede [name] in [fullName]
  /// (es. "INBOX.Sent" o "INBOX/Sent" -> 1). L'Api non espone il separatore.
  int get depth {
    if (fullName == name || !fullName.endsWith(name)) return 0;
    final separator = fullName[fullName.length - name.length - 1];
    return separator.allMatches(fullName).length;
  }
}
