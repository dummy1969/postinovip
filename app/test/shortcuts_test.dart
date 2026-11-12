import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'compose_helpers.dart';
import 'package:postinovip/ui/compose_page.dart';

// Stesso core finto della selezione multipla: INBOX con "Mail 5"…"Mail 1" (UID 5–1, da leggere),
// Archivio, Posta eliminata con "Vecchia 9" e "Vecchia 8".
import 'multi_select_test.dart' as ms;

Future<void> key(WidgetTester tester, LogicalKeyboardKey key, {bool control = false, bool shift = false}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

List<bool> selection(WidgetTester tester) => [
  for (final n in [5, 4, 3, 2, 1]) ms.selected(tester, 'Mail $n'),
];

void main() {
  testWidgets('frecce, Maiusc+frecce e Ctrl+A', (tester) async {
    final core = await ms.start(tester);

    await key(tester, LogicalKeyboardKey.arrowDown); // nessuna selezione: la prima riga
    expect(selection(tester), [true, false, false, false, false]);
    expect(find.text('testo'), findsOneWidget); // aperta
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(selection(tester), [false, true, false, false, false]);
    await key(tester, LogicalKeyboardKey.arrowDown, shift: true);
    await key(tester, LogicalKeyboardKey.arrowDown, shift: true);
    expect(selection(tester), [false, true, true, true, false]);
    expect(find.text('3 elementi selezionati'), findsOneWidget);
    await key(tester, LogicalKeyboardKey.arrowUp); // senza Maiusc: una sola, sopra l'ultima raggiunta
    expect(selection(tester), [false, false, true, false, false]);

    await key(tester, LogicalKeyboardKey.keyA, control: true);
    expect(find.text('5 elementi selezionati'), findsOneWidget);
    expect(core.writes, isEmpty);
    await core.sse.close();
  });

  testWidgets('Ctrl+Q / Ctrl+U, Canc, Maiusc+Canc fuori da Posta eliminata = Canc', (tester) async {
    final core = await ms.start(tester);
    await ms.click(tester, 'Mail 5');
    await ms.click(tester, 'Mail 4', holding: LogicalKeyboardKey.controlLeft);

    await key(tester, LogicalKeyboardKey.keyQ, control: true);
    expect(core.writes.last, 'PUT /accounts/a1/messages/INBOX/seen {"uids":[4,5],"seen":true}');
    await key(tester, LogicalKeyboardKey.keyU, control: true);
    expect(core.writes.last, 'PUT /accounts/a1/messages/INBOX/seen {"uids":[4,5],"seen":false}');

    await key(tester, LogicalKeyboardKey.delete);
    expect(core.writes.last, 'POST /accounts/a1/messages/INBOX/delete {"uids":[4,5],"permanent":false}');

    await ms.click(tester, 'Mail 3');
    await key(tester, LogicalKeyboardKey.delete, shift: true);
    expect(core.writes.last, 'DELETE /accounts/a1/messages/INBOX/3 '); // percorso di una mail: spostata
    await core.sse.close();
  });

  testWidgets('Ctrl+Maiusc+V: finestra "Sposta elementi" con filtro', (tester) async {
    final core = await ms.start(tester);
    await ms.click(tester, 'Mail 5');
    await ms.click(tester, 'Mail 4', holding: LogicalKeyboardKey.controlLeft);

    await key(tester, LogicalKeyboardKey.keyV, control: true, shift: true);
    expect(find.text('Sposta i 2 elementi selezionati nella cartella:'), findsOneWidget);
    expect(find.byKey(const ValueKey('move-to:INBOX')), findsNothing); // la cartella di partenza no
    await tester.enterText(find.widgetWithText(TextField, 'Cerca una cartella'), 'arch');
    await tester.pump();
    expect(find.byKey(const ValueKey('move-to:Posta eliminata')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('move-to:Archivio')));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(core.writes.last, 'POST /accounts/a1/messages/INBOX/move {"uids":[4,5],"destination":"Archivio"}');
    await core.sse.close();
  });

  testWidgets('mentre si scrive nella ricerca i tasti restano al testo; Ctrl+E porta alla ricerca', (tester) async {
    final core = await ms.start(tester);
    await ms.click(tester, 'Mail 5');

    await key(tester, LogicalKeyboardKey.keyE, control: true);
    final focused = find.byWidgetPredicate((w) => w is EditableText && w.focusNode.hasFocus);
    expect(focused, findsOneWidget);

    // Un clic sulla lista riporta la tastiera alla posta.
    await ms.click(tester, 'Mail 4');
    expect(focused, findsNothing);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(ms.selected(tester, 'Mail 3'), isTrue);

    // Si scrive nella ricerca: Canc, Ctrl+D, Ctrl+A restano al testo.
    await key(tester, LogicalKeyboardKey.keyE, control: true);
    await tester.enterText(find.byType(TextField).first, 'parola');
    await key(tester, LogicalKeyboardKey.delete);
    await key(tester, LogicalKeyboardKey.keyD, control: true);
    await key(tester, LogicalKeyboardKey.keyA, control: true);
    expect(core.writes, isEmpty); // nessuna mail eliminata
    await core.sse.close();
  });

  testWidgets('Ctrl+N apre la composizione; Esc la chiude, Ctrl+Invio chiede conferma prima di inviare', (
    tester,
  ) async {
    final core = await ms.start(tester);

    await key(tester, LogicalKeyboardKey.keyN, control: true);
    expect(find.byType(ComposePage), findsOneWidget);
    await key(tester, LogicalKeyboardKey.escape); // niente di scritto: si chiude subito
    expect(find.byType(ComposePage), findsNothing);

    await key(tester, LogicalKeyboardKey.keyN, control: true);
    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'anna@example.com');
    await typeBody(tester, 'Ciao');
    await tester.pump();
    await key(tester, LogicalKeyboardKey.enter, control: true);
    expect(find.text('Inviare il messaggio?'), findsOneWidget); // sempre il riepilogo
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    await key(tester, LogicalKeyboardKey.escape); // c'è qualcosa di scritto: domanda
    expect(find.text('Salvare le modifiche?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'No'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposePage), findsNothing);
    expect(core.writes, isEmpty); // nessun invio
    await core.sse.close();
  });
}
