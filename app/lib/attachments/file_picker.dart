import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// File scelto dal disco per essere allegato.
class PickedFile {
  const PickedFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Scelta di file da allegare; sostituibile nei test.
abstract interface class FilePickerService {
  /// Vuota se l'utente annulla.
  Future<List<PickedFile>> pickFiles();

  /// Un solo file con una di queste estensioni (es. importazione dei contatti); null se l'utente annulla.
  Future<PickedFile?> pickFile({required String label, required List<String> extensions});
}

class SystemFilePicker implements FilePickerService {
  @override
  Future<List<PickedFile>> pickFiles() async {
    final files = await openFiles(); // finestra di sistema, selezione multipla
    return [for (final f in files) PickedFile(f.name, await f.readAsBytes())];
  }

  @override
  Future<PickedFile?> pickFile({required String label, required List<String> extensions}) async {
    final f = await openFile(
      acceptedTypeGroups: [XTypeGroup(label: label, extensions: extensions)],
    );
    return f == null ? null : PickedFile(f.name, await f.readAsBytes());
  }
}

/// Dimensione leggibile (1,2 MB / 340 KB).
String formatSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes byte';
}
