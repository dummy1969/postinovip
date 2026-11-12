/// Contrassegno e categorie di un messaggio (3.3). Il contrassegno è \Flagged sul server,
/// "completato" la parola chiave $Completed; la scadenza [due] esiste solo nella copia sul computer.
/// [categories]: numeri da 1 a 6 (vedi ui/categories.dart).
class MessageTags {
  const MessageTags({this.flagged = false, this.completed = false, this.due, this.categories = const []});

  static const none = MessageTags();

  final bool flagged;
  final bool completed;

  /// Solo il giorno (ora locale a mezzanotte).
  final DateTime? due;
  final List<int> categories;

  /// Campi `flagged`, `completed`, `due` (aaaa-mm-gg), `categories`: assenti con un core precedente.
  factory MessageTags.fromJson(Map<String, dynamic> json) {
    final due = json['due'] as String?;
    return MessageTags(
      flagged: json['flagged'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
      due: due == null ? null : DateTime.parse(due),
      categories: (json['categories'] as List?)?.cast<int>() ?? const [],
    );
  }

  /// Giorno nel formato del core (aaaa-mm-gg).
  static String formatDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}
