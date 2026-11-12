import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/compose/signature_text.dart';
import 'package:postinovip/models/signature.dart';

Signature sig(String id, String text, {Map<String, dynamic>? attrs}) => Signature(
  id: id,
  name: id,
  delta: [
    {'insert': text, 'attributes': ?attrs},
    {'insert': '\n'},
  ],
);

QuillController controllerFor(Document d) =>
    QuillController(document: d, selection: const TextSelection.collapsed(offset: 0));

void main() {
  test('messaggio nuovo: riga vuota per scrivere e firma sotto, formattata', () {
    final d = composeDocument(signature: sig('a', 'Mario Rossi', attrs: {'bold': true}));
    expect(d.toPlainText(), '\n\nMario Rossi\n');
    expect(d.toDelta().toList().any((op) => op.attributes?['bold'] == true), isTrue);
    expect(composeDocument().toPlainText(), '\n');
  });

  test('firma intatta sostituita; modificata: la nuova va al cursore', () {
    final c = controllerFor(composeDocument(signature: sig('a', 'Mario Rossi')));
    c.replaceText(0, 0, 'Ciao', const TextSelection.collapsed(offset: 4));
    var plain = replaceSignature(c, 'Mario Rossi', sig('b', 'M. Rossi - Ufficio'));
    expect(c.document.toPlainText(), 'Ciao\n\nM. Rossi - Ufficio\n');
    expect(plain, 'M. Rossi - Ufficio');

    // Tolta (account senza firma): anche la riga vuota che la precede.
    plain = replaceSignature(c, plain, null);
    expect(c.document.toPlainText(), 'Ciao\n\n');
    expect(plain, isNull);

    // Firma cambiata a mano: non si ritrova, la nuova entra dove sta il cursore.
    final c2 = controllerFor(composeDocument(signature: sig('a', 'Mario')));
    c2.replaceText(3, 0, 'XX', null); // "\n\nMXXario"
    c2.updateSelection(const TextSelection.collapsed(offset: 0), ChangeSource.local);
    replaceSignature(c2, 'Mario', sig('b', 'Firma'));
    expect(c2.document.toPlainText(), 'Firma\n\n\nMXXario\n');
  });

  test('firma con testo aggiunto sulla stessa riga: non più intatta', () {
    final d = composeDocument(signature: sig('a', 'Ing. Mario Rossi'));
    final c = controllerFor(d)..replaceText(d.length - 1, 0, ' (cell. 123)', null);
    expect(findSignature(c.document, 'Ing. Mario Rossi'), isNull);
    expect(findSignature(composeDocument(signature: sig('a', 'Ing. Mario Rossi')), 'Ing. Mario Rossi'), 2);
  });
}
