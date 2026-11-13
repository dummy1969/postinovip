import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show Attribute, ChangeSource;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/compose/rich_text.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/ribbon_parts.dart';

import 'compose_helpers.dart';
import 'single_account_core.dart';

// Formato del messaggio HTML / Testo normale (13/11/2026, scelte 1a 2a 3a 4a).

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

/// Core finto: una mail di solo testo in INBOX (bozza di risposta con plainText), registra i POST /send.
MockClient _core(List<Map<String, dynamic>> sent) => MockClient((request) async {
  switch (request.url.path) {
    case '/folders':
      return _json([
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 1},
      ]);
    case '/folders/INBOX/messages':
      return _json({
        'total': 1,
        'offset': 0,
        'limit': 50,
        'items': [
          {'uid': 9, 'subject': 'Riunione', 'from': 'Mario Rossi', 'date': null, 'seen': true},
        ],
      });
    case '/messages/INBOX/9':
      return _json({
        'uid': 9, 'subject': 'Riunione', 'from': 'Mario Rossi', 'to': ['me@example.com'], 'cc': [],
        'date': null, 'textBody': 'Ci vediamo alle 10.', 'htmlBody': null, 'hasRemoteImages': false,
        'attachments': [],
      });
    case '/messages/INBOX/9/draft':
      return _json({
        'to': ['mario@example.com'],
        'cc': [],
        'subject': 'Re: Riunione',
        'body': '\n\nIl giorno Mario Rossi ha scritto:\n> Ci vediamo alle 10.',
        'inReplyTo': 'orig@example.com',
        'references': ['orig@example.com'],
        'quoteHtml': '<p>Ci vediamo alle 10.</p>',
        'plainText': true,
      });
    case '/account':
      return _json({'address': 'me@example.com'});
    case '/send':
      sent.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _json({'serverResponse': '2.0.0 Ok'});
  }
  return http.Response('{}', 404);
});

Future<AppSettings> _start(WidgetTester tester, List<Map<String, dynamic>> sent, {bool plainOption = false}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = AppSettings(MemorySettingsStore());
  await settings.setComposePlainText(plainOption);
  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(_core(sent))), settings: settings));
  await tester.pumpAndSettle();
  return settings;
}

Future<void> _send(WidgetTester tester, {String? to}) async {
  if (to != null) await tester.enterText(find.widgetWithText(TextFormField, 'A…'), to);
  await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
  await tester.pumpAndSettle();
}

final _plainButton = find.byKey(const Key('compose-format-plain'));
final _htmlButton = find.byKey(const Key('compose-format-html'));
bool _selected(WidgetTester tester, Finder f) => tester.widget<RibbonLargeButton>(f).selected;

void main() {
  testWidgets('Formato testo → Testo normale: avviso, formattazione tolta, comandi spenti, invio senza HTML', (
    tester,
  ) async {
    final sent = <Map<String, dynamic>>[];
    await _start(tester, sent);
    await tester.tap(find.text('Nuovo messaggio'));
    await tester.pumpAndSettle();

    await typeBody(tester, 'Importante');
    final editor = composeEditor(tester);
    editor.formatText(0, 10, Attribute.bold);
    await tester.pump();
    await tester.tap(find.text('Formato testo'));
    await tester.pumpAndSettle();
    expect(find.text('Formato'), findsOneWidget);
    expect(_selected(tester, _htmlButton), isTrue); // predefinito HTML

    // Annulla: resta HTML con il grassetto.
    await tester.tap(_plainButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plain-text-confirm')), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(_selected(tester, _htmlButton), isTrue);
    expect(hasFormatting(editor.document), isTrue);

    await tester.tap(_plainButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    expect(_selected(tester, _plainButton), isTrue);
    expect(hasFormatting(editor.document), isFalse);
    expect(editor.document.toPlainText().trim(), 'Importante');
    // Comandi di formato spenti: il Grassetto dalla barra non cambia niente.
    editor.updateSelection(const TextSelection(baseOffset: 0, extentOffset: 4), ChangeSource.local);
    await tester.tap(find.byTooltip('Grassetto (Ctrl+B)').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(hasFormatting(editor.document), isFalse);
    final bold = find.descendant(of: find.byTooltip('Grassetto (Ctrl+B)').first, matching: find.byType(InkWell));
    expect(tester.widget<InkWell>(bold).onTap, isNull);

    // Formattazione arrivata dopo (scorciatoia, incolla): tolta subito.
    editor.updateSelection(const TextSelection(baseOffset: 0, extentOffset: 4), ChangeSource.local);
    editor.formatSelection(Attribute.italic);
    await tester.pumpAndSettle();
    expect(hasFormatting(editor.document), isFalse);

    await tester.enterText(find.widgetWithText(TextFormField, 'Oggetto'), 'S');
    await _send(tester, to: 'a@example.com');
    expect(sent.single['body'], 'Importante');
    expect(sent.single.containsKey('htmlBody'), isFalse); // solo testo
  });

  testWidgets('File → Opzioni «Testo normale»: i messaggi nuovi partono in testo, si torna a HTML senza avviso', (
    tester,
  ) async {
    final sent = <Map<String, dynamic>>[];
    await _start(tester, sent, plainOption: true);
    await tester.tap(find.text('Nuovo messaggio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Formato testo'));
    await tester.pumpAndSettle();
    expect(_selected(tester, _plainButton), isTrue);

    await typeBody(tester, 'Ciao');
    await _send(tester, to: 'a@example.com');
    expect(sent.single.containsKey('htmlBody'), isFalse);

    await tester.tap(find.text('Nuovo messaggio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Formato testo'));
    await tester.pumpAndSettle();
    await tester.tap(_htmlButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plain-text-confirm')), findsNothing);
    await typeBody(tester, 'Ciao');
    await _send(tester, to: 'a@example.com');
    expect(sent.last['htmlBody'], contains('Ciao'));
  });

  testWidgets('risposta a una mail di solo testo: testo normale, citazione come testo, ripresa dal core', (
    tester,
  ) async {
    final sent = <Map<String, dynamic>>[];
    await _start(tester, sent); // opzione HTML: vale il formato dell'originale
    await tester.tap(find.text('Riunione'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Rispondi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('compose-quote-text')), findsOneWidget);
    expect(find.textContaining('> Ci vediamo alle 10.'), findsOneWidget);
    await tester.tap(find.text('Formato testo'));
    await tester.pumpAndSettle();
    expect(_selected(tester, _plainButton), isTrue);

    await typeBody(tester, 'Va bene');
    await _send(tester);
    expect(sent.single['body'], 'Va bene');
    expect(sent.single.containsKey('htmlBody'), isFalse);
    expect(sent.single['quote'], {'account': 'main', 'folder': 'INBOX', 'uid': 9, 'mode': 'reply'});
  });

  testWidgets('File → Opzioni → Posta: «Componi messaggi in questo formato»', (tester) async {
    final settings = await _start(tester, []);
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Posta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-compose-format')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testo normale').last);
    await tester.pumpAndSettle();
    expect(settings.composePlainText, isTrue);
  });
}
