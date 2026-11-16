import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../l10n/formats.dart';
import '../models/mail_importance.dart';
import '../models/message_detail.dart';
import '../ui/html_body_view.dart';
import '../ui/html_to_text.dart';
import '../ui/theme.dart';

/// Stampa di una mail (P3, scelte 2a e 3a): un PDF A4 come la stampa «Stile memo» di Outlook classico.
/// Le intestazioni sono testo vero; il corpo è disegnato fuori schermo come nel riquadro di lettura (stesso
/// motore HTML, immagini remote bloccate) e diviso in pagine, tagliando tra una riga e l'altra.
class MessagePdf {
  static const format = PdfPageFormat.a4;
  static const margin = 15 * PdfPageFormat.mm;
  static const footerHeight = 18.0;

  /// 1 pixel logico = 0,75 punti, come i px del CSS: il corpo si dispone largo circa 680 pixel.
  static const pxToPt = 0.75;

  /// Risoluzione dell'immagine del corpo: 2 pixel per pixel logico (circa 190 dpi).
  static const pixelRatio = 2.0;

  static double get contentWidth => format.width - 2 * margin;
  static double get contentHeight => format.height - 2 * margin - footerHeight;
  static double get bodyWidthPx => contentWidth / pxToPt;

  /// Crea il PDF di [message]; [account] è il nome stampato in cima (come Outlook stampa il nome dell'utente).
  /// [view] serve a disegnare il corpo fuori schermo; [fonts] null = Helvetica di serie (solo Latin-1).
  static Future<Uint8List> build({
    required MessageDetail message,
    required String account,
    required ui.FlutterView view,
    PrintFonts? fonts,
  }) async {
    final theme = fonts == null
        ? pw.ThemeData.base()
        : pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold);
    String t(String s) => fonts == null ? latin1Only(s) : s;
    final header = _header(message, account, t);
    final headerHeight = _measure(header, theme);

    final slices = await renderBody(
      view: view,
      body: bodyWidget(message),
      width: bodyWidthPx,
      first: (contentHeight - headerHeight) / pxToPt,
      other: contentHeight / pxToPt,
    );

    final doc = pw.Document(
      theme: theme,
      deflate: zlib.encode, // compressione nativa di dart:io, molto più veloce di quella in Dart del pacchetto
      title: t(message.subject),
      creator: 'PostinoVip',
    );
    final pages = slices.isEmpty ? 1 : slices.length;
    for (var i = 0; i < pages; i++) {
      final slice = i < slices.length ? slices[i] : null;
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(margin),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (i == 0) header,
              if (slice != null)
                pw.Image(
                  pw.RawImage(bytes: slice.rgba, width: slice.width, height: slice.height),
                  width: contentWidth,
                  height: slice.heightPx * pxToPt,
                  fit: pw.BoxFit.fill,
                ),
              pw.Spacer(),
              pw.Container(
                height: footerHeight,
                alignment: pw.Alignment.bottomCenter,
                child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 9)),
              ),
            ],
          ),
        ),
      );
    }
    return doc.save();
  }

  /// Corpo come nel riquadro di lettura: HTML se c'è, altrimenti testo; su fondo bianco.
  static Widget bodyWidget(MessageDetail m) {
    final text = m.textBody != null && m.textBody!.trim().isNotEmpty
        ? m.textBody!
        : m.htmlBody != null
        ? htmlToText(m.htmlBody!)
        : '';
    return MessageSurface(
      child: m.htmlBody != null
          ? HtmlBodyView(html: m.htmlBody!, allowRemoteImages: false, buildAsync: false)
          : Text(text, style: const TextStyle(height: 1.4)),
    );
  }

  /// Intestazioni come la stampa di Outlook: nome in grassetto con una riga spessa, poi Da, Inviato, A, Cc,
  /// Oggetto, Priorità e Allegati.
  static pw.Widget _header(MessageDetail m, String account, String Function(String) t) {
    final from = m.fromAddress != null && m.fromAddress != m.from ? '${m.from} <${m.fromAddress}>' : m.from;
    final rows = <(String, String)>[
      // Etichette nella lingua dell'app (L7).
      (formatL10n.printFrom, from),
      if (m.date != null) (formatL10n.printSent, formatPrintDate(m.date!)),
      if (m.to.isNotEmpty) (formatL10n.printTo, m.to.join('; ')),
      if (m.cc.isNotEmpty) (formatL10n.printCc, m.cc.join('; ')),
      (formatL10n.printSubject, m.subject),
      if (m.importance != MailImportance.normal)
        (formatL10n.printImportance, m.importance == MailImportance.high ? formatL10n.printHigh : formatL10n.printLow),
      if (m.attachments.isNotEmpty) (formatL10n.printAttachments, m.attachments.map((a) => a.fileName).join('; ')),
    ];
    const label = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
    const value = pw.TextStyle(fontSize: 10);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(t(account), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Container(height: 2.5, color: PdfColors.black, margin: const pw.EdgeInsets.only(top: 3, bottom: 8)),
        pw.Table(
          columnWidths: const {0: pw.FixedColumnWidth(62), 1: pw.FlexColumnWidth()},
          children: [
            for (final (l, v) in rows)
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(l, style: label)),
                  pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(t(v), style: value)),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  /// Altezza delle intestazioni in punti, per sapere quanto corpo sta nella prima pagina.
  static double _measure(pw.Widget widget, pw.ThemeData theme) {
    final context = pw.Context(document: PdfDocument());
    final themed = pw.Theme(data: theme, child: widget);
    themed.layout(context, pw.BoxConstraints(maxWidth: contentWidth), parentUsesSize: true);
    return themed.box!.height;
  }

  /// «lunedì 9 novembre 2026 10:05», come la riga «Inviato:» di Outlook (nella lingua dell'app).
  static String formatPrintDate(DateTime d) => formatLongDateTime(d);

  /// Helvetica di serie conosce solo Latin-1: gli altri caratteri diventano «?» invece di far fallire il PDF.
  static String latin1Only(String s) => String.fromCharCodes(s.runes.map((r) => r <= 0xff ? r : 0x3f));
}

/// Caratteri per il testo delle intestazioni, presi dal sistema (nessun carattere distribuito con l'app).
class PrintFonts {
  const PrintFonts(this.regular, this.bold);

  final pw.Font regular;
  final pw.Font bold;

  /// Coppie normale/grassetto cercate in quest'ordine: Windows, Linux (Noto, Liberation, DejaVu), macOS.
  static List<(String, String)> get candidates {
    final windows = Platform.environment['WINDIR'] ?? r'C:\Windows';
    return [
      ('$windows\\Fonts\\segoeui.ttf', '$windows\\Fonts\\segoeuib.ttf'),
      ('$windows\\Fonts\\arial.ttf', '$windows\\Fonts\\arialbd.ttf'),
      ('/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf', '/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf'),
      (
        '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
      ),
      ('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'),
      ('/usr/share/fonts/TTF/DejaVuSans.ttf', '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'),
      ('/System/Library/Fonts/Supplemental/Arial.ttf', '/System/Library/Fonts/Supplemental/Arial Bold.ttf'),
    ];
  }

  /// La prima coppia leggibile; null se non ce n'è nessuna (allora Helvetica).
  static Future<PrintFonts?> load([List<(String, String)>? paths]) async {
    for (final (regular, bold) in paths ?? candidates) {
      try {
        final r = await File(regular).readAsBytes();
        final b = await File(bold).readAsBytes();
        return PrintFonts(pw.Font.ttf(r.buffer.asByteData()), pw.Font.ttf(b.buffer.asByteData()));
      } on Object {
        // mancante o non leggibile: la prossima
      }
    }
    return null;
  }
}

/// Un pezzo del corpo, una pagina: pixel RGBA e altezza in pixel logici.
class BodySlice {
  const BodySlice(this.rgba, this.width, this.height, this.heightPx);

  final Uint8List rgba;
  final int width;
  final int height;
  final double heightPx;
}

/// Punti di taglio del corpo alto [total] (pixel logici dall'alto) per pagine alte [first] (la prima, sotto le
/// intestazioni) e [other]. [keep] sono righe di testo e immagini (inizio, fine) da non tagliare: il taglio
/// risale all'inizio della riga, ma non sopra metà pagina (una riga o un'immagine più alta si taglia).
List<double> pageCuts(double total, double first, double other, List<(double, double)> keep) {
  final cuts = <double>[];
  var start = 0.0;
  var page = first < 0 ? 0.0 : first;
  while (total - start > page + 0.5) {
    final target = start + page;
    var cut = target;
    bool inside(double y) => keep.any((k) => k.$1 < y && y < k.$2);
    for (var moved = true; moved;) {
      moved = false;
      for (final (top, bottom) in keep) {
        if (top < cut && cut < bottom && top > start) {
          cut = top;
          moved = true;
        }
      }
    }
    // Un pixel sopra la riga, se lì è vuoto: sul bordo dell'immagine resterebbe la cima delle lettere.
    if (cut != target && !inside(cut - 1)) cut -= 1;
    if (cut < start + page / 2) cut = target;
    cuts.add(cut);
    start = cut;
    page = other;
  }
  return cuts;
}

/// Disegna [body] fuori schermo, largo [width] pixel logici, e lo restituisce diviso in pagine (vedi [pageCuts]).
/// Le immagini nella mail (data:) si decodificano dopo il primo disegno: si ridisegna finché la costruzione
/// resta ferma per 200 ms (al massimo 2 secondi).
Future<List<BodySlice>> renderBody({
  required ui.FlutterView view,
  required Widget body,
  required double width,
  required double first,
  required double other,
  double pixelRatio = MessagePdf.pixelRatio,
}) async {
  final boundary = _CaptureBoundary();
  final renderView = RenderView(
    view: view,
    child: boundary,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints(minWidth: width, maxWidth: width),
      physicalConstraints: BoxConstraints(minWidth: width * pixelRatio, maxWidth: width * pixelRatio),
      devicePixelRatio: pixelRatio,
    ),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  var dirty = false;
  final focus = FocusManager();
  final build = BuildOwner(focusManager: focus, onBuildScheduled: () => dirty = true);
  Widget wrap(Widget? child) => MediaQuery(
    data: MediaQueryData(size: Size(width, 100000), devicePixelRatio: pixelRatio),
    child: Directionality(textDirection: TextDirection.ltr, child: child ?? const SizedBox.shrink()),
  );
  final root = RenderObjectToWidgetAdapter<RenderBox>(container: boundary, child: wrap(body)).attachToRenderTree(build);
  void frame() {
    build.buildScope(root);
    build.finalizeTree();
    pipeline.flushLayout();
    pipeline.flushCompositingBits();
    pipeline.flushPaint();
  }

  try {
    frame();
    var quiet = 0;
    for (var i = 0; i < 40 && quiet < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (dirty) {
        dirty = false;
        frame();
        quiet = 0;
      } else {
        quiet++;
      }
    }

    final total = boundary.size.height;
    final cuts = pageCuts(total, first, other, _keepIntervals(boundary));
    final edges = [0.0, ...cuts, total];
    final slices = <BodySlice>[];
    for (var i = 0; i + 1 < edges.length; i++) {
      final (top, bottom) = (edges[i], edges[i + 1]);
      if (bottom - top < 0.5) continue;
      final image = await boundary.capture(Rect.fromLTRB(0, top, width, bottom), pixelRatio);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        slices.add(BodySlice(data!.buffer.asUint8List(), image.width, image.height, bottom - top));
      } finally {
        image.dispose();
      }
    }
    return slices;
  } finally {
    // Smonta l'albero: stati chiusi, immagini rilasciate.
    RenderObjectToWidgetAdapter<RenderBox>(container: boundary, child: wrap(null)).attachToRenderTree(build, root);
    build.buildScope(root);
    build.finalizeTree();
    focus.dispose();
    pipeline.rootNode = null;
    pipeline.dispose();
  }
}

/// Righe di testo e immagini del corpo, in pixel logici dall'alto: dove non tagliare.
List<(double, double)> _keepIntervals(RenderBox boundary) {
  final keep = <(double, double)>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.hasSize) {
      final m = o.getTransformTo(boundary);
      final length = o.text.toPlainText(includeSemanticsLabels: false).length;
      for (final box in o.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length))) {
        final top = MatrixUtils.transformPoint(m, Offset(0, box.top)).dy;
        final bottom = MatrixUtils.transformPoint(m, Offset(0, box.bottom)).dy;
        keep.add((top, bottom));
      }
    } else if (o is RenderImage && o.hasSize) {
      final r = MatrixUtils.transformRect(o.getTransformTo(boundary), Offset.zero & o.size);
      keep.add((r.top, r.bottom));
    }
    o.visitChildren(visit);
  }

  boundary.visitChildren(visit);
  return keep;
}

class _CaptureBoundary extends RenderRepaintBoundary {
  /// Solo il rettangolo [rect] del disegno (la pagina), non tutto il corpo: un'immagine sola di una mail
  /// lunga supererebbe i limiti delle texture.
  Future<ui.Image> capture(Rect rect, double pixelRatio) =>
      (layer! as OffsetLayer).toImage(rect, pixelRatio: pixelRatio);
}
