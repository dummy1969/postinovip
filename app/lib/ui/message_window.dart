import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/compose_draft.dart';
import '../print/print_actions.dart';
import '../settings/app_settings.dart';
import '../state/mailbox_model.dart';
import 'eml_view.dart';
import 'archive_ui.dart';
import 'conversation_tools_ui.dart';
import 'junk_ui.dart';
import 'message_actions.dart';
import 'reading_pane.dart';
import 'reading_zoom.dart';
import 'ribbon_parts.dart';
import 'rules_dialog.dart';
import 'tag_menus.dart';

/// Apre la mail selezionata nella sua finestra (scelta 1b del 09/11/2026): doppio clic o Invio, come Outlook. Per ora
/// è una pagina a tutta finestra dentro l'app (le finestre vere di Flutter sono ancora sperimentali; il pacchetto
/// desktop_multi_window è stato scartato per il crash su Linux alla chiusura di una finestra). Una conversazione: la
/// sua mail più recente.
Future<void> openMessageWindow(BuildContext context) async {
  final model = context.read<MailboxModel>();
  if (model.messageWindowOpen || !MessageWindow.shows(model)) return;
  model.messageWindowOpen = true;
  unawaited(model.markOpened()); // ora vale «Segna come letto»
  try {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MessageWindow()));
  } finally {
    model.messageWindowOpen = false;
  }
}

/// La mail aperta con la sua barra «Messaggio» (Elimina, Rispondi, Sposta, Tag, Zoom) e il menu File (Salva con nome,
/// Stampa), le frecce ↑ ↓ per la precedente e la successiva della lista. Mostra sempre la mail selezionata nella lista:
/// spostandosi con le frecce, o dopo Elimina e Sposta (si apre la successiva), la lista dietro segue. Senza più una mail
/// selezionata si chiude da sola.
class MessageWindow extends StatefulWidget {
  const MessageWindow({super.key});

  /// C'è una mail da mostrare: una sola selezionata, o la riga di una conversazione.
  static bool shows(MailboxModel model) =>
      model.selectedUid != null && (!model.multiSelection || model.selectedConversation != null);

  @override
  State<MessageWindow> createState() => _MessageWindowState();
}

class _MessageWindowState extends State<MessageWindow> {
  static const _otherFolder = '\u0000altra';
  bool _closing = false;

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    if (!MessageWindow.shows(model)) {
      // Mail tolta (ultima della cartella) o selezione cambiata: si torna alla lista. Controllato di nuovo dopo il
      // disegno: tra l'eliminazione e l'apertura della successiva la selezione è vuota per un attimo.
      if (!_closing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _closing || MessageWindow.shows(context.read<MailboxModel>())) return;
          _closing = true;
          _close();
        });
      }
      return const Scaffold(body: SizedBox.shrink());
    }
    final settings = context.read<AppSettings>();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        // Come Outlook: Ctrl+, e Ctrl+. elemento precedente e successivo.
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () => _step(-1),
        const SingleActivator(LogicalKeyboardKey.period, control: true): () => _step(1),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () => _reply(DraftMode.reply),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true, shift: true): () => _reply(DraftMode.replyAll),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => _reply(DraftMode.forward),
        const SingleActivator(LogicalKeyboardKey.delete): _delete,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _delete,
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () {
          if (MessageActions.canModify(model)) MessageActions.setSeen(context, true);
        },
        const SingleActivator(LogicalKeyboardKey.keyU, control: true): () {
          if (MessageActions.canModify(model)) MessageActions.setSeen(context, false);
        },
        const SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true): () => _move(_otherFolder),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () => PrintActions.printMessage(context),
        const SingleActivator(LogicalKeyboardKey.f12): () => EmlActions.saveAs(context),
        const SingleActivator(LogicalKeyboardKey.f1, control: true): () =>
            settings.setRibbonCollapsed(!settings.ribbonCollapsed),
        ...ZoomedBody.shortcuts(settings),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: const ValueKey('message-window'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TitleBar(
                subject: model.detail?.subject ?? '',
                onPrevious: model.canMoveCursor(-1) ? () => _step(-1) : null,
                onNext: model.canMoveCursor(1) ? () => _step(1) : null,
                onClose: _close,
              ),
              RibbonFrame(
                leading: const _FileMenu(),
                tabs: const ['Messaggio'],
                selected: 0,
                onSelect: (_) {},
                groups: _groups(model),
              ),
              const Expanded(child: ReadingPane()),
            ],
          ),
        ),
      ),
    );
  }

  /// Mail precedente o successiva della lista (anche la lista dietro si sposta).
  void _step(int delta) {
    final model = context.read<MailboxModel>();
    if (model.canMoveCursor(delta)) model.moveCursor(delta);
  }

  void _reply(DraftMode mode) {
    if (MessageActions.hasMessage(context.read<MailboxModel>())) MessageActions.reply(context, mode);
  }

  void _delete() {
    final model = context.read<MailboxModel>();
    if (MessageActions.canModify(model)) model.removeAndOpenNext(() => MessageActions.delete(context));
  }

  void _move(String destination) {
    final model = context.read<MailboxModel>();
    if (!MessageActions.canModify(model)) return;
    model.removeAndOpenNext(() => destination == _otherFolder
        ? MessageActions.moveToFolder(context)
        : MessageActions.move(context, destination));
  }

  List<Widget> _groups(MailboxModel model) {
    final hasMessage = MessageActions.hasMessage(model);
    final canModify = MessageActions.canModify(model);
    final offlineHint = hasMessage && !model.isOnline(model.openAccount) ? MailboxModel.offlineMessage : null;
    final seen = MessageActions.seenState(model);
    final tagTarget = canModify ? TagTarget.open(model) : null;
    final moveTargets = MessageActions.moveTargets(model);
    final permanent = MessageActions.deletesPermanently(model);
    final zoom = context.watch<AppSettings>().readingZoom;
    return [
      RibbonGroup(
        label: 'Elimina',
        children: [
          RibbonLargeButton(
            key: const Key('message-window-delete'),
            icon: FluentIcons.delete_24_regular,
            label: permanent ? 'Elimina definitivamente' : 'Elimina',
            tooltip:
                offlineHint ??
                (permanent
                    ? 'Elimina dal server, senza possibilità di recupero (poi la mail successiva)'
                    : 'Sposta in Posta eliminata e apri la mail successiva (Canc)'),
            onPressed: canModify ? _delete : null,
          ),
          RibbonLargeButton(
            key: const Key('message-window-archive'),
            icon: FluentIcons.archive_24_regular,
            label: 'Archivia',
            tooltip: offlineHint ??
                (model.selectionInArchive
                    ? ArchiveActions.tooltip(model)
                    : 'Sposta nella cartella di archiviazione e apri la mail successiva'),
            onPressed: ArchiveActions.canArchive(model) ? () => ArchiveActions.archive(context, openNext: true) : null,
          ),
          RibbonSmallColumn(
            children: [
              // Ignora (C2): come la finestra del messaggio di Outlook, poi la mail successiva.
              RibbonSmallButton(
                key: const Key('message-window-ignore'),
                icon: FluentIcons.mail_prohibited_20_regular,
                label: ConversationToolActions.ignoreLabel(model),
                tooltip: offlineHint ?? ConversationToolActions.ignoreTooltip(model),
                onPressed: ConversationToolActions.canIgnore(model)
                    ? () => ConversationToolActions.ignore(context, openNext: true)
                    : null,
              ),
              RibbonMenuButton(
                key: const Key('message-window-junk'),
                icon: FluentIcons.person_prohibited_20_regular,
                label: 'Posta indesiderata',
                tooltip: 'Blocca mittente, Non bloccare mai, Opzioni posta indesiderata',
                enabled: true,
                menuChildren: JunkActions.menuItems(context, openNext: true),
              ),
            ],
          ),
        ],
      ),
      RibbonGroup(
        label: 'Rispondi',
        children: [
          for (final (mode, icon) in [
            (DraftMode.reply, FluentIcons.arrow_reply_24_regular),
            (DraftMode.replyAll, FluentIcons.arrow_reply_all_24_regular),
            (DraftMode.forward, FluentIcons.arrow_forward_24_regular),
          ])
            RibbonLargeButton(
              key: Key('message-window-${mode.name}'),
              icon: icon,
              label: mode.label,
              onPressed: hasMessage ? () => _reply(mode) : null,
            ),
        ],
      ),
      RibbonGroup(
        label: 'Sposta',
        children: [
          PopupMenuButton<String>(
            enabled: canModify && moveTargets.isNotEmpty,
            tooltip: offlineHint ?? 'Sposta in un\'altra cartella e apri la mail successiva',
            onSelected: _move,
            itemBuilder: (context) => [
              for (final f in moveTargets) PopupMenuItem(value: f.fullName, child: Text(f.fullName)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: _otherFolder, child: Text('Altra cartella… (Ctrl+Maiusc+V)')),
            ],
            child: RibbonLargeButton(
              icon: FluentIcons.folder_arrow_right_24_regular,
              label: 'Sposta',
              enabled: canModify && moveTargets.isNotEmpty,
            ),
          ),
          RibbonSmallColumn(
            children: [
              RibbonMenuButton(
                icon: FluentIcons.filter_20_regular,
                label: 'Regole',
                tooltip: 'Smista da sola la posta in arrivo',
                enabled: true,
                menuChildren: [
                  MenuItemButton(
                    onPressed: hasMessage && !model.multiSelection ? () => RulesUi.createFor(context) : null,
                    child: const Text('Crea regola…'),
                  ),
                  MenuItemButton(
                    onPressed: () => RulesUi.manage(context),
                    child: const Text('Gestisci regole e avvisi…'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      RibbonGroup(
        label: 'Tag',
        children: [
          RibbonSmallColumn(
            children: [
              RibbonSmallButton(
                icon: seen == true ? FluentIcons.mail_unread_20_regular : FluentIcons.mail_read_20_regular,
                label: seen == true ? 'Segna come da leggere' : 'Segna come letto',
                tooltip: offlineHint,
                onPressed: canModify && seen != null ? () => MessageActions.toggleSeen(context) : null,
              ),
              RibbonMenuButton(
                icon: FluentIcons.tag_20_regular,
                label: 'Categorizza',
                tooltip: offlineHint ?? 'Assegna una categoria colorata',
                menuChildren: TagMenus.categoryItems(context, tagTarget),
                enabled: tagTarget != null,
              ),
              RibbonMenuButton(
                icon: FluentIcons.flag_20_regular,
                label: 'Completa',
                tooltip: offlineHint ?? 'Contrassegna per completamento, con una scadenza',
                menuChildren: TagMenus.followUpItems(context, tagTarget),
                enabled: tagTarget != null,
              ),
            ],
          ),
        ],
      ),
      RibbonGroup(
        label: 'Zoom',
        children: [
          MenuAnchor(
            menuChildren: [
              for (final percent in const [50, 75, 100, 125, 150, 175, 200])
                MenuItemButton(
                  leadingIcon: Icon(percent == zoom ? Icons.check : null, size: 16),
                  onPressed: () => context.read<AppSettings>().setReadingZoom(percent),
                  child: Text('$percent%'),
                ),
            ],
            builder: (context, controller, _) => RibbonLargeButton(
              key: const Key('message-window-zoom'),
              icon: FluentIcons.zoom_in_24_regular,
              label: 'Zoom ($zoom%)',
              tooltip: 'Ingrandisci o riduci il testo della mail (Ctrl+rotella, Ctrl++, Ctrl+-, Ctrl+0)',
              onPressed: () => controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
        ],
      ),
    ];
  }
}

/// Striscia in alto come la barra del titolo della finestra di un messaggio di Outlook: oggetto, ↑ ↓, chiudi.
class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.subject, required this.onPrevious, required this.onNext, required this.onClose});

  final String subject;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(color: scheme.onPrimary);
    Widget button(Key key, IconData icon, String tooltip, VoidCallback? onPressed) => IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: onPressed == null ? scheme.onPrimary.withValues(alpha: 0.4) : scheme.onPrimary),
    );
    return Container(
      height: 36,
      color: scheme.primary,
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Icon(FluentIcons.mail_20_regular, size: 18, color: scheme.onPrimary),
          const SizedBox(width: 8),
          Text('Messaggio', style: style.copyWith(fontWeight: FontWeight.w600)),
          if (subject.isNotEmpty) Text('  –  ', style: style),
          Expanded(child: Text(subject, overflow: TextOverflow.ellipsis, style: style)),
          button(const Key('message-window-previous'), FluentIcons.arrow_up_20_regular, 'Elemento precedente (Ctrl+,)', onPrevious),
          button(const Key('message-window-next'), FluentIcons.arrow_down_20_regular, 'Elemento successivo (Ctrl+.)', onNext),
          const SizedBox(width: 8),
          button(const Key('message-window-close'), FluentIcons.dismiss_20_regular, 'Chiudi (Esc)', onClose),
        ],
      ),
    );
  }
}

/// «File» della finestra della mail: Salva con nome, Stampa, Salva come PDF.
class _FileMenu extends StatelessWidget {
  const _FileMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('message-window-file'),
      tooltip: 'File',
      position: PopupMenuPosition.under,
      onSelected: (choice) => switch (choice) {
        'save-eml' => EmlActions.saveAs(context),
        'print' => PrintActions.printMessage(context),
        _ => PrintActions.saveAsPdf(context),
      },
      itemBuilder: (_) => [
        for (final (value, icon, text) in [
          ('save-eml', FluentIcons.save_20_regular, 'Salva con nome… (F12)'),
          ('print', FluentIcons.print_20_regular, 'Stampa… (Ctrl+P)'),
          ('pdf', FluentIcons.document_pdf_20_regular, 'Salva come PDF…'),
        ])
          PopupMenuItem(
            key: Key('message-window-file-$value'),
            value: value,
            child: ListTile(leading: Icon(icon), title: Text(text), contentPadding: EdgeInsets.zero),
          ),
      ],
      child: const RibbonFileTab(),
    );
  }
}
