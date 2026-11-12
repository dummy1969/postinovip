import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/compose_page.dart';
import 'package:postinovip/ui/outbox_view.dart';

import 'compose_helpers.dart';

/// Core finto (3.8): account a1 con INBOX e Bozze (una bozza, UID 7, con un allegato e una citazione),
/// /drafts, /send e la Posta in uscita in memoria.
class DraftCore {
  final sse = StreamController<List<int>>();
  final drafts = <Map<String, dynamic>>[];
  final sent = <Map<String, dynamic>>[];
  final calls = <String>[];
  final outbox = <Map<String, dynamic>>[
    {
      'id': 'aa01',
      'subject': 'In attesa',
      'to': ['anna@example.com'],
      'created': '2026-11-03T10:00:00Z',
      'sendAfter': null,
      'error': null,
    },
  ];
  int _uid = 100;

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = Uri.decodeComponent(request.url.path);
    final text = await bodyStream.bytesToString();
    final decoded = text.isEmpty ? null : jsonDecode(text);
    final body = decoded is Map<String, dynamic> ? decoded : null; // POST senza contenuto: "null"
    calls.add('${request.method} $path');
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
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 0, 'unread': 0, 'specialUse': 'inbox'},
        {'fullName': 'Bozze', 'name': 'Bozze', 'count': 1, 'unread': 0, 'specialUse': 'drafts'},
      ]);
    }
    if (path == '/accounts/a1/folders/INBOX/messages') return json({'total': 0, 'offset': 0, 'limit': 50, 'items': []});
    if (path == '/accounts/a1/folders/Bozze/messages') {
      return json({
        'total': 1,
        'offset': 0,
        'limit': 50,
        'items': [
          {'uid': 7, 'subject': 'Preventivo', 'from': 'io@example.com', 'date': null, 'seen': true},
        ],
      });
    }
    if (path == '/accounts/a1/messages/Bozze/7') {
      return json({
        'uid': 7,
        'subject': 'Preventivo',
        'from': 'io@example.com',
        'to': ['mario@example.com'],
        'cc': [],
        'date': null,
        'textBody': 'Ecco il preventivo',
        'htmlBody': null,
        'hasRemoteImages': false,
        'attachments': [
          {'index': 0, 'fileName': 'offerta.pdf', 'contentType': 'application/pdf'},
        ],
      });
    }
    if (path == '/accounts/a1/messages/Bozze/7/compose') {
      return json({
        'to': ['mario@example.com'],
        'cc': [],
        'subject': 'Re: Preventivo',
        'html': '<p>Ecco il <strong>preventivo</strong></p>',
        'text': '',
        'inReplyTo': 'orig@x',
        'references': ['orig@x'],
        'quoteHtml': '<p><b>Da:</b> Mario</p><p>Mi mandi il preventivo?</p>',
        'attachments': [
          {'index': 0, 'fileName': 'offerta.pdf', 'contentType': 'application/pdf'},
        ],
      });
    }
    if (path == '/accounts/a1/messages/Bozze/7/attachments/0') {
      return http.StreamedResponse(Stream.value([1, 2, 3]), 200, headers: {'content-type': 'application/pdf'});
    }
    if (path == '/accounts/a1/drafts') {
      drafts.add(body!);
      return json({'folder': 'Bozze', 'uid': _uid++, 'pending': false, 'localId': null});
    }
    if (path == '/accounts/a1/send') {
      sent.add(body!);
      final after = body['sendAfter'];
      return json(
        after == null
            ? {'serverResponse': '250 OK'}
            : {'serverResponse': null, 'queued': true, 'outboxId': 'bb02', 'sendAfter': after},
      );
    }
    if (path == '/accounts/a1/outbox') return json(outbox);
    final item = RegExp(r'^/accounts/a1/outbox/([^/]+)(/send|/to-drafts)?$').firstMatch(path);
    if (item != null) {
      if (request.method == 'DELETE' || item[2] == '/to-drafts') outbox.removeWhere((e) => e['id'] == item[1]);
      if (item[2] == '/to-drafts') return json({'folder': 'Bozze', 'uid': 8, 'pending': false, 'localId': null});
      return http.StreamedResponse(const Stream.empty(), request.method == 'DELETE' ? 204 : 202);
    }
    if (path.endsWith('/account')) return json({'address': 'io@example.com', 'configured': true});
    return json({}, 404);
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<DraftCore> start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = DraftCore();
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      settings: AppSettings(MemorySettingsStore())..readMode = ReadMode.manual,
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

Future<void> newMail(WidgetTester tester, {String subject = 'Prova'}) async {
  await tester.tap(find.text('Nuovo messaggio'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Oggetto'), subject);
  await tester.pump();
}

Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> sendConfirmed(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Invia').first);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Ctrl+S salva in Bozze e poi sostituisce la stessa bozza; inviando la bozza si elimina', (tester) async {
    final core = await start(tester);
    await newMail(tester);
    await ctrl(tester, LogicalKeyboardKey.keyS);
    expect(core.drafts.single['subject'], 'Prova');
    expect(core.drafts.single['to'], isEmpty); // una bozza può essere incompleta
    expect(core.drafts.single.containsKey('replace'), isFalse);
    expect(find.textContaining('Bozza salvata alle'), findsOneWidget);

    await typeBody(tester, 'Testo');
    await ctrl(tester, LogicalKeyboardKey.keyS);
    expect(core.drafts.last['replace'], {'uid': 100});

    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'anna@example.com');
    await sendConfirmed(tester);
    expect(core.sent.single['deleteDraft'], {'uid': 101});
    await core.sse.close();
  });

  testWidgets('chiudendo con modifiche: Sì salva, No chiude, Annulla resta; senza modifiche nessuna domanda', (
    tester,
  ) async {
    final core = await start(tester);
    await newMail(tester);
    await tester.tap(find.byTooltip('Chiudi (Esc)'));
    await tester.pumpAndSettle();
    expect(find.text('Salvare le modifiche?'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposePage), findsOneWidget);

    await tester.tap(find.byTooltip('Chiudi (Esc)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sì'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposePage), findsNothing);
    expect(core.drafts.single['subject'], 'Prova');

    await newMail(tester, subject: 'Altro');
    await tester.tap(find.byTooltip('Chiudi (Esc)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'No'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposePage), findsNothing);
    expect(core.drafts, hasLength(1)); // nessun salvataggio

    // Salvata e non più modificata: si chiude senza domanda.
    await newMail(tester, subject: 'Terza');
    await ctrl(tester, LogicalKeyboardKey.keyS);
    await tester.tap(find.byTooltip('Chiudi (Esc)'));
    await tester.pumpAndSettle();
    expect(find.text('Salvare le modifiche?'), findsNothing);
    expect(find.byType(ComposePage), findsNothing);
    await core.sse.close();
  });

  testWidgets('salvataggio automatico ogni 3 minuti, solo con modifiche', (tester) async {
    final core = await start(tester);
    await newMail(tester);
    await tester.pump(ComposePage.autosaveInterval);
    await tester.pumpAndSettle();
    expect(core.drafts, hasLength(1));
    await tester.pump(ComposePage.autosaveInterval); // niente di nuovo: nessun salvataggio
    await tester.pumpAndSettle();
    expect(core.drafts, hasLength(1));
    await core.sse.close();
  });

  testWidgets('Ritarda recapito: la mail va nella Posta in uscita con l\'ora scelta', (tester) async {
    final core = await start(tester);
    await newMail(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'anna@example.com');
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ritarda recapito'));
    await tester.pumpAndSettle();
    expect(find.text('Non recapitare prima del:'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Invia').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Recapito: non prima del'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();

    final after = DateTime.parse(core.sent.single['sendAfter'] as String);
    expect(after.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 50))), isTrue);
    expect(find.textContaining('Messaggio nella Posta in uscita: verrà inviato dopo il'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('Posta in uscita nel riquadro cartelle: elenco, Invia ora, Elimina con conferma', (tester) async {
    final core = await start(tester);
    final row = find.byKey(const ValueKey('outbox:a1'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('[1]')), findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(OutboxView.listKey), findsOneWidget);
    expect(find.text('anna@example.com'), findsOneWidget);
    expect(find.text('In attesa'), findsOneWidget);

    await tester.tap(find.byTooltip('Invia ora'));
    await tester.pumpAndSettle();
    expect(core.calls, contains('POST /accounts/a1/outbox/aa01/send'));

    await tester.tap(find.byTooltip('Elimina (non verrà inviata)'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare la mail?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Elimina'));
    await tester.pumpAndSettle();
    expect(core.calls, contains('DELETE /accounts/a1/outbox/aa01'));
    expect(find.text('Nessuna mail in attesa di invio'), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('[1]')), findsNothing);
    await core.sse.close();
  });

  testWidgets('bozza riaperta da Bozze: testo, citazione e allegato; inviandola la bozza si elimina', (tester) async {
    final core = await start(tester);
    await tester.tap(find.byKey(const ValueKey('folder:a1:Bozze')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preventivo'));
    await tester.pumpAndSettle();
    expect(find.text('Bozza: non ancora inviata.'), findsOneWidget);

    await tester.tap(find.text('Modifica bozza'));
    await tester.pumpAndSettle();
    expect(composeEditor(tester).document.toPlainText().trim(), 'Ecco il preventivo');
    expect(find.byKey(ComposePage.quoteKey), findsOneWidget);
    expect(find.textContaining('offerta.pdf'), findsOneWidget);
    expect(find.text('Salvare le modifiche?'), findsNothing);

    await sendConfirmed(tester);
    final body = core.sent.single;
    expect(body['to'], ['mario@example.com']);
    expect(body['inReplyTo'], 'orig@x');
    expect(body['quote'], {'html': '<p><b>Da:</b> Mario</p><p>Mi mandi il preventivo?</p>'});
    expect(body['deleteDraft'], {'uid': 7});
    expect((body['attachments'] as List).single['fileName'], 'offerta.pdf');
    await core.sse.close();
  });
}
