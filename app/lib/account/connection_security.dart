/// Crittografia della connessione con un server (4.1), come il menu "Crittografia" di Outlook.
/// [coreName]: il valore che il core legge (enum `ConnectionSecurity`).
enum MailSecurity {
  ssl('SslOnConnect', 'SSL/TLS'),
  startTls('StartTls', 'STARTTLS'),
  none('None', 'Nessuna');

  const MailSecurity(this.coreName, this.label);

  final String coreName;
  final String label;

  static MailSecurity? fromCore(String? value) {
    for (final s in values) {
      if (s.coreName == value) return s;
    }
    return null;
  }

  /// Proposta per una porta di ricezione IMAP: 143 STARTTLS, il resto SSL/TLS (come il core).
  static MailSecurity defaultForImap(int port) => port == 143 ? startTls : ssl;

  /// Proposta per una porta di invio SMTP: 465 SSL/TLS, il resto STARTTLS (come il core).
  static MailSecurity defaultForSmtp(int port) => port == 465 ? ssl : startTls;

  /// Porte note e la crittografia che usano: cambiando la porta si propone questa (scelta 1a).
  static MailSecurity? forKnownImapPort(int? port) => switch (port) {
    993 => ssl,
    143 => startTls,
    _ => null,
  };

  /// Porta standard di ricezione IMAP per questa crittografia (cambiando la crittografia si propone questa).
  int get imapPort => this == ssl ? 993 : 143;

  /// Porta standard di invio SMTP per questa crittografia.
  int get smtpPort => switch (this) {
    ssl => 465,
    startTls => 587,
    none => 25,
  };

  /// Porta standard di ricezione POP3 per questa crittografia (995 SSL/TLS, altrimenti 110).
  int get pop3Port => this == ssl ? 995 : 110;

  static const standardImapPorts = {993, 143};
  static const standardPop3Ports = {995, 110};

  static MailSecurity? forKnownPop3Port(int? port) => switch (port) {
    995 => ssl,
    110 => startTls,
    _ => null,
  };

  /// Proposta per una porta di ricezione POP3: 110 STARTTLS, il resto SSL/TLS (come il core).
  static MailSecurity defaultForPop3(int port) => port == 110 ? startTls : ssl;
  static const standardSmtpPorts = {465, 587, 25};

  static MailSecurity? forKnownSmtpPort(int? port) => switch (port) {
    465 => ssl,
    587 || 25 => startTls,
    _ => null,
  };
}

/// Tipo di account (4.2): IMAP (mail sul server) o POP3 (mail scaricate sul computer). Non cambia dopo la creazione.
enum AccountType {
  imap('Imap', 'IMAP'),
  pop3('Pop3', 'POP3');

  const AccountType(this.coreName, this.label);

  final String coreName;
  final String label;

  static AccountType fromCore(String? value) => value == pop3.coreName ? pop3 : imap;
}

/// Certificato non valido presentato da un server, da mostrare prima di decidere se fidarsi (4.1, 6a).
class CertificateInfo {
  const CertificateInfo({
    required this.host,
    required this.port,
    required this.subject,
    required this.issuer,
    this.notBefore,
    this.notAfter,
    required this.sha256,
    this.problems = const [],
  });

  final String host;
  final int port;
  final String subject;
  final String issuer;
  final DateTime? notBefore;
  final DateTime? notAfter;

  /// Impronta SHA-256, esadecimale maiuscolo senza separatori.
  final String sha256;
  final List<String> problems;

  /// Impronta leggibile: coppie separate da ":".
  String get formattedSha256 => [for (var i = 0; i + 1 < sha256.length; i += 2) sha256.substring(i, i + 2)].join(':');

  factory CertificateInfo.fromJson(Map<String, dynamic> json) => CertificateInfo(
    host: json['host'] as String? ?? '',
    port: json['port'] as int? ?? 0,
    subject: json['subject'] as String? ?? '',
    issuer: json['issuer'] as String? ?? '',
    notBefore: DateTime.tryParse(json['notBefore'] as String? ?? '')?.toLocal(),
    notAfter: DateTime.tryParse(json['notAfter'] as String? ?? '')?.toLocal(),
    sha256: json['sha256'] as String,
    problems: [for (final p in json['problems'] as List? ?? const []) p as String],
  );
}

/// Esito di "Verifica connessione": errore per server (null = riuscita) e, se la causa è il certificato,
/// il certificato da proporre all'utente.
class AccountTestResult {
  const AccountTestResult({this.imapError, this.smtpError, this.imapCertificate, this.smtpCertificate});

  final String? imapError;
  final String? smtpError;
  final CertificateInfo? imapCertificate;
  final CertificateInfo? smtpCertificate;

  bool get ok => imapError == null && smtpError == null;
}
