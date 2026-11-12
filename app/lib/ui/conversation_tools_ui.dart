import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/app_settings.dart';
import '../state/mailbox_model.dart';
import 'message_actions.dart';

/// Ignora e Pulisci conversazione (C2, scelte 1b, 3b e 4a), come Outlook classico: «Ignora» in Home → Elimina, nella
/// finestra della mail e nel tasto destro; il menu «Pulisci» con Pulisci conversazione e Pulisci cartella. Tutto
/// MODIFICA la casella spostando in Posta eliminata (Interrompi Ignora: in Posta in arrivo); niente si cancella.
class ConversationToolActions {
  ConversationToolActions._();

  /// Ignora / Interrompi Ignora si può usare (mail aperta o selezionate, server raggiungibile).
  static bool canIgnore(MailboxModel model) => MessageActions.canModify(model);

  /// Etichetta del comando: in Posta eliminata, su una conversazione ignorata, «Interrompi Ignora conversazione».
  static String ignoreLabel(MailboxModel model) => model.openIgnoredInTrash ? 'Interrompi Ignora' : 'Ignora';

  static String ignoreTooltip(MailboxModel model) => model.openIgnoredInTrash
      ? 'La conversazione torna in Posta in arrivo e le mail nuove non vanno più in Posta eliminata'
      : 'Sposta in Posta eliminata la conversazione e le mail che arriveranno';

  /// Pulisci conversazione: mail aperta o selezionate, non in Posta eliminata né nella posta indesiderata.
  static bool canCleanUpConversation(MailboxModel model) =>
      MessageActions.canModify(model) && model.selection.every((r) => model.canCleanUpIn(r.account, r.folder));

  /// Pulisci cartella su [folder] di [account] (di serie la cartella aperta, non durante una ricerca).
  static bool canCleanUpFolder(MailboxModel model, {String? account, String? folder}) {
    final a = account ?? (model.searchActive ? null : model.selectedAccount);
    final f = folder ?? (model.searchActive ? null : model.selectedFolder);
    return a != null &&
        f != null &&
        f != MailboxModel.outboxFolder &&
        model.isOnline(a) &&
        !model.actionInProgress &&
        model.canCleanUpIn(a, f);
  }

  /// «Ignora» o «Interrompi Ignora conversazione», con la conferma di Outlook (finché non si spunta «Non
  /// visualizzare più questo messaggio»). [openNext]: nella finestra della mail poi si apre la successiva.
  static Future<void> ignore(BuildContext context, {bool openNext = false}) async {
    final model = context.read<MailboxModel>();
    if (!canIgnore(model)) return;
    final settings = context.read<AppSettings>();
    final messenger = ScaffoldMessenger.of(context);
    final stop = model.openIgnoredInTrash;
    if (stop ? settings.confirmStopIgnoring : settings.confirmIgnore) {
      final answer = await showDialog<_Answer>(
        context: context,
        builder: (_) => _IgnoreDialog(stop: stop),
      );
      if (answer == null) return;
      if (answer.dontAskAgain) {
        await (stop ? settings.setConfirmStopIgnoring(false) : settings.setConfirmIgnore(false));
      }
    }
    Future<void> run() async =>
        _show(messenger, (await (stop ? model.stopIgnoringSelected() : model.ignoreSelected())).message);
    await (openNext ? model.removeAndOpenNext(run) : run());
  }

  /// «Pulisci conversazione»: nessuna conferma (come Outlook; si recupera da Posta eliminata).
  static Future<void> cleanUpConversation(BuildContext context) async {
    final model = context.read<MailboxModel>();
    if (!canCleanUpConversation(model)) return;
    final messenger = ScaffoldMessenger.of(context);
    _show(messenger, (await model.cleanUpSelected()).message);
  }

  /// «Pulisci cartella» (di serie la cartella aperta; dal tasto destro sulle cartelle quella indicata), dopo la conferma.
  static Future<void> cleanUpFolder(BuildContext context, {String? account, String? folder}) async {
    final model = context.read<MailboxModel>();
    if (!canCleanUpFolder(model, account: account, folder: folder)) return;
    account ??= model.selectedAccount!;
    folder ??= model.selectedFolder!;
    final name = model.foldersByAccount[account]?.where((f) => f.fullName == folder).firstOrNull?.name ?? folder;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('clean-up-folder-dialog'),
        icon: const Icon(FluentIcons.broom_20_regular),
        title: const Text('Pulisci cartella'),
        content: Text(
          'Le mail superflue della cartella «$name» (quelle citate per intero da una risposta) verranno spostate '
          'in Posta eliminata. Le mail da leggere, contrassegnate, con categorie o firmate restano dove sono.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          FilledButton(
            key: const Key('clean-up-folder-ok'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pulisci cartella'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _show(messenger, (await model.cleanUpFolder(account, folder)).message);
  }

  /// Voci del menu «Pulisci».
  static List<Widget> cleanUpItems(BuildContext context) {
    final model = context.watch<MailboxModel>();
    return [
      MenuItemButton(
        key: const Key('clean-up-conversation'),
        leadingIcon: const Icon(FluentIcons.chat_multiple_20_regular, size: 16),
        onPressed: canCleanUpConversation(model) ? () => cleanUpConversation(context) : null,
        child: const Text('Pulisci conversazione'),
      ),
      MenuItemButton(
        key: const Key('clean-up-folder'),
        leadingIcon: const Icon(FluentIcons.folder_20_regular, size: 16),
        onPressed: canCleanUpFolder(model) ? () => cleanUpFolder(context) : null,
        child: const Text('Pulisci cartella'),
      ),
    ];
  }

  static void _show(ScaffoldMessengerState messenger, String text) {
    if (text.isEmpty) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

typedef _Answer = ({bool dontAskAgain});

/// Conferma di Ignora / Interrompi Ignora conversazione, con «Non visualizzare più questo messaggio».
class _IgnoreDialog extends StatefulWidget {
  const _IgnoreDialog({required this.stop});

  final bool stop;

  @override
  State<_IgnoreDialog> createState() => _IgnoreDialogState();
}

class _IgnoreDialogState extends State<_IgnoreDialog> {
  bool _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.stop ? 'Interrompi Ignora conversazione' : 'Ignora conversazione';
    return AlertDialog(
      key: const Key('ignore-dialog'),
      icon: Icon(widget.stop ? FluentIcons.mail_arrow_up_20_regular : FluentIcons.mail_prohibited_20_regular),
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.stop
                ? 'La conversazione selezionata non verrà più ignorata e le sue mail in Posta eliminata verranno '
                      'spostate in Posta in arrivo.'
                : 'Le mail della conversazione selezionata in questa cartella e tutte quelle che arriveranno verranno '
                      'spostate in Posta eliminata.',
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const Key('ignore-dont-ask'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _dontAskAgain,
            onChanged: (v) => setState(() => _dontAskAgain = v ?? false),
            title: const Text('Non visualizzare più questo messaggio'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          key: const Key('ignore-ok'),
          onPressed: () => Navigator.pop<_Answer>(context, (dontAskAgain: _dontAskAgain)),
          child: Text(title),
        ),
      ],
    );
  }
}
