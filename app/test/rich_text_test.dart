import 'dart:typed_data';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/compose/rich_text.dart';

Document doc(List<Map<String, dynamic>> ops) => Document.fromDelta(Delta.fromJson(ops));

void main() {
  test('immagine "data:": stessa immagine per lo stesso URL (non sparisce mentre si scrive)', () {
    final url = pastedImageUrl(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]))!;
    final first = dataImage(url);
    expect(first, isNotNull);
    expect(identical(dataImage(url), first), isTrue);
    expect(dataImage('https://esempio.it/a.png'), isNull);
    expect(dataImage('data:image/png;base64,%%%'), isNull);
  });

  test('HTML per la posta: stili negli elementi, pt, elenchi, link', () {
    final html = documentToHtml(doc([
      {'insert': 'Ciao '},
      {'insert': 'Mario', 'attributes': {'bold': true, 'color': '#C00000', 'size': '14', 'font': 'Georgia'}},
      {'insert': '\n'},
      {'insert': 'uno'},
      {'insert': '\n', 'attributes': {'list': 'bullet'}},
      {'insert': 'centro'},
      {'insert': '\n', 'attributes': {'align': 'center'}},
      {'insert': 'sito', 'attributes': {'link': 'https://example.com'}},
      {'insert': '\n'},
    ]));
    expect(html, contains('<strong'));
    expect(html, contains('color:#C00000'));
    expect(html, contains('font-size:14pt'));
    expect(html, contains('font-family:Georgia, serif'));
    expect(html, contains('<ul>'));
    expect(html, contains('text-align:center'));
    expect(html, contains('href="https://example.com"'));
    expect(html, isNot(contains('class="ql-')));
  });

  test('testo semplice e documento vuoto', () {
    expect(documentToHtml(Document()), '');
    expect(documentToPlainText(doc([
      {'insert': 'riga\n'},
      {'insert': {'image': 'data:image/png;base64,AAAA'}},
      {'insert': '\n'},
    ])), 'riga\n[immagine]');
  });

  test('immagini incollate: tipo riconosciuto dai primi byte', () {
    expect(pastedImageUrl(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2])), startsWith('data:image/png;base64,'));
    expect(pastedImageUrl(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
