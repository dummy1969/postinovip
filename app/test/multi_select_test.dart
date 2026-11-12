import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';

/// Core finto con un account ("a1"): INBOX con 5 mail da leggere (UID 1–5, "Mail 1"…), Archivio,
/// Posta eliminata con 2 mail lette. Le richieste in blocco agiscono davvero sull'elenco.
class SelectCore {
  final sse = StreamController<List<int>>();
  final writes = <String>[];
  final mail = <String, List<Map<String, dynamic>>>{
    'INBOX': [for (var uid = 5; uid >= 1; uid--) header(uid, 'Mail $uid', seen: false)],
    'Archivio': [],
    'Posta eliminata': [header(9, 'Vecchia 9'), header(8, 'Vecchia 8')],
  };

  static Map<String, dynamic> header(int uid, String subject, {bool seen = true}) => {
    'uid': uid,
    'subject': subject,
    'from': 'Anna',
    'date': null,
    'seen': seen,
    'categories': <int>[],
  };

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = Uri.decodeComponent(request.url.path);
    final text = await bodyStream.bytesToString();
    final body = text.isEmpty ? null : jsonDecode(text) as Map<String, dynamic>;
    http.StreamedResponse json(Object value, [int status = 200]) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(value))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'io@example.com', 'address': 'io@example.com', 'configured': true, 'online': true},
      ]);
    }
    if (path == '/accounts/a1/folders') {
      return json([
        for (final MapEntry(key: name, value: items) in mail.entries)
          {
            'fullName': name,
            'name': name.split('/').last,
            'count': items.length,
            'unread': items.where((m) => m['seen'] != true).length,
            if (name == 'INBOX') 'specialUse': 'inbox',
            if (name == 'Posta eliminata') 'specialUse': 'trash',
          },
      ]);
    }
    final list = RegExp(r'^/accounts/a1/folders/(.+)/messages$').firstMatch(path);
    if (list != null) {
      final items = mail[list[1]!]!;
      return json({'total': items.length, 'offset': 0, 'limit': 50, 'items': items});
    }
    final detail = RegExp(r'^/accounts/a1/messages/(.+)/(\d+)$').firstMatch(path);
    if (detail != null && request.method == 'GET') {
      return json({
        'uid': int.parse(detail[2]!),
        'subject': 'x',
        'from': 'Anna',
        'to': [],
        'cc': [],
        'date': null,
        'textBody': 'testo',
        'htmlBody': null,
        'hasRemoteImages': false,
        'attachments': [],
      });
    }

    if (path == '/accounts/a1/search') return json({'total': 0, 'offset': 0, 'limit': 50, 'items': []});
    // Posta in uscita (3.8): non serve a queste prove, come un core senza cache locale.
    if (path == '/accounts/a1/outbox') return json({}, 404);
    // Risposte automatiche: spente (le legge l'app all'avvio per la barra gialla).
    if (path == '/accounts/a1/autoreply') return json({'enabled': false, 'html': '', 'text': '', 'active': false});
    // Completamento degli indirizzi (C3): nessun suggerimento (sola lettura, non è una scrittura).
    if (path == '/addresses/suggest') return json({'items': []});
    // Ignora conversazione (C2): in Posta eliminata l'app chiede se la conversazione è ignorata (sola lettura).
    if (request.method == 'GET' && path.endsWith('/ignored')) return json({'ignored': false});
    writes.add('${request.method} $path $text');
    // Sposta cartella (3.5c): la cartella e le sottocartelle cambiano nome, le mail restano.
    final moveFolder = RegExp(r'^/accounts/a1/folders/(.+)/move$').firstMatch(path);
    if (moveFolder != null) {
      final from = moveFolder[1]!;
      final parent = body!['parent'] as String?;
      final to = [?parent, from.split('/').last].join('/');
      final renamed = {
        for (final MapEntry(:key, :value) in mail.entries)
          (key == from || key.startsWith('$from/') ? to + key.substring(from.length) : key): value,
      };
      mail
        ..clear()
        ..addAll(renamed);
      return json({'fullName': to, 'separator': '/'});
    }
    // Una sola mail (finestra della mail): DELETE …/{uid} in Posta eliminata, POST …/{uid}/move.
    final single = RegExp(r'^/accounts/a1/messages/([^/]+)/(\d+)(/move)?$').firstMatch(path);
    if (single != null && (request.method == 'DELETE' || single[3] != null)) {
      final items = mail[single[1]!]!;
      final found = items.where((m) => m['uid'] == int.parse(single[2]!)).toList();
      final to = single[3] != null ? body!['destination'] as String : 'Posta eliminata';
      items.removeWhere(found.contains);
      mail[to]!.insertAll(0, found);
      return json({'movedTo': to, 'permanent': false});
    }
    final batch = RegExp(r'^/accounts/a1/messages/([^/]+)/(seen|flags|move|delete|copy)$').firstMatch(path);
    if (batch == null) return json({}, 404);
    final folder = batch[1]!;
    final uids = (body!['uids'] as List).cast<int>().toSet();
    final items = mail[folder]!;
    final found = [
      for (final m in items)
        if (uids.contains(m['uid'])) m,
    ];
    switch (batch[2]) {
      case 'seen':
        for (final m in found) {
          m['seen'] = body['seen'];
        }
        return json({
          'uids': [for (final m in found) m['uid']],
          'seen': body['seen'],
        });
      case 'flags':
        for (final m in found) {
          m['categories'] = {
            ...(m['categories'] as List).cast<int>(),
            ...((body['addCategories'] as List?) ?? []),
          }.toList()..sort();
        }
        return json({
          'items': [
            for (final m in found)
              {'uid': m['uid'], 'flagged': false, 'completed': false, 'due': null, 'categories': m['categories']},
          ],
        });
      case 'copy':
        final to = body['destination'] as String;
        mail[to]!.insertAll(0, [for (final m in found) {...m, 'uid': (m['uid'] as int) + 100}]);
        return json({
          'copiedTo': to,
          'uids': [for (final m in found) m['uid']],
        });
      default:
        final permanent = body['permanent'] == true;
        final to = batch[2] == 'move' ? body['destination'] as String : (permanent ? null : 'Posta eliminata');
        items.removeWhere(found.contains);
        if (to != null) mail[to]!.insertAll(0, found);
        return json({
          'movedTo': to,
          'permanent': permanent,
          'uids': [for (final m in found) m['uid']],
        });
    }
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

/// [folders]: cartelle in più (vuote), dopo quelle predefinite.
Future<SelectCore> start(WidgetTester tester, {List<String> folders = const []}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = SelectCore();
  for (final f in folders) {
    core.mail[f] = [];
  }
  // Lettura manuale: aprire una mail non la segna come letta (non conta per queste prove).
  final settings = AppSettings(MemorySettingsStore())..readMode = ReadMode.manual;
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      settings: settings,
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

Future<void> click(WidgetTester tester, String subject, {LogicalKeyboardKey? holding}) async {
  if (holding != null) await tester.sendKeyDownEvent(holding);
  await tester.tap(find.text(subject));
  if (holding != null) await tester.sendKeyUpEvent(holding);
  await tester.pumpAndSettle();
}

/// La riga è evidenziata: la selezione colora lo sfondo del suo Material (trasparente altrimenti).
bool selected(WidgetTester tester, String subject) =>
    tester.widget<Material>(find.ancestor(of: find.text(subject), matching: find.byType(Material)).first).color !=
    Colors.transparent;

void main() {
  testWidgets('Ctrl+clic e Maiusc+clic: più mail selezionate, riquadro di lettura con il numero', (tester) async {
    final core = await start(tester);

    await click(tester, 'Mail 5');
    expect(find.text('testo'), findsOneWidget); // una sola: aperta
    await click(tester, 'Mail 3', holding: LogicalKeyboardKey.controlLeft);
    expect(find.text('2 elementi selezionati'), findsOneWidget);
    expect(
      [
        for (final n in [5, 4, 3]) selected(tester, 'Mail $n'),
      ],
      [true, false, true],
    );

    // Maiusc+clic: dall'ultima cliccata (Mail 3) fino a Mail 1.
    await click(tester, 'Mail 1', holding: LogicalKeyboardKey.shiftLeft);
    expect(find.text('3 elementi selezionati'), findsOneWidget);
    expect(
      [
        for (final n in [5, 4, 3, 2, 1]) selected(tester, 'Mail $n'),
      ],
      [false, false, true, true, true],
    );

    // Ctrl+clic su una selezionata la toglie; con una sola rimasta... ne restano due.
    await click(tester, 'Mail 2', holding: LogicalKeyboardKey.controlLeft);
    expect(find.text('2 elementi selezionati'), findsOneWidget);

    // Clic semplice: torna una sola, aperta.
    await click(tester, 'Mail 4');
    expect(find.text('testo'), findsOneWidget);
    expect(core.writes, isEmpty);
    await core.sse.close();
  });

  testWidgets('in blocco: segna come letto, categoria, sposta (una richiesta per cartella)', (tester) async {
    final core = await start(tester);

    await click(tester, 'Mail 5');
    await click(tester, 'Mail 3', holding: LogicalKeyboardKey.shiftLeft);
    expect(find.text('3 elementi selezionati'), findsOneWidget);

    await tester.tap(find.text('Segna come letto'));
    await tester.pumpAndSettle();
    expect(core.writes.last, 'PUT /accounts/a1/messages/INBOX/seen {"uids":[3,4,5],"seen":true}');
    expect(find.text('3 mail segnate come lette'), findsOneWidget);
    expect(find.text('Elementi: 5      Da leggere: 2'), findsOneWidget);
    expect(find.text('Segna come non letto'), findsOneWidget); // tutte lette: il comando si inverte

    await tester.tap(find.text('Categorizza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categoria rossa'));
    await tester.pumpAndSettle();
    expect(core.writes.last, 'PUT /accounts/a1/messages/INBOX/flags {"uids":[3,4,5],"addCategories":[1]}');

    await tester.tap(find.text('Sposta').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Archivio'));
    await tester.pumpAndSettle();
    expect(core.writes.last, 'POST /accounts/a1/messages/INBOX/move {"uids":[3,4,5],"destination":"Archivio"}');
    expect(find.text('3 mail spostate in "Archivio"'), findsOneWidget);
    expect(find.text('Mail 5'), findsNothing);
    expect(find.text('Seleziona un messaggio'), findsOneWidget);
    expect(find.text('Elementi: 2      Da leggere: 2'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('tasto destro: su una selezionata tiene la selezione; Elimina in blocco', (tester) async {
    final core = await start(tester);

    await click(tester, 'Mail 5');
    await click(tester, 'Mail 4', holding: LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Mail 4'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('2 elementi selezionati'), findsOneWidget);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Elimina'));
    await tester.pumpAndSettle();
    expect(core.writes.last, 'POST /accounts/a1/messages/INBOX/delete {"uids":[4,5],"permanent":false}');
    expect(find.text('2 mail spostate in Posta eliminata'), findsOneWidget);

    // Tasto destro su una non selezionata: seleziona solo quella.
    await click(tester, 'Mail 3');
    await click(tester, 'Mail 2', holding: LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Mail 1'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect([selected(tester, 'Mail 3'), selected(tester, 'Mail 1')], [false, true]);
    await core.sse.close();
  });

  testWidgets('in Posta eliminata: definitiva in blocco solo dopo la conferma che dice quante', (tester) async {
    final core = await start(tester);
    await tester.tap(find.text('Posta eliminata').last);
    await tester.pumpAndSettle();

    await click(tester, 'Vecchia 9');
    await click(tester, 'Vecchia 8', holding: LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Elimina definitivamente'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 mail selezionate in Posta eliminata verranno cancellate'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(core.writes, isEmpty);

    await tester.tap(find.text('Elimina definitivamente'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Elimina definitivamente')));
    await tester.pumpAndSettle();
    expect(core.writes.single, 'POST /accounts/a1/messages/Posta eliminata/delete {"uids":[8,9],"permanent":true}');
    expect(find.text('2 mail eliminate definitivamente'), findsOneWidget);
    expect(find.text('Vecchia 9'), findsNothing);
    await core.sse.close();
  });
}
