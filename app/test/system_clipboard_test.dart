import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
// ignore: experimental_member_use
import 'package:flutter_quill/internal.dart' show ClipboardServiceProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/compose/system_clipboard.dart';

// Appunti dell'editor su Linux senza xclip: il programma nativo è sostituito da un canale finto.

Uint8List utf16le(String s, {bool bom = false}) => Uint8List.fromList([
  if (bom) ...[0xFF, 0xFE],
  for (final u in s.codeUnits) ...[u & 0xFF, u >> 8],
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = GtkClipboardService.defaultChannel;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    // ignore: experimental_member_use
    ClipboardServiceProvider.setInstanceToDefault();
  });

  test('HTML degli appunti: UTF-8, UTF-16 con e senza BOM, vuoto', () {
    expect(decodeClipboardHtml(Uint8List.fromList(utf8.encode('<b>Città</b>'))), '<b>Città</b>');
    expect(decodeClipboardHtml(utf16le('<p>Perché</p>', bom: true)), '<p>Perché</p>'); // Firefox
    expect(decodeClipboardHtml(utf16le('<p>ciao a tutti</p>')), '<p>ciao a tutti</p>');
    expect(decodeClipboardHtml(Uint8List.fromList([...utf8.encode('<i>x</i>'), 0])), '<i>x</i>'); // NUL finale
    expect(decodeClipboardHtml(Uint8List(0)), isNull);
  });

  test('servizio GTK: HTML e immagine dal programma nativo, copia di un\'immagine', () async {
    final calls = <MethodCall>[];
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'getHtml' => Uint8List.fromList(utf8.encode('<p>da <strong>browser</strong></p>')),
        'getImage' => png,
        _ => null,
      };
    });
    final service = GtkClipboardService();
    expect(await service.getHtmlText(), '<p>da <strong>browser</strong></p>');
    expect(await service.getImageFile(), png);
    await service.copyImage(png);
    expect(calls.last.method, 'copyImage');
    expect(calls.last.arguments, png);
    expect(await service.getHtmlFile(), isNull);
    expect(await service.getGifFile(), isNull);
  });

  test('appunti vuoti o canale assente: null, nessun errore', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await GtkClipboardService().getHtmlText(), isNull);
    expect(await GtkClipboardService().getImageFile(), isNull);
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'x', message: 'rotto'));
    expect(await GtkClipboardService().getHtmlText(), isNull);
    messenger.setMockMethodCallHandler(channel, null); // nessun programma nativo
    expect(await GtkClipboardService().getImageFile(), isNull);
  });

  test('l\'editor incolla l\'HTML letto dal servizio GTK (formattazione compresa)', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getHtml') return utf16le('<p>Testo <strong>forte</strong></p>', bom: true);
      return null;
    });
    // ignore: experimental_member_use
    ClipboardServiceProvider.setInstance(GtkClipboardService());
    final controller = QuillController.basic();
    controller.updateSelection(const TextSelection.collapsed(offset: 0), ChangeSource.local);
    // ignore: experimental_member_use
    expect(await controller.clipboardPaste(), isTrue);
    final ops = controller.document.toDelta().toList();
    expect(controller.document.toPlainText(), contains('Testo forte'));
    expect(ops.any((Operation op) => op.data == 'forte' && op.attributes?['bold'] == true), isTrue);
  });
}
