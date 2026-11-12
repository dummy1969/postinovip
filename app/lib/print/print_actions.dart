import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../attachments/file_saver.dart';
import '../state/mailbox_model.dart';
import 'message_pdf.dart';

/// Stampa (P3, scelta 2a): il PDF della mail aperta si apre nel visualizzatore PDF del sistema, che ha
/// anteprima e stampante (nessuna parte nativa in più nell'app); oppure si salva dove sceglie l'utente.
class PrintActions {
  /// Apre un file con il programma predefinito; sostituibile nei test.
  static Future<bool> Function(Uri file) openFile = launchUrl;

  /// Cartelle temporanee della stampa (create con permessi solo per l'utente, 0700 su Linux).
  static const tempPrefix = 'postinovip-stampa-';

  /// Una sola mail aperta (non più selezionate).
  static bool canPrint(MailboxModel model) => model.detail != null && model.selectedUid != null && !model.multiSelection;

  /// File → Stampa, Ctrl+P.
  static Future<void> printMessage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _fileName(context);
    final bytes = await _build(context);
    if (bytes == null) return;
    try {
      unawaited(_removeOldTempDirs()); // in sottofondo: la cartella temporanea può avere molti file
      final dir = await Directory.systemTemp.createTemp(tempPrefix);
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(bytes, flush: true);
      final opened = await openFile(Uri.file(file.path));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Aperta l\'anteprima nel visualizzatore PDF: stampa da lì.'
                : 'Nessun programma per aprire i PDF. File in ${file.path}',
          ),
        ),
      );
    } on FileSystemException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Stampa non preparata: ${e.message} (${e.path})')));
    }
  }

  /// File → Salva come PDF.
  static Future<void> saveAsPdf(BuildContext context) async {
    final saver = context.read<FileSaver>();
    final messenger = ScaffoldMessenger.of(context);
    final path = await saver.pickSaveLocation(_fileName(context));
    if (path == null || !context.mounted) return; // annullato
    final bytes = await _build(context);
    if (bytes == null) return;
    try {
      await saver.write(path, bytes);
      messenger.showSnackBar(SnackBar(content: Text('Salvato in $path')));
    } on FileSystemException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('File non scritto: ${e.message} (${e.path})')));
    }
  }

  static String _fileName(BuildContext context) {
    final subject = context.read<MailboxModel>().detail?.subject.trim() ?? '';
    return '${safeFileName(subject.isEmpty ? 'messaggio' : subject)}.pdf';
  }

  /// PDF della mail aperta; null (con l'errore mostrato) se non si può.
  static Future<Uint8List?> _build(BuildContext context) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    final detail = model.detail;
    if (!canPrint(model) || detail == null) return null;
    final account = model.openAccountInfo;
    final view = View.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Preparazione del PDF…'), duration: Duration(seconds: 30)));
    try {
      final pdf = await MessagePdf.build(
        message: detail,
        account: account == null ? '' : (account.name.isNotEmpty ? account.name : account.address),
        view: view,
        fonts: await PrintFonts.load(),
      );
      messenger.hideCurrentSnackBar();
      return pdf;
    } on Object catch (e) {
      // Solo il tipo dell'errore: il messaggio potrebbe contenere testo della mail.
      debugPrint('[stampa] PDF non creato: ${e.runtimeType}');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('PDF non creato: ${e.runtimeType}')));
      return null;
    }
  }

  /// Le stampe di prima (più vecchie di un'ora: il visualizzatore le ha già aperte) non restano nella cartella
  /// temporanea con il testo delle mail.
  static Future<void> _removeOldTempDirs() async {
    final limit = DateTime.now().subtract(const Duration(hours: 1));
    try {
      await for (final entry in Directory.systemTemp.list()) {
        final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
        if (entry is Directory && name.startsWith(tempPrefix) && (await entry.stat()).modified.isBefore(limit)) {
          await entry.delete(recursive: true);
        }
      }
    } on FileSystemException {
      // cartella non leggibile o file in uso: si riprova la prossima volta
    }
  }
}
