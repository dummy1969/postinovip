import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../models/signature.dart';

// Firma nel testo del messaggio (3.7c, scelta 8a): come Outlook entra nell'editor, modificabile.
// Il messaggio parte con una riga vuota (lì si scrive) e la firma sotto; nelle risposte e negli
// inoltri la citazione sta comunque sotto l'editor (scelta 6a), quindi la firma resta sopra di essa.

Delta signatureDelta(Signature s) => Delta.fromJson(s.delta);

/// Testo della firma senza l'a capo finale: serve a ritrovarla nel messaggio.
String signaturePlainText(Signature s) {
  final text = Document.fromDelta(signatureDelta(s)).toPlainText();
  return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
}

/// Documento iniziale della composizione: [body] (vuoto di solito) e, se c'è, la firma dopo una riga vuota.
Document composeDocument({String body = '', Signature? signature}) {
  final delta = Delta();
  if (body.isNotEmpty) delta.insert(body.endsWith('\n') ? body : '$body\n');
  if (signature == null) {
    if (delta.isEmpty) delta.insert('\n');
    return Document.fromDelta(delta);
  }
  if (body.isEmpty) delta.insert('\n'); // la riga in cui si scrive
  delta.insert('\n');
  for (final op in signatureDelta(signature).toList()) {
    delta.push(op);
  }
  return Document.fromDelta(delta);
}

/// Posizione della firma [plain] nel messaggio (l'ultima, se ripetuta), solo se è intatta: le stesse
/// righe intere, senza nulla aggiunto prima o dopo sulla stessa riga. null altrimenti.
int? findSignature(Document document, String plain) {
  if (plain.isEmpty) return null;
  final text = document.toPlainText();
  var at = text.lastIndexOf(plain);
  while (at >= 0) {
    final startsLine = at == 0 || text[at - 1] == '\n';
    final end = at + plain.length;
    final endsLine = end == text.length || text[end] == '\n';
    if (startsLine && endsLine) return at;
    at = at == 0 ? -1 : text.lastIndexOf(plain, at - 1);
  }
  return null;
}

/// Mette la firma [next] al posto di quella inserita prima ([previousPlain], se si trova ancora intatta);
/// altrimenti la inserisce dove sta il cursore, come il menu "Firma" di Outlook. [next] null toglie la firma
/// intatta (cambio di account senza firma predefinita). Restituisce il testo della firma ora presente.
String? replaceSignature(QuillController controller, String? previousPlain, Signature? next) {
  final at = previousPlain == null ? null : findSignature(controller.document, previousPlain);
  final length = controller.document.length;
  if (at != null) {
    final old = previousPlain!.length;
    if (next == null) {
      // Con la riga vuota che la precede; resta l'a capo finale della firma.
      final start = at > 0 ? at - 1 : at;
      controller.replaceText(start, at + old - start, '', TextSelection.collapsed(offset: start));
      return null;
    }
    // Il testo della firma e il suo a capo finale (se è l'ultimo del documento lo sostituisce quello nuovo).
    final end = (at + old + 1).clamp(0, length);
    controller.replaceText(
      at,
      end - at,
      signatureDelta(next),
      TextSelection.collapsed(offset: controller.selection.start.clamp(0, at)),
    );
    return signaturePlainText(next);
  }
  if (next == null) return null;
  final cursor = controller.selection.start.clamp(0, length - 1);
  controller.replaceText(cursor, 0, signatureDelta(next), TextSelection.collapsed(offset: cursor));
  return signaturePlainText(next);
}

/// Aggiunge la firma in fondo al messaggio, dopo una riga vuota (cambio di "Da:" quando prima non ce
/// n'era una). Restituisce il testo della firma.
String appendSignature(QuillController controller, Signature signature) {
  final end = controller.document.length - 1;
  final delta = Delta()..insert('\n');
  for (final op in signatureDelta(signature).toList()) {
    delta.push(op);
  }
  controller.replaceText(end, 0, delta, controller.selection);
  return signaturePlainText(signature);
}
