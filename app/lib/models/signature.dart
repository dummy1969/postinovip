/// Firma (3.7c, scelte 7a/8a/9a): nome e contenuto formattato come operazioni dell'editor
/// (formato Delta di flutter_quill, che può contenere immagini "data:"). Solo su questo computer.
class Signature {
  const Signature({required this.id, required this.name, required this.delta});

  /// Identificativo interno stabile (le firme predefinite degli account vi fanno riferimento).
  final String id;
  final String name;

  /// Operazioni del documento (JSON di Delta); termina sempre con un a capo.
  final List<Map<String, dynamic>> delta;

  Signature copyWith({String? name, List<Map<String, dynamic>>? delta}) =>
      Signature(id: id, name: name ?? this.name, delta: delta ?? this.delta);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'delta': delta};

  static Signature? fromJson(Object? json) {
    if (json case {'id': final String id, 'name': final String name, 'delta': final List delta}) {
      final ops = [
        for (final op in delta)
          if (op is Map) Map<String, dynamic>.from(op),
      ];
      if (ops.isEmpty) return null;
      return Signature(id: id, name: name, delta: ops);
    }
    return null;
  }
}

/// Firme predefinite di un account, come in Outlook: per i nuovi messaggi e per risposte e inoltri
/// (null = nessuna).
class SignatureDefaults {
  const SignatureDefaults({this.newMessage, this.reply});

  final String? newMessage;
  final String? reply;

  static const none = SignatureDefaults();

  Map<String, dynamic> toJson() => {'new': newMessage, 'reply': reply};

  static SignatureDefaults fromJson(Object? json) =>
      json is Map ? SignatureDefaults(newMessage: json['new'] as String?, reply: json['reply'] as String?) : none;

  @override
  bool operator ==(Object other) =>
      other is SignatureDefaults && other.newMessage == newMessage && other.reply == reply;

  @override
  int get hashCode => Object.hash(newMessage, reply);
}
