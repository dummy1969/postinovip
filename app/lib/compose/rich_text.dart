import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';
import '../l10n/language.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

// Testo formattato della composizione (3.7b): documento di flutter_quill, convertito in HTML con gli
// stili scritti negli elementi (i programmi di posta ignorano i fogli di stile) e in testo semplice
// per la parte text/plain. Il core ripulisce comunque l'HTML prima dell'invio.

/// Carattere predefinito delle mail scritte (Outlook usa Aptos/Calibri 11 pt, non ridistribuibili:
/// qui solo il nome, il destinatario usa quello che ha o uno simile).
const defaultMailFont = 'Calibri, Arial, sans-serif';

/// Caratteri proposti nel menu "Carattere": il nome resta nel documento (il convertitore accetta solo
/// nomi semplici), nell'HTML diventa il nome seguito dai caratteri di riserva.
const mailFonts = <String, String>{
  'Arial': 'Arial, sans-serif',
  'Calibri': 'Calibri, Arial, sans-serif',
  'Georgia': 'Georgia, serif',
  'Times New Roman': '"Times New Roman", serif',
  'Verdana': 'Verdana, sans-serif',
  'Courier New': '"Courier New", monospace',
};

/// Dimensioni del menu "Dimensione carattere", in punti come Outlook.
const mailFontSizes = [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 36];

/// Colori del menu "Colore carattere" ed "Evidenziatore" (palette standard di Office); il primo è «Automatico».
/// I nomi sono in [fontColorNames], nello stesso ordine.
const fontColors = <int>[0x000000, 0xC00000, 0xFF0000, 0xFFC000, 0xFFFF00, 0x92D050, 0x00B050, 0x00B0F0, 0x0070C0, 0x002060, 0x7030A0];

List<String> fontColorNames(AppLocalizations l) => [
  l.fontColorAutomatic,
  l.fontColorDarkRed,
  l.fontColorRed,
  l.fontColorOrange,
  l.fontColorYellow,
  l.fontColorLightGreen,
  l.fontColorGreen,
  l.fontColorLightBlue,
  l.fontColorBlue,
  l.fontColorDarkBlue,
  l.fontColorPurple,
];

String cssColor(int rgb) => '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// HTML del documento, pronto per una mail: stili negli elementi, dimensioni in pt, paragrafi con
/// margini piccoli come in Outlook. Un documento vuoto dà ''.
String documentToHtml(Document document) {
  if (documentToPlainText(document).trim().isEmpty && !_hasEmbeds(document)) return '';
  final ops = [for (final op in document.toDelta().toJson()) Map<String, dynamic>.from(op as Map)];
  final converter = QuillDeltaToHtmlConverter(
    ops,
    ConverterOptions(
      converterOptions: OpConverterOptions(
        inlineStylesFlag: true,
        inlineStyles: InlineStyles({
          'font': InlineStyleType(fn: (value, _) => 'font-family:${mailFonts[value] ?? value}'),
          // Dimensioni numeriche dell'editor = punti; i nomi di Quill come sopra.
          'size': InlineStyleType(
            fn: (value, _) => switch (value) {
              'small' => 'font-size:9pt',
              'large' => 'font-size:16pt',
              'huge' => 'font-size:24pt',
              _ => 'font-size:${double.tryParse(value)?.toStringAsFixed(0) ?? 11}pt',
            },
          ),
          'indent': InlineStyleType(fn: (value, _) => 'margin-left:${(int.tryParse(value) ?? 0) * 36}pt'),
        }),
        paragraphTag: 'p',
        customCssStyles: (op) {
          if (op.isImage()) return ['max-width:100%'];
          return null;
        },
      ),
    ),
  );
  final body = converter.convert();
  // Paragrafi stretti come in Outlook (il <p> predefinito ha 1em sopra e sotto).
  final compact = body
      .replaceAll('<p>', '<p style="margin:0">')
      .replaceAllMapped(RegExp(r'<p style="(?!margin)'), (m) => '<p style="margin:0;');
  return '<div style="font-family:$defaultMailFont;font-size:11pt">$compact</div>';
}

/// Documento dell'editor da un HTML (bozza riaperta, 3.8). Le mail scritte con altri programmi possono
/// perdere parte dell'impaginazione (tabelle, colonne): l'editor ha solo paragrafi, elenchi e stili.
Document htmlToDocument(String html) {
  final delta = HtmlToDelta().convert(html);
  if (delta.isEmpty) return Document();
  final last = delta.last.data;
  if (last is! String || !last.endsWith('\n')) delta.insert('\n');
  return Document.fromDelta(delta);
}

/// Testo per la parte text/plain: le immagini incorporate diventano "[immagine]" (nella lingua dell'app, L6b).
String documentToPlainText(Document document) {
  final buffer = StringBuffer();
  for (final op in document.toDelta().toList()) {
    final data = op.data;
    if (data is String) {
      buffer.write(data);
    } else {
      buffer.write('[${formatL10n.imagePlaceholder}]');
    }
  }
  return buffer.toString().trimRight();
}

/// Testo normale (13/11/2026): il documento ha formattazione (stili, elenchi, allineamenti) o immagini che
/// passando a testo normale andrebbero perse.
bool hasFormatting(Document document) =>
    document.toDelta().toList().any((op) => op.data is! String || (op.attributes?.isNotEmpty ?? false));

/// Testo normale: toglie dal documento ogni formattazione e le immagini, lasciando il testo e gli a capo
/// (e il cursore dov'è). Usato passando a testo normale e dopo ogni modifica (incolla, firma, scorciatoie).
void stripFormatting(QuillController controller) {
  final ops = controller.document.toDelta().toList();
  final embeds = <int>[];
  final formatted = <({int offset, int length, String key})>[];
  var offset = 0;
  for (final op in ops) {
    final length = op.length ?? 0;
    if (op.data is! String) {
      embeds.add(offset);
    } else {
      for (final key in op.attributes?.keys ?? const <String>[]) {
        formatted.add((offset: offset, length: length, key: key));
      }
    }
    offset += length;
  }
  for (final f in formatted) {
    final remove = Attribute.fromKeyValue(f.key, null) ?? Attribute(f.key, AttributeScope.inline, null);
    controller.formatText(f.offset, f.length, remove);
  }
  // Immagini dalla fine, così le posizioni di quelle prima non cambiano.
  for (final at in embeds.reversed) {
    final sel = controller.selection;
    int shift(int o) => o > at ? o - 1 : o;
    controller.replaceText(
      at,
      1,
      '',
      TextSelection(baseOffset: shift(sel.baseOffset), extentOffset: shift(sel.extentOffset)),
    );
  }
}

bool _hasEmbeds(Document document) => document.toDelta().toList().any((op) => op.data is! String);

/// Immagine incollata dagli appunti: diventa un'immagine "data:" nel documento (il core la trasforma
/// in una parte incorporata della mail). null se il formato non è riconosciuto.
String? pastedImageUrl(Uint8List bytes) {
  final type = imageMimeType(bytes);
  return type == null ? null : 'data:$type;base64,${base64Encode(bytes)}';
}

/// Tipo dell'immagine dai primi byte (PNG, JPEG, GIF, WebP, BMP).
String? imageMimeType(Uint8List b) {
  bool starts(List<int> sig) =>
      b.length >= sig.length && [for (var i = 0; i < sig.length; i++) b[i] == sig[i]].every((x) => x);
  if (starts([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (starts([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts([0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  if (starts([0x42, 0x4D])) return 'image/bmp';
  if (b.length >= 12 &&
      starts([0x52, 0x49, 0x46, 0x46]) &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

/// Byte delle immagini "data:" del documento (contano nel limite di 25 MB, come gli allegati).
int embeddedImageBytes(Document document) {
  var total = 0;
  for (final op in document.toDelta().toList()) {
    final data = op.data;
    if (data is Map && data['image'] is String) {
      final url = data['image'] as String;
      final comma = url.indexOf(',');
      if (url.startsWith('data:') && comma > 0) total += (url.length - comma - 1) * 3 ~/ 4;
    }
  }
  return total;
}

/// Immagini nel documento: quelle incollate ("data:") si vedono; quelle con un indirizzo internet
/// (incollate da una pagina) non vengono scaricate qui (riservatezza): un riquadro al loro posto.
/// Immagini "data:" già decodificate, per URL. L'editor ricostruisce le immagini a ogni tasto: decodificare
/// di nuovo il base64 produceva byte nuovi, quindi per Flutter un'immagine nuova da ricaricare, e l'immagine
/// spariva mentre si scriveva. Con lo stesso [MemoryImage] resta nella cache delle immagini di Flutter.
final _dataImages = <String, MemoryImage>{};
const _dataImagesMax = 32;

/// L'immagine di un URL "data:…;base64,…" (sempre lo stesso oggetto per lo stesso URL), o null.
MemoryImage? dataImage(String url) {
  final cached = _dataImages.remove(url);
  if (cached != null) {
    _dataImages[url] = cached; // in fondo: usata di recente
    return cached;
  }
  final comma = url.indexOf(',');
  if (!url.startsWith('data:') || comma <= 0) return null;
  try {
    final image = MemoryImage(base64Decode(url.substring(comma + 1)));
    _dataImages[url] = image;
    if (_dataImages.length > _dataImagesMax) _dataImages.remove(_dataImages.keys.first);
    return image;
  } on FormatException {
    return null;
  }
}

class MailImageEmbedBuilder extends EmbedBuilder {
  const MailImageEmbedBuilder();

  @override
  String get key => BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final image = dataImage(url);
    if (image != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 400),
        // gaplessPlayback: se l'immagine va ricaricata resta visibile quella di prima.
        child: Image(image: image, fit: BoxFit.contain, gaplessPlayback: true),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant)),
      child: Text(context.l10n.remoteImagePlaceholder, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
    );
  }
}
