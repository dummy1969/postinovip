import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'single_account_core.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/api/sse.dart';
import 'package:postinovip/main.dart';

Map<String, dynamic> header(int uid, String subject, {bool seen = true}) =>
    {'uid': uid, 'subject': subject, 'from': 'Anna', 'date': null, 'seen': seen};

/// Core finto con /events in streaming: il test spinge gli eventi SSE con [sse]
/// e cambia il contenuto di INBOX modificando [inbox].
class FakeCore {
  final sse = StreamController<List<int>>();
  List<Map<String, dynamic>> inbox = [header(2, 'Seconda'), header(1, 'Prima')];

  void push(Map<String, dynamic> event) => sse.add(utf8.encode('data: ${jsonEncode(event)}\n\n'));

  late final client = MockClient.streaming((request, _) async {
    http.StreamedResponse json(Object body) =>
        http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
    switch (request.url.path) {
      case '/events':
        return http.StreamedResponse(sse.stream, 200, headers: {'content-type': 'text/event-stream'});
      case '/folders':
        return json([
          {
            'fullName': 'INBOX',
            'name': 'INBOX',
            'count': inbox.length,
            'unread': inbox.where((m) => m['seen'] != true).length,
            'specialUse': 'inbox',
          },
        ]);
      case '/folders/INBOX/messages':
        return json({'total': inbox.length, 'offset': 0, 'limit': 50, 'items': inbox});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

/// Numero delle da leggere accanto a INBOX nell'albero; null se non c'è.
String? inboxCount(WidgetTester tester) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(const ValueKey('folder:main:INBOX')), matching: find.byType(Text)),
  );
  return texts.length > 1 ? texts.last.data : null;
}

void main() {
  testWidgets('folder-synced: la lista aperta si rilegge quando il core ha completato la cartella', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final core = FakeCore();
    await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(core.client))));
    await tester.pumpAndSettle();
    expect(find.text('Più vecchia'), findsNothing);

    // Il download in background ha scaricato le intestazioni più vecchie, poi avvisa.
    core.inbox = [...core.inbox, header(0, 'Più vecchia')];
    core.push({'type': 'folder-synced', 'account': 'main', 'folder': 'Altra'}); // altra cartella: niente
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Più vecchia'), findsNothing);
    core.push({'type': 'folder-synced', 'account': 'main', 'folder': 'INBOX'});
    await tester.pump(const Duration(milliseconds: 400)); // oltre il debounce
    await tester.pumpAndSettle();
    expect(find.text('Più vecchia'), findsOneWidget);
    await core.sse.close();
  });

  test('sseData: eventi separati da riga vuota, commenti ignorati', () async {
    final lines = Stream.fromIterable([': connesso', '', 'data: {"a":1}', '', ': ping', '', 'data: x', 'data: y', '']);
    expect(await sseData(lines).toList(), ['{"a":1}', 'x\ny']);
  });

  testWidgets('nuova mail: compare in cima senza premere Aggiorna; rimossa altrove: sparisce', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final core = FakeCore();
    await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(core.client))));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.sync_disabled), findsNothing); // stato non ancora noto

    // Collegamento attivo: nessuna icona (compare solo quando qualcosa non va).
    core.push({'type': 'watch-status', 'account': 'main', 'connected': true});
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.sync_disabled), findsNothing);

    // Arriva una mail: il server la mostra, il core notifica il nuovo conteggio.
    core.inbox = [header(3, 'Nuova', seen: false), ...core.inbox];
    core.push({'type': 'mailbox-changed', 'folder': 'INBOX', 'count': 3});
    await tester.pump(const Duration(milliseconds: 400)); // oltre il debounce
    await tester.pumpAndSettle();

    expect(find.text('Nuova'), findsOneWidget);
    expect(inboxCount(tester), '1'); // da leggere: riletto dal core dopo l'evento
    // In cima alla lista.
    expect(tester.getTopLeft(find.text('Nuova')).dy, lessThan(tester.getTopLeft(find.text('Seconda')).dy));

    // Un altro client elimina "Seconda".
    core.inbox = [core.inbox[0], core.inbox[2]];
    core.push({'type': 'mailbox-changed', 'folder': 'INBOX', 'count': 2});
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Seconda'), findsNothing);
    expect(find.text('Prima'), findsOneWidget);

    // Il core perde la connessione IDLE: avviso accanto all'account, con il motivo nel tooltip.
    core.push({'type': 'watch-status', 'account': 'main', 'connected': false});
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.sync_disabled), findsOneWidget);
    expect(find.byTooltip('Aggiornamento automatico non attivo per me@example.com: '
        'le nuove mail compaiono solo con "Aggiorna"'), findsOneWidget);

    await core.sse.close();
    await tester.pumpAndSettle();
  });
}
