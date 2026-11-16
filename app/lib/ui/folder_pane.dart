import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/language.dart';
import '../models/account_info.dart';
import '../models/favorite_folder.dart';
import '../models/mail_folder.dart';
import '../settings/app_settings.dart';
import '../state/mailbox_model.dart';
import 'conversation_tools_ui.dart';
import 'drag_drop.dart';
import 'error_view.dart';
import 'folder_actions.dart';
import 'module_bar.dart';

/// Pannello sinistro: Preferiti in cima (scelta 3.4-1a), poi l'albero degli account, ognuno con
/// le sue cartelle (come Outlook). Account chiusi e sezione Preferiti chiusa vengono ricordati.
class FolderPane extends StatelessWidget {
  const FolderPane({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final settings = context.watch<AppSettings>();

    if (model.loadingFolders && model.accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (model.foldersError != null) {
      return ErrorView(message: model.foldersError!, onRetry: model.loadFolders);
    }

    final favorites = settings.favorites ?? FavoriteFolder.defaults(model.accounts, model.foldersByAccount);
    // Preferiti mostrabili: account configurato e cartella esistente. Gli altri restano salvati ma
    // nascosti (cartella sparita, account rimosso o cartelle non ancora caricate).
    final shown = [
      for (final fav in favorites)
        if (model.accounts.where((a) => a.id == fav.account).firstOrNull case final account?)
          if ((model.foldersByAccount[fav.account] ?? const <MailFolder>[])
                  .where((f) => f.fullName == fav.folder)
                  .firstOrNull
              case final folder?)
            (favorite: fav, account: account, folder: folder),
    ];
    final menu = _FavoritesEditor(settings, favorites, [for (final s in shown) s.favorite]);

    // Material e non un semplice riquadro colorato: le righe selezionate disegnano lì il loro sfondo.
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // Una cartella rilasciata sull'intestazione va in fondo ai Preferiti (anche se sono chiusi).
                DropZone(
                  accepts: (data) => data is FolderDrag && !menu.contains(data.account, data.folder.fullName),
                  onDrop: (data) =>
                      menu.place(FavoriteFolder((data as FolderDrag).account, data.folder.fullName), null),
                  child: _SectionHeader(
                    title: context.l10n.favorites,
                    expanded: !settings.favoritesCollapsed,
                    onToggle: (expanded) => settings.setFavoritesCollapsed(!expanded),
                  ),
                ),
                if (!settings.favoritesCollapsed)
                  for (final (i, s) in shown.indexed)
                    _FolderRow(
                      key: ValueKey('favorite:${s.account.id}:${s.folder.fullName}'),
                      folder: s.folder,
                      // Con più account il nome della cartella da solo non basta (come Outlook).
                      label: model.accounts.length > 1
                          ? '${s.folder.displayName(context.l10n)} - ${s.account.name}'
                          : s.folder.displayName(context.l10n),
                      indent: 32,
                      selected: s.account.id == model.selectedAccount && s.folder.fullName == model.selectedFolder,
                      onTap: () => model.selectFolder(s.folder.fullName, account: s.account.id),
                      dragData: FavoriteDrag(s.favorite),
                      // Mail: spostate in quella cartella; Preferito o cartella: prende questo posto nei Preferiti.
                      accepts: (data) => switch (data) {
                        MessagesDrag d => model.canDropMessages(d.refs, s.account.id, s.folder.fullName),
                        FavoriteDrag d => d.favorite != s.favorite,
                        FolderDrag d => !s.favorite.isFor(d.account, d.folder.fullName),
                        _ => false,
                      },
                      onDrop: (data) => switch (data) {
                        MessagesDrag d => DropActions.messages(context, d, s.folder.fullName),
                        FavoriteDrag d => menu.place(d.favorite, s.favorite),
                        FolderDrag d => menu.place(FavoriteFolder(d.account, d.folder.fullName), s.favorite),
                        _ => null,
                      },
                      menuItems: [
                        _item(FluentIcons.star_off_20_regular, context.l10n.removeFromFavorites, () => menu.remove(s.favorite)),
                        _item(FluentIcons.arrow_up_20_regular, context.l10n.moveUp, i > 0 ? () => menu.swap(i, i - 1) : null),
                        _item(
                          FluentIcons.arrow_down_20_regular,
                          context.l10n.moveDown,
                          i < shown.length - 1 ? () => menu.swap(i, i + 1) : null,
                        ),
                      ],
                    ),
                for (final account in model.accounts) ...[
                  // Tasto destro sul nome dell'account: nuova cartella in cima (scelta 3.4-2b).
                  _ContextMenuRegion(
                    menuItems: [
                      _item(
                        FluentIcons.folder_add_20_regular,
                        context.l10n.newFolder,
                        model.isOnline(account.id) ? () => model.startNewFolder(account.id, null) : null,
                      ),
                    ],
                    // Cartella rilasciata sul nome dell'account: va in cima all'account.
                    child: DropZone(
                      accepts: (data) =>
                          data is FolderDrag && model.canMoveFolder(data.account, data.folder, account.id, null),
                      onDrop: (data) => DropActions.folder(context, data as FolderDrag, null),
                      child: _AccountHeader(
                        account: account,
                        expanded: !settings.collapsedAccounts.contains(account.id),
                        watching: model.watchStatus[account.id],
                        onToggle: (expanded) => settings.setAccountExpanded(account.id, expanded),
                      ),
                    ),
                  ),
                  if (!settings.collapsedAccounts.contains(account.id)) ..._folders(context, model, account, menu),
                ],
              ],
            ),
          ),
          ...ModuleBar.bottomOf(context),
        ],
      ),
    );
  }

  static Widget _item(IconData icon, String label, VoidCallback? onPressed) =>
      MenuItemButton(leadingIcon: Icon(icon, size: 16), onPressed: onPressed, child: Text(label));

  List<Widget> _folders(BuildContext context, MailboxModel model, AccountInfo account, _FavoritesEditor menu) {
    if (model.folderErrors[account.id] case final error?) {
      return [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 32, right: 8),
          leading: Icon(Icons.error_outline, size: 20, color: Theme.of(context).colorScheme.error),
          title: Text(error, maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: TextButton(onPressed: () => model.loadAccountFolders(account.id), child: Text(context.l10n.retry)),
        ),
      ];
    }
    final folders = model.foldersByAccount[account.id];
    if (folders == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ];
    }
    final edit = model.folderEdit?.account == account.id ? model.folderEdit : null;
    final online = model.isOnline(account.id);
    return [
      if (edit != null && edit.isNew && edit.parent == null) const _NewFolderRow(indent: 32),
      for (final folder in folders) ...[
        _FolderRow(
          key: ValueKey('folder:${account.id}:${folder.fullName}'),
          folder: folder,
          label: folder.displayName(context.l10n),
          indent: 32.0 + folder.depth * 16,
          selected: account.id == model.selectedAccount && folder.fullName == model.selectedFolder,
          editing: edit != null && edit.folder == folder.fullName,
          onTap: () => model.selectFolder(folder.fullName, account: account.id),
          // Tutte trascinabili: quelle con un ruolo solo verso i Preferiti (canMoveFolder le rifiuta).
          dragData: FolderDrag(account.id, folder),
          accepts: (data) => switch (data) {
            MessagesDrag d => model.canDropMessages(d.refs, account.id, folder.fullName),
            FolderDrag d => model.canMoveFolder(d.account, d.folder, account.id, folder.fullName),
            _ => false,
          },
          onDrop: (data) => switch (data) {
            MessagesDrag d => DropActions.messages(context, d, folder.fullName),
            FolderDrag d => DropActions.folder(context, d, folder.fullName),
            _ => null,
          },
          menuItems: [
            if (menu.contains(account.id, folder.fullName))
              _item(
                FluentIcons.star_off_20_regular,
                context.l10n.removeFromFavorites,
                () => menu.remove(FavoriteFolder(account.id, folder.fullName)),
              )
            else
              _item(
                FluentIcons.star_20_regular,
                context.l10n.showInFavorites,
                () => menu.add(FavoriteFolder(account.id, folder.fullName)),
              ),
            const Divider(height: 8),
            _item(
              FluentIcons.folder_add_20_regular,
              context.l10n.newFolder,
              online ? () => model.startNewFolder(account.id, folder.fullName) : null,
            ),
            _item(
              FluentIcons.rename_20_regular,
              context.l10n.renameFolder,
              model.canEditFolder(account.id, folder)
                  ? () => model.startRenameFolder(account.id, folder.fullName)
                  : null,
            ),
            // Pulisci cartella (C2): come il tasto destro sulle cartelle di Outlook.
            _item(
              FluentIcons.broom_20_regular,
              context.l10n.cleanUpFolder,
              ConversationToolActions.canCleanUpFolder(model, account: account.id, folder: folder.fullName)
                  ? () => ConversationToolActions.cleanUpFolder(context, account: account.id, folder: folder.fullName)
                  : null,
            ),
            // Svuota cartella (12/11/2026): solo Posta eliminata e Posta indesiderata, come Outlook.
            if (folder.role == 'trash' || folder.role == 'junk')
              _item(
                FluentIcons.delete_dismiss_20_regular,
                context.l10n.emptyFolder,
                model.canEmptyFolder(account.id, folder) ? () => FolderActions.empty(context, account.id, folder) : null,
              ),
            _item(
              FluentIcons.delete_20_regular,
              context.l10n.deleteFolder,
              model.canEditFolder(account.id, folder) ? () => FolderActions.delete(context, account.id, folder) : null,
            ),
          ],
        ),
        // La nuova sottocartella si scrive subito sotto la cartella che la conterrà.
        if (edit != null && edit.isNew && edit.parent == folder.fullName)
          _NewFolderRow(indent: 32.0 + (folder.depth + 1) * 16),
      ],
      // Posta in uscita (3.8): sul computer, non sul server; come Bozze, il numero tra parentesi quadre.
      if (model.outboxByAccount[account.id] case final outbox?)
        folderTile(
          key: ValueKey('outbox:${account.id}'),
          indent: 32,
          leading: const Icon(FluentIcons.mail_clock_20_regular, size: 20),
          title: Text(context.l10n.outbox, overflow: TextOverflow.ellipsis),
          trailing: outbox.isEmpty
              ? null
              : Text('[${outbox.length}]', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          selected: account.id == model.selectedAccount && model.showingOutbox,
          onTap: () => model.selectFolder(MailboxModel.outboxFolder, account: account.id),
        ),
    ];
  }
}

/// Modifiche ai Preferiti dal menu del tasto destro. Alla prima modifica i predefiniti diventano
/// un elenco salvato; i Preferiti nascosti (cartella o account spariti) restano al loro posto.
class _FavoritesEditor {
  _FavoritesEditor(this._settings, this._all, this._shown);

  final AppSettings _settings;
  final List<FavoriteFolder> _all;
  final List<FavoriteFolder> _shown;

  bool contains(String account, String folder) => _all.any((f) => f.isFor(account, folder));

  void add(FavoriteFolder favorite) => _settings.setFavorites([..._all, favorite]);

  void remove(FavoriteFolder favorite) => _settings.setFavorites([..._all]..remove(favorite));

  /// Trascinamento: [favorite] (già nei Preferiti o nuovo) prende il posto di [target], che scorre di
  /// uno; senza [target] va in fondo.
  void place(FavoriteFolder favorite, FavoriteFolder? target) {
    final list = [..._all];
    final at = target == null ? list.length : list.indexOf(target);
    list.remove(favorite);
    list.insert(at < 0 ? list.length : at.clamp(0, list.length), favorite);
    _settings.setFavorites(list);
  }

  /// Scambia due Preferiti visibili ([a] e [b] sono posizioni tra quelli mostrati).
  void swap(int a, int b) {
    final list = [..._all];
    final i = list.indexOf(_shown[a]);
    final j = list.indexOf(_shown[b]);
    list[i] = _shown[b];
    list[j] = _shown[a];
    _settings.setFavorites(list);
  }
}

/// Testo a destra del nome della cartella (scelta 3.4-2a, come Outlook): per Bozze e Posta
/// indesiderata il totale tra parentesi quadre, per le altre il numero delle mail da leggere.
/// Null se non c'è niente da mostrare (zero o numero non noto).
({String text, bool unread})? folderBadge(MailFolder folder) {
  if (folder.role == 'drafts' || folder.role == 'junk') {
    final count = folder.count ?? 0;
    return count > 0 ? (text: '[$count]', unread: false) : null;
  }
  final unread = folder.unread ?? 0;
  return unread > 0 ? (text: '$unread', unread: true) : null;
}

/// Icona della cartella secondo il ruolo (icone Fluent, licenza MIT).
IconData folderIcon(MailFolder folder) => switch (folder.role) {
  'inbox' => FluentIcons.mail_inbox_20_regular,
  'sent' => FluentIcons.send_20_regular,
  'drafts' => FluentIcons.drafts_20_regular,
  'trash' => FluentIcons.delete_20_regular,
  'junk' => FluentIcons.folder_prohibited_20_regular,
  'archive' => FluentIcons.archive_20_regular,
  _ => FluentIcons.folder_20_regular,
};

/// Riga del riquadro delle cartelle come l'Outlook di oggi (tappa «Aspetto», V4): alta 32, staccata di 6 px dai bordi
/// del riquadro così che la selezione e il passaggio del mouse abbiano gli angoli arrotondati visibili. [indent] è
/// il rientro del contenuto misurato dal bordo del riquadro, come prima.
Widget folderTile({
  Key? key,
  required double indent,
  required Widget leading,
  required Widget title,
  Widget? trailing,
  bool selected = false,
  VoidCallback? onTap,
}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: _folderInset, vertical: 1),
  child: ListTile(
    key: key,
    dense: true,
    minTileHeight: 32,
    minVerticalPadding: 0,
    contentPadding: EdgeInsets.only(left: indent - _folderInset, right: 16 - _folderInset),
    leading: leading,
    title: title,
    trailing: trailing,
    selected: selected,
    onTap: onTap,
  ),
);

const _folderInset = 6.0;

/// Riga di una cartella (nei Preferiti o nell'albero) con il suo menu del tasto destro.
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    super.key,
    required this.folder,
    required this.label,
    required this.indent,
    required this.selected,
    required this.onTap,
    required this.menuItems,
    this.editing = false,
    this.dragData,
    this.accepts,
    this.onDrop,
  });

  final MailFolder folder;
  final String label;
  final double indent;
  final bool selected;
  final VoidCallback onTap;
  final List<Widget> menuItems;

  /// Dati trascinati prendendo la riga (null = non trascinabile).
  final Object? dragData;

  /// Cosa si può rilasciare sulla riga e cosa succede (null = niente).
  final bool Function(Object data)? accepts;
  final void Function(Object data)? onDrop;

  /// Rinomina in corso: al posto del nome una casella di testo (scelta 3.4-3a).
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = folderBadge(folder);
    final bold = badge?.unread ?? false;
    Widget row = _ContextMenuRegion(
      menuItems: menuItems,
      child: folderTile(
        indent: indent,
        leading: Icon(folderIcon(folder), size: 20),
        title: editing
            ? _FolderNameField(initial: folder.name)
            : Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
              ),
        trailing: badge == null || editing
            ? null
            : Text(
                badge.text,
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: badge.unread ? FontWeight.bold : null),
              ),
        selected: selected,
        onTap: editing ? null : onTap,
      ),
    );
    if (accepts != null && onDrop != null && !editing) {
      row = DropZone(accepts: accepts!, onDrop: onDrop!, child: row);
    }
    if (dragData != null && !editing) {
      row = MailDraggable<Object>(
        data: dragData,
        feedback: DragFeedback(icon: folderIcon(folder), text: label),
        childWhenDragging: Opacity(opacity: 0.5, child: row),
        child: row,
      );
    }
    return row;
  }
}

/// Riga della nuova cartella, con il nome da scrivere.
class _NewFolderRow extends StatelessWidget {
  const _NewFolderRow({required this.indent});

  final double indent;

  @override
  Widget build(BuildContext context) => folderTile(
    key: const ValueKey('new-folder'),
    indent: indent,
    leading: const Icon(FluentIcons.folder_add_20_regular, size: 20),
    title: const _FolderNameField(initial: ''),
  );
}

/// Casella del nome per Nuova cartella e Rinomina: Invio conferma, Esc o un clic altrove annulla.
/// Se il server rifiuta il nome il motivo compare sotto e la casella resta aperta.
class _FolderNameField extends StatefulWidget {
  const _FolderNameField({required this.initial});

  final String initial;

  @override
  State<_FolderNameField> createState() => _FolderNameFieldState();
}

class _FolderNameFieldState extends State<_FolderNameField> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
  final _focus = FocusNode(debugLabel: 'Nome della cartella');

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Se è la finestra dell'app a perdere il fuoco (altra finestra in primo piano) Flutter toglie il fuoco a tutto e
    // lo ridà alla casella al ritorno: non è un clic altrove, la casella resta aperta.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    if (!_focus.hasFocus && mounted) {
      context.read<MailboxModel>().cancelFolderEdit(reason: 'la casella ha perso il fuoco');
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final model = context.read<MailboxModel>();
    final rename = model.folderEdit?.isNew == false;
    // Rinomina senza cambiamenti: niente richiesta al server.
    if (rename && _controller.text.trim() == widget.initial) {
      model.cancelFolderEdit(reason: 'nome non cambiato');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (!await model.commitFolderEdit(_controller.text)) {
      if (mounted) _focus.requestFocus();
    } else if (model.takeFolderNotice() case final notice?) {
      messenger.showSnackBar(SnackBar(content: Text(notice), duration: const Duration(seconds: 10)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => model.cancelFolderEdit(reason: 'Esc')},
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        autofocus: true,
        readOnly: model.folderEditBusy,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: context.l10n.folderNameHint,
          errorText: model.folderEditError,
          errorMaxLines: 4,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        ),
        onSubmitted: (_) {
          folderLog('Invio nella casella del nome');
          _submit();
        },
        onEditingComplete: () {}, // Invio non toglie il fuoco: in caso di errore si corregge e si riprova
        onTapOutside: (_) => _focus.unfocus(),
      ),
    );
  }
}

/// Zona con un menu del tasto destro, aperto nel punto del clic.
class _ContextMenuRegion extends StatefulWidget {
  const _ContextMenuRegion({required this.menuItems, required this.child});

  final List<Widget> menuItems;
  final Widget child;

  @override
  State<_ContextMenuRegion> createState() => _ContextMenuRegionState();
}

class _ContextMenuRegionState extends State<_ContextMenuRegion> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    menuChildren: widget.menuItems,
    child: GestureDetector(
      onSecondaryTapUp: (d) => _menu.open(position: d.localPosition),
      child: widget.child,
    ),
  );
}

/// Intestazione di sezione apribile (Preferiti).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.expanded, required this.onToggle});

  final String title;
  final bool expanded;
  final void Function(bool expanded) onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 12),
      leading: Icon(expanded ? Icons.expand_more : Icons.chevron_right),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      onTap: () => onToggle(!expanded),
    );
  }
}

/// Riga dell'account: freccia apri/chiudi, nome e, solo se l'aggiornamento automatico non è
/// attivo, un'icona di avviso con il motivo nel tooltip.
class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.account, required this.expanded, required this.watching, required this.onToggle});

  final AccountInfo account;
  final bool expanded;

  /// Stato dell'aggiornamento automatico: true attivo, false non attivo, null non ancora noto.
  final bool? watching;
  final void Function(bool expanded) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 12),
      leading: Icon(expanded ? Icons.expand_more : Icons.chevron_right),
      title: Text(
        account.name,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      trailing: watching == false
          ? Tooltip(
              message: context.l10n.noAutoUpdate(account.address),
              child: Icon(Icons.sync_disabled, size: 20, color: theme.colorScheme.error),
            )
          : null,
      onTap: () => onToggle(!expanded),
    );
  }
}
