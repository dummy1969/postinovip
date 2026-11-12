/// Evento dal core (GET /events), sempre relativo a un account:
/// "mailbox-changed" (folder, count), "watch-status" (connected) o "connection-status" (online:
/// false se il server non è raggiungibile e il core usa la copia locale), "contacts-changed" (C4c: la
/// sincronizzazione CardDAV ha cambiato la rubrica, o serve la conferma della prima volta), "calendars-changed" (K3: lo
/// stesso per i calendari con CalDAV).
class MailboxEvent {
  const MailboxEvent({
    required this.type,
    this.account,
    this.folder,
    this.count,
    this.connected,
    this.online,
    this.refreshToken,
    this.needsLogin,
  });

  final String type;

  /// Id dell'account (null solo da un core precedente al multi-account).
  final String? account;
  final String? folder;
  final int? count;
  final bool? connected;
  final bool? online;

  /// "credentials-changed" (OAuth2): nuovo token di rinnovo da salvare nel portachiavi.
  final String? refreshToken;

  /// "login-status" (OAuth2, 2a): true se serve un nuovo accesso.
  final bool? needsLogin;

  factory MailboxEvent.fromJson(Map<String, dynamic> json) => MailboxEvent(
    type: json['type'] as String,
    account: json['account'] as String?,
    folder: json['folder'] as String?,
    count: json['count'] as int?,
    connected: json['connected'] as bool?,
    online: json['online'] as bool?,
    refreshToken: json['refreshToken'] as String?,
    needsLogin: json['needsLogin'] as bool?,
  );
}
