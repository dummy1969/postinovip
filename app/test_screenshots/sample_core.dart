import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Casella d'esempio per le schermate (V0): persone, indirizzi e mail **inventati** (dominio riservato `.example`),
/// nessuna richiesta che modifichi qualcosa (le scritture rispondono 404 e vengono contate in [writes]).
/// Le date sono relative a [now], così i gruppi della lista (Oggi, Ieri…) e la settimana del calendario sono sempre
/// quelli del giorno in cui si creano le schermate.
class SampleCore {
  SampleCore(this.now);

  final DateTime now;
  final sse = StreamController<List<int>>();
  final writes = <String>[];

  static const _account = 'laura.bianchi@studiolumen.example';

  DateTime _at(int daysAgo, int hour, int minute) =>
      DateTime(now.year, now.month, now.day - daysAgo, hour, minute);

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  late final Map<String, List<Map<String, dynamic>>> _mail = {
    'INBOX': [
      _m(12, 'Marta Conti', 'Bozze della home page, terzo giro',
          'Ciao a tutti, in allegato il terzo giro. La novità principale è la parte alta: un messaggio, un pulsante',
          _at(0, 9, 42), seen: false, attachments: true, categories: [1]),
      _m(11, 'Paolo Russo', 'La revisione del piano trimestrale passa a giovedì',
          'Laura, la revisione del piano si sposta a giovedì alle 15, stessa sala. Porto io i numeri aggiornati',
          _at(0, 9, 5), seen: false, importance: 'high'),
      _m(10, 'Fatturazione Nuvola', 'La fattura di novembre è pronta',
          'La fattura di novembre è pronta. Importo: 49,00 €. Puoi scaricarla dall\'area clienti', _at(0, 8, 10),
          seen: false, attachments: true),
      _m(9, 'Tommaso Greco', 'R: Elenco dei controlli per il rilascio',
          'Ottima osservazione sul passo della firma dell\'installatore. Lo aggiungo all\'elenco', _at(1, 16, 20),
          flagged: true),
      _m(8, 'Elena Marino', 'Note spese entro venerdì',
          'Un promemoria: le note spese di ottobre vanno consegnate entro venerdì', _at(1, 11, 5)),
      _m(7, 'Davide Ricci', 'Commenti sul flusso di primo accesso',
          'Ciao Laura, abbiamo provato il nuovo flusso con cinque persone. Ecco cosa è emerso', _at(2, 14, 48),
          seen: false),
      _m(6, 'Sara Colombo', 'Foto della giornata in sede', 'Ecco le foto di ieri, scegli tu quali mettere nel sito',
          _at(4, 10, 30), attachments: true, categories: [4]),
      _m(5, 'Giorgio Esposito', 'Accesso al server di prova',
          'Ti ho dato i permessi sul server di prova, fammi sapere se funziona', _at(8, 9, 15), importance: 'low'),
      _m(4, 'Chiara Lombardi', 'Programma del seminario', 'In allegato il programma definitivo del seminario',
          _at(12, 17, 2)),
      _m(3, 'Notiziario Lumen', 'Le novità di ottobre', 'Questo mese: il nuovo ufficio, tre progetti chiusi e un benvenuto',
          _at(20, 7, 0)),
    ],
    'Bozze': [_m(20, 'Laura Bianchi', 'Proposta per il cliente', 'Gentile cliente, come concordato…', _at(1, 18, 0))],
    'Posta inviata': [
      _m(30, 'Laura Bianchi', 'R: Bozze della home page, secondo giro', 'Grazie Marta, ecco i miei commenti', _at(3, 12, 0)),
    ],
    'Posta eliminata': [],
    'Archivio': [],
    'Posta indesiderata': [_m(40, 'Offerte Imperdibili', 'Hai vinto!', 'Clicca qui', _at(2, 3, 0), seen: false)],
    'Progetti': [],
    'Progetti/Atlas': [
      _m(50, 'Marta Conti', 'Benvenuti nel progetto Atlas', 'Si parte! In breve: una riunione a settimana', _at(30, 9, 0)),
    ],
    'Ricevute': [],
  };

  static const _roles = {
    'INBOX': 'inbox',
    'Bozze': 'drafts',
    'Posta inviata': 'sent',
    'Posta eliminata': 'trash',
    'Archivio': 'archive',
    'Posta indesiderata': 'junk',
  };

  Map<String, dynamic> _m(
    int uid,
    String from,
    String subject,
    String preview,
    DateTime date, {
    bool seen = true,
    bool attachments = false,
    bool flagged = false,
    String importance = 'normal',
    List<int> categories = const [],
  }) => {
    'uid': uid,
    'subject': subject,
    'from': from,
    'date': _iso(date),
    'received': _iso(date),
    'seen': seen,
    'preview': preview,
    'hasAttachments': attachments,
    'flagged': flagged,
    'completed': false,
    'categories': categories,
    'importance': importance,
    'size': 18000 + uid * 1300,
  };

  static const _body = '''
<p>Ciao a tutti,</p>
<p>in allegato il terzo giro delle bozze. La novità principale è la parte alta della pagina: un solo messaggio, un solo
pulsante, e le opinioni dei clienti scendono più in basso.</p>
<p>Due cose su cui vorrei il vostro parere:</p>
<ol>
<li>Il riquadro dei prezzi: tre fasce sono troppe per la prima schermata?</li>
<li>La versione scura: secondo me si legge meglio, secondo Tommaso nasconde l'illustrazione.</li>
</ol>
<p>Le note per ogni schermata sono nel file di testo. Se ci mettiamo d'accordo entro giovedì, venerdì passo tutto a chi
deve realizzarla.</p>
<p>Marta</p>
''';

  Map<String, dynamic> _detail(String folder, int uid) {
    final h = _mail[folder]!.firstWhere((m) => m['uid'] == uid);
    final name = h['from'] as String;
    final address = '${name.toLowerCase().replaceAll(' ', '.')}@studiolumen.example';
    final main = uid == 12;
    return {
      ...h, // uid, oggetto, data, importanza, contrassegni e categorie come nella lista
      'from': '$name <$address>',
      'fromAddress': address,
      'to': ['Laura Bianchi <$_account>', if (main) 'Tommaso Greco <tommaso.greco@studiolumen.example>'],
      'cc': <String>[],
      'textBody': h['preview'],
      'htmlBody': main ? _body : null,
      'hasRemoteImages': false,
      'attachments': [
        if (h['hasAttachments'] == true) {'index': 0, 'fileName': 'note-home-page-terzo-giro.txt', 'contentType': 'text/plain'},
      ],
    };
  }

  /// Appuntamenti della settimana di [now] (lunedì = giorno 0), in ora locale.
  List<Map<String, dynamic>> _events() {
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    Map<String, dynamic> e(String cal, String id, String summary, int day, int h, int m, int minutes,
        {String? location, bool recurring = false}) {
      final start = DateTime(monday.year, monday.month, monday.day + day, h, m);
      return {
        'calendarId': cal, 'eventId': id, 'uid': id, 'recurrenceId': recurring ? _iso(start) : null,
        'start': _iso(start), 'end': _iso(start.add(Duration(minutes: minutes))), 'allDay': false,
        'summary': summary, 'location': location, 'recurring': recurring, 'reminderMinutes': 15,
      };
    }

    final friday = DateTime(monday.year, monday.month, monday.day + 4);
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return [
      e('c1', 'e1', 'Riunione di avvio settimana', 0, 9, 30, 30, location: 'Sala Verde', recurring: true),
      e('c1', 'e2', 'Revisione delle bozze', 1, 11, 0, 60, location: 'Videochiamata'),
      e('c2', 'e3', 'Pranzo con il cliente', 1, 13, 0, 90, location: 'Trattoria al Ponte'),
      e('c1', 'e4', 'Revisione del piano trimestrale', 3, 15, 0, 60, location: 'Sala Grande'),
      e('c1', 'e5', 'Riunione di avvio settimana', 2, 9, 30, 30, location: 'Sala Verde', recurring: true),
      e('c2', 'e6', 'Dentista', 2, 17, 30, 45),
      e('c1', 'e7', 'Consegna del rilascio', 4, 10, 0, 120),
      {
        'calendarId': 'c2', 'eventId': 'e8', 'uid': 'e8', 'recurrenceId': null, 'start': day(friday),
        'end': day(friday), 'allDay': true, 'summary': 'Seminario a Bologna', 'location': null, 'recurring': false,
        'reminderMinutes': null,
      },
    ];
  }

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = Uri.decodeComponent(request.url.path);
    http.StreamedResponse json(Object? value, [int status = 200]) => http.StreamedResponse(
      Stream.value(value == null ? <int>[] : utf8.encode(jsonEncode(value))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (request.method != 'GET') {
      writes.add('${request.method} $path');
      return json({}, 404);
    }
    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/version') return json({'version': 'esempio', 'runtime': '-', 'os': '-'});
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': _account, 'address': _account, 'configured': true, 'online': true, 'calDav': true},
      ]);
    }
    if (path == '/accounts/a1/folders') {
      return json([
        for (final MapEntry(key: name, value: items) in _mail.entries)
          {
            'fullName': name,
            'name': name.split('/').last,
            'count': items.length,
            'unread': items.where((m) => m['seen'] != true).length,
            'specialUse': ?_roles[name],
          },
      ]);
    }
    final list = RegExp(r'^/accounts/a1/folders/(.+)/messages$').firstMatch(path);
    if (list != null) {
      final items = _mail[list[1]!] ?? [];
      return json({'total': items.length, 'offset': 0, 'limit': 50, 'items': items});
    }
    final detail = RegExp(r'^/accounts/a1/messages/(.+)/(\d+)$').firstMatch(path);
    if (detail != null) return json(_detail(detail[1]!, int.parse(detail[2]!)));
    if (path == '/accounts/a1/search') return json({'total': 0, 'offset': 0, 'limit': 50, 'items': []});
    if (path == '/accounts/a1/autoreply') return json({'enabled': false, 'html': '', 'text': '', 'active': false});
    if (path == '/addresses/suggest') return json({'items': []});
    if (path.endsWith('/ignored')) return json({'ignored': false});
    if (path == '/accounts/a1/calendars') {
      return json({
        'items': [
          {'id': 'c1', 'name': 'Calendario', 'synced': true, 'count': 6},
          {'id': 'c2', 'name': 'Personale', 'synced': true, 'count': 2},
        ],
      });
    }
    if (path == '/accounts/a1/calendars/sync') {
      return json({
        'enabled': true, 'state': 'ok', 'lastSync': _iso(now), 'needsConfirmation': false, 'pendingUpload': 0,
        'addressBook': '2 calendari',
      });
    }
    if (path == '/accounts/a1/calendars/events') {
      final from = DateTime.parse(request.url.queryParameters['from']!);
      final to = DateTime.parse(request.url.queryParameters['to']!);
      return json({
        'items': [
          for (final e in _events())
            if (DateTime.parse(e['start'] as String).isBefore(to) && !DateTime.parse(e['end'] as String).isBefore(from)) e,
        ],
        'truncated': false,
      });
    }
    // Il resto (Posta in uscita, contatti, opzioni…): come un core che non lo ha.
    return json({}, 404);
  });
}
