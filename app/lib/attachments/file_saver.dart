import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../l10n/formats.dart';

/// Nome di file sicuro a partire da quello scelto dal mittente della mail: niente percorsi
/// ("../../.bashrc" -> ".bashrc"), niente caratteri di controllo né caratteri non validi su Windows.
String safeFileName(String name) {
  var s = name.split(RegExp(r'[/\\]')).last;
  s = s.replaceAll(RegExp(r'[\x00-\x1f<>:"|?*]'), '_').trim();
  s = s.replaceAll(RegExp(r'^\.+$'), ''); // "." e ".." da soli non sono nomi
  s = s.replaceAll(RegExp(r'[ .]+$'), ''); // Windows ignora punti e spazi finali
  if (s.length > 200) s = s.substring(s.length - 200);
  return s.isEmpty ? formatL10n.defaultAttachmentFileName : s;
}

/// Sceglie dove salvare e scrive il file. Separato dalla UI per poterlo sostituire nei test.
abstract interface class FileSaver {
  /// Percorso scelto dall'utente, null se annulla.
  Future<String?> pickSaveLocation(String suggestedName);
  Future<void> write(String path, Uint8List bytes);
}

class SystemFileSaver implements FileSaver {
  @override
  Future<String?> pickSaveLocation(String suggestedName) async =>
      (await getSaveLocation(suggestedName: suggestedName))?.path;

  @override
  Future<void> write(String path, Uint8List bytes) => File(path).writeAsBytes(bytes, flush: true);
}
