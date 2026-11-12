/// Un messaggio trovato dalla ricerca del core (cache locale).
class SearchHit {
  const SearchHit({
    required this.folder,
    required this.uid,
    required this.subject,
    required this.from,
    required this.date,
    required this.seen,
    required this.snippet,
    required this.bodySearched,
    this.fromServer = false,
  });

  /// Inizio e fine delle parole trovate dentro [snippet].
  static const highlightStart = '\u0002';
  static const highlightEnd = '\u0003';

  final String folder;
  final int uid;
  final String subject;
  final String from;
  final DateTime? date;
  final bool seen;

  /// Estratto con le parole trovate tra [highlightStart] e [highlightEnd]; null se si cercava solo per filtri.
  final String? snippet;

  /// false: del messaggio sono state cercate solo le intestazioni (corpo non in cache).
  final bool bodySearched;

  /// Trovato dalla ricerca sul server (mail il cui corpo non è nella cache locale), senza estratto.
  final bool fromServer;

  SearchHit copyWith({bool? seen}) => SearchHit(
    folder: folder,
    uid: uid,
    subject: subject,
    from: from,
    date: date,
    seen: seen ?? this.seen,
    snippet: snippet,
    bodySearched: bodySearched,
    fromServer: fromServer,
  );

  factory SearchHit.fromJson(Map<String, dynamic> json) => SearchHit(
    folder: json['folder'] as String,
    uid: json['uid'] as int,
    subject: json['subject'] as String,
    from: json['from'] as String,
    date: json['date'] == null ? null : DateTime.parse(json['date'] as String).toLocal(),
    seen: json['seen'] as bool,
    snippet: json['snippet'] as String?,
    bodySearched: json['bodySearched'] as bool,
    fromServer: json['fromServer'] as bool? ?? false,
  );
}

/// Una pagina di risultati, dal più recente; [total] = tutti i messaggi trovati.
class SearchPage {
  const SearchPage({required this.total, required this.items});

  final int total;
  final List<SearchHit> items;

  factory SearchPage.fromJson(Map<String, dynamic> json) => SearchPage(
    total: json['total'] as int,
    items: [for (final e in json['items'] as List) SearchHit.fromJson(e as Map<String, dynamic>)],
  );
}
