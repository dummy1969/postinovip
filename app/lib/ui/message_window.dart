import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../l10n/language.dart';
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
import 'keys.dart';
import 'mac_menu_bar.dart';
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
        // Come Outlook: Ctrl+, e Ctrl+. elemento precedente e successivo (sul Mac ⌘[ e ⌘], keys.dart).
        previousItemKey: () => _step(-1),
        nextItemKey: () => _step(1),
        cmd(LogicalKeyboardKey.keyR): () => _reply(DraftMode.reply),
        cmd(LogicalKeyboardKey.keyR, shift: true): () => _reply(DraftMode.replyAll),
        cmd(LogicalKeyboardKey.keyF): () => _reply(DraftMode.forward),
        const SingleActivator(LogicalKeyboardKey.delete): _delete,
        ...macBackspaceDeletes(_delete),
        cmd(LogicalKeyboardKey.keyD): _delete,
        markReadKey: () {
          if (MessageActions.canModify(model)) MessageActions.setSeen(context, true);
        },
        markUnreadKey: () {
          if (MessageActions.canModify(model)) MessageActions.setSeen(context, false);
        },
        cmd(LogicalKeyboardKey.keyV, shift: true): () => _move(_otherFolder),
        cmd(LogicalKeyboardKey.keyP): () => PrintActions.printMessage(context),
        const SingleActivator(LogicalKeyboardKey.f12): () => EmlActions.saveAs(context),
        cmd(LogicalKeyboardKey.f1): () =>
            settings.setRibbonCollapsed(!settings.ribbonCollapsed),
        ...ZoomedBody.shortcuts(settings),
      },
      // Sul Mac i comandi anche nella barra dei menu in alto (M2b).
      child: MacMenuScope(
        menus: _macMenus,
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
                  tabs: [context.l10n.messageTab],
                  selected: 0,
                  onSelect: (_) {},
                  groups: _groups(model),
                ),
                const Expanded(child: ReadingPane()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Menu del Mac (M2b): File, Messaggio e Visualizza della finestra della mail, come la sua barra.
  List<PlatformMenu> _macMenus(BuildContext context) {
    final l = context.l10n;
    final model = context.read<MailboxModel>();
    final settings = context.read<AppSettings>();
    final hasMessage = MessageActions.hasMessage(model);
    final canModify = MessageActions.canModify(model);
    final seen = MessageActions.seenState(model);
    final permanent = MessageActions.deletesPermanently(model);
    return [
      PlatformMenu(
        label: l.fileTab,
        menus: [
          PlatformMenuItemGroup(
            members: [
              macItem(macLabel(l.saveAs), () => EmlActions.saveAs(context), macKey(LogicalKeyboardKey.keyS, shift: true)),
              macItem(l.saveAsPdf, () => PrintActions.saveAsPdf(context)),
            ],
          ),
          PlatformMenuItemGroup(
            members: [macItem(macLabel(l.printMessage), () => PrintActions.printMessage(context), macKey(LogicalKeyboardKey.keyP))],
          ),
          PlatformMenuItemGroup(members: [macItem(l.macMenuCloseWindow, _close, macKey(LogicalKeyboardKey.keyW))]),
        ],
      ),
      PlatformMenu(
        label: l.messageTab,
        menus: [
          PlatformMenuItemGroup(
            members: [
              for (final (mode, key) in [
                (DraftMode.reply, macKey(LogicalKeyboardKey.keyR)),
                (DraftMode.replyAll, macKey(LogicalKeyboardKey.keyR, shift: true)),
                (DraftMode.forward, macKey(LogicalKeyboardKey.keyF)),
              ])
                macItem(mode.label(l), hasMessage ? () => _reply(mode) : null, key),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              macItem(
                l.markRead,
                canModify && seen != true ? () => MessageActions.setSeen(context, true) : null,
                macKey(LogicalKeyboardKey.keyT),
              ),
              macItem(
                l.markUnread,
                canModify && seen != false ? () => MessageActions.setSeen(context, false) : null,
                macKey(LogicalKeyboardKey.keyT, shift: true),
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenu(
                label: l.move,
                menus: [
                  PlatformMenuItemGroup(
                    members: [
                      for (final f in MessageActions.moveTargets(model))
                        macItem(f.fullName, canModify ? () => _move(f.fullName) : null),
                    ],
                  ),
                  PlatformMenuItemGroup(
                    members: [
                      macItem(
                        macLabel(l.moveOtherFolder),
                        canModify ? () => _move(_otherFolder) : null,
                        macKey(LogicalKeyboardKey.keyV, shift: true),
                      ),
                    ],
                  ),
                ],
              ),
              // Senza tasto nel menu: ⌫ serve anche a scrivere (vedi MacMenuBar).
              macItem(
                l.archive,
                ArchiveActions.canArchive(model) ? () => ArchiveActions.archive(context, openNext: true) : null,
              ),
              macItem(permanent ? l.deletePermanently : l.delete, canModify ? _delete : null),
              macItem(
                ConversationToolActions.ignoreLabel(l, model),
                ConversationToolActions.canIgnore(model) ? () => ConversationToolActions.ignore(context, openNext: true) : null,
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenu(label: l.junk, menus: JunkActions.macItems(context, openNext: true)),
              PlatformMenu(label: l.categorize, menus: TagMenus.categoryMacItems(context, canModify ? TagTarget.open(model) : null)),
              PlatformMenu(label: l.followUp, menus: TagMenus.followUpMacItems(context, canModify ? TagTarget.open(model) : null)),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              macItem(macLabel(l.previousItem), model.canMoveCursor(-1) ? () => _step(-1) : null, previousItemKey),
              macItem(macLabel(l.nextItem), model.canMoveCursor(1) ? () => _step(1) : null, nextItemKey),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: l.tabView,
        menus: [
          PlatformMenuItemGroup(
            members: [
              macItem(macLabel(l.zoomIn), () => settings.zoomBy(1), const CharacterActivator('+', meta: true)),
              macItem(macLabel(l.zoomOut), () => settings.zoomBy(-1), const CharacterActivator('-', meta: true)),
              macItem(l.macMenuZoomReset, () => settings.setReadingZoom(100), macKey(LogicalKeyboardKey.digit0)),
            ],
          ),
        ],
      ),
    ];
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
    final offlineHint = hasMessage && !model.isOnline(model.openAccount) ? context.l10n.offlineUnavailable : null;
    final seen = MessageActions.seenState(model);
    final tagTarget = canModify ? TagTarget.open(model) : null;
    final moveTargets = MessageActions.moveTargets(model);
    final permanent = MessageActions.deletesPermanently(model);
    final zoom = context.watch<AppSettings>().readingZoom;
    return [
      RibbonGroup(
        label: context.l10n.delete,
        children: [
          RibbonLargeButton(
            key: const Key('message-window-delete'),
            icon: FluentIcons.delete_24_regular,
            label: permanent ? context.l10n.deletePermanently : context.l10n.delete,
            tooltip:
                offlineHint ??
                (permanent
                    ? context.l10n.windowDeletePermanentlyTooltip
                    : keyLabel(context.l10n.windowDeleteTooltip)),
            onPressed: canModify ? _delete : null,
          ),
          RibbonLargeButton(
            key: const Key('message-window-archive'),
            icon: FluentIcons.archive_24_regular,
            label: context.l10n.archive,
            tooltip: offlineHint ??
                (model.selectionInArchive
                    ? ArchiveActions.tooltip(context.l10n, model)
                    : context.l10n.windowArchiveTooltip),
            onPressed: ArchiveActions.canArchive(model) ? () => ArchiveActions.archive(context, openNext: true) : null,
          ),
          RibbonSmallColumn(
            children: [
              // Ignora (C2): come la finestra del messaggio di Outlook, poi la mail successiva.
              RibbonSmallButton(
                key: const Key('message-window-ignore'),
                icon: FluentIcons.mail_prohibited_20_regular,
                label: ConversationToolActions.ignoreLabel(context.l10n, model),
                tooltip: offlineHint ?? ConversationToolActions.ignoreTooltip(context.l10n, model),
                onPressed: ConversationToolActions.canIgnore(model)
                    ? () => ConversationToolActions.ignore(context, openNext: true)
                    : null,
              ),
              RibbonMenuButton(
                key: const Key('message-window-junk'),
                icon: FluentIcons.person_prohibited_20_regular,
                label: context.l10n.junk,
                tooltip: context.l10n.junkTooltip,
                enabled: true,
                menuChildren: JunkActions.menuItems(context, openNext: true),
              ),
            ],
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.groupRespond,
        children: [
          for (final (mode, icon) in [
            (DraftMode.reply, FluentIcons.arrow_reply_24_regular),
            (DraftMode.replyAll, FluentIcons.arrow_reply_all_24_regular),
            (DraftMode.forward, FluentIcons.arrow_forward_24_regular),
          ])
            RibbonLargeButton(
              key: Key('message-window-${mode.name}'),
              icon: icon,
              label: mode.label(context.l10n),
              onPressed: hasMessage ? () => _reply(mode) : null,
            ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.move,
        children: [
          PopupMenuButton<String>(
            enabled: canModify && moveTargets.isNotEmpty,
            tooltip: offlineHint ?? context.l10n.windowMoveTooltip,
            onSelected: _move,
            itemBuilder: (context) => [
              for (final f in moveTargets) PopupMenuItem(value: f.fullName, child: Text(f.fullName)),
              const PopupMenuDivider(),
              PopupMenuItem(value: _otherFolder, child: Text(keyLabel(context.l10n.moveOtherFolder))),
            ],
            child: RibbonLargeButton(
              icon: FluentIcons.folder_arrow_right_24_regular,
              label: context.l10n.move,
              enabled: canModify && moveTargets.isNotEmpty,
            ),
          ),
          RibbonSmallColumn(
            children: [
              RibbonMenuButton(
                icon: FluentIcons.filter_20_regular,
                label: context.l10n.rules,
                tooltip: context.l10n.rulesTooltip,
                enabled: true,
                menuChildren: [
                  MenuItemButton(
                    onPressed: hasMessage && !model.multiSelection ? () => RulesUi.createFor(context) : null,
                    child: Text(context.l10n.createRule),
                  ),
                  MenuItemButton(
                    onPressed: () => RulesUi.manage(context),
                    child: Text(context.l10n.manageRulesEllipsis),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.groupTags,
        children: [
          RibbonSmallColumn(
            children: [
              RibbonSmallButton(
                icon: seen == true ? FluentIcons.mail_unread_20_regular : FluentIcons.mail_read_20_regular,
                label: seen == true ? context.l10n.markUnreadWindow : context.l10n.markRead,
                tooltip: offlineHint,
                onPressed: canModify && seen != null ? () => MessageActions.toggleSeen(context) : null,
              ),
              RibbonMenuButton(
                icon: FluentIcons.tag_20_regular,
                label: context.l10n.categorize,
                tooltip: offlineHint ?? context.l10n.categorizeTooltip,
                menuChildren: TagMenus.categoryItems(context, tagTarget),
                enabled: tagTarget != null,
              ),
              RibbonMenuButton(
                icon: FluentIcons.flag_20_regular,
                label: context.l10n.followUp,
                tooltip: offlineHint ?? context.l10n.followUpTooltip,
                menuChildren: TagMenus.followUpItems(context, tagTarget),
                enabled: tagTarget != null,
              ),
            ],
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.groupZoom,
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
              label: context.l10n.zoomPercent(zoom),
              tooltip: keyLabel(context.l10n.zoomTooltip),
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
          Text(context.l10n.messageTab, style: style.copyWith(fontWeight: FontWeight.w600)),
          if (subject.isNotEmpty) Text('  –  ', style: style),
          Expanded(child: Text(subject, overflow: TextOverflow.ellipsis, style: style)),
          button(const Key('message-window-previous'), FluentIcons.arrow_up_20_regular, keyLabel(context.l10n.previousItem), onPrevious),
          button(const Key('message-window-next'), FluentIcons.arrow_down_20_regular, keyLabel(context.l10n.nextItem), onNext),
          const SizedBox(width: 8),
          button(const Key('message-window-close'), FluentIcons.dismiss_20_regular, context.l10n.closeEsc, onClose),
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
      tooltip: context.l10n.fileTab,
      position: PopupMenuPosition.under,
      onSelected: (choice) => switch (choice) {
        'save-eml' => EmlActions.saveAs(context),
        'print' => PrintActions.printMessage(context),
        _ => PrintActions.saveAsPdf(context),
      },
      itemBuilder: (_) => [
        for (final (value, icon, text) in [
          ('save-eml', FluentIcons.save_20_regular, context.l10n.saveAs),
          ('print', FluentIcons.print_20_regular, keyLabel(context.l10n.printMessage)),
          ('pdf', FluentIcons.document_pdf_20_regular, context.l10n.saveAsPdf),
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
