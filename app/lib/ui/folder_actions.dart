import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/language.dart';
import '../models/mail_folder.dart';
import '../state/mailbox_model.dart';

/// Comandi sulle cartelle (3.4b), condivisi da scheda Cartella, menu del tasto destro e F2.
/// Tutti MODIFICANO la casella sul server.
class FolderActions {
  FolderActions._();

  /// Cartella selezionata nel riquadro (null se non ce n'è una).
  static ({String account, MailFolder folder})? selected(MailboxModel model) {
    final account = model.selectedAccount;
    final folder = model.selectedFolderInfo;
    return account == null || folder == null ? null : (account: account, folder: folder);
  }

  /// F2 / "Rinomina cartella" sulla cartella selezionata.
  static void renameSelected(BuildContext context) {
    final model = context.read<MailboxModel>();
    if (selected(model) case final s?) model.startRenameFolder(s.account, s.folder.fullName);
  }

  /// Elimina con conferma: in Posta eliminata in modo definitivo (unica operazione non reversibile).
  static Future<void> delete(BuildContext context, String account, MailFolder folder) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    final permanent = model.isInTrash(account, folder);
    if (!await _confirm(context, folder.name, permanent)) return;
    final outcome = await model.deleteFolder(account, folder);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  /// "Svuota cartella" (Posta eliminata e Posta indesiderata) con conferma: non reversibile.
  static Future<void> empty(BuildContext context, String account, MailFolder folder) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    final subfolders = folder.role == 'trash' ? model.subfoldersOf(account, folder).length : 0;
    final l = context.l10n;
    final mails = switch (folder.count) {
      null => l.emptyFolderAllMails,
      1 => l.emptyFolderOnlyMail,
      final n => l.emptyFolderNMails(n),
    };
    final also = switch (subfolders) {
      0 => '',
      1 => l.emptyFolderOneSubfolder,
      final n => l.emptyFolderNSubfolders(n),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever),
        title: Text(l.emptyFolderQuestion(folder.name)),
        content: Text(l.emptyFolderContent(mails, folder.name, also)),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          TextButton(
            key: const Key('empty-folder-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(context.l10n.emptyFolder),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final outcome = await model.emptyFolder(account, folder);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  static Future<bool> _confirm(BuildContext context, String name, bool permanent) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(permanent ? Icons.delete_forever : Icons.delete_outline),
        title: Text(permanent ? context.l10n.deleteFolderPermanentlyQuestion : context.l10n.deleteFolderQuestion),
        content: Text(permanent ? context.l10n.deleteFolderPermanentlyContent(name) : context.l10n.deleteFolderContent(name)),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: permanent ? TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error) : null,
            child: Text(permanent ? context.l10n.deletePermanently : context.l10n.delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
