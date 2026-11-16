import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language.dart';
import '../models/mail_folder.dart';
import '../state/mailbox_model.dart';
import 'message_actions.dart';

/// Archivia (A2, scelte 1a e 3a): come Outlook classico per IMAP e POP3. Il comando sposta le mail selezionate nella
/// cartella di archiviazione del loro account; la prima volta (o se la cartella è sparita) si sceglie o si crea con
/// «Imposta cartella di archiviazione». MODIFICA la casella come Sposta: niente si cancella.
class ArchiveActions {
  ArchiveActions._();

  /// Archivia si può usare: c'è qualcosa da spostare e nessuna mail è già nella cartella di archiviazione.
  static bool canArchive(MailboxModel model) => MessageActions.canModify(model) && !model.selectionInArchive;

  /// Testo del suggerimento del comando.
  static String tooltip(AppLocalizations l, MailboxModel model) =>
      model.selectionInArchive ? l.alreadyInArchive : l.archiveTooltip;

  /// «Archivia». Per gli account senza cartella di archiviazione prima la finestra di scelta: annullata, non si
  /// sposta niente. [openNext]: nella finestra della mail dopo lo spostamento si apre la successiva.
  static Future<void> archive(BuildContext context, {bool openNext = false}) async {
    final model = context.read<MailboxModel>();
    if (!canArchive(model)) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    for (final account in model.selectionAccountsWithoutArchive) {
      if (!context.mounted) return;
      final chosen = await ArchiveFolderDialog.show(context, account: account, beforeArchive: true);
      if (!chosen) return;
    }
    // Dopo la scelta la cartella potrebbe contenere le mail selezionate (es. archivio = cartella aperta).
    if (!canArchive(model)) {
      _show(messenger, l.mailsAlreadyInArchive);
      return;
    }
    Future<void> run() async => _show(messenger, (await model.archiveSelected()).message);
    await (openNext ? model.removeAndOpenNext(run) : run());
  }

  static void _show(ScaffoldMessengerState messenger, String text) {
    if (text.isEmpty) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

/// «Imposta cartella di archiviazione» per un account: una cartella esistente (di serie quella scelta o la
/// proposta del core) oppure una nuova in cima all'account. true se la scelta è stata salvata.
class ArchiveFolderDialog extends StatefulWidget {
  const ArchiveFolderDialog({super.key, required this.account, this.beforeArchive = false});

  final String account;

  /// Aperta da Archivia: il testo spiega perché e il pulsante dice cosa succede dopo.
  final bool beforeArchive;

  static Future<bool> show(BuildContext context, {required String account, bool beforeArchive = false}) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => ArchiveFolderDialog(account: account, beforeArchive: beforeArchive),
      ) ??
      false;

  @override
  State<ArchiveFolderDialog> createState() => _ArchiveFolderDialogState();
}

class _ArchiveFolderDialogState extends State<ArchiveFolderDialog> {
  /// Ruoli che non possono essere l'archivio (il core li rifiuta comunque).
  static const _excludedRoles = {'inbox', 'sent', 'drafts', 'trash', 'junk', 'outbox'};

  final _name = TextEditingController();
  bool _nameSet = false;
  bool _loading = true;
  bool _saving = false;
  bool _create = false;
  String? _folder;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nome proposto per la cartella nuova, nella lingua dell'app.
    if (!_nameSet) {
      _nameSet = true;
      _name.text = context.l10n.archiveFolderName;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ApiClient get _api => context.read<ApiClient>().forAccount(widget.account);

  List<MailFolder> _folders(MailboxModel model) => [
    for (final f in model.foldersByAccount[widget.account] ?? const <MailFolder>[])
      if (!_excludedRoles.contains(f.role)) f,
  ];

  Future<void> _load() async {
    try {
      final options = await _api.getArchiveOptions();
      if (!mounted) return;
      final folders = _folders(context.read<MailboxModel>());
      final initial = options.folder ?? options.suggested;
      setState(() {
        _folder = folders.any((f) => f.fullName == initial) ? initial : null;
        _create = folders.isEmpty || _folder == null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 503 ? context.l10n.offlineUnavailable : '$e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final model = context.read<MailboxModel>();
    final navigator = Navigator.of(context);
    final l = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var folder = _folder;
      if (_create) {
        // MODIFICA la casella: la cartella nuova, in cima all'account.
        folder = (await _api.createFolder(null, _name.text)).fullName;
      }
      await _api.setArchiveFolder(folder);
      await model.reloadFolders(widget.account);
      navigator.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.statusCode == 503
            ? l.offlineUnavailable
            : (e.fieldErrors['name'] ?? e.fieldErrors['folder'])?.join(' ') ?? '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final theme = Theme.of(context);
    final folders = _folders(model);
    final accountName = model.accounts.where((a) => a.id == widget.account).firstOrNull?.name ?? widget.account;
    final canSave = !_loading && !_saving && (_create ? _name.text.trim().isNotEmpty : _folder != null);
    final l = context.l10n;
    return AlertDialog(
      key: const Key('archive-dialog'),
      icon: const Icon(FluentIcons.archive_24_regular),
      title: Text(l.setArchiveFolder),
      content: SizedBox(
        width: 440,
        child: _loading
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.beforeArchive ? l.archiveFirstTime(accountName) : l.archiveInfo(accountName),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<bool>(
                      groupValue: _create,
                      onChanged: (v) => _saving ? null : setState(() => _create = v ?? false),
                      child: Column(
                        children: [
                          RadioListTile<bool>(
                            key: const Key('archive-existing'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: false,
                            enabled: folders.isNotEmpty,
                            title: Text(l.useExistingFolder),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('archive-folder:${widget.account}'),
                              initialValue: _folder,
                              isExpanded: true,
                              decoration: InputDecoration(isDense: true, hintText: l.chooseAFolder),
                              items: [
                                for (final f in folders)
                                  DropdownMenuItem(
                                    value: f.fullName,
                                    child: Text(f.fullName, overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                              onChanged: _saving || folders.isEmpty
                                  ? null
                                  : (v) => setState(() {
                                      _folder = v;
                                      _create = false;
                                    }),
                            ),
                          ),
                          const SizedBox(height: 8),
                          RadioListTile<bool>(
                            key: const Key('archive-create'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: true,
                            title: Text(l.createTopFolder),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: TextField(
                              key: const Key('archive-new-name'),
                              controller: _name,
                              enabled: !_saving,
                              decoration: InputDecoration(isDense: true, hintText: l.folderNameHint),
                              onTap: () => setState(() => _create = true),
                              onChanged: (_) => setState(() => _create = true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error,
                          key: const Key('archive-error'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(
          key: const Key('archive-ok'),
          onPressed: canSave ? _save : null,
          child: Text(widget.beforeArchive ? l.okAndArchive : 'OK'),
        ),
      ],
    );
  }
}
