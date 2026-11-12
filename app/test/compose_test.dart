import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' show ChangeSource;
import 'package:flutter_test/flutter_test.dart';

import 'compose_helpers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'single_account_core.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/compose/address_list.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/compose_page.dart';
import 'package:postinovip/ui/ribbon_parts.dart';

/// Core finto per la composizione: registra i POST /send e risponde come l'Api reale.
MockClient fakeCore(List<Map<String, dynamic>> sent, {bool rejectCc = false, String? saveError}) =>
    MockClient((request) async {
      final path = request.url.path;
      if (path == '/folders') return http.Response('[]', 200);
      if (path == '/account') return http.Response(jsonEncode({'address': 'me@example.com'}), 200);
      if (path == '/send') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (rejectCc) {
          return http.Response(
              jsonEncode({
                'title': 'Richiesta non valida',
                'status': 400,
                'errors': {'cc': ['Indirizzo non valido: x@']},
              }),
              400);
        }
        sent.add(body);
        final saved = body['saveCopy'] == true && saveError == null;
        return http.Response(
            jsonEncode({
              'serverResponse': '2.0.0 Ok: queued',
              'savedTo': saved ? 'Posta inviata' : null,
              'saveError': body['saveCopy'] == true ? saveError : null,
            }),
            200);
      }
      return http.Response('{}', 404);
    });

Future<void> openCompose(WidgetTester tester, MockClient core) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(core))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nuovo messaggio'));
  await tester.pumpAndSettle();
}

// A e Cc hanno l'etichetta come pulsante «A…»/«Cc…» (Rubrica, C3).
Finder field(String label) => find.widgetWithText(TextFormField, label == 'A' || label == 'Cc' ? '$label…' : label);

void main() {
  test('splitAddresses e validateAddressField', () {
    expect(splitAddresses(' a@x.it, b@y.it; ,c@z.it '), ['a@x.it', 'b@y.it', 'c@z.it']);
    // Virgola nel nome visualizzato (tra virgolette) e dentro <...>: non divide.
    expect(splitAddresses('"Rossi, Mario" <m@x.it>, b@y.it'), ['"Rossi, Mario" <m@x.it>', 'b@y.it']);
    expect(splitAddresses('Anna <a,b@x.it>'), ['Anna <a,b@x.it>']);
    expect(validateAddressField('', required: true), isNotNull);
    expect(validateAddressField('', required: false), isNull);
    expect(validateAddressField('a@x.it, mario', required: true), contains('mario'));
  });

  testWidgets('invio: conferma, POST con liste to/cc, snackbar di esito', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await openCompose(tester, fakeCore(sent));

    expect(find.text('me@example.com'), findsOneWidget);
    await tester.enterText(field('A'), 'a@example.com, b@example.com');
    await tester.enterText(field('Cc'), 'c@example.com');
    await tester.enterText(field('Oggetto'), 'Prova');
    await typeBody(tester, 'Ciao');

    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    expect(find.text('Inviare il messaggio?'), findsOneWidget);
    expect(sent, isEmpty); // niente invio prima della conferma

    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();

    expect(sent.single, {
      'to': ['a@example.com', 'b@example.com'],
      'cc': ['c@example.com'],
      'bcc': [],
      'subject': 'Prova',
      'body': 'Ciao',
      // Testo formattato (3.7b): HTML con gli stili negli elementi; nessuna citazione in un messaggio nuovo.
      'htmlBody': '<div style="font-family:Calibri, Arial, sans-serif;font-size:11pt"><p style="margin:0">Ciao</p></div>',
      'quote': null,
      'inReplyTo': null, // nuovo messaggio: nessun thread
      'references': [],
      'saveCopy': true, // casella attiva di default
      'attachments': [],
      'forwardAttachments': null,
    });
    expect(find.byType(ComposePage), findsNothing); // pagina chiusa
    expect(find.textContaining('salvato in "Posta inviata"'), findsOneWidget);
  });

  testWidgets('Priorità alta / bassa (P1): una sola alla volta, di nuovo clic per toglierla, inviata al core', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await openCompose(tester, fakeCore(sent));
    await tester.enterText(field('A'), 'a@example.com');
    await tester.enterText(field('Oggetto'), 'Urgente');
    final high = find.byKey(const Key('compose-importance-high'));
    final low = find.byKey(const Key('compose-importance-low'));
    bool selected(Finder f) => tester.widget<RibbonLargeButton>(f).selected;
    await tester.tap(low);
    await tester.pump();
    await tester.tap(high);
    await tester.pump();
    expect((selected(high), selected(low)), (true, false));

    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();
    expect(sent.single['importance'], 'high');

    await tester.tap(find.text('Nuovo messaggio'));
    await tester.pumpAndSettle();
    await tester.enterText(field('A'), 'a@example.com');
    await tester.tap(high);
    await tester.pump();
    await tester.tap(high); // tolta
    await tester.pump();
    expect(selected(high), isFalse);
    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();
    expect(sent.last.containsKey('importance'), isFalse);
  });

  testWidgets('Richiedi conferma di lettura (R2): Opzioni → Rilevamento, predefinita da File → Opzioni', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sent = <Map<String, dynamic>>[];
    final settings = AppSettings(MemorySettingsStore());
    await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(fakeCore(sent))), settings: settings));
    await tester.pumpAndSettle();
    final receipt = find.byKey(const Key('compose-read-receipt'));
    bool selected() => tester.widget<RibbonLargeButton>(receipt).selected;
    Future<void> send() async {
      await tester.enterText(field('A'), 'a@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Nuovo messaggio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    expect(selected(), isFalse);
    await tester.tap(receipt);
    await tester.pump();
    expect(selected(), isTrue);
    await send();
    expect(sent.single['readReceipt'], isTrue);

    // «Chiedi sempre la conferma di lettura»: già acceso; spento per questo messaggio, non si chiede.
    await settings.setRequestReadReceipt(true);
    await tester.tap(find.text('Nuovo messaggio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    expect(selected(), isTrue);
    await tester.tap(receipt);
    await tester.pump();
    await send();
    expect(sent.last.containsKey('readReceipt'), isFalse);
  });

  testWidgets('annullando la conferma non si invia nulla', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await openCompose(tester, fakeCore(sent));

    await tester.enterText(field('A'), 'a@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('oggetto è vuoto'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(sent, isEmpty);
    expect(find.text('Nuovo messaggio'), findsOneWidget);
  });

  testWidgets('destinatario mancante: errore sul campo, nessuna richiesta', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await openCompose(tester, fakeCore(sent));

    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();

    expect(find.text('Indicare almeno un destinatario'), findsOneWidget);
    expect(find.text('Inviare il messaggio?'), findsNothing);
  });

  testWidgets('errore del core sul campo Cc mostrato sotto il campo', (tester) async {
    await openCompose(tester, fakeCore([], rejectCc: true));

    await tester.enterText(field('A'), 'a@example.com');
    await tester.enterText(field('Cc'), 'x@');
    await tester.enterText(field('Oggetto'), 'S');
    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();

    expect(find.text('Indirizzo non valido: x@'), findsOneWidget);
    expect(find.text('Nuovo messaggio'), findsOneWidget); // resta aperta per correggere
  });

  testWidgets('chiudere con testo scritto chiede conferma', (tester) async {
    await openCompose(tester, fakeCore([]));

    await tester.enterText(field('Oggetto'), 'bozza');
    await tester.pump(); // ricostruisce PopScope con canPop aggiornato, come accade tra un tasto e un clic reali
    await tester.tap(find.byTooltip('Chiudi (Esc)'));
    await tester.pumpAndSettle();
    expect(find.text('Salvare le modifiche?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'No'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposePage), findsNothing);
  });

  Future<void> sendSimple(WidgetTester tester) async {
    await tester.enterText(field('A'), 'a@example.com');
    await tester.enterText(field('Oggetto'), 'S');
    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
  }

  testWidgets('casella tolta: saveCopy false e riepilogo coerente', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await openCompose(tester, fakeCore(sent));

    await tester.tap(find.text('Salva copia in Posta inviata'));
    await tester.pump();
    await sendSimple(tester);
    expect(find.text('Copia in Posta inviata: no'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();

    expect(sent.single['saveCopy'], false);
    expect(find.textContaining('salvato in'), findsNothing);
    expect(find.textContaining('Messaggio inviato'), findsOneWidget);
  });

  testWidgets('copia non salvata: avviso esplicito, non una semplice SnackBar', (tester) async {
    await openCompose(tester, fakeCore([], saveError: 'Il server non dichiara una cartella \\Sent'));

    await sendSimple(tester);
    expect(find.text('Copia in Posta inviata: sì'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();

    expect(find.text('Messaggio inviato, copia non salvata'), findsOneWidget);
    expect(find.textContaining('Non reinviarla'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Messaggio inviato, copia non salvata'), findsNothing);
  });

  testWidgets('aspetto come Outlook: barra multifunzione propria, oggetto nel titolo, Ctrl+F1', (tester) async {
    await openCompose(tester, fakeCore([]));
    final title = find.byKey(ComposePage.titleKey);

    for (final tab in ['Messaggio', 'Inserisci', 'Opzioni']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.text('Allega file'), findsOneWidget);
    expect(find.text('Salva copia in Posta inviata'), findsOneWidget);

    await tester.enterText(field('Oggetto'), 'Riunione');
    await tester.pump();
    expect(find.descendant(of: title, matching: find.text('Riunione')), findsOneWidget);

    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    expect(find.text('Allega file'), findsNothing);
    expect(find.text('Salva copia in Posta inviata'), findsOneWidget);
    await tester.tap(find.text('Inserisci'));
    await tester.pumpAndSettle();
    expect(find.text('Allega file'), findsOneWidget);

    // Ctrl+F1 comprime e riapre (come nella finestra principale).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Allega file'), findsNothing);
    expect(find.text('Inserisci'), findsOneWidget);
    await tester.tap(find.text('Inserisci'));
    await tester.pumpAndSettle();
    expect(find.text('Allega file'), findsOneWidget);
  });

  testWidgets('testo formattato: Grassetto e Elenco puntato dalla barra, HTML con gli stili', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await openCompose(tester, fakeCore(sent));

    expect(find.text('Testo base'), findsOneWidget); // gruppo della scheda Messaggio
    await typeBody(tester, 'Importante');
    final editor = composeEditor(tester);
    editor.updateSelection(const TextSelection(baseOffset: 0, extentOffset: 10), ChangeSource.local);
    await tester.tap(find.byTooltip('Grassetto (Ctrl+B)'));
    await tester.pump();
    await tester.tap(find.byTooltip('Elenco puntato'));
    await tester.pump();

    await tester.tap(find.text('Formato testo'));
    await tester.pumpAndSettle();
    expect(find.text('Carattere'), findsOneWidget);
    expect(find.text('Paragrafo'), findsOneWidget);

    await tester.enterText(field('A'), 'a@example.com');
    await tester.enterText(field('Oggetto'), 'S');
    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();

    final html = sent.single['htmlBody'] as String;
    expect(html, contains('<ul><li><strong>Importante</strong></li></ul>'));
    expect(sent.single['body'], 'Importante');
  });
}
