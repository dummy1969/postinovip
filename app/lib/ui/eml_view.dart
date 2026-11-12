import 'dart:async';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../attachments/file_picker.dart';
import '../attachments/file_saver.dart';
import '../models/compose_draft.dart';
import '../models/message_detail.dart';
import '../state/mailbox_model.dart';
import 'compose_page.dart';
import 'reading_pane.dart';

/// File .eml (E2, scelte 1a e 2a): «Salva con nome…» della mail aperta e «Apri file .eml…», anche per le mail
/// allegate. Il file aperto resta nel core, in memoria e in sola lettura, finché la sua finestra è aperta.
class EmlActions {
  /// Una sola mail aperta (non più selezionate).
  static bool canSave(MailboxModel model) => model.detail != null && model.selectedUid != null && !model.multiSelection;

  /// File → «Salva con nome…» (F12, come Outlook): i byte originali della mail in un file .eml.
  static Future<void> saveAs(BuildContext context) async {
    final model = context.read<MailboxModel>();
    final saver = context.read<FileSaver>();
    final messenger = ScaffoldMessenger.of(context);
    final (detail, folder, uid) = (model.detail, model.openFolder, model.selectedUid);
    if (!canSave(model) || detail == null || folder == null || uid == null) return;
    final api = model.accountApi;
    final path = await saver.pickSaveLocation(fileName(detail.subject));
    if (path == null) return; // annullato
    try {
      await saver.write(path, await api.getRawMessage(folder, uid));
      messenger.showSnackBar(SnackBar(content: Text('Salvato in $path')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Mail non salvata: $e')));
    } on FileSystemException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('File non scritto: ${e.message} (${e.path})')));
    }
  }

  /// File → «Apri file .eml…».
  static Future<void> openFile(BuildContext context) async {
    final picked = await context.read<FilePickerService>().pickFile(label: 'Messaggi di posta', extensions: ['eml']);
    if (picked == null || !context.mounted) return; // annullato
    await open(context, picked.bytes, name: picked.name);
  }

  /// Apre [bytes] (un file .eml o una mail allegata) nella sua finestra; la chiude nel core quando si chiude.
  static Future<void> open(BuildContext context, Uint8List bytes, {String? name}) async {
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final ({String id, MessageDetail message}) opened;
    try {
      opened = await api.openEml(bytes);
    } on ApiException catch (e) {
      final why = e.fieldErrors['file']?.firstOrNull ?? '$e';
      messenger.showSnackBar(SnackBar(content: Text('${name ?? 'File'} non aperto: $why')));
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => EmlPage(id: opened.id, message: opened.message, bytes: bytes, name: name)),
    );
    // Chiusa la finestra il core lo dimentica; se non risponde, lo chiude da solo oltre i 20 file aperti.
    unawaited(api.closeEml(opened.id).catchError((Object _) {}));
  }

  /// Nome proposto per salvare: l'oggetto, senza caratteri non validi.
  static String fileName(String subject) =>
      '${safeFileName(subject.trim().isEmpty ? 'messaggio' : subject.trim())}.eml';
}

/// Finestra di un file .eml: la mail come nel riquadro di lettura, sola lettura, con Rispondi, Rispondi a tutti,
/// Inoltra e «Salva con nome…». Esc chiude, come la mail aperta a tutta finestra.
class EmlPage extends StatelessWidget {
  const EmlPage({super.key, required this.id, required this.message, required this.bytes, this.name});

  final String id;
  final MessageDetail message;

  /// I byte del file, per «Salva con nome» (anche di una mail allegata).
  final Uint8List bytes;

  /// Nome del file aperto, se c'è.
  final String? name;

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: theme.colorScheme.surfaceContainer,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    TextButton.icon(
                      key: const Key('eml-close'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Chiudi (Esc)'),
                    ),
                    const SizedBox(width: 8),
                    Icon(FluentIcons.mail_20_regular, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name ?? 'Messaggio',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text('Sola lettura', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      key: const Key('eml-save'),
                      onPressed: () => _save(context),
                      icon: const Icon(FluentIcons.save_20_regular, size: 18),
                      label: const Text('Salva con nome…'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: MessageView(
                  message,
                  attachmentBytes: (index) => api.getEmlAttachmentBytes(id, index),
                  attachmentUrl: (a) => api.emlAttachmentUrl(id, a.index),
                  attachmentHeaders: api.authHeaders,
                  onReply: (mode) => _reply(context, mode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final saver = context.read<FileSaver>();
    final messenger = ScaffoldMessenger.of(context);
    final path = await saver.pickSaveLocation(name != null && name!.toLowerCase().endsWith('.eml')
        ? safeFileName(name!)
        : EmlActions.fileName(message.subject));
    if (path == null) return;
    try {
      await saver.write(path, bytes);
      messenger.showSnackBar(SnackBar(content: Text('Salvato in $path')));
    } on FileSystemException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('File non scritto: ${e.message} (${e.path})')));
    }
  }

  /// Risposta o inoltro dall'account in uso (come Outlook per un file aperto). Citazione e allegati inoltrati
  /// entrano subito nella composizione, così questa finestra si può chiudere prima di inviare.
  Future<void> _reply(BuildContext context, DraftMode mode) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    final account = model.currentAccount ?? model.accounts.firstOrNull;
    final root = context.read<ApiClient>();
    final api = account == null ? root : root.forAccount(account.id);
    try {
      final draft = await api.getEmlDraft(id, mode);
      final files = [
        for (final a in draft.forwardAttachments) PickedFile(a.fileName, await root.getEmlAttachmentBytes(id, a.index)),
      ];
      if (!context.mounted) return;
      await openCompose(
        context,
        title: mode.label,
        account: account,
        accounts: model.accounts,
        files: files,
        draft: ComposeDraft(
          to: draft.to,
          cc: draft.cc,
          subject: draft.subject,
          body: draft.body,
          inReplyTo: draft.inReplyTo,
          references: draft.references,
          quoteHtml: draft.quoteHtml,
          quoteInline: true,
          mode: mode,
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Bozza non disponibile: $e')));
    }
  }
}
