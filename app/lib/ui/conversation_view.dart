import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/app_settings.dart';
import '../state/mailbox_model.dart';

/// "Mostra come conversazioni" (Visualizza, scelta 3.6-3a): come Outlook chiede se la modifica vale
/// per la cartella aperta o per tutte. Ricordato solo su questo computer.
class ConversationViewCommand {
  ConversationViewCommand._();

  /// Stato del comando per la cartella aperta (null: nessuna cartella).
  static bool? isOn(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final settings = context.watch<AppSettings>();
    final (account, folder) = (model.selectedAccount, model.selectedFolder);
    return account == null || folder == null ? null : settings.showsConversations(account, folder);
  }

  static Future<void> toggle(BuildContext context) async {
    final model = context.read<MailboxModel>();
    final settings = context.read<AppSettings>();
    final (account, folder) = (model.selectedAccount, model.selectedFolder);
    if (account == null || folder == null) return;
    final on = !settings.showsConversations(account, folder);
    final name = model.selectedFolderInfo?.name ?? folder;
    final allFolders = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(on ? 'Mostra come conversazioni' : 'Non mostrare come conversazioni'),
        content: Text(
          on
              ? 'Le mail della stessa conversazione verranno raccolte in una riga, con le risposte che stanno in altre cartelle.\n\n'
                    'Applicare a "$name" o a tutte le cartelle?'
              : 'Applicare a "$name" o a tutte le cartelle?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tutte le cartelle')),
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Questa cartella')),
        ],
      ),
    );
    if (allFolders == null) return;
    await model.setConversationView(on, allFolders: allFolders);
  }
}
