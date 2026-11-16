import '../l10n/app_localizations.dart';

/// Livello del filtro della posta indesiderata, come in Outlook classico (Opzioni posta indesiderata). I livelli si
/// basano sul giudizio che il server scrive nella mail (SpamAssassin e simili), scelta 2a della J1.
enum JunkLevel {
  none('None'),
  low('Low'),
  high('High'),
  safeListsOnly('SafeListsOnly');

  const JunkLevel(this.coreName);

  final String coreName;

  String label(AppLocalizations l) => switch (this) {
    none => l.junkLevelNone,
    low => l.junkLevelLow,
    high => l.junkLevelHigh,
    safeListsOnly => l.junkLevelSafeOnly,
  };

  String description(AppLocalizations l) => switch (this) {
    none => l.junkLevelNoneInfo,
    low => l.junkLevelLowInfo,
    high => l.junkLevelHighInfo,
    safeListsOnly => l.junkLevelSafeOnlyInfo,
  };

  static JunkLevel fromCore(String? name) => values.firstWhere((l) => l.coreName == name, orElse: () => none);
}

/// Elenchi delle Opzioni posta indesiderata.
enum JunkList {
  safeSenders('safeSenders'),
  safeRecipients('safeRecipients'),
  blockedSenders('blockedSenders');

  const JunkList(this.field);

  /// Nome del campo nel JSON del core (anche negli errori di validazione, in minuscolo).
  final String field;

  String label(AppLocalizations l) => switch (this) {
    safeSenders => l.safeSenders,
    safeRecipients => l.safeRecipients,
    blockedSenders => l.blockedSenders,
  };

  String description(AppLocalizations l) => switch (this) {
    safeSenders => l.safeSendersInfo,
    safeRecipients => l.safeRecipientsInfo,
    blockedSenders => l.blockedSendersInfo,
  };
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
  sender('Sender'),
  domain('Domain'),
  group('Group');

  const NeverBlockKind(this.coreName);

  final String coreName;

  /// [many]: più mail selezionate (per il gruppo cambia il testo).
  String label(AppLocalizations l, {bool many = false}) => switch (this) {
    sender => l.neverBlockSender,
    domain => l.neverBlockDomain,
    group => many ? l.neverBlockGroups : l.neverBlockGroup,
  };
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
