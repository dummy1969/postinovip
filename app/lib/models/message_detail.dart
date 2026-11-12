import 'attachment_info.dart';
import 'mail_importance.dart';
import 'message_tags.dart';

/// Messaggio completo, come restituito da GET /messages/{folder}/{uid}.
class MessageDetail {
  const MessageDetail({
    required this.uid,
    required this.subject,
    required this.from,
    required this.to,
    required this.cc,
    required this.date,
    required this.textBody,
    required this.htmlBody,
    required this.hasRemoteImages,
    required this.attachments,
    this.tags = MessageTags.none,
    this.fromAddress,
    this.importance = MailImportance.normal,
    this.receiptTo,
    this.receiptHandled = false,
  });

  final int uid;
  final String subject;
  final String from;
  final List<String> to;
  final List<String> cc;
  final DateTime? date;
  final String? textBody;
  /// Già sanificato dal core.
  final String? htmlBody;
  final bool hasRemoteImages;
  final List<AttachmentInfo> attachments;

  /// Contrassegno e categorie (dalla copia sul computer).
  final MessageTags tags;

  /// Indirizzo del mittente ([from] mostra il nome, se c'è): per "Crea regola…".
  final String? fromAddress;

  /// Priorità alta o bassa indicata dal mittente (P1).
  final MailImportance importance;

  /// Il mittente chiede una conferma di lettura a questo indirizzo (R1: solo se è il mittente stesso).
  final String? receiptTo;

  /// Alla richiesta si è già risposto ($MDNSent, o $MDNReceived del server).
  final bool receiptHandled;

  MessageDetail copyWith({MessageTags? tags, bool? receiptHandled}) => MessageDetail(
        uid: uid,
        subject: subject,
        from: from,
        to: to,
        cc: cc,
        date: date,
        textBody: textBody,
        htmlBody: htmlBody,
        hasRemoteImages: hasRemoteImages,
        attachments: attachments,
        tags: tags ?? this.tags,
        fromAddress: fromAddress,
        importance: importance,
        receiptTo: receiptTo,
        receiptHandled: receiptHandled ?? this.receiptHandled,
      );

  factory MessageDetail.fromJson(Map<String, dynamic> json) => MessageDetail(
        uid: json['uid'] as int,
        subject: json['subject'] as String,
        from: json['from'] as String,
        to: (json['to'] as List).cast<String>(),
        cc: (json['cc'] as List).cast<String>(),
        date: json['date'] == null ? null : DateTime.parse(json['date'] as String).toLocal(),
        textBody: json['textBody'] as String?,
        htmlBody: json['htmlBody'] as String?,
        hasRemoteImages: json['hasRemoteImages'] as bool? ?? false,
        attachments: (json['attachments'] as List)
            .map((e) => AttachmentInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        tags: MessageTags.fromJson(json),
        fromAddress: json['fromAddress'] as String?,
        importance: MailImportance.fromJson(json['importance']),
        receiptTo: json['receiptTo'] as String?,
        receiptHandled: json['receiptHandled'] as bool? ?? false,
      );
}
