import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/ui/compose_page.dart';

/// Editor della composizione (testo formattato, 3.7b).
QuillController composeEditor(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byKey(ComposePage.editorKey)).controller;

/// Clic nel testo del messaggio (la tastiera va lì) e scrittura di [text] dove sta il cursore.
Future<void> typeBody(WidgetTester tester, String text) async {
  await tester.tap(find.byKey(ComposePage.editorKey));
  await tester.pump();
  final c = composeEditor(tester);
  final at = c.selection.start;
  c.replaceText(at, 0, text, TextSelection.collapsed(offset: at + text.length));
  await tester.pump();
}
