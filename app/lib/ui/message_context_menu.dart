import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/compose_draft.dart';
import '../state/mailbox_model.dart';
import 'archive_ui.dart';
import 'conversation_tools_ui.dart';
import 'junk_ui.dart';
import 'message_actions.dart';
import 'people_view.dart';
import 'rules_dialog.dart';
import 'tag_menus.dart';

/// Menu del tasto destro sulla lista (scelta 3.3-4b). Come in Outlook il clic destro seleziona la
/// mail, quindi i comandi sono quelli della barra multifunzione sulla mail aperta.
/// [builder] riceve la funzione che apre il menu nel punto indicato (coordinate dello schermo).
class MessageContextMenu extends StatefulWidget {
  const MessageContextMenu({super.key, required this.builder});

  final Widget Function(BuildContext context, void Function(Offset globalPosition) open) builder;

  @override
  State<MessageContextMenu> createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends State<MessageContextMenu> {
  final _controller = MenuController();

  void _open(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _controller.open(position: box.globalToLocal(globalPosition));
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final hasMessage = MessageActions.hasMessage(model);
    final canModify = MessageActions.canModify(model);
    final seen = MessageActions.seenState(model);
    final tagTarget = canModify ? TagTarget.open(model) : null;
    final moveTargets = MessageActions.moveTargets(model);

    return MenuAnchor(
      controller: _controller,
      menuChildren: [
        for (final (mode, icon) in [
          (DraftMode.reply, FluentIcons.arrow_reply_20_regular),
          (DraftMode.replyAll, FluentIcons.arrow_reply_all_20_regular),
          (DraftMode.forward, FluentIcons.arrow_forward_20_regular),
        ])
          MenuItemButton(
            leadingIcon: Icon(icon, size: 16),
            onPressed: hasMessage ? () => MessageActions.reply(context, mode) : null,
            child: Text(mode.label),
          ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: Icon(
            seen == true ? FluentIcons.mail_unread_20_regular : FluentIcons.mail_read_20_regular,
            size: 16,
          ),
          onPressed: canModify && seen != null ? () => MessageActions.toggleSeen(context) : null,
          child: Text(seen == true ? 'Segna come non letto' : 'Segna come letto'),
        ),
        SubmenuButton(
          leadingIcon: const Icon(FluentIcons.tag_20_regular, size: 16),
          menuChildren: TagMenus.categoryItems(context, tagTarget),
          child: const Text('Categorizza'),
        ),
        SubmenuButton(
          leadingIcon: const Icon(FluentIcons.flag_20_regular, size: 16),
          menuChildren: TagMenus.followUpItems(context, tagTarget),
          child: const Text('Completa'),
        ),
        const Divider(height: 8),
        SubmenuButton(
          leadingIcon: const Icon(FluentIcons.folder_arrow_right_20_regular, size: 16),
          menuChildren: [
            for (final f in moveTargets)
              MenuItemButton(
                onPressed: canModify ? () => MessageActions.move(context, f.fullName) : null,
                child: Text(f.fullName),
              ),
          ],
          child: const Text('Sposta'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(FluentIcons.person_add_20_regular, size: 16),
          onPressed: hasMessage && !model.multiSelection && (model.detail?.fromAddress?.isNotEmpty ?? false)
              ? () => PeopleActions.addSender(context)
              : null,
          child: const Text('Aggiungi il mittente a Contatti'),
        ),
        SubmenuButton(
          leadingIcon: const Icon(FluentIcons.filter_20_regular, size: 16),
          menuChildren: [
            MenuItemButton(
              onPressed: hasMessage && !model.multiSelection ? () => RulesUi.createFor(context) : null,
              child: const Text('Crea regola…'),
            ),
            MenuItemButton(onPressed: () => RulesUi.manage(context), child: const Text('Gestisci regole e avvisi…')),
          ],
          child: const Text('Regole'),
        ),
        MenuItemButton(
          key: const Key('context-ignore'),
          leadingIcon: const Icon(FluentIcons.mail_prohibited_20_regular, size: 16),
          onPressed: ConversationToolActions.canIgnore(model) ? () => ConversationToolActions.ignore(context) : null,
          child: Text(model.openIgnoredInTrash ? 'Interrompi Ignora conversazione' : 'Ignora conversazione'),
        ),
        MenuItemButton(
          key: const Key('context-clean-up'),
          leadingIcon: const Icon(FluentIcons.broom_20_regular, size: 16),
          onPressed: ConversationToolActions.canCleanUpConversation(model)
              ? () => ConversationToolActions.cleanUpConversation(context)
              : null,
          child: const Text('Pulisci conversazione'),
        ),
        SubmenuButton(
          key: const Key('context-junk'),
          leadingIcon: const Icon(FluentIcons.person_prohibited_20_regular, size: 16),
          menuChildren: JunkActions.menuItems(context),
          child: const Text('Posta indesiderata'),
        ),
        MenuItemButton(
          key: const Key('context-archive'),
          leadingIcon: const Icon(FluentIcons.archive_20_regular, size: 16),
          onPressed: ArchiveActions.canArchive(model) ? () => ArchiveActions.archive(context) : null,
          child: const Text('Archivia'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(FluentIcons.delete_20_regular, size: 16),
          onPressed: canModify ? () => MessageActions.delete(context) : null,
          child: Text(MessageActions.deletesPermanently(model) ? 'Elimina definitivamente' : 'Elimina'),
        ),
      ],
      child: widget.builder(context, _open),
    );
  }
}
