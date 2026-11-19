import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../account/accounts_page.dart';
import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../l10n/core_errors.dart';
import '../l10n/formats.dart';
import '../l10n/language.dart';
import '../attachments/file_picker.dart';
import '../attachments/file_saver.dart';
import '../models/account_info.dart';
import '../models/carddav.dart';
import '../models/compose_draft.dart';
import '../models/contact.dart';
import '../settings/app_settings.dart';
import '../state/contacts_model.dart';
import '../state/mailbox_model.dart';
import 'compose_page.dart';
import 'contact_dialog.dart';
import 'home_page.dart';
import 'module_bar.dart';
import 'ribbon_parts.dart';
import 'keys.dart';

/// Comandi della vista Persone (C2), comuni a barra multifunzione, scorciatoie e scheda del contatto.
class PeopleActions {
  PeopleActions._();

  /// «Contatti – account» (con più account) o «Contatti».
  static String bookLabel(AppLocalizations l, MailboxModel mail, String? account) {
    final info = mail.accounts.where((a) => a.id == account).firstOrNull;
    return mail.multipleAccounts && info != null ? '${l.contacts} - ${info.name}' : l.contacts;
  }

  static Future<void> newContact(BuildContext context) async {
    final book = context.read<ContactsModel>().book;
    if (book == null) return;
    await ContactDialog.show(context, account: book, accountLabel: _label(context, book));
  }

  static Future<void> edit(BuildContext context) async {
    final model = context.read<ContactsModel>();
    final contact = model.selected;
    final book = model.book;
    if (contact == null || book == null) return;
    await ContactDialog.show(context, account: book, accountLabel: _label(context, book), initial: contact);
  }

  static Future<void> delete(BuildContext context) async {
    final model = context.read<ContactsModel>();
    final contact = model.selected;
    if (contact == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteContactQuestion),
        content: Text(l.deleteContactContent(contact.name)),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await model.delete(contact.id);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.contactNotDeleted('$e'))));
    }
  }

  /// Nuova mail a un indirizzo del contatto (il primo, se non è indicato).
  static Future<void> composeTo(BuildContext context, Contact contact, [ContactEmail? email]) {
    final mail = context.read<MailboxModel>();
    final address = email ?? contact.emails.firstOrNull;
    if (address == null) return Future.value();
    final book = context.read<ContactsModel>().book;
    final account = mail.accounts.where((a) => a.id == book).firstOrNull ?? mail.currentAccount;
    return openCompose(
      context,
      draft: ComposeDraft(to: [_mailbox(contact.name, address.address)]),
      account: account ?? mail.accounts.firstOrNull,
      accounts: mail.accounts,
    );
  }

  /// `Nome <indirizzo>`, con il nome tra virgolette se contiene caratteri speciali.
  static String _mailbox(String name, String address) {
    if (name.isEmpty || name == address) return address;
    final quoted = RegExp(r'[",;<>@()\[\]:\\]').hasMatch(name)
        ? '"${name.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"'
        : name;
    return '$quoted <$address>';
  }

  static Future<void> importFile(BuildContext context) async {
    final model = context.read<ContactsModel>();
    final picker = context.read<FilePickerService>();
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    if (model.book == null) return;
    final file = await picker.pickFile(label: l.contactFilesLabel, extensions: ['vcf', 'csv']);
    if (file == null) return;
    final format = file.name.toLowerCase().endsWith('.csv') ? 'csv' : 'vcf';
    try {
      final r = await model.import(format, file.bytes);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.importDone),
          content: Text(
            [
              '${file.name}:',
              l.importAdded(r.imported),
              if (r.duplicates > 0) l.importDuplicates(r.duplicates),
              if (r.invalid > 0) l.importInvalid(r.invalid),
            ].join('\n'),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.importFailed('$e'))));
    }
  }

  static Future<void> exportFile(BuildContext context) async {
    final model = context.read<ContactsModel>();
    final saver = context.read<FileSaver>();
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final label = bookLabel(l, context.read<MailboxModel>(), model.book);
    if (model.book == null) return;
    final format = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.exportContacts),
        children: [
          SimpleDialogOption(
            key: const Key('export-vcf'),
            onPressed: () => Navigator.pop(context, 'vcf'),
            child: ListTile(
              title: const Text('vCard (.vcf)'),
              subtitle: Text(l.exportVcfHint),
            ),
          ),
          SimpleDialogOption(
            key: const Key('export-csv'),
            onPressed: () => Navigator.pop(context, 'csv'),
            child: ListTile(
              title: const Text('CSV (.csv)'),
              subtitle: Text(l.exportCsvHint),
            ),
          ),
        ],
      ),
    );
    if (format == null) return;
    final path = await saver.pickSaveLocation('$label.$format');
    if (path == null) return;
    try {
      await saver.write(path, await model.export(format));
      messenger.showSnackBar(SnackBar(content: Text(l.exportDone(model.count, path))));
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    }
  }

  /// «Aggiungi a Contatti» sul mittente della mail aperta: nella rubrica dell'account della mail. Se l'indirizzo
  /// c'è già, si apre quel contatto invece di crearne un doppione.
  static Future<void> addSender(BuildContext context) async {
    final mail = context.read<MailboxModel>();
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final detail = mail.detail;
    final account = mail.openAccount;
    final address = detail?.fromAddress;
    if (detail == null || account == null || address == null || address.isEmpty) return;
    final List<Contact> existing;
    try {
      existing = await api.forAccount(account).getContacts();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.contactsNotAvailable('$e'))));
      return;
    }
    if (!context.mounted) return;
    final known = existing
        .where((c) => c.emails.any((e) => e.address.toLowerCase() == address.toLowerCase()))
        .firstOrNull;
    final name = detail.from.trim();
    final words = name == address || name.contains('@') ? <String>[] : name.split(RegExp(r'\s+'));
    final label = _label(context, account);
    final saved = await ContactDialog.show(
      context,
      account: account,
      accountLabel: label,
      initial:
          known ??
          Contact(
            givenName: words.firstOrNull,
            familyName: words.length > 1 ? words.skip(1).join(' ') : null,
            emails: [ContactEmail(address)],
          ),
    );
    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(l.contactSavedIn(saved.name, bookLabel(l, mail, account)))));
    }
  }

  /// Riga di stato della sincronizzazione CardDAV (C4c, 2a); null se non è attiva per l'account.
  static ({String text, bool error})? syncLabel(AppLocalizations l, CardDavStatus s) {
    if (!s.enabled) return null;
    String when(DateTime t) {
      final now = DateTime.now();
      final today = t.year == now.year && t.month == now.month && t.day == now.day;
      final time = formatTime(t);
      return today ? l.syncedAt(time) : l.syncedOnAt(formatDayMonth(t), time);
    }

    return switch (s.state) {
      'waiting' || 'syncing' => (text: l.syncing, error: false),
      'ok' => (text: s.lastSync == null ? l.synced : when(s.lastSync!), error: false),
      'offline' => (text: l.syncServerUnreachable, error: true),
      'unavailable' => (text: s.error ?? l.syncUnavailable, error: false),
      _ => (text: s.error ?? l.syncFailed, error: true),
    };
  }

  /// «Carica sul server…» (3a): conferma esplicita, perché **modifica la rubrica del server**.
  static Future<void> confirmUpload(BuildContext context) async {
    final model = context.read<ContactsModel>();
    final status = model.statusOf(model.book);
    final n = status.pendingUpload;
    final l = context.l10n;
    final book = bookLabel(l, context.read<MailboxModel>(), model.book);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.uploadContactsQuestion),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(l.uploadContactsContent(n, book, status.addressBook ?? l.contacts)),
        ),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.uploadToServer)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await model.confirmUpload();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.contactsNotUploaded(e.message))));
      }
    }
  }

  static String? _label(BuildContext context, String account) {
    final mail = context.read<MailboxModel>();
    return mail.multipleAccounts ? bookLabel(context.l10n, mail, account) : null;
  }

  /// Gruppi della scheda Home nella vista Persone.
  static List<Widget> ribbonGroups(BuildContext context) {
    final model = context.watch<ContactsModel>();
    final hasBook = model.book != null;
    final selected = model.selected;
    return [
      RibbonGroup(
        label: context.l10n.groupNew,
        children: [
          RibbonLargeButton(
            icon: FluentIcons.person_add_24_regular,
            label: context.l10n.newContact,
            tooltip: keyLabel(context.l10n.newContactTooltip),
            onPressed: hasBook ? () => newContact(context) : null,
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.delete,
        children: [
          RibbonLargeButton(
            icon: FluentIcons.delete_24_regular,
            label: context.l10n.delete,
            tooltip: keyLabel(context.l10n.deleteContactTooltip),
            onPressed: selected != null ? () => delete(context) : null,
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.groupCommunicate,
        children: [
          RibbonLargeButton(
            icon: FluentIcons.mail_add_24_regular,
            label: context.l10n.emailMessage,
            tooltip: context.l10n.emailMessageTooltip,
            onPressed: selected != null && selected.emails.isNotEmpty ? () => composeTo(context, selected) : null,
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.groupActions,
        children: [
          RibbonLargeButton(
            icon: FluentIcons.edit_24_regular,
            label: context.l10n.edit,
            tooltip: context.l10n.editContactTooltip,
            onPressed: selected != null ? () => edit(context) : null,
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.groupSync,
        children: [
          RibbonLargeButton(
            icon: FluentIcons.arrow_sync_24_regular,
            label: context.l10n.sync,
            tooltip: model.statusOf(model.book).enabled
                ? context.l10n.syncContactsTooltip
                : context.l10n.syncContactsOffTooltip,
            onPressed: hasBook && model.statusOf(model.book).enabled && !model.statusOf(model.book).busy
                ? model.syncNow
                : null,
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.groupImportExport,
        children: [
          RibbonLargeButton(
            icon: FluentIcons.arrow_import_24_regular,
            label: context.l10n.importEllipsis,
            tooltip: context.l10n.importTooltip,
            onPressed: hasBook ? () => importFile(context) : null,
          ),
          RibbonLargeButton(
            icon: FluentIcons.arrow_export_ltr_24_regular,
            label: context.l10n.exportEllipsis,
            tooltip: context.l10n.exportTooltip,
            onPressed: hasBook && model.count > 0 ? () => exportFile(context) : null,
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.groupFind,
        children: [
          RibbonLargeButton(
            icon: FluentIcons.search_24_regular,
            label: context.l10n.searchContacts,
            tooltip: keyLabel(context.l10n.searchContactsTooltip),
            onPressed: hasBook ? () => model.searchFocus.requestFocus() : null,
          ),
        ],
      ),
    ];
  }
}

/// Vista Persone (9a): rubriche a sinistra, elenco al centro, scheda a destra.
class PeopleView extends StatelessWidget {
  const PeopleView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: settings.folderPaneWidth, child: const _BooksPane()),
        PaneDivider(
          axis: Axis.horizontal,
          onDrag: (delta, {required save}) =>
              settings.setPaneLayout(folderWidth: settings.folderPaneWidth + delta, save: save),
        ),
        Expanded(
          child: PaneSplit(
            axis: Axis.horizontal,
            fraction: settings.listFractionRight,
            onChanged: (d, {required save}) =>
                settings.setPaneLayout(listRight: settings.listFractionRight + d, save: save),
            first: const _ContactList(),
            second: const _ContactCard(),
          ),
        ),
      ],
    );
  }
}

/// «I miei contatti»: una rubrica per account (6a).
class _BooksPane extends StatelessWidget {
  const _BooksPane();

  @override
  Widget build(BuildContext context) {
    final mail = context.watch<MailboxModel>();
    final model = context.watch<ContactsModel>();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(context.l10n.myContacts, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final AccountInfo a in mail.accounts)
                  ListTile(
                    key: Key('book:${a.id}'),
                    dense: true,
                    leading: const Icon(FluentIcons.book_contacts_20_regular),
                    title: Text(PeopleActions.bookLabel(context.l10n, mail, a.id), overflow: TextOverflow.ellipsis),
                    subtitle: _subtitle(context.l10n, theme, a.id, mail.multipleAccounts ? null : a.address, model.statusOf(a.id)),
                    selected: model.book == a.id,
                    trailing: model.book == a.id && model.count > 0 ? Text('${model.count}') : null,
                    onTap: () => model.openBook(a.id),
                  ),
              ],
            ),
          ),
          ...ModuleBar.bottomOf(context),
        ],
      ),
    );
  }
}

Widget? _subtitle(AppLocalizations l, ThemeData theme, String account, String? address, CardDavStatus status) {
  final sync = PeopleActions.syncLabel(l, status);
  if (address == null && sync == null) return null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (address != null) Text(address, overflow: TextOverflow.ellipsis),
      if (sync != null)
        Tooltip(
          message: sync.text,
          child: Text(
            sync.text,
            key: Key('sync-status:$account'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: sync.error ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    ],
  );
}

/// Account Gmail con la sincronizzazione accesa ma senza il permesso dei contatti (C4d) o del calendario (G3, [calendar]):
/// striscia con «Accedi di nuovo», che apre la schermata dell'account e fa partire l'accesso con quel permesso.
class ReloginStrip extends StatelessWidget {
  const ReloginStrip({super.key, required this.account, this.calendar = false});

  final String account;
  final bool calendar;

  /// Errore del core che chiede un nuovo accesso («…Accedi con Google…», «…Accedi di nuovo…») su un account OAuth2.
  static bool needed(BuildContext context, String? account, CardDavStatus status) {
    if (account == null || status.state != 'error' || !signInAgainCodes.contains(status.errorCode)) return false;
    return context.read<AccountsEditing?>()?.accounts.where((a) => a.id == account).firstOrNull?.usesOAuth ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onErrorContainer;
    final editing = context.read<AccountsEditing?>();
    final config = editing?.accounts.where((a) => a.id == account).firstOrNull;
    return Container(
      key: Key(calendar ? 'caldav-relogin-strip' : 'carddav-relogin-strip'),
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(calendar ? FluentIcons.calendar_error_16_regular : FluentIcons.person_warning_16_regular, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              calendar
                  ? context.l10n.reloginCalendar
                  : context.l10n.reloginContacts,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          if (editing != null && config != null)
            TextButton(
              key: Key(calendar ? 'caldav-relogin' : 'carddav-relogin'),
              onPressed: () => AccountsPage.editAccount(
                context,
                api: context.read<ApiClient>(),
                editing: editing,
                account: config,
                signInAgain: true,
              ),
              style: TextButton.styleFrom(foregroundColor: color),
              child: Text(context.l10n.signInAgain),
            ),
        ],
      ),
    );
  }
}

/// Prima volta con contatti solo sul computer (3a): striscia gialla con «Carica sul server…».
class _UploadStrip extends StatelessWidget {
  const _UploadStrip({required this.status});

  final CardDavStatus status;

  @override
  Widget build(BuildContext context) {
    final n = status.pendingUpload;
    return Container(
      key: const Key('carddav-upload-strip'),
      color: const Color(0xFFFFF4CE), // giallo delle barre informative di Office
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          const Icon(FluentIcons.info_16_regular, size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.contactsUploadStrip(n),
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          TextButton(onPressed: () => PeopleActions.confirmUpload(context), child: Text(context.l10n.uploadToServerEllipsis)),
        ],
      ),
    );
  }
}

class _ContactList extends StatefulWidget {
  const _ContactList();

  @override
  State<_ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<_ContactList> {
  final _search = TextEditingController();
  String? _book;
  String? _lastTapId;
  DateTime? _lastTap;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Doppio clic misurato a mano (come nella lista della posta): il clic semplice seleziona subito.
  void _tap(BuildContext context, Contact c) {
    final model = context.read<ContactsModel>();
    final now = DateTime.now();
    final again =
        _lastTapId == c.id && _lastTap != null && now.difference(_lastTap!) < const Duration(milliseconds: 450);
    model.select(c.id);
    _lastTapId = c.id;
    _lastTap = now;
    if (again) {
      _lastTap = null;
      PeopleActions.edit(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ContactsModel>();
    final theme = Theme.of(context);
    if (_book != model.book) {
      // Rubrica cambiata: la ricerca riparte vuota (il controller si cambia dopo il disegno).
      _book = model.book;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _search.text != model.query) _search.text = model.query;
      });
    }
    final list = model.visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            key: const Key('contact-search'),
            controller: _search,
            focusNode: model.searchFocus,
            onChanged: model.setQuery,
            decoration: InputDecoration(
              hintText: context.l10n.searchContacts,
              prefixIcon: const Icon(FluentIcons.search_20_regular, size: 18),
              suffixIcon: model.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.clearSearch,
                      icon: const Icon(FluentIcons.dismiss_16_regular, size: 16),
                      onPressed: () {
                        _search.clear();
                        model.setQuery('');
                      },
                    ),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (model.statusOf(model.book).needsConfirmation) _UploadStrip(status: model.statusOf(model.book)),
        if (ReloginStrip.needed(context, model.book, model.statusOf(model.book))) ReloginStrip(account: model.book!),
        if (model.loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: model.error != null
              ? Center(child: Text(context.l10n.contactsNotAvailable('${model.error}'), textAlign: TextAlign.center))
              : list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      model.query.isNotEmpty
                          ? context.l10n.noContactsFound
                          : model.loading
                          ? ''
                          : context.l10n.noContactsHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                )
              : ListView.builder(
                  key: const Key('contact-list'),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final c = list[i];
                    return ListTile(
                      key: Key('contact:${c.id}'),
                      dense: true,
                      selected: c.id == model.selectedId,
                      leading: CircleAvatar(radius: 16, child: Text(c.initials, style: const TextStyle(fontSize: 12))),
                      title: Text(c.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [if (c.emails.isNotEmpty) c.emails.first.address, ?c.company].join(' · '),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _tap(context, c),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Scheda del contatto selezionato, in sola lettura (si modifica con la finestra «Contatto»).
class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ContactsModel>().selected;
    final theme = Theme.of(context);
    if (c == null) {
      return Center(
        child: Text(context.l10n.selectContact, style: TextStyle(color: theme.colorScheme.outline)),
      );
    }
    Widget section(String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
    return SingleChildScrollView(
      key: const Key('contact-card'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 32, child: Text(c.initials, style: const TextStyle(fontSize: 22))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(c.name, style: theme.textTheme.headlineSmall),
                    if (c.company case final company?) Text(company, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (c.emails.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => PeopleActions.composeTo(context, c),
                  icon: const Icon(FluentIcons.mail_20_regular, size: 18),
                  label: Text(context.l10n.emailMessage),
                ),
              OutlinedButton.icon(
                onPressed: () => PeopleActions.edit(context),
                icon: const Icon(FluentIcons.edit_20_regular, size: 18),
                label: Text(context.l10n.edit),
              ),
            ],
          ),
          if (c.emails.isNotEmpty)
            section(context.l10n.emailSection, [
              for (final e in c.emails)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 90, child: Text(emailLabels(context.l10n)[e.label] ?? '', style: theme.textTheme.bodySmall)),
                      Flexible(
                        child: InkWell(
                          onTap: () => PeopleActions.composeTo(context, c, e),
                          child: Text(
                            e.address,
                            style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
          if (c.phones.isNotEmpty)
            section(context.l10n.phoneSection, [
              for (final p in c.phones)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 90, child: Text(phoneLabels(context.l10n)[p.label] ?? '', style: theme.textTheme.bodySmall)),
                      Flexible(child: SelectableText(p.number)),
                    ],
                  ),
                ),
            ]),
          if (c.notes case final notes?) section(context.l10n.notes, [SelectableText(notes)]),
        ],
      ),
    );
  }
}
