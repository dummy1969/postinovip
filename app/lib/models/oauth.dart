import '../l10n/core_errors.dart';

/// Accesso OAuth2 (O2): fornitori del core e stato di un accesso in corso.
class OAuthProviderInfo {
  const OAuthProviderInfo({required this.id, required this.name, required this.configured});

  final String id;
  final String name;

  /// Il core ha il client ID: si può mostrare "Accedi con …".
  final bool configured;

  factory OAuthProviderInfo.fromJson(Map<String, dynamic> json) => OAuthProviderInfo(
    id: json['id'] as String,
    name: json['name'] as String? ?? json['id'] as String,
    configured: json['configured'] as bool? ?? false,
  );
}

/// Server proposti dal fornitore dopo l'accesso.
class OAuthServers {
  const OAuthServers({
    required this.imapHost,
    required this.imapPort,
    required this.smtpHost,
    required this.smtpPort,
    required this.pop3Host,
    required this.pop3Port,
  });

  final String imapHost;
  final int imapPort;
  final String smtpHost;
  final int smtpPort;
  final String pop3Host;
  final int pop3Port;

  factory OAuthServers.fromJson(Map<String, dynamic> json) => OAuthServers(
    imapHost: json['imapHost'] as String,
    imapPort: json['imapPort'] as int,
    smtpHost: json['smtpHost'] as String,
    smtpPort: json['smtpPort'] as int,
    pop3Host: json['pop3Host'] as String,
    pop3Port: json['pop3Port'] as int,
  );
}

class OAuthFlowStatus {
  const OAuthFlowStatus({required this.status, this.email, this.refreshToken, this.error, this.servers, this.contacts, this.calendar});

  /// "pending", "done" o "error".
  final String status;
  final String? email;
  final String? refreshToken;
  final String? error;
  final OAuthServers? servers;

  /// Permesso dei contatti concesso (C4d); null se non chiesto.
  final bool? contacts;

  /// Permesso del calendario concesso (G3); null se non chiesto.
  final bool? calendar;

  bool get done => status == 'done';
  bool get failed => status == 'error';

  factory OAuthFlowStatus.fromJson(Map<String, dynamic> json) => OAuthFlowStatus(
    status: json['status'] as String,
    email: json['email'] as String?,
    refreshToken: json['refreshToken'] as String?,
    error: coreErrorText(json['errorCode'] as String?, coreErrorArgs(json['errorArgs']), json['error'] as String?),
    servers: json['servers'] is Map<String, dynamic> ? OAuthServers.fromJson(json['servers'] as Map<String, dynamic>) : null,
    contacts: json['contacts'] as bool?,
    calendar: json['calendar'] as bool?,
  );
}
