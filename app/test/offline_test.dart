import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';

/// Core finto con un account il cui server non è raggiungibile: cartelle e lista dalla copia locale,
/// la mail 2 è in cache e la 1 no (503), le modifiche e l'invio rispondono 503.
class OfflineCore {
  final sse = StreamController<List<int>>();
  final requests = <String>[];
  bool online = false;

  void push(Map<String, dynamic> e) => sse.add(utf8.encode('data: ${jsonEncode(e)}\n\n'));

  late final client = MockClient.streaming((request, _) async {
    final path = request.url.path;
    requests.add('${request.method} $path');
    http.StreamedResponse json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    final notConnected = json({
      'title': 'Non connesso',
      'detail': 'Server non raggiungibile (SocketException: Connection refused).',
    }, 503);

    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'io@example.com', 'address': 'io@example.com', 'configured': true, 'online': online},
      ]);
    }
    if (path == '/accounts/a1/folders') {
      return json([
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 2, 'specialUse': 'inbox'},
        {'fullName': 'Archivio', 'name': 'Archivio', 'count': 0},
      ]);
    }
    if (path.endsWith('/messages') && path.startsWith('/accounts/a1/folders/')) {
      return json({
        'total': 2,
        'offset': 0,
        'limit': 50,
        'items': [
          {'uid': 2, 'subject': 'In cache', 'from': 'Anna', 'date': null, 'seen': false},
          {'uid': 1, 'subject': 'Vecchia', 'from': 'Anna', 'date': null, 'seen': false},
        ],
      });
    }
    if (path == '/accounts/a1/messages/INBOX/2' && request.method == 'GET') {
      return json({
        'uid': 2,
        'subject': 'In cache',
        'from': 'Anna',
        'to': <String>[],
        'cc': <String>[],
        'date': null,
        'textBody': 'Testo salvato sul computer',
        'htmlBody': null,
        'hasRemoteImages': false,
        'attachments': [],
      });
    }
    // Senza connessione il core mette la mail nella Posta in uscita (3.8).
    if (path == '/accounts/a1/send') return json({'serverResponse': null, 'queued': true, 'offlineQueued': true});
    if (path == '/accounts/a1/account' || path == '/account') {
      return json({'address': 'io@example.com', 'configured': true});
    }
    return notConnected; // mail non in cache, letto, sposta, elimina, invio
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<OfflineCore> start(WidgetTester tester, {bool online = false}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = OfflineCore()..online = online;
  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: core.client), windowPresenter: _NoWindow()));
  await tester.pumpAndSettle();
  return core;
}

Finder get offlineBar => find.textContaining('Non connesso: mostro la copia sul computer');

/// Il comando della barra multifunzione con questa etichetta (InkWell; onTap null = disattivato).
InkWell ribbonCommand(WidgetTester tester, String label) =>
    tester.widget<InkWell>(find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first);

T button<T extends Widget>(WidgetTester tester, String label) =>
    tester.widget<T>(find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is T)).first);

void main() {
  testWidgets('senza connessione: barra in alto, lista dalla copia locale', (tester) async {
    final core = await start(tester);

    expect(offlineBar, findsOneWidget);
    expect(find.text('In cache'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('mail in cache: si apre, resta non letta, modifiche disattivate', (tester) async {
    final core = await start(tester);

    await tester.tap(find.text('In cache'));
    await tester.pumpAndSettle();

    expect(find.text('Testo salvato sul computer'), findsOneWidget);
    expect(core.requests, isNot(contains('PUT /accounts/a1/messages/INBOX/2/seen'))); // niente "letto" automatico
    // Comandi della barra multifunzione disattivati, con il motivo nel suggerimento.
    expect(ribbonCommand(tester, 'Elimina').onTap, isNull);
    expect(ribbonCommand(tester, 'Segna come letto').onTap, isNull);
    expect(find.byTooltip('Non disponibile senza connessione al server.'), findsNWidgets(7)); // Elimina, Archivia, Ignora, Sposta, Letto, Categorizza, Completa
    expect(ribbonCommand(tester, 'Categorizza').onTap, isNull);
    expect(button<OutlinedButton>(tester, 'Rispondi').onPressed, isNotNull); // la bozza viene dalla copia locale
    await core.sse.close();
  });

  testWidgets('mail non ancora scaricata: messaggio chiaro', (tester) async {
    final core = await start(tester);

    await tester.tap(find.text('Vecchia'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mail non disponibile senza connessione'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('invio senza connessione (3.8): riepilogo, poi nella Posta in uscita', (tester) async {
    final core = await start(tester);
    await tester.tap(find.text('Nuovo messaggio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'dest@example.com');
    await tester.pump();

    await tester.tap(find.text('Invia'));
    await tester.pumpAndSettle();
    expect(find.text('Inviare il messaggio?'), findsOneWidget); // il riepilogo c'è sempre
    await tester.tap(find.widgetWithText(FilledButton, 'Invia').last);
    await tester.pumpAndSettle();

    expect(core.requests.where((r) => r.endsWith('/send')), hasLength(1));
    expect(find.textContaining('il messaggio è nella Posta in uscita e partirà da solo'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('il server torna raggiungibile: barra tolta, cartelle e lista ricaricate', (tester) async {
    final core = await start(tester);
    final before = core.requests.where((r) => r == 'GET /accounts/a1/folders').length;

    core.online = true;
    core.push({'type': 'connection-status', 'account': 'a1', 'online': true});
    await tester.pumpAndSettle();

    expect(offlineBar, findsNothing);
    expect(core.requests.where((r) => r == 'GET /accounts/a1/folders').length, before + 1);
    await core.sse.close();
  });

  testWidgets('connesso: nessuna barra', (tester) async {
    final core = await start(tester, online: true);
    expect(offlineBar, findsNothing);

    core.push({'type': 'connection-status', 'account': 'a1', 'online': false});
    await tester.pumpAndSettle();
    expect(offlineBar, findsOneWidget);
    await core.sse.close();
  });
}
