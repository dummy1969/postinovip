import 'dart:async';
import 'dart:convert';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/models/message_tags.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/follow_up.dart';

/// Core finto: "Contratto" contrassegnata entro il 06/11/2025 (data passata: non coincide mai con «oggi») con la categoria blu, "Saluti" senza niente.
/// PUT .../flags applica la richiesta come il core vero e la registra.
class TagsCore {
  final sse = StreamController<List<int>>();
  final puts = <Map<String, dynamic>>[];

  final tags = <int, Map<String, dynamic>>{
    2: {'flagged': true, 'completed': false, 'due': '2025-11-06', 'categories': [5]},
    1: {'flagged': false, 'completed': false, 'due': null, 'categories': <int>[]},
  };

  Map<String, dynamic> _header(int uid, String subject) =>
      {'uid': uid, 'subject': subject, 'from': 'Anna', 'date': null, 'seen': true, ...tags[uid]!};

  late final client = MockClient.streaming((request, bodyStream) async {
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
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 2, 'unread': 0, 'specialUse': 'inbox'},
      ]);
    }
    if (path == '/accounts/a1/folders/INBOX/messages') {
      return json({'total': 2, 'offset': 0, 'limit': 50, 'items': [_header(2, 'Contratto'), _header(1, 'Saluti')]});
    }
    final flags = RegExp(r'^/accounts/a1/messages/INBOX/(\d+)/flags$').firstMatch(path);
    if (flags != null && request.method == 'PUT') {
      final uid = int.parse(flags[1]!);
      final body = jsonDecode(await bodyStream.bytesToString()) as Map<String, dynamic>;
      puts.add({'uid': uid, ...body});
      final t = tags[uid]!;
      switch (body['followUp']) {
        case 'flagged':
          t.addAll({'flagged': true, 'completed': false, 'due': body['due']});
        case 'completed':
          t.addAll({'flagged': false, 'completed': true, 'due': null});
        case 'none':
          t.addAll({'flagged': false, 'completed': false, 'due': null});
      }
      if (body['categories'] != null) t['categories'] = body['categories'];
      return json(t);
    }
    final message = RegExp(r'^/accounts/a1/messages/INBOX/(\d+)$').firstMatch(path);
    if (message != null) {
      final uid = int.parse(message[1]!);
      return json({
        ..._header(uid, uid == 2 ? 'Contratto' : 'Saluti'),
        'to': <String>[],
        'cc': <String>[],
        'textBody': 'Testo $uid',
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

Future<(TagsCore, MemorySettingsStore)> start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = TagsCore();
  final store = MemorySettingsStore();
  await tester.pumpWidget(
    PostinoVipApp(api: ApiClient(httpClient: core.client), settings: AppSettings(store), windowPresenter: _NoWindow()),
  );
  await tester.pumpAndSettle();
  return (core, store);
}

String today() => MessageTags.formatDay(FollowUpChoice.today.dueFrom(DateTime.now())!);

void main() {
  test('scadenze del menu "Completa"', () {
    final wednesday = DateTime(2026, 11, 4, 15, 30);
    final saturday = DateTime(2026, 11, 7, 9);
    String due(FollowUpChoice c, DateTime now) => MessageTags.formatDay(c.dueFrom(now)!);

    expect(due(FollowUpChoice.today, wednesday), '2026-11-04');
    expect(due(FollowUpChoice.tomorrow, wednesday), '2026-11-05');
    expect(due(FollowUpChoice.thisWeek, wednesday), '2026-11-06'); // venerdì
    expect(due(FollowUpChoice.nextWeek, wednesday), '2026-11-13');
    expect(due(FollowUpChoice.thisWeek, saturday), '2026-11-07'); // fine settimana: oggi
    expect(due(FollowUpChoice.nextWeek, saturday), '2026-11-13');
    expect(due(FollowUpChoice.tomorrow, DateTime(2026, 12, 31)), '2027-01-01');
    expect(FollowUpChoice.noDate.dueFrom(wednesday), isNull);
    expect(formatDueDate(DateTime(2026, 11, 5)), 'gio 05/11/2026');
  });

  testWidgets('riga e riquadro di lettura: bandierina, categoria, scadenza', (tester) async {
    final (core, _) = await start(tester);

    expect(find.byIcon(FluentIcons.flag_16_filled), findsOneWidget); // solo "Contratto"
    expect(find.byTooltip('Categoria blu'), findsOneWidget); // quadratino nella riga

    await tester.tap(find.text('Contratto'));
    await tester.pumpAndSettle();
    expect(find.text('Categoria blu'), findsOneWidget); // etichetta nel riquadro di lettura
    expect(find.textContaining('Completare entro gio 06/11/2025'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('clic sulla bandierina: contrassegna per oggi, poi completa', (tester) async {
    final (core, _) = await start(tester);
    final flag = find.byTooltip('Contrassegna per oggi');
    expect(flag, findsOneWidget); // "Saluti", visibile solo passando sopra ma presente

    await tester.tap(flag);
    await tester.pumpAndSettle();
    expect(core.puts.last, {'uid': 1, 'followUp': 'flagged', 'due': today()});
    expect(find.byIcon(FluentIcons.flag_16_filled), findsNWidgets(2));

    await tester.tap(find.byTooltip('Completare entro ${formatDueDate(DateTime.parse(today()))}: clic per completare'));
    await tester.pumpAndSettle();
    expect(core.puts.last, {'uid': 1, 'followUp': 'completed'});
    expect(find.byIcon(FluentIcons.checkmark_16_regular), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('barra multifunzione: Categorizza e Completa sulla mail aperta', (tester) async {
    final (core, _) = await start(tester);
    await tester.tap(find.text('Contratto'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Categorizza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categoria rossa'));
    await tester.pumpAndSettle();
    expect(core.puts.last, {
      'uid': 2,
      'categories': [1, 5],
    });
    expect(find.text('Categoria rossa'), findsOneWidget); // ora anche nel riquadro di lettura

    await tester.tap(find.text('Completa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancella contrassegno'));
    await tester.pumpAndSettle();
    expect(core.puts.last, {'uid': 2, 'followUp': 'none'});
    expect(find.textContaining('Completare entro'), findsNothing);
    await core.sse.close();
  });

  testWidgets('tasto destro: seleziona la mail e apre il menu', (tester) async {
    final (core, _) = await start(tester);

    await tester.tap(find.text('Saluti'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Testo 1'), findsOneWidget); // selezionata e aperta
    expect(find.text('Elimina'), findsNWidgets(3)); // gruppo e comando della barra multifunzione, menu
    expect(find.text('Rispondi a tutti'), findsNWidgets(3)); // barra, riquadro di lettura e menu

    await tester.tap(find.text('Completa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Domani'));
    await tester.pumpAndSettle();
    expect(core.puts.last['followUp'], 'flagged');
    expect(core.puts.last['due'], MessageTags.formatDay(FollowUpChoice.tomorrow.dueFrom(DateTime.now())!));
    await core.sse.close();
  });

  testWidgets('"Tutte le categorie": rinomina, ricordato', (tester) async {
    final (core, store) = await start(tester);
    await tester.tap(find.text('Contratto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categorizza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutte le categorie…'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Categoria blu'), 'Clienti');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('Clienti'), findsOneWidget); // etichetta nel riquadro di lettura
    expect(jsonDecode((await store.read('categoryNames'))!), [
      'Categoria rossa',
      'Categoria arancione',
      'Categoria gialla',
      'Categoria verde',
      'Clienti',
      'Categoria viola',
    ]);
    expect(core.puts, isEmpty); // rinominare non tocca il server
    await core.sse.close();
  });
}
