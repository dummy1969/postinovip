import 'message_header.dart';

/// Una pagina di intestazioni; [total] è il numero di messaggi nella cartella.
class MessagePage {
  const MessagePage({
    required this.total,
    required this.offset,
    required this.limit,
    required this.items,
  });

  final int total;
  final int offset;
  final int limit;
  final List<MessageHeader> items;

  factory MessagePage.fromJson(Map<String, dynamic> json) => MessagePage(
        total: json['total'] as int,
        offset: json['offset'] as int,
        limit: json['limit'] as int,
        items: (json['items'] as List)
            .map((e) => MessageHeader.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
