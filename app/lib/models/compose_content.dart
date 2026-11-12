import 'attachment_info.dart';
import 'mail_importance.dart';

/// Bozza da riaprire nella composizione (3.8, GET .../messages/{folder}/{uid}/compose): testo scritto ([html],
/// oppure [text] se era solo testo), citazione che stava sotto ([quoteHtml]) e allegati da riprendere.
class ComposeContent {
  const ComposeContent({
    required this.to,
    required this.cc,
    this.bcc = const [],
    this.importance = MailImportance.normal,
    this.readReceipt = false,
    required this.subject,
    this.html,
    this.text = '',
    this.inReplyTo,
    this.references = const [],
    this.quoteHtml,
    this.attachments = const [],
  });

  final List<String> to;
  final List<String> cc;
  final List<String> bcc;

  /// Priorità della bozza (P1).
  final MailImportance importance;

  /// La bozza chiede la conferma di lettura (R2).
  final bool readReceipt;
  final String subject;
  final String? html;
  final String text;
  final String? inReplyTo;
  final List<String> references;
  final String? quoteHtml;
  final List<AttachmentInfo> attachments;

  factory ComposeContent.fromJson(Map<String, dynamic> json) => ComposeContent(
    to: (json['to'] as List).cast<String>(),
    cc: (json['cc'] as List).cast<String>(),
    bcc: (json['bcc'] as List?)?.cast<String>() ?? const [],
    importance: MailImportance.fromJson(json['importance']),
    readReceipt: json['readReceipt'] as bool? ?? false,
    subject: json['subject'] as String,
    html: json['html'] as String?,
    text: json['text'] as String? ?? '',
    inReplyTo: json['inReplyTo'] as String?,
    references: (json['references'] as List).cast<String>(),
    quoteHtml: json['quoteHtml'] as String?,
    attachments: [
      for (final a in (json['attachments'] as List?) ?? const []) AttachmentInfo.fromJson(a as Map<String, dynamic>),
    ],
  );
}
