import 'dart:async';
import 'dart:convert';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
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
import 'package:postinovip/ui/reading_pane.dart';

/// Core finto con un account: una mail di oggi (da leggere, con allegato) e una del 2020 (letta).
class ListCore {
  final sse = StreamController<List<int>>();
  final queries = <String>[];

  static final today = DateTime.now().toUtc().toIso8601String();

  final items = [
    {
      'uid': 2,
      'subject': 'Preventivo',
      'from': 'Anna',
      'date': today,
      'received': today,
      'seen': false,
      'preview': 'Ciao, ti mando il preventivo aggiornato',
      'hasAttachments': true,
    },
    {
      'uid': 1,
      'subject': 'Vecchia',
      'from': 'Bruno',
      'date': '2020-03-01T10:00:00+00:00',
      'received': '2020-03-01T10:00:00+00:00',
      'seen': true,
      'preview': '',
      'hasAttachments': false,
    },
  ];

  late final client = MockClient.streaming((request, _) async {
    final path = request.url.path;
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
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 2, 'unread': 1, 'specialUse': 'inbox'},
      ]);
    }
    if (path == '/accounts/a1/folders/INBOX/messages') {
      final q = request.url.queryParameters;
      if (q['limit'] != '10') queries.add('unread=${q['unread'] ?? '-'} order=${q['order'] ?? '-'}');
      var list = items.where((m) => q['unread'] != 'true' || m['seen'] == false).toList();
      if (q['order'] == 'asc') list = list.reversed.toList();
      return json({'total': list.length, 'offset': 0, 'limit': 50, 'items': list});
    }
    if (path == '/accounts/a1/messages/INBOX/2') {
      return json({
        'uid': 2,
        'subject': 'Preventivo',
        'from': 'Anna',
        'to': ['io@example.com'],
        'cc': [],
        'date': today,
        'textBody': 'Ciao',
        'htmlBody': null,
        'hasRemoteImages': false,
        'attachments': [],
        'importance': 'high',
      });
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<ListCore> start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = ListCore();
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

void main() {
  testWidgets('importanza (P1): «!» rosso e freccia blu nella lista, avviso nella lettura', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final core = ListCore();
    core.items[0]['importance'] = 'high';
    core.items[1]['importance'] = 'low';
    await tester.pumpWidget(
      PostinoVipApp(
        api: ApiClient(httpClient: core.client),
        windowPresenter: _NoWindow(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('importance-high')), findsOneWidget);
    expect(find.byKey(const Key('importance-low')), findsOneWidget);
    expect(find.byKey(const Key('importance-banner')), findsNothing);

    await tester.tap(find.text('Preventivo'));
    await tester.pumpAndSettle();
    expect(find.text('Il messaggio è stato inviato con priorità alta.'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('zoom (P2): cursore nella barra di stato, Ctrl++/-/0, Ctrl+rotella, ricordato', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    final core = ListCore();
    await tester.pumpWidget(
      PostinoVipApp(
        api: ApiClient(httpClient: core.client),
        settings: settings,
        windowPresenter: _NoWindow(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preventivo'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const Key('reading-zoom')), findsNothing);
    final normal = tester.getSize(find.text('Ciao'));

    // Il «+» della tastiera italiana sta sul tasto fisico dopo la «è» (bracketRight negli Stati Uniti).
    Future<void> ctrl(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(
        key,
        physicalKey: key == LogicalKeyboardKey.add ? PhysicalKeyboardKey.bracketRight : null,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await ctrl(LogicalKeyboardKey.add);
    await ctrl(LogicalKeyboardKey.equal);
    expect(find.text('120%'), findsOneWidget);
    expect(await store.read('readingZoom'), '120');
    // Il corpo è disegnato più grande (le intestazioni no: «Preventivo» c'è anche nella lista).
    final zoomed = tester.getRect(find.text('Ciao'));
    expect(zoomed.height, closeTo(normal.height * 1.2, 0.5));

    await ctrl(LogicalKeyboardKey.minus);
    expect(find.text('110%'), findsOneWidget);

    // Ctrl+rotella sul corpo: in su ingrandisce, senza Ctrl scorre soltanto.
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(zoomed.center));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
    await tester.pumpAndSettle();
    expect(find.text('120%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('zoom-out')));
    await tester.pumpAndSettle();
    expect(find.text('110%'), findsOneWidget);
    await ctrl(LogicalKeyboardKey.digit0);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const Key('reading-zoom')), findsNothing);

    // Limiti 50–200 e valore ricordato al riavvio.
    await settings.setReadingZoom(500);
    expect(settings.readingZoom, 200);
    await settings.zoomBy(1);
    expect(settings.readingZoom, 200);
    await settings.setReadingZoom(70);
    final again = AppSettings(store);
    await again.load();
    expect(again.readingZoom, 70);
    await store.write('readingZoom', 'boh');
    await again.load();
    expect(again.readingZoom, 100);
    await core.sse.close();
  });

  testWidgets('riquadro di lettura basso: le intestazioni scorrono invece di traboccare', (tester) async {
    tester.view.physicalSize = const Size(1500, 330);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final core = ListCore();
    await tester.pumpWidget(
      PostinoVipApp(
        api: ApiClient(httpClient: core.client),
        windowPresenter: _NoWindow(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preventivo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // niente «BOTTOM OVERFLOWED»
    final pane = tester.getRect(find.byType(ReadingPane));
    final header = tester.getRect(find.byKey(const Key('reading-header')));
    expect(header.height, lessThanOrEqualTo(pane.height * 0.6 + 0.5));
    await core.sse.close();
  });

  testWidgets('intestazioni (4a): Rispondi/Inoltra sulla riga del mittente se c\'è spazio, sopra se stretto', (
    tester,
  ) async {
    for (final (width, sameRow) in [(1500.0, true), (1150.0, false)]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      final core = ListCore();
      await tester.pumpWidget(
        PostinoVipApp(
          api: ApiClient(httpClient: core.client),
          windowPresenter: _NoWindow(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preventivo'));
      await tester.pumpAndSettle();
      final reply = tester.getCenter(find.byKey(const Key('header-reply')));
      final from = tester.getCenter(find.byKey(const Key('reading-from'))); // V5: nome del mittente, niente «Da:»
      expect((reply.dy - from.dy).abs() < 8, sameRow, reason: 'larghezza $width');
      if (sameRow) expect(reply.dx > from.dx, isTrue); // a destra
      await core.sse.close();
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.reset();
  });

  testWidgets('ricerca nella barra in alto (V2): al centro, al massimo 560, «dove cercare» dentro la casella', (
    tester,
  ) async {
    for (final width in [640.0, 900.0, 1500.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      final core = ListCore();
      await tester.pumpWidget(
        PostinoVipApp(
          api: ApiClient(httpClient: core.client),
          windowPresenter: _NoWindow(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'larghezza $width');
      final bar = tester.getRect(find.byKey(const Key('top-bar')));
      final box = tester.getRect(find.byKey(const Key('search-box')));
      final scope = tester.getRect(find.byKey(const Key('search-scope')));
      expect(box.top >= bar.top && box.bottom <= bar.bottom, isTrue, reason: 'larghezza $width: nella barra in alto');
      expect(box.width, lessThanOrEqualTo(560), reason: 'larghezza $width');
      expect((box.center.dx - width / 2).abs(), lessThan(1), reason: 'larghezza $width: al centro');
      expect(
        scope.left >= box.left && scope.right <= box.right && scope.center.dy - box.center.dy < 2,
        isTrue,
        reason: 'larghezza $width: «dove cercare» dentro la casella',
      );
      await core.sse.close();
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.reset();
  });

  testWidgets('righe con anteprima e graffetta, gruppi per data comprimibili', (tester) async {
    final core = await start(tester);

    expect(find.text('Oggi'), findsOneWidget);
    expect(find.text('Più vecchi'), findsOneWidget);
    expect(find.text('Ciao, ti mando il preventivo aggiornato'), findsOneWidget);
    expect(find.byIcon(FluentIcons.attach_16_regular), findsOneWidget); // solo la mail con allegato

    await tester.tap(find.text('Più vecchi'));
    await tester.pumpAndSettle();
    expect(find.text('Vecchia'), findsNothing); // gruppo chiuso
    expect(find.text('Preventivo'), findsOneWidget);

    await tester.tap(find.text('Più vecchi'));
    await tester.pumpAndSettle();
    expect(find.text('Vecchia'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('filtro "Da leggere" e ordine "più vecchi in cima" chiesti al core', (tester) async {
    final core = await start(tester);
    expect(core.queries, ['unread=- order=-']);

    await tester.tap(find.text('Da leggere'));
    await tester.pumpAndSettle();
    expect(core.queries.last, 'unread=true order=-');
    expect(find.text('Vecchia'), findsNothing);

    await tester.tap(find.text('Tutti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per data: più vecchi in cima'));
    await tester.pumpAndSettle();
    expect(core.queries.last, 'unread=- order=asc');
    // Il gruppo del 2020 ora viene prima di "Oggi".
    expect(tester.getTopLeft(find.text('Più vecchi')).dy, lessThan(tester.getTopLeft(find.text('Oggi')).dy));
    await core.sse.close();
  });
}
