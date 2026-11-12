/// Divide un campo destinatari in indirizzi: separatori "," e ";", spazi e voci vuote ignorati.
/// I separatori tra virgolette o tra parentesi angolari non dividono, quindi
/// `"Rossi, Mario" <m@x.it>` resta un solo indirizzo.
List<String> splitAddresses(String text) {
  final result = <String>[];
  final current = StringBuffer();
  var inQuotes = false;
  var inAngle = false;

  void flush() {
    final a = current.toString().trim();
    if (a.isNotEmpty) result.add(a);
    current.clear();
  }

  for (final ch in text.split('')) {
    if (ch == '"') inQuotes = !inQuotes;
    if (!inQuotes && ch == '<') inAngle = true;
    if (!inQuotes && ch == '>') inAngle = false;

    if ((ch == ',' || ch == ';') && !inQuotes && !inAngle) {
      flush();
    } else {
      current.write(ch);
    }
  }
  flush();
  return result;
}

/// Controllo rapido lato app; la validazione vera (RFC rigorosa) la fa il core.
String? validateAddressField(String text, {required bool required}) {
  final list = splitAddresses(text);
  if (list.isEmpty) return required ? 'Indicare almeno un destinatario' : null;
  final bad = list.where((a) => !a.contains('@')).toList();
  return bad.isEmpty ? null : 'Indirizzo non valido: ${bad.join(', ')}';
}

/// `Nome <indirizzo>` per un destinatario; il nome va tra virgolette se contiene caratteri speciali.
String formatMailbox(String? name, String address) {
  final n = name?.trim() ?? '';
  if (n.isEmpty || n.toLowerCase() == address.toLowerCase()) return address;
  final quoted = RegExp(r'[",;<>@()\[\]:\\.]').hasMatch(n) ? '"${n.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"' : n;
  return '$quoted <$address>';
}

/// Il destinatario che si sta scrivendo: dall'ultimo separatore (virgola o punto e virgola fuori da
/// virgolette e < >) fino al cursore. [start] è dove comincia, spazi iniziali esclusi.
({int start, String text}) currentRecipient(String text, int cursor) {
  final end = cursor < 0 || cursor > text.length ? text.length : cursor;
  var start = 0;
  var inQuotes = false;
  var inAngle = false;
  for (var i = 0; i < end; i++) {
    final ch = text[i];
    if (ch == '"') inQuotes = !inQuotes;
    if (!inQuotes && ch == '<') inAngle = true;
    if (!inQuotes && ch == '>') inAngle = false;
    if ((ch == ',' || ch == ';') && !inQuotes && !inAngle) start = i + 1;
  }
  while (start < end && text[start] == ' ') {
    start++;
  }
  return (start: start, text: text.substring(start, end));
}

/// Il testo del campo con il destinatario che si sta scrivendo sostituito da [mailbox], seguito da ", ".
String replaceCurrentRecipient(String text, int cursor, String mailbox) {
  final end = cursor < 0 || cursor > text.length ? text.length : cursor;
  final current = currentRecipient(text, end);
  final before = text.substring(0, current.start);
  var after = text.substring(end);
  // Il resto del destinatario dopo il cursore (se si scriveva in mezzo) viene sostituito anch'esso.
  final next = RegExp(r'[,;]').firstMatch(after);
  after = next == null ? '' : after.substring(next.end).trimLeft();
  return '$before$mailbox, $after';
}

/// Gli indirizzi (senza nome) già presenti nel campo, in minuscolo.
Set<String> addressesIn(String text) => {
  for (final a in splitAddresses(text))
    (RegExp(r'<([^>]+)>').firstMatch(a)?.group(1) ?? a).trim().toLowerCase(),
};
