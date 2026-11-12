import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/compose_draft.dart';
import '../attachments/file_picker.dart';
import '../models/mail_folder.dart';
import '../models/send_result.dart';
import '../state/mailbox_model.dart';
import 'compose_page.dart';
import 'move_dialog.dart';

/// Comandi sulla mail aperta, condivisi da barra multifunzione e pannello di lettura.
/// Agiscono sempre sull'account e sulla cartella della mail aperta (che dopo una ricerca possono
/// essere diversi da quelli selezionati).
class MessageActions {
  MessageActions._();

  /// C'è una mail aperta su cui agire.
  static bool hasMessage(MailboxModel model) => model.detail != null && model.selectedUid != null;

  /// Comandi che modificano la casella: servono una mail aperta (o più mail selezionate, 3.5a), il
  /// server raggiungibile e nessun'altra operazione in corso.
  static bool canModify(MailboxModel model) => model.multiSelection
      ? model.canModifySelection
      : hasMessage(model) && model.isOnline(model.openAccount) && !model.actionInProgress;

  /// C'è qualcosa su cui agire: la mail aperta o più mail selezionate.
  static bool hasTarget(MailboxModel model) => model.multiSelection || hasMessage(model);

  /// Stato letto per l'etichetta del comando: true = "Segna come non letto". Con più mail come
  /// Outlook: se ce n'è almeno una da leggere il comando le segna tutte come lette.
  static bool? seenState(MailboxModel model) {
    if (model.multiSelection) return !model.selectionHasUnread;
    return model.selectedUid == null ? null : model.isSeen(model.selectedUid!);
  }

  /// "Elimina" sarà definitivo (mail aperta o almeno una delle selezionate in Posta eliminata).
  static bool deletesPermanently(MailboxModel model) =>
      model.multiSelection ? model.selectionInTrash : model.inTrash && hasMessage(model);

  /// Destinazioni di "Sposta".
  static List<MailFolder> moveTargets(MailboxModel model) => model.multiSelection
      ? model.selectionMoveTargets
      : [
          for (final f in model.openAccountFolders)
            if (f.fullName != model.openFolder) f,
        ];

  /// Nuovo messaggio: proposto l'account della cartella aperta (come Outlook); si cambia con "Da:".
  static Future<void> compose(BuildContext context) {
    final model = context.read<MailboxModel>();
    return openCompose(context, account: model.currentAccount ?? model.accounts.firstOrNull, accounts: model.accounts);
  }

  /// Chiede al core la bozza (destinatari, oggetto, citazione, thread) e apre la composizione.
  static Future<void> reply(BuildContext context, DraftMode mode) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    final folder = model.openFolder;
    final uid = model.selectedUid;
    if (folder == null || uid == null) return;
    final account = model.openAccountInfo;
    try {
      final draft = (await model.accountApi.getDraft(folder, uid, mode)).withForwardSource(
        folder,
        uid,
        account: account?.id,
        mode: mode,
      );
      if (!context.mounted) return;
      await openCompose(context, draft: draft, title: mode.label, account: account, accounts: model.accounts);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Bozza non disponibile: $e')));
    }
  }

  /// Riapre la bozza aperta nella composizione (3.8): testo scritto, citazione e allegati (ripresi dal server
  /// o dalla copia locale); salvando o inviando la bozza viene sostituita o eliminata.
  static Future<void> editDraft(BuildContext context) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    final folder = model.openFolder;
    final uid = model.selectedUid;
    if (folder == null || uid == null) return;
    final api = model.accountApi;
    try {
      final content = await api.getComposeContent(folder, uid);
      final files = [
        for (final a in content.attachments) PickedFile(a.fileName, await api.getAttachmentBytes(folder, uid, a.index)),
      ];
      if (!context.mounted) return;
      await openCompose(
        context,
        title: 'Bozza',
        account: model.openAccountInfo,
        accounts: model.accounts,
        files: files,
        draft: ComposeDraft(
          to: content.to,
          cc: content.cc,
          bcc: content.bcc,
          subject: content.subject,
          body: content.text,
          htmlBody: content.html ?? (content.text.isEmpty ? '' : null),
          inReplyTo: content.inReplyTo,
          references: content.references,
          quoteHtml: content.quoteHtml,
          quoteInline: true,
          draftRef: DraftRef(uid: uid),
          importance: content.importance,
          readReceipt: content.readReceipt,
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Bozza non disponibile: $e')));
    }
  }

  /// Elimina la mail aperta: in Posta eliminata in modo definitivo, dopo una conferma esplicita.
  static Future<void> delete(BuildContext context) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    if (model.multiSelection) {
      final inTrash = model.selection.where((r) => model.isInTrashFolder(r.account, r.folder)).length;
      if (inTrash > 0 && !await _confirmPermanentDeleteMany(context, inTrash)) return;
      final outcome = await model.deleteSelected();
      messenger
        ..hideCurrentSnackBar() // con azioni in fila l'esito nuovo prende il posto del precedente
        ..showSnackBar(SnackBar(content: Text(outcome.message)));
      return;
    }
    final uid = model.selectedUid;
    if (uid == null) return;
    if (model.inTrash && !await _confirmPermanentDelete(context, model.detail?.subject ?? '')) return;
    final outcome = await model.deleteMessage(uid);
    if (outcome != null) messenger.showSnackBar(SnackBar(content: Text(outcome)));
  }

  static Future<void> move(BuildContext context, String destination) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    if (model.multiSelection) {
      final outcome = await model.moveSelected(destination);
      messenger
        ..hideCurrentSnackBar() // con azioni in fila l'esito nuovo prende il posto del precedente
        ..showSnackBar(SnackBar(content: Text(outcome.message)));
      return;
    }
    final uid = model.selectedUid;
    if (uid == null) return;
    final outcome = await model.moveMessage(uid, destination);
    if (outcome != null) messenger.showSnackBar(SnackBar(content: Text(outcome)));
  }

  /// "Segna come letto" / "Segna come non letto" sulla mail aperta (null: stato non noto).
  static Future<void> toggleSeen(BuildContext context) async {
    final model = context.read<MailboxModel>();
    if (model.multiSelection) {
      final messenger = ScaffoldMessenger.of(context);
      final outcome = await model.setSeenSelected(model.selectionHasUnread);
      messenger
        ..hideCurrentSnackBar() // con azioni in fila l'esito nuovo prende il posto del precedente
        ..showSnackBar(SnackBar(content: Text(outcome.message)));
      return;
    }
    final uid = model.selectedUid;
    final seen = uid == null ? null : model.isSeen(uid);
    if (uid == null || seen == null) return;
    await model.setSeen(uid, !seen);
  }

  /// Più mail: la conferma dice quante verranno cancellate (le altre selezionate vanno in Posta eliminata).
  static Future<bool> _confirmPermanentDeleteMany(BuildContext context, int count) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever),
        title: const Text('Eliminare definitivamente?'),
        content: Text(
          '${count == 1 ? '1 mail selezionata in Posta eliminata verrà cancellata' : '$count mail selezionate in Posta eliminata verranno cancellate'} '
          'dal server.\nL\'operazione non è reversibile.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Elimina definitivamente'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Ctrl+Q / Ctrl+U: segna come letto o da leggere la mail aperta o tutte le selezionate.
  static Future<void> setSeen(BuildContext context, bool seen) async {
    final model = context.read<MailboxModel>();
    if (model.multiSelection) {
      final messenger = ScaffoldMessenger.of(context);
      final outcome = await model.setSeenSelected(seen);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(outcome.message)));
      return;
    }
    final uid = model.selectedUid;
    if (uid != null && model.isSeen(uid) != seen) await model.setSeen(uid, seen);
  }

  /// Ctrl+Maiusc+V e "Altra cartella…": finestra "Sposta elementi" (scelta 3.5b-2a), poi sposta.
  static Future<void> moveToFolder(BuildContext context) async {
    final model = context.read<MailboxModel>();
    final targets = moveTargets(model);
    if (targets.isEmpty) return;
    final destination = await showDialog<String>(
      context: context,
      builder: (_) => MoveDialog(folders: targets, count: model.multiSelection ? model.selection.length : 1),
    );
    if (destination != null && context.mounted) await move(context, destination);
  }

  /// Unica operazione non reversibile: conferma esplicita, pulsante "Annulla" come predefinito.
  static Future<bool> _confirmPermanentDelete(BuildContext context, String subject) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever),
        title: const Text('Eliminare definitivamente?'),
        content: Text('"$subject" verrà cancellato dal server.\nL\'operazione non è reversibile.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Elimina definitivamente'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
