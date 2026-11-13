import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final mails = switch (folder.count) {
      null => 'Tutte le mail',
      1 => 'L\'unica mail',
      final n => 'Tutte le $n mail',
    };
    final also = switch (subfolders) {
      0 => '',
      1 => ' e la sottocartella, con le sue mail,',
      final n => ' e le $n sottocartelle, con le loro mail,',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever),
        title: Text('Svuotare "${folder.name}"?'),
        content: Text('$mails di "${folder.name}"$also verranno cancellate dal server.\nL\'operazione non è reversibile.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(
            key: const Key('empty-folder-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Svuota cartella'),
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
        title: Text(permanent ? 'Eliminare definitivamente la cartella?' : 'Eliminare la cartella?'),
        content: Text(
          permanent
              ? 'La cartella "$name", con tutte le mail e le sottocartelle, verrà cancellata dal server.\n'
                    'L\'operazione non è reversibile.'
              : 'La cartella "$name", con tutte le mail e le sottocartelle, verrà spostata in Posta eliminata.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: permanent ? TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error) : null,
            child: Text(permanent ? 'Elimina definitivamente' : 'Elimina'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
