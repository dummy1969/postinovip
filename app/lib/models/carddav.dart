import '../l10n/core_errors.dart';

/// Stato della sincronizzazione CardDAV della rubrica di un account (C4c, GET …/contacts/sync).
class CardDavStatus {
  const CardDavStatus({
    required this.enabled,
    required this.state,
    this.lastSync,
    this.error,
    this.needsConfirmation = false,
    this.pendingUpload = 0,
    this.addressBook,
    this.errorCode,
  });

  static const off = CardDavStatus(enabled: false, state: 'off');

  /// Codice di [error] dal core (L6): la striscia «Accedi di nuovo» lo riconosce da qui.
  final String? errorCode;

  /// false = sincronizzazione non attiva per l'account (rubrica solo sul computer).
  final bool enabled;

  /// "off", "waiting", "syncing", "ok", "offline", "error", "unavailable".
  final String state;
  final DateTime? lastSync;
  final String? error;

  /// Prima volta (2a): [pendingUpload] contatti sono solo sul computer e vanno sul server dopo la conferma.
  final bool needsConfirmation;
  final int pendingUpload;

  /// Nome della rubrica sul server (es. «Contatti»).
  final String? addressBook;

  bool get busy => state == 'waiting' || state == 'syncing';

  factory CardDavStatus.fromJson(Map<String, dynamic> json) => CardDavStatus(
    enabled: json['enabled'] as bool? ?? false,
    state: json['state'] as String? ?? 'off',
    lastSync: json['lastSync'] == null ? null : DateTime.parse(json['lastSync'] as String).toLocal(),
    error: coreErrorText(json['errorCode'] as String?, coreErrorArgs(json['errorArgs']), json['error'] as String?),
    errorCode: json['errorCode'] as String?,
    needsConfirmation: json['needsConfirmation'] as bool? ?? false,
    pendingUpload: json['pendingUpload'] as int? ?? 0,
    addressBook: json['addressBook'] as String?,
  );
}

/// Esito di «Verifica rubrica» (POST /account/test-carddav): rubrica trovata o il motivo.
class CardDavTestResult {
  const CardDavTestResult({required this.ok, this.error, this.addressBook, this.url});

  final bool ok;
  final String? error;
  final String? addressBook;
  final String? url;

  factory CardDavTestResult.fromJson(Map<String, dynamic> json) => CardDavTestResult(
    ok: json['ok'] as bool? ?? false,
    error: json['error'] as String?,
    addressBook: json['addressBook'] as String?,
    url: json['url'] as String?,
  );
}
