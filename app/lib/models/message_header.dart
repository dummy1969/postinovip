import 'mail_importance.dart';
import 'message_tags.dart';

/// Intestazione sintetica di un messaggio (voce della lista).
class MessageHeader {
  const MessageHeader({
    required this.uid,
    required this.subject,
    required this.from,
    required this.date,
    required this.seen,
    this.preview,
    this.hasAttachments,
    this.received,
    this.tags = MessageTags.none,
    this.size,
    this.importance = MailImportance.normal,
  });

  final int uid;
  final String subject;
  final String from;

  /// Data dell'intestazione (decisa dal mittente).
  final DateTime? date;
  final bool seen;

  /// Inizio del testo su una riga; null se non ancora noto, vuoto se la mail non ha testo.
  final String? preview;

  /// null se non ancora noto.
  final bool? hasAttachments;

  /// Arrivo sul server: ordine e gruppi della lista, come "Ricevuto" in Outlook.
  final DateTime? received;

  /// Contrassegno e categorie.
  final MessageTags tags;

  /// Dimensione in byte (colonna "Dimensione", 3.9); null se non nota.
  final int? size;

  /// Priorità alta o bassa indicata dal mittente (P1).
  final MailImportance importance;

  /// Data mostrata e usata per i gruppi: l'arrivo, altrimenti la data dell'intestazione.
  DateTime? get listDate => received ?? date;

  MessageHeader copyWith({bool? seen, MessageTags? tags}) => MessageHeader(
    uid: uid,
    subject: subject,
    from: from,
    date: date,
    seen: seen ?? this.seen,
    preview: preview,
    hasAttachments: hasAttachments,
    received: received,
    tags: tags ?? this.tags,
    size: size,
    importance: importance,
  );

  // L'Api invia ISO 8601 con offset; si converte all'ora locale.
  static DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String).toLocal();

  factory MessageHeader.fromJson(Map<String, dynamic> json) => MessageHeader(
    uid: json['uid'] as int,
    subject: json['subject'] as String,
    from: json['from'] as String,
    date: _date(json['date']),
    seen: json['seen'] as bool,
    preview: json['preview'] as String?,
    hasAttachments: json['hasAttachments'] as bool?,
    received: _date(json['received']),
    tags: MessageTags.fromJson(json),
    size: (json['size'] as num?)?.toInt(),
    importance: MailImportance.fromJson(json['importance']),
  );
}
