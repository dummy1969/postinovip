import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'compose_helpers.dart';
import 'package:postinovip/ui/compose_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'single_account_core.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';

http.Response json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

/// Core finto con un messaggio in INBOX e l'endpoint delle bozze.
/// [quote]: la bozza ha l'anteprima della citazione formattata (core dalla 3.7b).
MockClient fakeCore({required List<Uri> calls, required List<Map<String, dynamic>> sent, bool quote = false}) =>
    MockClient((request) async {
      calls.add(request.url);
      switch (request.url.path) {
        case '/folders':
          return json([{'fullName': 'INBOX', 'name': 'INBOX', 'count': 1}]);
        case '/folders/INBOX/messages':
          return json({
            'total': 1, 'offset': 0, 'limit': 50,
            'items': [{'uid': 9, 'subject': 'Riunione', 'from': 'Mario Rossi', 'date': null, 'seen': true}],
          });
        case '/messages/INBOX/9':
          return json({
            'uid': 9, 'subject': 'Riunione', 'from': 'Mario Rossi', 'to': ['me@example.com'], 'cc': [],
            'date': null, 'textBody': 'Ci vediamo alle 10.', 'htmlBody': null, 'hasRemoteImages': false,
            'attachments': [],
          });
        case '/messages/INBOX/9/draft':
          final mode = request.url.queryParameters['mode'];
          return json({
            'to': mode == 'forward' ? [] : ['"Rossi, Mario" <mario@example.com>'],
            'cc': [],
            'subject': mode == 'forward' ? 'Fwd: Riunione' : 'Re: Riunione',
            'body': '\n\n> Ci vediamo alle 10.',
            'inReplyTo': mode == 'forward' ? null : 'orig@example.com',
            'references': mode == 'forward' ? [] : ['orig@example.com'],
            if (quote) 'quoteHtml': '<p><b>Da:</b> Mario Rossi</p><p>Ci vediamo <i>alle 10</i>.</p>',
          });
        case '/account':
          return json({'address': 'me@example.com'});
        case '/send':
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          return json({'serverResponse': '2.0.0 Ok'});
      }
      return http.Response('{}', 404);
    });

Future<void> openMessage(WidgetTester tester, MockClient core) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(core))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Riunione'));
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(find.widgetWithText(TextFormField, label == 'A' || label == 'Cc' ? '$label…' : label)).controller!.text;

void main() {
  testWidgets('Rispondi: bozza dal core, invio con intestazioni di thread', (tester) async {
    final calls = <Uri>[];
    final sent = <Map<String, dynamic>>[];
    await openMessage(tester, fakeCore(calls: calls, sent: sent));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Rispondi'));
    await tester.pumpAndSettle();

    expect(calls.any((u) => u.path == '/messages/INBOX/9/draft' && u.queryParameters['mode'] == 'reply'), isTrue);
    expect(find.descendant(of: find.byKey(ComposePage.titleKey), matching: find.text('Rispondi')), findsOneWidget);
    expect(fieldText(tester, 'A'), '"Rossi, Mario" <mario@example.com>');
    expect(fieldText(tester, 'Oggetto'), 'Re: Riunione');

    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();

    final body = sent.single;
    expect(body['to'], ['"Rossi, Mario" <mario@example.com>']); // la virgola nel nome non divide
    expect(body['subject'], 'Re: Riunione');
    expect(body['inReplyTo'], 'orig@example.com');
    expect(body['references'], ['orig@example.com']);
    expect(find.textContaining('Messaggio inviato'), findsOneWidget);
  });

  testWidgets('Inoltra: destinatari vuoti, nessuna intestazione di thread', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await openMessage(tester, fakeCore(calls: [], sent: sent));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Inoltra'));
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'A'), '');
    expect(fieldText(tester, 'Oggetto'), 'Fwd: Riunione');

    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'anna@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();

    expect(sent.single['to'], ['anna@example.com']);
    expect(sent.single['inReplyTo'], isNull);
  });

  testWidgets('bozza non modificata si chiude senza conferma', (tester) async {
    await openMessage(tester, fakeCore(calls: [], sent: []));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Rispondi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chiudi (Esc)'));
    await tester.pumpAndSettle();

    expect(find.text('Salvare le modifiche?'), findsNothing);
    expect(find.descendant(of: find.byKey(ComposePage.titleKey), matching: find.text('Rispondi')), findsNothing);
  });

  testWidgets('citazione formattata sotto l\'editor: ripresa dal core all\'invio', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await openMessage(tester, fakeCore(calls: [], sent: sent, quote: true));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Rispondi a tutti'));
    await tester.pumpAndSettle();
    expect(find.byKey(ComposePage.quoteKey), findsOneWidget);
    expect(find.textContaining('Ci vediamo', findRichText: true), findsOneWidget);
    expect(composeEditor(tester).document.toPlainText().trim(), ''); // si scrive sopra, l'editor parte vuoto

    await typeBody(tester, 'Va bene');
    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();

    final body = sent.single;
    expect(body['body'], 'Va bene');
    expect(body['htmlBody'], contains('Va bene'));
    expect(body['quote'], {'account': 'main', 'folder': 'INBOX', 'uid': 9, 'mode': 'replyAll'});
  });

  testWidgets('"Rimuovi citazione": nessuna citazione inviata', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await openMessage(tester, fakeCore(calls: [], sent: sent, quote: true));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Inoltra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rimuovi citazione'));
    await tester.pumpAndSettle();
    expect(find.byKey(ComposePage.quoteKey), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'anna@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();
    expect(sent.single['quote'], isNull);
  });
}
