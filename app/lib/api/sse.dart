/// Lettore minimo di Server-Sent Events: raccoglie le righe "data:" fino alla riga vuota
/// che chiude l'evento; le righe che iniziano con ":" sono commenti (ping) e vengono ignorate.
Stream<String> sseData(Stream<String> lines) async* {
  final data = <String>[];
  await for (final line in lines) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield data.join('\n');
      data.clear();
    } else if (line.startsWith(':')) {
      continue;
    } else if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
    // Altri campi SSE (event:, id:, retry:) non sono usati dal core.
  }
  if (data.isNotEmpty) yield data.join('\n');
}
