import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../about/about_dialog.dart';
import '../models/compose_draft.dart';
import '../print/print_actions.dart';
import '../settings/app_settings.dart';
import '../state/contacts_model.dart';
import 'calendar_view.dart';
import '../state/mailbox_model.dart';
import 'conversation_view.dart';
import 'eml_view.dart';
import 'folder_actions.dart';
import 'archive_ui.dart';
import 'conversation_tools_ui.dart';
import 'junk_ui.dart';
import 'ribbon_parts.dart';
import 'auto_reply_dialog.dart';
import 'rules_dialog.dart';
import 'message_actions.dart';
import 'people_view.dart';
import 'tag_menus.dart';
import 'settings_dialog.dart';

/// Il campo "Cerca" sopra la lista, raggiungibile dal comando "Cerca" della barra multifunzione.
class SearchFocus {
  final node = FocusNode(debugLabel: 'Cerca');
}

enum _RibbonTab {
  home('Home'),
  sendReceive('Invia/Ricevi'),
  folder('Cartella'),
  view('Visualizza');

  const _RibbonTab(this.label);

  final String label;
}

/// Barra multifunzione in stile Outlook classico: "File" (menu), schede con i comandi raggruppati
/// e l'etichetta del gruppo sotto, comando per comprimerla (anche Ctrl+F1). Compressa mostra solo
/// i nomi delle schede: un clic su una scheda la riapre.
class Ribbon extends StatefulWidget {
  const Ribbon({super.key});

  @override
  State<Ribbon> createState() => _RibbonState();
}

class _RibbonState extends State<Ribbon> {
  /// Voce "Altra cartella…" del menu Sposta (un valore che non può essere il nome di una cartella).
  static const _otherFolder = '\u0000altra';

  _RibbonTab _tab = _RibbonTab.home;

  /// Schede della vista attiva: nella vista Persone solo Home e Visualizza (C2).
  List<_RibbonTab> _tabsFor(AppModule module) =>
      module == AppModule.mail ? _RibbonTab.values : const [_RibbonTab.home, _RibbonTab.view];

  @override
  Widget build(BuildContext context) {
    final module = context.watch<ContactsModel>().module;
    final tabs = _tabsFor(module);
    final tab = tabs.contains(_tab) ? _tab : _RibbonTab.home;
    return RibbonFrame(
      leading: const _FileMenu(),
      tabs: [for (final t in tabs) t.label],
      selected: tabs.indexOf(tab),
      onSelect: (i) => setState(() => _tab = tabs[i]),
      groups: switch (module) {
        AppModule.people => _peopleGroups(context, tab),
        AppModule.calendar => tab == _RibbonTab.home ? CalendarActions.ribbonGroups(context) : _peopleGroups(context, tab),
        AppModule.mail => _groups(context),
      },
    );
  }

  List<Widget> _peopleGroups(BuildContext context, _RibbonTab tab) => tab == _RibbonTab.home
      ? PeopleActions.ribbonGroups(context)
      : [
          RibbonGroup(
            label: 'Layout',
            children: [
              _themeButton(context),
              RibbonLargeButton(
                icon: FluentIcons.chevron_up_20_regular,
                label: 'Comprimi barra multifunzione',
                tooltip: 'Mostra solo i nomi delle schede (Ctrl+F1)',
                onPressed: () => context.read<AppSettings>().setRibbonCollapsed(true),
              ),
            ],
          ),
        ];

  Widget _themeButton(BuildContext context) => _menuButton(context, FluentIcons.dark_theme_24_regular, 'Tema', [
    for (final t in AppTheme.values)
      (t.label, context.watch<AppSettings>().theme == t, () => context.read<AppSettings>().setTheme(t)),
  ]);

  List<Widget> _groups(BuildContext context) {
    final model = context.watch<MailboxModel>();
    return switch (_tab) {
      _RibbonTab.home => _homeGroups(context, model),
      _RibbonTab.sendReceive => [
        RibbonGroup(
          label: 'Invia e ricevi',
          children: [
            RibbonLargeButton(
              icon: FluentIcons.arrow_sync_24_regular,
              label: 'Invia/ricevi tutte le cartelle',
              tooltip: 'Aggiorna cartelle e messaggi di tutti gli account (F9)',
              onPressed: model.refresh,
            ),
          ],
        ),
      ],
      _RibbonTab.folder => _folderGroups(context, model),
      _RibbonTab.view => [
        RibbonGroup(
          label: 'Layout',
          children: [
            _menuButton(context, FluentIcons.layout_column_two_split_right_24_regular, 'Riquadro di lettura', [
              for (final p in ReadingPanePosition.values)
                (
                  p.label,
                  context.watch<AppSettings>().readingPane == p,
                  () => context.read<AppSettings>().setReadingPane(p),
                ),
            ]),
            _menuButton(context, FluentIcons.text_description_24_regular, 'Anteprima messaggio', [
              for (final (n, label) in [(0, 'Disattivata'), (1, '1 riga'), (2, '2 righe'), (3, '3 righe')])
                (
                  label,
                  context.watch<AppSettings>().previewLines == n,
                  () => context.read<AppSettings>().setPreviewLines(n),
                ),
            ]),
            _themeButton(context),
          ],
        ),
        RibbonGroup(
          label: 'Messaggi',
          children: [
            // Pulsante che resta premuto finché la vista è attiva (come i comandi a interruttore di Office).
            RibbonLargeButton(
              icon: ConversationViewCommand.isOn(context) == true
                  ? FluentIcons.chat_multiple_24_filled
                  : FluentIcons.chat_multiple_24_regular,
              label: 'Mostra come conversazioni',
              selected: ConversationViewCommand.isOn(context) == true,
              tooltip: ConversationViewCommand.isOn(context) == true
                  ? 'Attivo in questa cartella: clic per tornare alla lista semplice'
                  : 'Raccoglie in una riga le mail della stessa conversazione',
              onPressed: model.selectedFolder == null ? null : () => ConversationViewCommand.toggle(context),
            ),
          ],
        ),
        RibbonGroup(
          label: 'Layout',
          children: [
            RibbonLargeButton(
              icon: FluentIcons.chevron_up_20_regular,
              label: 'Comprimi barra multifunzione',
              tooltip: 'Mostra solo i nomi delle schede (Ctrl+F1)',
              onPressed: () => context.read<AppSettings>().setRibbonCollapsed(true),
            ),
          ],
        ),
      ],
    };
  }

  /// Comando grande con un menu di scelte (segno di spunta su quella attiva), scheda Visualizza (3.9).
  Widget _menuButton(BuildContext context, IconData icon, String label, List<(String, bool, VoidCallback)> items) =>
      MenuAnchor(
        menuChildren: [
          for (final (text, checked, action) in items)
            MenuItemButton(
              leadingIcon: Icon(checked ? Icons.check : null, size: 16),
              onPressed: action,
              child: Text(text),
            ),
        ],
        builder: (context, controller, _) => RibbonLargeButton(
          icon: icon,
          label: label,
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        ),
      );

  /// Scheda Cartella (3.4b): comandi sulla cartella selezionata nel riquadro. MODIFICANO la casella.
  List<Widget> _folderGroups(BuildContext context, MailboxModel model) {
    final target = FolderActions.selected(model);
    final online = target != null && model.isOnline(target.account);
    final editable = target != null && model.canEditFolder(target.account, target.folder);
    final emptiable = target != null && model.canEmptyFolder(target.account, target.folder);
    final trashOrJunk = target?.folder.role == 'trash' || target?.folder.role == 'junk';
    final offlineHint = target != null && !online ? MailboxModel.offlineMessage : null;
    final specialHint = target != null && online && !editable
        ? 'Posta in arrivo, Posta inviata, Posta eliminata e le altre cartelle speciali non si possono rinominare né eliminare'
        : null;
    return [
      RibbonGroup(
        label: 'Nuovo',
        children: [
          RibbonLargeButton(
            icon: FluentIcons.folder_add_24_regular,
            label: 'Nuova cartella',
            tooltip: offlineHint ?? 'Crea una sottocartella della cartella selezionata',
            onPressed: online ? () => model.startNewFolder(target.account, target.folder.fullName) : null,
          ),
        ],
      ),
      RibbonGroup(
        label: 'Azioni',
        children: [
          RibbonSmallColumn(
            children: [
              RibbonSmallButton(
                icon: FluentIcons.rename_20_regular,
                label: 'Rinomina cartella',
                tooltip: offlineHint ?? specialHint ?? 'Cambia il nome della cartella selezionata (F2)',
                onPressed: editable ? () => model.startRenameFolder(target.account, target.folder.fullName) : null,
              ),
              RibbonSmallButton(
                icon: FluentIcons.delete_20_regular,
                label: 'Elimina cartella',
                tooltip:
                    offlineHint ??
                    specialHint ??
                    (editable && model.isInTrash(target.account, target.folder)
                        ? 'Elimina dal server, senza possibilità di recupero'
                        : 'Sposta la cartella, con il suo contenuto, in Posta eliminata'),
                onPressed: editable ? () => FolderActions.delete(context, target.account, target.folder) : null,
              ),
              // Svuota cartella (12/11/2026): in Outlook qui si chiama «Elimina tutto»; solo Posta eliminata e indesiderata.
              RibbonSmallButton(
                key: const Key('ribbon-empty-folder'),
                icon: FluentIcons.delete_dismiss_20_regular,
                label: 'Svuota cartella',
                tooltip:
                    offlineHint ??
                    (trashOrJunk
                        ? 'Elimina dal server tutte le mail della cartella, senza possibilità di recupero'
                        : 'Solo per Posta eliminata e Posta indesiderata'),
                onPressed: emptiable ? () => FolderActions.empty(context, target.account, target.folder) : null,
              ),
            ],
          ),
        ],
      ),
      // Archivia (A2, 3a): la cartella di archiviazione dell'account della cartella selezionata.
      RibbonGroup(
        label: 'Archivio',
        children: [
          RibbonLargeButton(
            key: const Key('ribbon-archive-folder'),
            icon: FluentIcons.archive_settings_24_regular,
            label: 'Imposta cartella di archiviazione',
            tooltip: offlineHint ?? 'Scegli o crea la cartella in cui Archivia sposta le mail di questo account',
            onPressed: online ? () => ArchiveFolderDialog.show(context, account: target.account) : null,
          ),
        ],
      ),
    ];
  }

  List<Widget> _homeGroups(BuildContext context, MailboxModel model) {
    final hasMessage = MessageActions.hasMessage(model);
    final canModify = MessageActions.canModify(model);
    final offline = model.multiSelection
        ? model.selection.any((r) => !model.isOnline(r.account))
        : hasMessage && !model.isOnline(model.openAccount);
    final offlineHint = offline ? MailboxModel.offlineMessage : null;
    final seen = MessageActions.seenState(model);
    final tagTarget = canModify ? TagTarget.open(model) : null;
    final moveTargets = MessageActions.moveTargets(model);
    final permanent = MessageActions.deletesPermanently(model);

    return [
      RibbonGroup(
        label: 'Nuovo',
        children: [
          RibbonLargeButton(
            icon: FluentIcons.mail_add_24_regular,
            label: 'Nuovo messaggio',
            tooltip: 'Scrivi un nuovo messaggio',
            onPressed: () => MessageActions.compose(context),
          ),
        ],
      ),
      RibbonGroup(
        label: 'Elimina',
        children: [
          RibbonLargeButton(
            icon: FluentIcons.delete_24_regular,
            label: permanent ? 'Elimina definitivamente' : 'Elimina',
            tooltip:
                offlineHint ??
                (permanent ? 'Elimina dal server, senza possibilità di recupero' : 'Sposta in Posta eliminata'),
            onPressed: canModify ? () => MessageActions.delete(context) : null,
          ),
          // Archivia (A2): come Outlook, accanto a Elimina.
          RibbonLargeButton(
            key: const Key('ribbon-archive'),
            icon: FluentIcons.archive_24_regular,
            label: 'Archivia',
            tooltip: offlineHint ?? ArchiveActions.tooltip(model),
            onPressed: ArchiveActions.canArchive(model) ? () => ArchiveActions.archive(context) : null,
          ),
          RibbonSmallColumn(
            children: [
              // Ignora e Pulisci (C2): come Outlook, sopra Posta indesiderata nel gruppo Elimina.
              RibbonSmallButton(
                key: const Key('ribbon-ignore'),
                icon: FluentIcons.mail_prohibited_20_regular,
                label: ConversationToolActions.ignoreLabel(model),
                tooltip: offlineHint ?? ConversationToolActions.ignoreTooltip(model),
                onPressed: ConversationToolActions.canIgnore(model) ? () => ConversationToolActions.ignore(context) : null,
              ),
              RibbonMenuButton(
                key: const Key('ribbon-clean-up'),
                icon: FluentIcons.broom_20_regular,
                label: 'Pulisci',
                tooltip: 'Sposta in Posta eliminata le mail superflue: quelle citate per intero da una risposta',
                enabled: true,
                menuChildren: ConversationToolActions.cleanUpItems(context),
              ),
              // Posta indesiderata (J2): come il menu di Outlook nel gruppo Elimina.
              RibbonMenuButton(
                key: const Key('ribbon-junk'),
                icon: FluentIcons.person_prohibited_20_regular,
                label: 'Posta indesiderata',
                tooltip: 'Blocca mittente, Non bloccare mai, Opzioni posta indesiderata',
                enabled: true,
                menuChildren: JunkActions.menuItems(context),
              ),
            ],
          ),
        ],
      ),
      RibbonGroup(
        label: 'Rispondi',
        children: [
          RibbonSmallColumn(
            children: [
              for (final (mode, icon) in [
                (DraftMode.reply, FluentIcons.arrow_reply_20_regular),
                (DraftMode.replyAll, FluentIcons.arrow_reply_all_20_regular),
                (DraftMode.forward, FluentIcons.arrow_forward_20_regular),
              ])
                RibbonSmallButton(
                  icon: icon,
                  label: mode.label,
                  onPressed: hasMessage ? () => MessageActions.reply(context, mode) : null,
                ),
            ],
          ),
        ],
      ),
      RibbonGroup(
        label: 'Sposta',
        children: [
          PopupMenuButton<String>(
            enabled: canModify && moveTargets.isNotEmpty,
            tooltip: offlineHint ?? 'Sposta in un\'altra cartella',
            onSelected: (destination) => destination == _otherFolder
                ? MessageActions.moveToFolder(context)
                : MessageActions.move(context, destination),
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
                label: seen == true ? 'Segna come non letto' : 'Segna come letto',
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
        label: 'Trova',
        children: [
          RibbonSmallColumn(
            children: [
              RibbonSmallButton(
                icon: FluentIcons.search_20_regular,
                label: 'Cerca',
                tooltip: 'Cerca nella posta',
                onPressed: () => context.read<SearchFocus>().node.requestFocus(),
              ),
            ],
          ),
        ],
      ),
    ];
  }
}

/// "File": in Outlook apre la vista Backstage; qui un menu con opzioni e informazioni.
class _FileMenu extends StatelessWidget {
  const _FileMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'File',
      position: PopupMenuPosition.under,
      onSelected: (choice) => switch (choice) {
        'open-eml' => EmlActions.openFile(context),
        'save-eml' => EmlActions.saveAs(context),
        'print' => PrintActions.printMessage(context),
        'pdf' => PrintActions.saveAsPdf(context),
        'options' => showDialog<void>(context: context, builder: (_) => const SettingsDialog()),
        'rules' => RulesUi.manage(context),
        'autoreply' => AutoReplyDialog.show(context),
        _ => showPostinoVipAbout(context),
      },
      itemBuilder: (_) => [
        // File .eml (E2) e stampa (P3): solo nella Posta; salvare e stampare con una mail aperta.
        if (context.read<ContactsModel>().module == AppModule.mail) ...[
          for (final (value, icon, text) in [
            ('open-eml', FluentIcons.folder_open_20_regular, 'Apri file .eml…'),
            ('save-eml', FluentIcons.save_20_regular, 'Salva con nome… (F12)'),
            ('print', FluentIcons.print_20_regular, 'Stampa… (Ctrl+P)'),
            ('pdf', FluentIcons.document_pdf_20_regular, 'Salva come PDF…'),
          ])
            PopupMenuItem(
              key: Key('file-$value'),
              value: value,
              enabled: value == 'open-eml' || PrintActions.canPrint(context.read<MailboxModel>()),
              child: ListTile(leading: Icon(icon), title: Text(text), contentPadding: EdgeInsets.zero),
            ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: 'options',
          child: ListTile(
            leading: Icon(FluentIcons.settings_20_regular),
            title: Text('Opzioni'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'autoreply',
          child: ListTile(
            leading: Icon(FluentIcons.mail_arrow_up_20_regular),
            title: Text('Risposte automatiche'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'rules',
          child: ListTile(
            leading: Icon(FluentIcons.filter_20_regular),
            title: Text('Gestisci regole e avvisi'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'about',
          child: ListTile(
            leading: Icon(FluentIcons.info_20_regular),
            title: Text('Informazioni su PostinoVip'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: const RibbonFileTab(),
    );
  }
}
