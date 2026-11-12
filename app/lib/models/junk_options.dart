/// Livello del filtro della posta indesiderata, come in Outlook classico (Opzioni posta indesiderata). I livelli si
/// basano sul giudizio che il server scrive nella mail (SpamAssassin e simili), scelta 2a della J1.
enum JunkLevel {
  none('None', 'Nessun filtro automatico',
      'La posta dei mittenti bloccati viene comunque spostata nella cartella della posta indesiderata.'),
  low('Low', 'Bassa', 'Sposta la posta indesiderata più evidente: quella che il server ha segnato come spam.'),
  high('High', 'Alta',
      'Sposta anche le mail con un punteggio vicino alla soglia del server: può capitare anche a posta normale, '
          'controlla spesso la cartella della posta indesiderata.'),
  safeListsOnly('SafeListsOnly', 'Solo elenchi attendibili',
      'Solo la posta di mittenti attendibili, o inviata a destinatari attendibili, resta in Posta in arrivo.');

  const JunkLevel(this.coreName, this.label, this.description);

  final String coreName;
  final String label;
  final String description;

  static JunkLevel fromCore(String? name) => values.firstWhere((l) => l.coreName == name, orElse: () => none);
}

/// Elenchi delle Opzioni posta indesiderata.
enum JunkList {
  safeSenders('safeSenders', 'Mittenti attendibili',
      'La posta proveniente da questi indirizzi o domini non verrà mai considerata posta indesiderata.'),
  safeRecipients('safeRecipients', 'Destinatari attendibili',
      'La posta inviata a questi indirizzi o domini (per esempio una mailing list) non verrà mai considerata posta indesiderata.'),
  blockedSenders('blockedSenders', 'Mittenti bloccati',
      'La posta proveniente da questi indirizzi o domini verrà sempre spostata nella cartella della posta indesiderata.');

  const JunkList(this.field, this.label, this.description);

  /// Nome del campo nel JSON del core (anche negli errori di validazione, in minuscolo).
  final String field;
  final String label;
  final String description;
}

/// Opzioni posta indesiderata di un account (GET/PUT …/junk).
class JunkOptions {
  const JunkOptions({
    this.level = JunkLevel.none,
    this.folder,
    this.junkFolder,
    this.trustContacts = true,
    this.safeSenders = const [],
    this.safeRecipients = const [],
    this.blockedSenders = const [],
  });

  final JunkLevel level;

  /// Cartella scelta dall'utente; null = quella del server o riconosciuta dal nome.
  final String? folder;

  /// Cartella in uso secondo il core (scelta, del server o dal nome); null = nessuna. Solo in lettura.
  final String? junkFolder;

  /// «Considera attendibili anche i miei contatti».
  final bool trustContacts;
  final List<String> safeSenders;
  final List<String> safeRecipients;
  final List<String> blockedSenders;

  List<String> entries(JunkList list) => switch (list) {
    JunkList.safeSenders => safeSenders,
    JunkList.safeRecipients => safeRecipients,
    JunkList.blockedSenders => blockedSenders,
  };

  factory JunkOptions.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) => ((json[key] as List?) ?? const []).cast<String>();
    return JunkOptions(
      level: JunkLevel.fromCore(json['level'] as String?),
      folder: json['folder'] as String?,
      junkFolder: json['junkFolder'] as String?,
      trustContacts: json['trustContacts'] as bool? ?? true,
      safeSenders: list('safeSenders'),
      safeRecipients: list('safeRecipients'),
      blockedSenders: list('blockedSenders'),
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level.coreName,
    'folder': folder,
    'trustContacts': trustContacts,
    'safeSenders': safeSenders,
    'safeRecipients': safeRecipients,
    'blockedSenders': blockedSenders,
  };
}

/// «Non bloccare mai…»: cosa diventa attendibile.
enum NeverBlockKind {
  sender('Sender', 'Non bloccare mai il mittente'),
  domain('Domain', 'Non bloccare mai il dominio del mittente'),
  group('Group', 'Non bloccare mai questo gruppo o mailing list');

  const NeverBlockKind(this.coreName, this.label);

  final String coreName;
  final String label;
}

/// Esito di un comando della posta indesiderata: voci aggiunte agli elenchi, mail spostate e destinazione.
class JunkCommandResult {
  const JunkCommandResult(this.entries, this.moved, this.folder);

  final List<String> entries;
  final List<int> moved;
  final String? folder;

  factory JunkCommandResult.fromJson(Map<String, dynamic> json) => JunkCommandResult(
    ((json['entries'] as List?) ?? const []).cast<String>(),
    ((json['moved'] as List?) ?? const []).cast<int>(),
    json['folder'] as String?,
  );
}
