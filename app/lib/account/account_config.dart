import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/app_localizations.dart';
import 'connection_security.dart';

export 'connection_security.dart';

/// Dati di una casella. Il nome utente IMAP/POP3/SMTP è l'indirizzo email (come sul server di prova).
/// Per un account POP3 (4.2, [type]) i campi `imap*` descrivono il server di ricezione POP3: è la stessa
/// riga "posta in arrivo" della schermata dell'account.
class AccountConfig {
  const AccountConfig({
    required this.id,
    this.type = AccountType.imap,
    this.name = '',
    required this.email,
    required this.password,
    required this.imapHost,
    this.imapPort = 993,
    required this.smtpHost,
    this.smtpPort = 587,
    this.bodyMonths = defaultBodyMonths,
    MailSecurity? imapSecurity,
    MailSecurity? smtpSecurity,
    this.smtpRequireAuth = true,
    this.imapCertificateSha256,
    this.smtpCertificateSha256,
    this.leaveOnServer = true,
    this.removeAfter = true,
    this.removeAfterDays = defaultRemoveAfterDays,
    this.removeWhenDeleted = false,
    this.checkMinutes = defaultCheckMinutes,
    this.oauthProvider,
    this.refreshToken,
    this.cardDavEnabled = false,
    this.cardDavUrl,
    this.calDavEnabled = false,
    this.calDavUrl,
  }) : imapSecurity =
           imapSecurity ??
           (type == AccountType.pop3
               ? (imapPort == 110 ? MailSecurity.startTls : MailSecurity.ssl)
               : (imapPort == 143 ? MailSecurity.startTls : MailSecurity.ssl)),
       smtpSecurity = smtpSecurity ?? (smtpPort == 465 ? MailSecurity.ssl : MailSecurity.startTls);

  /// Scelte per [bodyMonths]: mesi, 0 = tutte.
  static const bodyMonthsChoices = [3, 6, 12, 24, 0];
  static const defaultBodyMonths = 12;

  static String bodyMonthsLabel(AppLocalizations l, int months) => months == 0 ? l.bodyMonthsAll : l.bodyMonthsLast(months);

  /// POP3 (scelte 2a e 3a): rimozione dal server dopo 14 giorni, controllo ogni 10 minuti.
  static const defaultRemoveAfterDays = 14;
  static const defaultCheckMinutes = 10;
  static const checkMinutesChoices = [5, 10, 15, 30, 60];

  /// OAuth2 (O2): fornitore ("microsoft") e token di rinnovo, nel portachiavi al posto della password.
  final String? oauthProvider;
  final String? refreshToken;

  bool get usesOAuth => (oauthProvider ?? '').isNotEmpty && (refreshToken ?? '').isNotEmpty;

  /// Sincronizzazione della rubrica con CardDAV (C4c, 1b): spenta di serie. [cardDavUrl] vuoto = il core cerca la
  /// rubrica da solo sul server di ricezione. Non è un dato di connessione della posta: cambiarla non richiede
  /// «Verifica connessione» (c'è «Verifica rubrica», facoltativa).
  final bool cardDavEnabled;
  final String? cardDavUrl;

  /// Sincronizzazione dei calendari con CalDAV (K3): come [cardDavEnabled], spenta di serie, con «Verifica calendario».
  final bool calDavEnabled;
  final String? calDavUrl;

  /// IMAP o POP3; non cambia dopo la creazione (scelta 1a).
  final AccountType type;

  bool get isPop3 => type == AccountType.pop3;

  /// POP3: "Lascia una copia dei messaggi sul server".
  final bool leaveOnServer;

  /// POP3, con [leaveOnServer]: "Rimuovi dal server dopo [removeAfterDays] giorni".
  final bool removeAfter;
  final int removeAfterDays;

  /// POP3, con [leaveOnServer]: "Rimuovi dal server quando eliminati da Posta eliminata".
  final bool removeWhenDeleted;

  /// POP3: ogni quanti minuti controllare la posta.
  final int checkMinutes;

  /// Identificativo interno e stabile (non cambia modificando indirizzo o nome); il core lo usa
  /// nei percorsi /accounts/{id}/...
  final String id;

  /// Nome scelto dall'utente (es. "Lavoro"); vuoto = si mostra l'indirizzo.
  final String name;
  final String email;
  final String password;
  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;

  /// Crittografia (4.1); se non indicata, secondo la porta (come il core).
  final MailSecurity imapSecurity;
  final MailSecurity smtpSecurity;

  /// "Il server di invio richiede l'autenticazione" (4.1, 3a).
  final bool smtpRequireAuth;

  /// Certificati non validi di cui l'utente ha scelto di fidarsi (impronta SHA-256), null = nessuno.
  final String? imapCertificateSha256;
  final String? smtpCertificateSha256;

  /// Almeno un server senza crittografia: password e mail in chiaro (scelta 2a, con conferma).
  bool get hasUnencrypted => imapSecurity == MailSecurity.none || smtpSecurity == MailSecurity.none;

  /// Mail scaricate dal core nella cache locale: arrivate negli ultimi N mesi, 0 = tutte.
  /// Le altre si scaricano solo quando vengono aperte. Non è un dato di connessione: cambiarlo non
  /// richiede una nuova verifica.
  final int bodyMonths;

  String get displayName => name.trim().isEmpty ? email : name.trim();

  /// Id casuale di 8 caratteri esadecimali, diverso da quelli in [existing].
  static String newId([Iterable<String> existing = const []]) {
    final random = Random.secure();
    while (true) {
      final id = List.generate(4, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      if (!existing.contains(id)) return id;
    }
  }

  /// Stessi dati di connessione (quelli che richiedono una verifica): il nome non conta.
  bool sameConnection(AccountConfig other) =>
      type == other.type &&
      oauthProvider == other.oauthProvider &&
      email == other.email &&
      password == other.password &&
      imapHost == other.imapHost &&
      imapPort == other.imapPort &&
      smtpHost == other.smtpHost &&
      smtpPort == other.smtpPort &&
      imapSecurity == other.imapSecurity &&
      smtpSecurity == other.smtpSecurity &&
      smtpRequireAuth == other.smtpRequireAuth &&
      imapCertificateSha256 == other.imapCertificateSha256 &&
      smtpCertificateSha256 == other.smtpCertificateSha256;

  /// Nome, mail scaricate e opzioni POP3 non sono dati di connessione: cambiarli non richiede una verifica.
  AccountConfig copyWith({
    String? id,
    String? name,
    int? bodyMonths,
    bool? leaveOnServer,
    bool? removeAfter,
    int? removeAfterDays,
    bool? removeWhenDeleted,
    int? checkMinutes,
    String? refreshToken,
    bool? cardDavEnabled,
    String? cardDavUrl,
    bool? calDavEnabled,
    String? calDavUrl,
  }) => AccountConfig(
    calDavEnabled: calDavEnabled ?? this.calDavEnabled,
    calDavUrl: calDavUrl == null ? this.calDavUrl : (calDavUrl.trim().isEmpty ? null : calDavUrl.trim()),
    cardDavEnabled: cardDavEnabled ?? this.cardDavEnabled,
    cardDavUrl: cardDavUrl == null ? this.cardDavUrl : (cardDavUrl.trim().isEmpty ? null : cardDavUrl.trim()),
    oauthProvider: oauthProvider,
    refreshToken: refreshToken ?? this.refreshToken,
    id: id ?? this.id,
    type: type,
    name: name ?? this.name,
    bodyMonths: bodyMonths ?? this.bodyMonths,
    leaveOnServer: leaveOnServer ?? this.leaveOnServer,
    removeAfter: removeAfter ?? this.removeAfter,
    removeAfterDays: removeAfterDays ?? this.removeAfterDays,
    removeWhenDeleted: removeWhenDeleted ?? this.removeWhenDeleted,
    checkMinutes: checkMinutes ?? this.checkMinutes,
    email: email,
    password: password,
    imapHost: imapHost,
    imapPort: imapPort,
    smtpHost: smtpHost,
    smtpPort: smtpPort,
    imapSecurity: imapSecurity,
    smtpSecurity: smtpSecurity,
    smtpRequireAuth: smtpRequireAuth,
    imapCertificateSha256: imapCertificateSha256,
    smtpCertificateSha256: smtpCertificateSha256,
  );

  /// Variabili d'ambiente lette dal core per l'account in posizione [index] dell'elenco
  /// (configurazione .NET: "__" separa le sezioni). Come il token, non passano negli argomenti
  /// del processo (visibili con "ps").
  Map<String, String> toCoreEnvironment(int index) {
    final p = 'Accounts__${index}__';
    if (isPop3) {
      return {
        '${p}Id': id,
        '${p}Name': name.trim(),
        '${p}Type': type.coreName,
        '${p}Pop3__Host': imapHost,
        '${p}Pop3__Port': '$imapPort',
        '${p}Pop3__Username': email,
        if (!usesOAuth) '${p}Pop3__Password': password,
        '${p}Pop3__Security': imapSecurity.coreName,
        '${p}Pop3__CertificateSha256': ?imapCertificateSha256,
        '${p}Pop3__LeaveOnServer': '$leaveOnServer',
        '${p}Pop3__RemoveAfterDays': '${removeAfter ? removeAfterDays : 0}',
        '${p}Pop3__RemoveWhenDeleted': '$removeWhenDeleted',
        '${p}Pop3__CheckMinutes': '$checkMinutes',
        ..._smtpEnvironment(p),
        ..._oauthEnvironment(p),
        ..._cardDavEnvironment(p),
      };
    }
    return {
      '${p}Id': id,
      '${p}Name': name.trim(),
      '${p}Imap__Host': imapHost,
      '${p}Imap__Port': '$imapPort',
      '${p}Imap__Username': email,
      if (!usesOAuth) '${p}Imap__Password': password,
      '${p}Smtp__Host': smtpHost,
      '${p}Smtp__Port': '$smtpPort',
      '${p}Smtp__Username': email,
      if (!usesOAuth) '${p}Smtp__Password': password,
      '${p}Cache__BodyMonths': '$bodyMonths',
      '${p}Imap__Security': imapSecurity.coreName,
      '${p}Smtp__Security': smtpSecurity.coreName,
      '${p}Smtp__RequireAuth': '$smtpRequireAuth',
      '${p}Imap__CertificateSha256': ?imapCertificateSha256,
      '${p}Smtp__CertificateSha256': ?smtpCertificateSha256,
      ..._oauthEnvironment(p),
      ..._cardDavEnvironment(p),
    };
  }

  Map<String, String> _cardDavEnvironment(String p) => {
    if (cardDavEnabled) ...{'${p}CardDav__Enabled': 'true', if ((cardDavUrl ?? '').trim().isNotEmpty) '${p}CardDav__Url': cardDavUrl!.trim()},
    if (calDavEnabled) ...{'${p}CalDav__Enabled': 'true', if ((calDavUrl ?? '').trim().isNotEmpty) '${p}CalDav__Url': calDavUrl!.trim()},
  };

  Map<String, String> _oauthEnvironment(String p) => usesOAuth
      ? {'${p}OAuth__Provider': oauthProvider!, '${p}OAuth__RefreshToken': refreshToken!}
      : const {};

  Map<String, String> _smtpEnvironment(String p) => {
    '${p}Smtp__Host': smtpHost,
    '${p}Smtp__Port': '$smtpPort',
    '${p}Smtp__Username': email,
    if (!usesOAuth) '${p}Smtp__Password': password,
    '${p}Smtp__Security': smtpSecurity.coreName,
    '${p}Smtp__RequireAuth': '$smtpRequireAuth',
    '${p}Smtp__CertificateSha256': ?smtpCertificateSha256,
  };

  /// Tutti gli account, nell'ordine dell'elenco (il primo è quello dei percorsi senza account).
  /// Elenco vuoto = nessuna variabile: in sviluppo il core usa gli user-secrets.
  static Map<String, String> coreEnvironment(List<AccountConfig> accounts) => {
    for (final (i, a) in accounts.indexed) ...a.toCoreEnvironment(i),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.coreName,
    'leaveOnServer': leaveOnServer,
    'removeAfter': removeAfter,
    'removeAfterDays': removeAfterDays,
    'removeWhenDeleted': removeWhenDeleted,
    'checkMinutes': checkMinutes,
    'oauthProvider': ?oauthProvider,
    'refreshToken': ?refreshToken,
    'cardDavEnabled': cardDavEnabled,
    'cardDavUrl': ?cardDavUrl,
    'calDavEnabled': calDavEnabled,
    'calDavUrl': ?calDavUrl,
    'name': name,
    'email': email,
    'password': password,
    'imapHost': imapHost,
    'imapPort': imapPort,
    'smtpHost': smtpHost,
    'smtpPort': smtpPort,
    'bodyMonths': bodyMonths,
    'imapSecurity': imapSecurity.coreName,
    'smtpSecurity': smtpSecurity.coreName,
    'smtpRequireAuth': smtpRequireAuth,
    'imapCertificateSha256': ?imapCertificateSha256,
    'smtpCertificateSha256': ?smtpCertificateSha256,
  };

  /// [fallbackId] per la voce del formato a un account, che non aveva id.
  factory AccountConfig.fromJson(Map<String, dynamic> json, {String? fallbackId}) => AccountConfig(
    id: json['id'] as String? ?? fallbackId ?? newId(),
    // Assenti negli account salvati prima della 4.2: IMAP, opzioni POP3 predefinite.
    type: AccountType.fromCore(json['type'] as String?),
    leaveOnServer: json['leaveOnServer'] as bool? ?? true,
    removeAfter: json['removeAfter'] as bool? ?? true,
    removeAfterDays: json['removeAfterDays'] as int? ?? defaultRemoveAfterDays,
    removeWhenDeleted: json['removeWhenDeleted'] as bool? ?? false,
    checkMinutes: json['checkMinutes'] as int? ?? defaultCheckMinutes,
    oauthProvider: json['oauthProvider'] as String?,
    refreshToken: json['refreshToken'] as String?,
    // Assenti negli account salvati prima del C4c: sincronizzazione dei contatti spenta.
    cardDavEnabled: json['cardDavEnabled'] as bool? ?? false,
    cardDavUrl: json['cardDavUrl'] as String?,
    calDavEnabled: json['calDavEnabled'] as bool? ?? false,
    calDavUrl: json['calDavUrl'] as String?,
    name: json['name'] as String? ?? '',
    email: json['email'] as String,
    password: json['password'] as String,
    imapHost: json['imapHost'] as String,
    imapPort: json['imapPort'] as int,
    smtpHost: json['smtpHost'] as String,
    smtpPort: json['smtpPort'] as int,
    // Assente negli account salvati prima dell'8b-3.
    bodyMonths: json['bodyMonths'] as int? ?? defaultBodyMonths,
    // Assenti negli account salvati prima della 4.1: secondo la porta (allora 993 TLS, 587 STARTTLS).
    imapSecurity: MailSecurity.fromCore(json['imapSecurity'] as String?),
    smtpSecurity: MailSecurity.fromCore(json['smtpSecurity'] as String?),
    smtpRequireAuth: json['smtpRequireAuth'] as bool? ?? true,
    imapCertificateSha256: json['imapCertificateSha256'] as String?,
    smtpCertificateSha256: json['smtpCertificateSha256'] as String?,
  );
}

/// Dove conservare gli account: portachiavi di sistema nell'app, memoria nei test.
abstract interface class AccountStore {
  Future<List<AccountConfig>> load();
  Future<void> save(List<AccountConfig> accounts);
}

/// Portachiavi di sistema (Linux: libsecret -> gnome-keyring/KWallet; Windows: archivio protetto; macOS: Portachiavi).
/// Tutti gli account stanno in una sola voce cifrata, password comprese: si salvano sempre insieme,
/// quindi non possono restare a metà (es. elenco aggiornato ma password mancante).
class SecureAccountStore implements AccountStore {
  static const _key = 'postinovip.accounts';

  /// Voce del formato a un account (fino al punto 7a): convertita al primo avvio.
  static const _legacyKey = 'postinovip.account';

  // macOS: portachiavi classico (usesDataProtectionKeychain: false), come consiglia il README del pacchetto per le
  // app senza condivisione del portachiavi: quello «data protection» chiede il permesso keychain-access-groups e
  // quindi un profilo di provisioning Apple. Le altre piattaforme ignorano mOptions.
  final _storage = const FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false));

  @override
  Future<List<AccountConfig>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw != null) {
      try {
        return [for (final j in jsonDecode(raw) as List) AccountConfig.fromJson(j as Map<String, dynamic>)];
      } on Object {
        debugPrint('[account] elenco nel portachiavi illeggibile: si ripropone la configurazione');
        return [];
      }
    }
    return _migrateLegacy();
  }

  Future<List<AccountConfig>> _migrateLegacy() async {
    final legacy = await _storage.read(key: _legacyKey);
    if (legacy == null) return [];
    try {
      final account = AccountConfig.fromJson(jsonDecode(legacy) as Map<String, dynamic>);
      // Prima si scrive il formato nuovo, poi si toglie il vecchio: in caso di errore a metà
      // la voce vecchia resta e la conversione verrà rifatta.
      await save([account]);
      await _storage.delete(key: _legacyKey);
      debugPrint('[account] voce a un account convertita in elenco');
      return [account];
    } on Object {
      return [];
    }
  }

  @override
  Future<void> save(List<AccountConfig> accounts) =>
      _storage.write(key: _key, value: jsonEncode([for (final a in accounts) a.toJson()]));
}

class MemoryAccountStore implements AccountStore {
  MemoryAccountStore([List<AccountConfig>? accounts]) : accounts = [...?accounts];

  List<AccountConfig> accounts;

  @override
  Future<List<AccountConfig>> load() async => [...accounts];

  @override
  Future<void> save(List<AccountConfig> accounts) async => this.accounts = [...accounts];
}
