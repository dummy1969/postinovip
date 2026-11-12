/// Conversione grezza HTML -> testo, solo come ripiego per le mail senza parte text/plain
/// finché non c'è un vero rendering HTML (step 5b). Non interpreta CSS né tabelle.
String htmlToText(String html) {
  var s = html;

  // Blocchi il cui contenuto non è testo visibile.
  s = s.replaceAll(RegExp(r'<(script|style|head)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true), '');
  s = s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  // A capo per gli elementi di blocco più comuni.
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</(p|div|tr|li|h[1-6]|table|blockquote)>', caseSensitive: false), '\n');

  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = _decodeEntities(s);

  // Spazi multipli e righe vuote ripetute.
  s = s.replaceAll(RegExp(r'[ \t ]+'), ' ');
  s = s.replaceAll(RegExp(r' *\n *'), '\n');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

String _decodeEntities(String s) {
  const named = {
    'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ',
    'egrave': 'è', 'eacute': 'é', 'agrave': 'à', 'ograve': 'ò', 'ugrave': 'ù', 'igrave': 'ì',
    'euro': '€', 'copy': '©', 'reg': '®', 'hellip': '…', 'laquo': '«', 'raquo': '»',
  };
  return s.replaceAllMapped(RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'), (m) {
    final e = m[1]!;
    if (e.startsWith('#x') || e.startsWith('#X')) {
      final code = int.tryParse(e.substring(2), radix: 16);
      return code == null ? m[0]! : String.fromCharCode(code);
    }
    if (e.startsWith('#')) {
      final code = int.tryParse(e.substring(1));
      return code == null ? m[0]! : String.fromCharCode(code);
    }
    return named[e.toLowerCase()] ?? m[0]!;
  });
}
