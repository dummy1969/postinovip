import 'message_header.dart';

/// Una mail di una conversazione con la cartella in cui si trova (può essere un'altra cartella
/// dell'account, ad esempio una propria risposta in Posta inviata: scelta 3.6-1a).
class ConversationMessage {
  const ConversationMessage(this.folder, this.message);

  final String folder;
  final MessageHeader message;

  factory ConversationMessage.fromJson(Map<String, dynamic> json) =>
      ConversationMessage(json['folder'] as String, MessageHeader.fromJson(json['message'] as Map<String, dynamic>));
}

/// Conversazione (3.6): le sue mail dalla più recente. [id] è stabile finché le mail non cambiano.
/// Numero, da leggere e allegati si calcolano dalle mail, così restano giusti dopo letto/sposta/elimina.
class Conversation {
  const Conversation(this.id, this.messages);

  final int id;
  final List<ConversationMessage> messages;

  int get count => messages.length;
  bool get hasUnread => messages.any((m) => !m.message.seen);
  bool get hasAttachments => messages.any((m) => m.message.hasAttachments == true);

  /// Le mail che stanno in [folder], dalla più recente.
  List<MessageHeader> inFolder(String folder) => [
    for (final m in messages)
      if (m.folder == folder) m.message,
  ];

  /// La mail più recente in [folder]: quella mostrata sulla riga della conversazione (l'ordine della
  /// lista segue la mail più recente della conversazione nella cartella aperta).
  MessageHeader? headIn(String folder) => messages.where((m) => m.folder == folder).firstOrNull?.message;

  /// Mail di [folder] con UID in [uids] cambiate da [change].
  Conversation patch(String folder, Set<int> uids, MessageHeader Function(MessageHeader m) change) => Conversation(id, [
    for (final m in messages)
      m.folder == folder && uids.contains(m.message.uid) ? ConversationMessage(folder, change(m.message)) : m,
  ]);

  /// Senza le mail di [folder] con UID in [uids].
  Conversation without(String folder, Set<int> uids) => Conversation(id, [
    for (final m in messages)
      if (!(m.folder == folder && uids.contains(m.message.uid))) m,
  ]);

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(json['id'] as int, [
    for (final m in json['messages'] as List) ConversationMessage.fromJson(m as Map<String, dynamic>),
  ]);
}

/// Una pagina di conversazioni; [total] è il numero di conversazioni con almeno una mail nella cartella.
class ConversationPage {
  const ConversationPage({required this.total, required this.offset, required this.limit, required this.items});

  final int total;
  final int offset;
  final int limit;
  final List<Conversation> items;

  factory ConversationPage.fromJson(Map<String, dynamic> json) => ConversationPage(
    total: json['total'] as int,
    offset: json['offset'] as int,
    limit: json['limit'] as int,
    items: [for (final c in json['items'] as List) Conversation.fromJson(c as Map<String, dynamic>)],
  );
}
