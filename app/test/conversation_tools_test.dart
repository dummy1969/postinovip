import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/ribbon_parts.dart';

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

/// Core finto di Ignora e Pulisci (C2): INBOX con «Offerta» (2) e «Risposta» (3) della stessa conversazione e
/// «Normale» (4); Posta eliminata con «Ignorata» (9), di una conversazione ignorata. Ignora sposta tutta la
/// conversazione della cartella, Pulisci conversazione «Offerta» (citata da «Risposta»), Pulisci cartella pure.
class ConversationCore {
  final sse = StreamController<List<int>>();
  final requests = <String>[];
  final inbox = <int, String>{2: 'Offerta', 3: 'Risposta', 4: 'Normale'};
  final trash = <int, String>{9: 'Ignorata'};
  final ignored = <int>{9};

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = Uri.decodeComponent(request.url.path);
    final raw = utf8.decode(await bodyStream.toBytes());
    final decoded = raw.isEmpty ? null : jsonDecode(raw);
    final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final now = DateTime.now().toUtc().toIso8601String();
    http.StreamedResponse json(Object value, [int code = 200]) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(value))),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    Map<String, dynamic> page(Map<int, String> items) => {
      'total': items.length,
      'offset': 0,
      'limit': 50,
      'items': [
        for (final MapEntry(key: uid, value: subject) in items.entries)
          {'uid': uid, 'subject': subject, 'from': 'Anna', 'date': now, 'received': now, 'seen': true},
      ],
    };
    Map<String, dynamic> folder(String name, int count, [String? role]) =>
        {'fullName': name, 'name': name, 'count': count, 'unread': 0, 'specialUse': role};
    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'io@example.com', 'address': 'io@example.com', 'configured': true, 'online': true},
      ]);
    }
    if (path == '/accounts/a1/folders') {
      return json([folder('INBOX', inbox.length, 'inbox'), folder('Posta eliminata', trash.length, 'trash'), folder('Vecchie', 0)]);
    }
    if (path == '/accounts/a1/folders/INBOX/messages') return json(page(inbox));
    if (path == '/accounts/a1/folders/Posta eliminata/messages') return json(page(trash));
    if (path.endsWith('/messages')) return json(page({}));
    final ignoredQuery = RegExp(r'^/accounts/a1/messages/([^/]+)/(\d+)/ignored$').firstMatch(path);
    if (ignoredQuery != null) return json({'ignored': ignored.contains(int.parse(ignoredQuery[2]!))});
    final detail = RegExp(r'^/accounts/a1/messages/([^/]+)/(\d+)$').firstMatch(path);
    if (detail != null) {
      return json({
        'uid': int.parse(detail[2]!),
        'subject': 'x',
        'from': 'Anna',
        'fromAddress': 'anna@fornitore.it',
        'to': ['io@example.com'],
        'cc': [],
        'date': now,
        'textBody': 'Ciao',
        'attachments': [],
      });
    }
    final command = RegExp(r'^/accounts/a1/(messages|folders)/([^/]+)/(ignore|stop-ignoring|clean-up)$').firstMatch(path);
    if (command != null && request.method == 'POST') {
      final name = command[2]!;
      requests.add('POST ${command[1]}/$name/${command[3]}${body.isEmpty ? '' : ' ${jsonEncode(body)}'}');
      final uids = ((body['uids'] as List?) ?? const []).cast<int>();
      final moved = switch (command[3]) {
        'ignore' when uids.any({2, 3}.contains) => [2, 3], // tutta la conversazione di «Offerta» in INBOX
        'ignore' => uids,
        'stop-ignoring' => [9],
        _ => [if (inbox.containsKey(2) && inbox.containsKey(3)) 2], // «Offerta» è citata da «Risposta»
      };
      for (final u in moved) {
        if (command[3] == 'stop-ignoring') {
          inbox[u] = trash.remove(u)!;
        } else {
          trash[u] = inbox.remove(u)!;
        }
      }
      return json({'movedTo': command[3] == 'stop-ignoring' ? 'INBOX' : 'Posta eliminata', 'permanent': false, 'uids': moved});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

Future<(ConversationCore, AppSettings)> _start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = ConversationCore();
  final settings = AppSettings(MemorySettingsStore());
  await tester.pumpWidget(
    PostinoVipApp(api: ApiClient(httpClient: core.client), settings: settings, windowPresenter: _NoWindow()),
  );
  await tester.pumpAndSettle();
  return (core, settings);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

RibbonSmallButton _small(WidgetTester tester, String key) =>
    tester.widget<RibbonSmallButton>(find.byKey(Key(key)));

void main() {
  testWidgets('Ignora chiede conferma, sposta la conversazione e «Non visualizzare più» vale per la volta dopo', (tester) async {
    final (core, settings) = await _start(tester);
    await _tap(tester, find.text('Offerta'));
    await _tap(tester, find.byKey(const Key('ribbon-ignore')));
    expect(find.byKey(const Key('ignore-dialog')), findsOneWidget);
    await _tap(tester, find.text('Annulla'));
    expect(core.requests, isEmpty); // annullato: niente spostato

    await _tap(tester, find.byKey(const Key('ribbon-ignore')));
    await _tap(tester, find.byKey(const Key('ignore-dont-ask')));
    await _tap(tester, find.byKey(const Key('ignore-ok')));
    expect(core.requests, ['POST messages/INBOX/ignore {"uids":[2]}']);
    expect(find.text('Offerta'), findsNothing);
    expect(find.text('Risposta'), findsNothing); // tutta la conversazione della cartella
    expect(find.textContaining('2 mail spostate in Posta eliminata'), findsOneWidget);
    expect(settings.confirmIgnore, isFalse);

    // La volta dopo nessuna domanda (anche dal tasto destro).
    await _tap(tester, find.text('Normale'));
    await tester.tap(find.text('Normale').first, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('context-ignore')));
    expect(find.byKey(const Key('ignore-dialog')), findsNothing);
    expect(core.requests.last, 'POST messages/INBOX/ignore {"uids":[4]}');
    await core.sse.close();
  });

  testWidgets('in Posta eliminata la conversazione ignorata si riporta in Posta in arrivo', (tester) async {
    final (core, _) = await _start(tester);
    await _tap(tester, find.text('Posta eliminata').last);
    await _tap(tester, find.text('Ignorata'));
    expect(_small(tester, 'ribbon-ignore').label, 'Interrompi Ignora');
    expect(_small(tester, 'ribbon-ignore').tooltip, contains('torna in Posta in arrivo'));
    await _tap(tester, find.byKey(const Key('ribbon-ignore')));
    expect(find.text('Interrompi Ignora conversazione'), findsWidgets); // titolo e pulsante
    await _tap(tester, find.byKey(const Key('ignore-ok')));
    expect(core.requests, ['POST messages/Posta eliminata/stop-ignoring {"uids":[9]}']);
    expect(find.text('Ignorata'), findsNothing);
    expect(find.text('1 mail riportate in Posta in arrivo'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('Pulisci conversazione senza domande, Pulisci cartella dopo la conferma; non in Posta eliminata', (tester) async {
    final (core, _) = await _start(tester);
    await _tap(tester, find.text('Risposta'));
    await _tap(tester, find.byKey(const Key('ribbon-clean-up')));
    await _tap(tester, find.byKey(const Key('clean-up-conversation')));
    expect(core.requests, ['POST messages/INBOX/clean-up {"uids":[3]}']);
    expect(find.text('Offerta'), findsNothing);
    expect(find.text('1 mail superflua spostata in Posta eliminata'), findsOneWidget);
    expect(find.text('Risposta'), findsWidgets); // resta selezionata e aperta
    expect(find.text('Seleziona un messaggio'), findsNothing);

    await _tap(tester, find.byKey(const Key('ribbon-clean-up')));
    await _tap(tester, find.byKey(const Key('clean-up-folder')));
    expect(find.byKey(const Key('clean-up-folder-dialog')), findsOneWidget);
    await _tap(tester, find.text('Annulla'));
    expect(core.requests, hasLength(1));
    await _tap(tester, find.byKey(const Key('ribbon-clean-up')));
    await _tap(tester, find.byKey(const Key('clean-up-folder')));
    await _tap(tester, find.byKey(const Key('clean-up-folder-ok')));
    expect(core.requests.last, 'POST folders/INBOX/clean-up');

    await _tap(tester, find.text('Posta eliminata').last);
    await _tap(tester, find.text('Ignorata'));
    await _tap(tester, find.byKey(const Key('ribbon-clean-up')));
    expect(tester.widget<MenuItemButton>(find.byKey(const Key('clean-up-conversation'))).onPressed, isNull);
    expect(tester.widget<MenuItemButton>(find.byKey(const Key('clean-up-folder'))).onPressed, isNull);
    await core.sse.close();
  });
}
