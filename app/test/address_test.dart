import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/compose/address_list.dart';
import 'package:postinovip/ui/compose_page.dart';

import 'compose_helpers.dart' show typeBody;
import 'people_test.dart' show start;

// Completamento degli indirizzi e Rubrica in composizione (C3).

Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

final toField = find.byKey(const Key('address-to'));
final ccField = find.byKey(const Key('address-cc'));
String text(WidgetTester tester, Finder f) => tester.widget<TextFormField>(f).controller!.text;

/// Scrive come una persona: il cursore resta in fondo (enterText lo mette lì) e i suggerimenti arrivano.
Future<void> type(WidgetTester tester, Finder field, String value) async {
  await tester.enterText(field, value);
  await tester.pump(const Duration(milliseconds: 200)); // attesa dopo l'ultima lettera
  await tester.pumpAndSettle();
}

void main() {
  group('testo dei destinatari', () {
    test('destinatario che si sta scrivendo e sostituzione', () {
      expect(currentRecipient('anna@x.it, mar', 14), (start: 11, text: 'mar'));
      expect(currentRecipient('"Rossi, Mario" <m@x.it>; lu', 27).text, 'lu');
      expect(currentRecipient('ma', 2), (start: 0, text: 'ma'));
      expect(replaceCurrentRecipient('anna@x.it, mar', 14, 'Mario <m@x.it>'), 'anna@x.it, Mario <m@x.it>, ');
      // Scrivendo in mezzo: sostituito solo quel destinatario, il resto resta.
      expect(replaceCurrentRecipient('ma, bob@x.it', 2, 'Mario <m@x.it>'), 'Mario <m@x.it>, bob@x.it');
    });

    test('nome tra virgolette quando serve; indirizzi già presenti', () {
      expect(formatMailbox('Mario Rossi', 'm@x.it'), 'Mario Rossi <m@x.it>');
      expect(formatMailbox('Rossi, Mario', 'm@x.it'), '"Rossi, Mario" <m@x.it>');
      expect(formatMailbox('M. "Il" Rossi', 'm@x.it'), r'"M. \"Il\" Rossi" <m@x.it>');
      expect(formatMailbox(null, 'm@x.it'), 'm@x.it');
      expect(formatMailbox('m@x.it', 'M@x.it'), 'M@x.it');
      expect(addressesIn('Mario <M@x.it>, b@y.it, '), {'m@x.it', 'b@y.it'});
    });
  });

  testWidgets('suggerimenti mentre si scrive: frecce e Invio, clic, ✕ su un recente, niente doppioni', (tester) async {
    final fake = await start(tester);
    await ctrl(tester, LogicalKeyboardKey.keyN);
    expect(find.byType(ComposePage), findsOneWidget);

    await type(tester, toField, 'ma');
    final suggestions = find.byKey(const Key('address-suggestions'));
    expect(suggestions, findsOneWidget);
    expect(find.descendant(of: suggestions, matching: find.text('Mario Rossi')), findsOneWidget);
    expect(find.descendant(of: suggestions, matching: find.text('marta@example.net')), findsOneWidget);
    // Primo evidenziato = il recente; freccia giù = Mario; Invio lo sceglie.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    // Invio in un campo di testo arriva come azione della tastiera (TextInputAction), non come tasto.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(text(tester, toField), 'Mario Rossi <mario@example.com>, ');
    expect(find.byKey(const Key('address-suggestions')), findsNothing);

    // Secondo destinatario con un clic; Mario non viene più proposto (c'è già).
    await type(tester, toField, '${text(tester, toField)}ma');
    expect(find.descendant(of: suggestions, matching: find.text('Mario Rossi')), findsNothing);
    // ✕ sul recente: tolto dai suggerimenti e dal core.
    await tester.tap(find.byKey(const Key('suggestion-remove:marta@example.net')));
    await tester.pumpAndSettle();
    expect(fake.requests, contains('DELETE /addresses/recent address=marta%40example.net'));
    expect(find.text('marta@example.net'), findsNothing);

    await type(tester, ccField, 'nic');
    await tester.tap(find.byKey(const Key('suggestion:luca@example.org')));
    await tester.pumpAndSettle();
    expect(text(tester, ccField), 'Luca Nicolò <luca@example.org>, ');

    // Esc con i suggerimenti aperti li chiude soltanto: la composizione resta.
    await type(tester, ccField, '${text(tester, ccField)}mar');
    expect(find.byKey(const Key('address-suggestions')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('address-suggestions')), findsNothing);
    expect(find.byType(ComposePage), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('Ccn: Opzioni → Ccn mostra il campo (ricordato), basta un Ccn, riepilogo e POST con bcc', (tester) async {
    final fake = await start(tester);
    await ctrl(tester, LogicalKeyboardKey.keyN);
    final bccField = find.byKey(const Key('address-bcc'));
    expect(bccField, findsNothing); // nascosto di serie, come Outlook
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Ccn'));
    await tester.pumpAndSettle();
    expect(bccField, findsOneWidget);

    // Dalla Rubrica: «Ccn ->».
    await tester.tap(find.byKey(const Key('book-open-Ccn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-entry:mario@example.com')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('book-bcc')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('book-ok')));
    await tester.pumpAndSettle();
    expect(text(tester, bccField), 'Mario Rossi <mario@example.com>');
    await tester.enterText(find.widgetWithText(TextFormField, 'Oggetto'), 'Solo Ccn');
    await typeBody(tester, 'Ciao');

    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    expect(find.text('Ccn: Mario Rossi <mario@example.com>'), findsOneWidget); // A vuoto: niente riga «A:»
    expect(find.textContaining('A: '), findsNothing);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();
    final post = jsonDecode(fake.requests.lastWhere((r) => r.startsWith('POST /accounts/a1/send')).split(' ').skip(2).join(' '));
    expect(post['to'], isEmpty);
    expect(post['bcc'], ['Mario Rossi <mario@example.com>']);

    // Nuovo messaggio: il campo Ccn resta visibile (scelta ricordata).
    await ctrl(tester, LogicalKeyboardKey.keyN);
    expect(bccField, findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('«A…» apre la Rubrica: A ->, Cc ->, doppio clic, OK aggiunge senza doppioni', (tester) async {
    final fake = await start(tester);
    await ctrl(tester, LogicalKeyboardKey.keyN);
    await tester.enterText(toField, 'anna@example.com');
    await tester.tap(find.byKey(const Key('book-open-A')));
    await tester.pumpAndSettle();
    expect(find.text('Rubrica'), findsOneWidget);
    expect(find.byKey(const Key('book-entry:mario@example.com')), findsOneWidget);

    await tester.tap(find.byKey(const Key('book-entry:mario@example.com')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('book-to')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('book-entry:luca@example.org')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('book-cc')));
    await tester.pump();
    // Doppio clic su Mario: già in A, non si ripete.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('book-entry:mario@example.com')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('book-entry:mario@example.com')));
    await tester.pump();
    expect(find.widgetWithText(InputChip, 'Mario Rossi <mario@example.com>'), findsOneWidget);

    // Ricerca senza accenti.
    await tester.enterText(find.byKey(const Key('book-search')), 'nicolo');
    await tester.pump();
    expect(find.byKey(const Key('book-entry:mario@example.com')), findsNothing);
    expect(find.byKey(const Key('book-entry:luca@example.org')), findsOneWidget);

    await tester.tap(find.byKey(const Key('book-ok')));
    await tester.pumpAndSettle();
    expect(text(tester, toField), 'anna@example.com, Mario Rossi <mario@example.com>');
    expect(text(tester, ccField), 'Luca Nicolò <luca@example.org>');

    // Di nuovo con gli stessi: niente doppioni.
    await tester.tap(find.byKey(const Key('book-open-Cc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-entry:luca@example.org')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('book-entry:luca@example.org'))); // doppio clic da «Cc…» = Cc
    await tester.pump();
    await tester.tap(find.byKey(const Key('book-ok')));
    await tester.pumpAndSettle();
    expect(text(tester, ccField), 'Luca Nicolò <luca@example.org>');
    await fake.core.sse.close();
  });
}
