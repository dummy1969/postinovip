import 'dart:async';
import 'dart:convert';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';

/// Core finto con un account: INBOX da 3 mail di cui 2 da leggere.
class RibbonCore {
  final sse = StreamController<List<int>>();
  final requests = <String>[];

  void push(Map<String, dynamic> e) => sse.add(utf8.encode('data: ${jsonEncode(e)}\n\n'));

  late final client = MockClient.streaming((request, _) async {
    final path = request.url.path;
    requests.add('${request.method} $path');
    http.StreamedResponse json(Object body) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
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
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 3, 'unread': 2, 'specialUse': 'inbox'},
      ]);
    }
    if (path == '/accounts/a1/folders/INBOX/messages') {
      return json({
        'total': 3,
        'offset': 0,
        'limit': 50,
        'items': [
          {'uid': 3, 'subject': 'Terza', 'from': 'Anna', 'date': null, 'seen': false},
          {'uid': 2, 'subject': 'Seconda', 'from': 'Anna', 'date': null, 'seen': false},
          {'uid': 1, 'subject': 'Prima', 'from': 'Anna', 'date': null, 'seen': true},
        ],
      });
    }
    if (path == '/accounts/a1/messages/INBOX/3/seen') return json({'seen': true});
    if (path == '/accounts/a1/messages/INBOX/3') {
      return json({
        'uid': 3,
        'subject': 'Terza',
        'from': 'Anna',
        'to': <String>[],
        'cc': <String>[],
        'date': null,
        'textBody': 'Testo',
        'htmlBody': null,
        'hasRemoteImages': false,
        'attachments': [],
      });
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<RibbonCore> start(WidgetTester tester, {AppSettings? settings}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = RibbonCore();
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

void main() {
  testWidgets('barra di stato: elementi, da leggere, connessione', (tester) async {
    final core = await start(tester);

    expect(find.text('Elementi: 3      Da leggere: 2'), findsOneWidget);
    expect(find.text('Connesso'), findsOneWidget);

    // Aprire una mail non letta la segna come letta: il conteggio scende.
    await tester.tap(find.text('Terza'));
    await tester.pumpAndSettle();
    expect(find.text('Elementi: 3      Da leggere: 1'), findsOneWidget);

    core.push({'type': 'connection-status', 'account': 'a1', 'online': false});
    await tester.pumpAndSettle();
    expect(find.text('Disconnesso'), findsOneWidget);
    expect(
      find.textContaining('Non connesso: mostro la copia sul computer'),
      findsOneWidget,
    ); // striscia sopra la lista
    await core.sse.close();
  });

  testWidgets('barra multifunzione: comprimi ed espandi, scelta ricordata', (tester) async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    final core = await start(tester, settings: settings);
    expect(find.text('Nuovo messaggio'), findsOneWidget);

    // Opzioni di visualizzazione → Mostra solo le schede (V3b: prima un pulsante a sé).
    await tester.tap(find.byKey(const Key('ribbon-display-options')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ribbon-tabs-only')));
    await tester.pumpAndSettle();
    expect(find.text('Nuovo messaggio'), findsNothing); // solo i nomi delle schede
    expect(await store.read('ribbonCollapsed'), 'true');

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Nuovo messaggio'), findsOneWidget); // un clic sulla scheda la riapre

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Nuovo messaggio'), findsNothing); // Ctrl+F1
    await core.sse.close();
  });

  testWidgets('comandi sulla mail disattivati finché non se ne apre una', (tester) async {
    final core = await start(tester);
    InkWell command(String label) =>
        tester.widget<InkWell>(find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first);

    expect(command('Elimina').onTap, isNull);
    expect(command('Rispondi').onTap, isNull);

    await tester.tap(find.text('Terza'));
    await tester.pumpAndSettle();
    expect(command('Elimina').onTap, isNotNull);
    expect(command('Segna come non letto').onTap, isNotNull); // appena aperta: già letta
    await core.sse.close();
  });

  testWidgets('F9 e "Invia/ricevi tutte le cartelle" aggiornano; "Cerca" va nella casella di ricerca', (tester) async {
    final core = await start(tester);
    int folderRequests() => core.requests.where((r) => r == 'GET /accounts/a1/folders').length;
    final before = folderRequests();

    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    expect(folderRequests(), before + 1);

    await tester.tap(find.text('Invia/Ricevi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invia/ricevi tutte le cartelle'));
    await tester.pumpAndSettle();
    expect(folderRequests(), before + 2);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerca').first);
    await tester.pump();
    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Cerca'));
    expect(field.focusNode!.hasFocus, isTrue);
    await core.sse.close();
  });

  testWidgets('barra semplificata (V3b): una riga, comandi piccoli con la sola icona; scelta ricordata', (
    tester,
  ) async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    final core = await start(tester, settings: settings);
    final classic = tester.getSize(find.byKey(const ValueKey('ribbon-panel'))).height;

    await tester.tap(find.byKey(const Key('ribbon-display-options')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ribbon-layout-simplified')));
    await tester.pumpAndSettle();
    expect(settings.ribbonLayout, RibbonLayout.simplified);
    expect(await store.read('ribbonLayout'), 'simplified');
    final panel = find.byKey(const ValueKey('ribbon-panel'));
    expect(tester.getSize(panel).height, lessThan(classic / 2));

    // Comandi grandi: icona e nome sulla stessa riga; piccoli: solo l'icona, il nome nel suggerimento.
    final newMail = find.descendant(of: panel, matching: find.text('Nuovo messaggio'));
    expect(newMail, findsOneWidget);
    final icon = tester.getCenter(find.byIcon(FluentIcons.mail_add_24_regular));
    expect((tester.getCenter(newMail).dy - icon.dy).abs(), lessThan(2));
    expect(find.descendant(of: panel, matching: find.text('Inoltra')), findsNothing);
    expect(find.byTooltip('Inoltra'), findsOneWidget);
    expect(find.descendant(of: panel, matching: find.text('Nuovo')), findsNothing); // niente etichette dei gruppi
    // Il comando funziona ancora: Nuovo messaggio apre la composizione.
    await tester.tap(newMail);
    await tester.pumpAndSettle();
    expect(find.text('Invia'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('ribbon-panel')).last).height, lessThan(classic / 2));

    final again = AppSettings(store);
    await again.load();
    expect(again.ribbonLayout, RibbonLayout.simplified);
    await core.sse.close();
  });
}
