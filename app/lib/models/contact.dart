/// Contatti (C2): stesse strutture del core (`Contacts/Contact.cs`), JSON con gli stessi nomi.
library;

/// Etichette degli indirizzi e dei telefoni, come le scrive il core (null = nessuna).
const emailLabels = {'work': 'Lavoro', 'home': 'Casa', 'other': 'Altro'};
const phoneLabels = {'mobile': 'Cellulare', 'work': 'Ufficio', 'home': 'Casa', 'other': 'Altro'};

class ContactEmail {
  const ContactEmail(this.address, [this.label]);

  final String address;
  final String? label;

  factory ContactEmail.fromJson(Map<String, dynamic> json) =>
      ContactEmail(json['address'] as String, json['label'] as String?);

  Map<String, dynamic> toJson() => {'address': address, 'label': label};
}

class ContactPhone {
  const ContactPhone(this.number, [this.label]);

  final String number;
  final String? label;

  factory ContactPhone.fromJson(Map<String, dynamic> json) =>
      ContactPhone(json['number'] as String, json['label'] as String?);

  Map<String, dynamic> toJson() => {'number': number, 'label': label};
}

class Contact {
  const Contact({
    this.id = '',
    this.name = '',
    this.givenName,
    this.familyName,
    this.displayName,
    this.emails = const [],
    this.phones = const [],
    this.company,
    this.notes,
    this.updated,
  });

  /// Id dato dal core ('' = contatto nuovo, non ancora salvato).
  final String id;

  /// Nome mostrato, calcolato dal core (nome scritto, altrimenti "Nome Cognome", società o indirizzo).
  final String name;
  final String? givenName;
  final String? familyName;
  final String? displayName;
  final List<ContactEmail> emails;
  final List<ContactPhone> phones;
  final String? company;
  final String? notes;
  final DateTime? updated;

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    givenName: json['givenName'] as String?,
    familyName: json['familyName'] as String?,
    displayName: json['displayName'] as String?,
    emails: [for (final e in json['emails'] as List? ?? const []) ContactEmail.fromJson(e as Map<String, dynamic>)],
    phones: [for (final p in json['phones'] as List? ?? const []) ContactPhone.fromJson(p as Map<String, dynamic>)],
    company: json['company'] as String?,
    notes: json['notes'] as String?,
    updated: DateTime.tryParse(json['updated'] as String? ?? ''),
  );

  /// Quello che si manda al core per crearlo o modificarlo (id e nome calcolato li decide il core).
  Map<String, dynamic> toJson() => {
    'givenName': givenName,
    'familyName': familyName,
    'displayName': displayName,
    'emails': [for (final e in emails) e.toJson()],
    'phones': [for (final p in phones) p.toJson()],
    'company': company,
    'notes': notes,
  };

  /// Iniziali per il riquadro rotondo della scheda ("Mario Rossi" -> "MR").
  String get initials {
    final words = name
        .split(RegExp(r'[\s@.]+'))
        .where((w) => w.isNotEmpty && RegExp(r'^\p{L}', unicode: true).hasMatch(w));
    final letters = words.take(2).map((w) => w.characters.first.toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}

/// Esito di un'importazione: aggiunti, già presenti, scartati.
class ContactImportResult {
  const ContactImportResult(this.imported, this.duplicates, this.invalid);

  final int imported;
  final int duplicates;
  final int invalid;

  factory ContactImportResult.fromJson(Map<String, dynamic> json) =>
      ContactImportResult(json['imported'] as int? ?? 0, json['duplicates'] as int? ?? 0, json['invalid'] as int? ?? 0);
}

/// Suggerimento del completamento degli indirizzi (C3).
class AddressSuggestion {
  const AddressSuggestion({
    required this.address,
    this.name,
    required this.source,
    required this.accountId,
    this.contactId,
  });

  final String address;
  final String? name;

  /// "contact" o "recent".
  final String source;
  final String accountId;
  final String? contactId;

  bool get isRecent => source == 'recent';

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) => AddressSuggestion(
    address: json['address'] as String,
    name: json['name'] as String?,
    source: json['source'] as String? ?? 'contact',
    accountId: json['accountId'] as String? ?? '',
    contactId: json['contactId'] as String?,
  );
}

/// Minuscolo e senza accenti, per filtrare l'elenco come fa il core ("nicolo" trova "Nicolò").
String foldText(String s) {
  const from = 'àáâãäåāăąçćčďèéêëēĕėęěìíîïīĭįıñńňòóôõöøōŏőùúûüūŭůűųýÿžźżšśşţťŕřľĺłđ';
  const to = 'aaaaaaaaacccdeeeeeeeeeiiiiiiiinnnooooooooouuuuuuuuuyyzzzsssttrrllld';
  final sb = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = from.indexOf(c);
    sb.write(i >= 0 ? to[i] : c);
  }
  return sb.toString();
}
