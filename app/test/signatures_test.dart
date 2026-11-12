import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/models/signature.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/compose_page.dart';
import 'package:postinovip/ui/signatures_dialog.dart';

import 'compose_helpers.dart' show composeEditor;
import 'multi_account_test.dart' as ma;

// Core finto a due account: "Personale" (a1, io@example.com) e "Lavoro" (b2, io@lavoro.example).

Signature sig(String id, String name, String text, {bool bold = false}) => Signature(
  id: id,
  name: name,
  delta: [
    {
      'insert': text,
      if (bold) 'attributes': {'bold': true},
    },
    {'insert': '\n'},
  ],
);

Future<AppSettings> settingsWith(List<Signature> list, Map<String, SignatureDefaults> defaults) async {
  final settings = AppSettings(MemorySettingsStore())..readMode = ReadMode.manual;
  await settings.setSignatures(list, defaults);
  return settings;
}

String body(WidgetTester tester) => composeEditor(tester).document.toPlainText();

Future<void> openNew(WidgetTester tester) async {
  await tester.tap(find.text('Nuovo messaggio'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('finestra Firme: nuova firma, predefinita per i nuovi messaggi, poi inserita da sola', (tester) async {
    final settings = AppSettings(MemorySettingsStore())..readMode = ReadMode.manual;
    final core = await ma.start(tester, settings: settings);
    await openNew(tester);
    expect(body(tester), '\n'); // nessuna firma ancora

    await tester.tap(find.text('Firma').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Firme…'));
    await tester.pumpAndSettle();
    expect(find.text('Firme e elementi decorativi'), findsOneWidget);

    await tester.tap(find.text('Nuova'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome della firma'), 'Lavoro');
    await tester.tap(find.widgetWithText(FilledButton, 'OK').last);
    await tester.pumpAndSettle();
    final editor = tester.widget<QuillEditor>(
      find.descendant(of: find.byType(SignaturesDialog), matching: find.byType(QuillEditor)),
    );
    editor.controller.replaceText(0, 0, 'Mario Rossi', null);
    await tester.pump();

    // Predefinita dei nuovi messaggi per "Personale" (l'account della cartella aperta).
    await tester.tap(find.byKey(const ValueKey('signature-new:a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lavoro').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(settings.signatures.single.name, 'Lavoro');
    expect(settings.defaultSignature('a1', reply: false)?.name, 'Lavoro');
    expect(settings.defaultSignature('a1', reply: true), isNull);

    // Chiude (non c'è nulla di scritto) e riapre: la firma c'è già, dopo una riga vuota.
    await tester.tap(find.byTooltip('Chiudi (Esc)'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposePage), findsNothing);
    await openNew(tester);
    expect(body(tester), '\n\nMario Rossi\n');
    await core.sse.close();
  });

  testWidgets('firma inserita: non conta come testo scritto, va nell\'invio; il menu la sostituisce', (tester) async {
    final settings = await settingsWith(
      [sig('s1', 'Breve', 'Mario', bold: true), sig('s2', 'Completa', 'Mario Rossi - Ufficio')],
      {'a1': const SignatureDefaults(newMessage: 's1')},
    );
    final core = await ma.start(tester, settings: settings);
    await openNew(tester);
    expect(body(tester), '\n\nMario\n');

    await tester.tap(find.byTooltip('Chiudi (Esc)')); // solo la firma: si chiude senza domanda
    await tester.pumpAndSettle();
    expect(find.text('Salvare le modifiche?'), findsNothing);

    await openNew(tester);
    await tester.tap(find.text('Firma').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completa'));
    await tester.pumpAndSettle();
    expect(body(tester), '\n\nMario Rossi - Ufficio\n');

    // Si scrive dove sta il cursore all'apertura: la riga vuota sopra la firma.
    composeEditor(tester).replaceText(0, 0, 'Ciao', null);
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'dest@example.com');
    await tester.pump();
    await ma.sendWithConfirm(tester);
    final sent = core.sent.single.$2;
    expect(sent['body'], 'Ciao\n\nMario Rossi - Ufficio');
    expect(sent['htmlBody'], contains('Mario Rossi - Ufficio'));
    await core.sse.close();
  });

  testWidgets('cambio di "Da:": firma intatta passa a quella del nuovo account, modificata resta', (tester) async {
    final settings = await settingsWith(
      [sig('p', 'Personale', 'Mario'), sig('l', 'Lavoro', 'Ing. Mario Rossi')],
      {'a1': const SignatureDefaults(newMessage: 'p'), 'b2': const SignatureDefaults(newMessage: 'l')},
    );
    final core = await ma.start(tester, settings: settings);
    await openNew(tester);
    expect(body(tester), '\n\nMario\n');

    Future<void> from(String label, String pick) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pick).last);
      await tester.pumpAndSettle();
    }

    await from('Personale <io@example.com>', 'Lavoro <io@lavoro.example>');
    expect(body(tester), '\n\nIng. Mario Rossi\n');

    // Firma cambiata a mano: cambiando di nuovo account resta com'è.
    final c = composeEditor(tester);
    c.replaceText(c.document.length - 1, 0, ' (cell. 123)', null);
    await tester.pump();
    await from('Lavoro <io@lavoro.example>', 'Personale <io@example.com>');
    expect(body(tester), '\n\nIng. Mario Rossi (cell. 123)\n');
    await core.sse.close();
  });

  testWidgets('risposte: la firma per risposte e inoltri, sopra la citazione', (tester) async {
    final settings = await settingsWith(
      [sig('n', 'Nuovi', 'Saluti, Mario'), sig('r', 'Risposte', 'M.')],
      {'a1': const SignatureDefaults(newMessage: 'n', reply: 'r')},
    );
    final core = await ma.start(tester, settings: settings);
    await tester.tap(find.text('Mail personale'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Rispondi'));
    await tester.pumpAndSettle();
    expect(body(tester), '\n\nM.\n');
    await core.sse.close();
  });

  test('firme salvate e rilette; predefinite di una firma eliminata tolte', () async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    await settings.setSignatures(
      [sig('a', 'A', 'x'), sig('b', 'B', 'y')],
      {'acc': const SignatureDefaults(newMessage: 'a', reply: 'b')},
    );
    await settings.setSignatures([sig('a', 'A', 'x')], settings.signatureDefaults);

    final again = AppSettings(store);
    await again.load();
    expect(again.signatures.map((s) => s.name), ['A']);
    expect(again.signatureDefaults['acc'], const SignatureDefaults(newMessage: 'a'));
  });
}
