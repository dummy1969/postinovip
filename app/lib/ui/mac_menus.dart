import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../l10n/language.dart';
import '../models/calendar.dart';
import '../models/compose_draft.dart';
import '../print/print_actions.dart';
import '../settings/app_settings.dart';
import '../state/calendar_model.dart';
import '../state/contacts_model.dart';
import '../state/mailbox_model.dart';
import 'archive_ui.dart';
import 'auto_reply_dialog.dart';
import 'calendar_view.dart';
import 'conversation_tools_ui.dart';
import 'conversation_view.dart';
import 'eml_view.dart';
import 'folder_actions.dart';
import 'mac_menu_bar.dart';
import 'message_actions.dart';
import 'module_bar.dart';
import 'people_view.dart';
import 'ribbon.dart';
import 'junk_ui.dart';
import 'rules_dialog.dart';
import 'tag_menus.dart';

/// Menu della finestra principale sul Mac (M2b): gli stessi comandi della barra multifunzione, con le stesse
/// condizioni (voce spenta dove il pulsante è spento). File, Visualizza e, nella posta, Messaggio e Cartella.
/// Categorizza, Completa, Pulisci e Posta indesiderata usano le voci gemelle dei loro menu della barra
/// (`categoryMacItems`, `followUpMacItems`, `cleanUpMacItems`, `JunkActions.macItems`).
abstract final class MainWindowMenus {
  /// Sposta → «Altra cartella…» (un valore che non può essere il nome di una cartella).
  static List<PlatformMenu> build(BuildContext context) {
    final l = context.l10n;
    final module = context.read<ContactsModel>().module;
    final settings = context.read<AppSettings>();
    final mail = context.read<MailboxModel>();

    final newItem = switch (module) {
      AppModule.mail => macItem(l.newMessage, () => MessageActions.compose(context), macKey(LogicalKeyboardKey.keyN)),
      AppModule.calendar => macItem(
        l.newAppointment,
        context.read<CalendarModel>().calendars.values.any((list) => list.any((c) => !c.readOnly))
            ? () => CalendarActions.newAppointment(context)
            : null,
        macKey(LogicalKeyboardKey.keyN),
      ),
      AppModule.people => macItem(l.newContact, () => PeopleActions.newContact(context), macKey(LogicalKeyboardKey.keyN)),
    };
    final canPrint = PrintActions.canPrint(mail);
    final file = PlatformMenu(
      label: l.fileTab,
      menus: [
        PlatformMenuItemGroup(members: [newItem]),
        if (module == AppModule.mail) ...[
          PlatformMenuItemGroup(
            members: [
              macItem(l.openEml, () => EmlActions.openFile(context), macKey(LogicalKeyboardKey.keyO)),
              macItem(
                macLabel(l.saveAs),
                EmlActions.canSave(mail) ? () => EmlActions.saveAs(context) : null,
                macKey(LogicalKeyboardKey.keyS, shift: true),
              ),
              macItem(l.saveAsPdf, canPrint ? () => PrintActions.saveAsPdf(context) : null),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              macItem(
                macLabel(l.printMessage),
                canPrint ? () => PrintActions.printMessage(context) : null,
                macKey(LogicalKeyboardKey.keyP),
              ),
            ],
          ),
        ],
        PlatformMenuItemGroup(
          members: [
            macItem('${l.automaticReplies}…', () => AutoReplyDialog.show(context)),
            macItem(l.manageRulesEllipsis, () => RulesUi.manage(context)),
          ],
        ),
      ],
    );

    return [
      file,
      _view(context, module, settings, mail),
      if (module == AppModule.mail) ...[_message(context, mail), _folder(context, mail)],
    ];
  }

  /// In fondo a Composizione: Cerca (⌘E), come Trova nelle app del Mac.
  static List<PlatformMenuItem> editExtras(BuildContext context) {
    final l = context.l10n;
    return [
      macItem(
        l.search,
        () => context.read<ContactsModel>().module == AppModule.people
            ? context.read<ContactsModel>().searchFocus.requestFocus()
            : context.read<SearchFocus>().node.requestFocus(),
        macKey(LogicalKeyboardKey.keyE),
      ),
    ];
  }

  static PlatformMenu _view(BuildContext context, AppModule module, AppSettings settings, MailboxModel mail) {
    final l = context.l10n;
    final conversations = module == AppModule.mail ? ConversationViewCommand.isOn(context) : null;
    final calendar = context.read<CalendarModel>();
    return PlatformMenu(
      label: l.tabView,
      menus: [
        PlatformMenuItemGroup(
          members: [
            for (final (m, label, key) in [
              (AppModule.mail, l.moduleMail, LogicalKeyboardKey.digit1),
              (AppModule.calendar, l.moduleCalendar, LogicalKeyboardKey.digit2),
              (AppModule.people, l.modulePeople, LogicalKeyboardKey.digit3),
            ])
              macItem(macChecked(macLabel(label), module == m), () => ModuleBar.show(context, m), macKey(key)),
          ],
        ),
        if (module == AppModule.mail)
          PlatformMenuItemGroup(
            members: [
              PlatformMenu(
                label: l.readingPane,
                menus: [
                  for (final p in ReadingPanePosition.values)
                    macItem(macChecked(p.label(l), settings.readingPane == p), () => settings.setReadingPane(p)),
                ],
              ),
              PlatformMenu(
                label: l.messagePreview,
                menus: [
                  for (final (n, label) in [
                    (0, l.messagePreviewOff),
                    for (final lines in [1, 2, 3]) (lines, l.messagePreviewLines(lines)),
                  ])
                    macItem(macChecked(label, settings.previewLines == n), () => settings.setPreviewLines(n)),
                ],
              ),
              macItem(
                macChecked(l.showAsConversations, conversations == true),
                mail.selectedFolder == null ? null : () => ConversationViewCommand.toggle(context),
              ),
            ],
          ),
        if (module == AppModule.calendar)
          PlatformMenuItemGroup(
            members: [
              PlatformMenu(
                label: l.macMenuCalendarView,
                menus: [
                  for (final (i, kind) in CalendarViewKind.values.indexed)
                    macItem(
                      macChecked(kind.label(l), calendar.view == kind),
                      () => calendar.setView(kind),
                      macKey(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), alt: true),
                    ),
                ],
              ),
              macItem(l.today, calendar.goToday),
            ],
          ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenu(
              label: l.optionsTheme,
              menus: [for (final t in AppTheme.values) macItem(macChecked(t.label(l), settings.theme == t), () => settings.setTheme(t))],
            ),
            macItem(macChecked(l.macMenuShowRibbon, settings.showRibbon), () => settings.setShowRibbon(!settings.showRibbon)),
          ],
        ),
        if (module == AppModule.mail)
          PlatformMenuItemGroup(
            members: [
              macItem(macLabel(l.zoomIn), () => settings.zoomBy(1), const CharacterActivator('+', meta: true)),
              macItem(macLabel(l.zoomOut), () => settings.zoomBy(-1), const CharacterActivator('-', meta: true)),
              macItem(l.macMenuZoomReset, () => settings.setReadingZoom(100), macKey(LogicalKeyboardKey.digit0)),
            ],
          ),
      ],
    );
  }

  static PlatformMenu _message(BuildContext context, MailboxModel model) {
    final l = context.l10n;
    final hasMessage = MessageActions.hasMessage(model);
    final canModify = MessageActions.canModify(model);
    final seen = MessageActions.seenState(model);
    final moveTargets = MessageActions.moveTargets(model);
    final permanent = MessageActions.deletesPermanently(model);
    final tagTarget = canModify ? TagTarget.open(model) : null;
    return PlatformMenu(
      label: l.messageTab,
      menus: [
        PlatformMenuItemGroup(
          members: [
            for (final (mode, key) in [
              (DraftMode.reply, macKey(LogicalKeyboardKey.keyR)),
              (DraftMode.replyAll, macKey(LogicalKeyboardKey.keyR, shift: true)),
              (DraftMode.forward, macKey(LogicalKeyboardKey.keyF)),
            ])
              macItem(mode.label(l), hasMessage ? () => MessageActions.reply(context, mode) : null, key),
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
                    for (final f in moveTargets)
                      macItem(f.fullName, canModify ? () => MessageActions.move(context, f.fullName) : null),
                  ],
                ),
                PlatformMenuItemGroup(
                  members: [
                    macItem(
                      macLabel(l.moveOtherFolder),
                      canModify ? () => MessageActions.moveToFolder(context) : null,
                      macKey(LogicalKeyboardKey.keyV, shift: true),
                    ),
                  ],
                ),
              ],
            ),
            // Senza tasto nel menu: ⌫ e ⌃E servono anche a scrivere (vedi MacMenuBar).
            macItem(l.archive, ArchiveActions.canArchive(model) ? () => ArchiveActions.archive(context) : null),
            macItem(permanent ? l.deletePermanently : l.delete, canModify ? () => MessageActions.delete(context) : null),
            macItem(
              ConversationToolActions.ignoreLabel(l, model),
              ConversationToolActions.canIgnore(model) ? () => ConversationToolActions.ignore(context) : null,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenu(label: l.cleanUp, menus: ConversationToolActions.cleanUpMacItems(context)),
            PlatformMenu(label: l.junk, menus: JunkActions.macItems(context)),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenu(label: l.categorize, menus: TagMenus.categoryMacItems(context, tagTarget)),
            PlatformMenu(label: l.followUp, menus: TagMenus.followUpMacItems(context, tagTarget)),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            macItem(l.createRule, hasMessage && !model.multiSelection ? () => RulesUi.createFor(context) : null),
          ],
        ),
      ],
    );
  }

  static PlatformMenu _folder(BuildContext context, MailboxModel model) {
    final l = context.l10n;
    final target = FolderActions.selected(model);
    final online = target != null && model.isOnline(target.account);
    final editable = target != null && model.canEditFolder(target.account, target.folder);
    final emptiable = target != null && model.canEmptyFolder(target.account, target.folder);
    return PlatformMenu(
      label: l.tabFolder,
      menus: [
        PlatformMenuItemGroup(
          members: [
            macItem('${l.newFolder}…', online ? () => model.startNewFolder(target.account, target.folder.fullName) : null),
            macItem(
              l.renameFolder,
              editable ? () => model.startRenameFolder(target.account, target.folder.fullName) : null,
              const SingleActivator(LogicalKeyboardKey.f2),
            ),
            macItem(l.deleteFolder, editable ? () => FolderActions.delete(context, target.account, target.folder) : null),
            macItem(l.emptyFolder, emptiable ? () => FolderActions.empty(context, target.account, target.folder) : null),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            macItem(
              '${l.setArchiveFolder}…',
              online ? () => ArchiveFolderDialog.show(context, account: target.account) : null,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [macItem(macLabel(l.sendReceiveAllF9), model.refresh, const SingleActivator(LogicalKeyboardKey.f9))],
        ),
      ],
    );
  }
}
