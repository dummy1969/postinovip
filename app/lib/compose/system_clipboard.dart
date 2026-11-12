import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// ClipboardService è esportato da internal.dart ed è sperimentale in flutter_quill 11.6.0: da ricontrollare
// a ogni aggiornamento del pacchetto (lo copre test/system_clipboard_test.dart).
// ignore: experimental_member_use
import 'package:flutter_quill/internal.dart' show ClipboardService, ClipboardServiceProvider;

/// Appunti dell'editor su Linux (scelta A sulla licenza di xclip): HTML e immagini letti con GTK dal
/// programma nativo dell'app (`linux/runner/clipboard_channel.cc`) invece che con lo xclip precompilato
/// (GPL) incluso da quill_native_bridge_linux, che così non viene mai eseguito e non va nei pacchetti.
/// Funziona anche con Wayland. Su Windows e macOS resta il servizio di serie di flutter_quill.
// ignore: experimental_member_use
class GtkClipboardService extends ClipboardService {
  GtkClipboardService({MethodChannel? channel}) : _channel = channel ?? defaultChannel;

  static const defaultChannel = MethodChannel('com.dumm1969.postinovip/clipboard');

  final MethodChannel _channel;

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      debugPrint('[appunti] $method non riuscito: ${e.message}');
      return null;
    } on MissingPluginException {
      return null; // programma nativo senza il canale (es. test): come appunti vuoti
    }
  }

  @override
  Future<String?> getHtmlText() async {
    final bytes = await _call<Uint8List>('getHtml');
    return bytes == null ? null : decodeClipboardHtml(bytes);
  }

  @override
  Future<Uint8List?> getImageFile() => _call<Uint8List>('getImage');

  @override
  Future<void> copyImage(Uint8List imageBytes) => _call<void>('copyImage', imageBytes);

  // File HTML o Markdown copiati da un file manager e GIF animate: non gestiti (incolla normale).
  @override
  Future<String?> getHtmlFile() async => null;

  @override
  Future<String?> getMarkdownFile() async => null;

  @override
  Future<Uint8List?> getGifFile() async => null;
}

/// Su Linux l'editor usa [GtkClipboardService]; da chiamare una volta all'avvio.
void installSystemClipboard() {
  if (!kIsWeb && Platform.isLinux) {
    // ignore: experimental_member_use
    ClipboardServiceProvider.setInstance(GtkClipboardService());
  }
}

/// HTML degli appunti: UTF-8 (Chromium e la maggior parte dei programmi) o UTF-16 (Firefox), con o senza
/// BOM; null se vuoto.
String? decodeClipboardHtml(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  String text;
  final littleBom = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE;
  final bigBom = bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF;
  if (littleBom || bigBom || _looksUtf16(bytes)) {
    final start = littleBom || bigBom ? 2 : 0;
    final big = bigBom;
    final units = <int>[
      for (var i = start; i + 1 < bytes.length; i += 2) big ? bytes[i] << 8 | bytes[i + 1] : bytes[i] | bytes[i + 1] << 8,
    ];
    text = String.fromCharCodes(units);
  } else {
    text = utf8.decode(bytes, allowMalformed: true);
  }
  text = text.replaceAll('\u0000', '').trim();
  return text.isEmpty ? null : text;
}

/// UTF-16 senza BOM: l'HTML è quasi tutto ASCII, quindi un byte su due (quello alto) è zero.
bool _looksUtf16(Uint8List b) {
  if (b.length < 4) return false;
  final sample = b.length < 200 ? b.length : 200;
  var zeros = 0;
  for (var i = 1; i < sample; i += 2) {
    if (b[i] == 0) zeros++;
  }
  return zeros > sample / 4;
}
