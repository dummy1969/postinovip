import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/junk_options.dart';
import '../models/mail_folder.dart';
import '../state/mailbox_model.dart';
import 'message_actions.dart';

/// Posta indesiderata (J2, scelte 1a e 4a): il menu «Posta indesiderata» di Outlook (Home → Elimina, finestra della
/// mail, menu del tasto destro) e la finestra «Opzioni posta indesiderata». I comandi agiscono sulla mail aperta o su
/// tutte le selezionate; «Blocca mittente» e «Non è posta indesiderata» MODIFICANO la casella (spostano le mail),
/// «Non bloccare mai…» cambia solo gli elenchi del core.
class JunkActions {
  JunkActions._();

  /// Voci del menu. [openNext]: nella finestra della mail, dopo uno spostamento si apre la successiva.
  static List<Widget> menuItems(BuildContext context, {bool openNext = false}) {
    final model = context.watch<MailboxModel>();
    final hasTarget = MessageActions.hasTarget(model) && !model.actionInProgress;
    final canModify = MessageActions.canModify(model);
    final group = model.multiSelection ? 'questi gruppi o mailing list' : 'questo gruppo o mailing list';
    Future<void> Function() run(Future<void> Function(BuildContext) action, {bool moves = false}) =>
        () => moves && openNext ? model.removeAndOpenNext(() => action(context)) : action(context);
    return [
      MenuItemButton(
        key: const Key('junk-block'),
        leadingIcon: const Icon(FluentIcons.person_prohibited_20_regular, size: 16),
        onPressed: canModify ? run(block, moves: true) : null,
        child: const Text('Blocca mittente'),
      ),
      for (final kind in NeverBlockKind.values)
        MenuItemButton(
          key: Key('junk-never-${kind.name}'),
          leadingIcon: Icon(
            kind == NeverBlockKind.group ? FluentIcons.people_checkmark_20_regular : FluentIcons.person_available_20_regular,
            size: 16,
          ),
          onPressed: hasTarget ? run((c) => neverBlock(c, kind)) : null,
          child: Text(kind == NeverBlockKind.group ? 'Non bloccare mai $group' : kind.label),
        ),
      MenuItemButton(
        key: const Key('junk-not-junk'),
        leadingIcon: const Icon(FluentIcons.mail_checkmark_20_regular, size: 16),
        onPressed: canModify && model.selectionInJunk ? run(notJunk, moves: true) : null,
        child: const Text('Non è posta indesiderata'),
      ),
      const Divider(height: 8),
      MenuItemButton(
        key: const Key('junk-options'),
        leadingIcon: const Icon(FluentIcons.settings_20_regular, size: 16),
        onPressed: model.accounts.isEmpty ? null : () => JunkOptionsDialog.show(context, account: model.openAccount),
        child: const Text('Opzioni posta indesiderata…'),
      ),
    ];
  }

  static void _show(ScaffoldMessengerState messenger, String text) {
    if (text.isEmpty) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// «Blocca mittente». Senza cartella della posta indesiderata (3b: si sceglie tra quelle esistenti) non si cambia
  /// niente e si propongono le Opzioni.
  static Future<void> block(BuildContext context) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    final missing = model.selectionAccountsWithoutJunk;
    if (missing.isNotEmpty) {
      final name = model.accounts.where((a) => a.id == missing.first).firstOrNull?.name ?? missing.first;
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('junk-no-folder'),
          icon: const Icon(FluentIcons.folder_prohibited_20_regular),
          title: const Text('Nessuna cartella della posta indesiderata'),
          content: Text(
            'L\'account «$name» non ha una cartella della posta indesiderata: sceglila in «Opzioni posta '
            'indesiderata». Il mittente non è stato bloccato.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Opzioni posta indesiderata…')),
          ],
        ),
      );
      if (open == true && context.mounted) await JunkOptionsDialog.show(context, account: missing.first);
      return;
    }
    final outcome = await model.blockSelected();
    _show(messenger, outcome.message);
  }

  static Future<void> neverBlock(BuildContext context, NeverBlockKind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await context.read<MailboxModel>().neverBlockSelected(kind);
    _show(messenger, outcome.message);
  }

  /// «Non è posta indesiderata»: come Outlook chiede se fidarsi sempre del mittente (spuntato di serie).
  static Future<void> notJunk(BuildContext context) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    final count = model.selection.length;
    final sender = count == 1 ? model.detail?.fromAddress : null;
    final trust = await showDialog<bool>(
      context: context,
      builder: (_) => _NotJunkDialog(count: count, sender: sender),
    );
    if (trust == null) return;
    final outcome = await model.notJunkSelected(trustSenders: trust);
    _show(messenger, outcome.message);
  }
}

class _NotJunkDialog extends StatefulWidget {
  const _NotJunkDialog({required this.count, this.sender});

  final int count;
  final String? sender;

  @override
  State<_NotJunkDialog> createState() => _NotJunkDialogState();
}

class _NotJunkDialogState extends State<_NotJunkDialog> {
  bool _trust = true;

  @override
  Widget build(BuildContext context) {
    final sender = widget.sender;
    return AlertDialog(
      key: const Key('junk-not-junk-dialog'),
      title: const Text('Contrassegna come posta non indesiderata'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.count == 1
                ? 'Il messaggio verrà riportato nella cartella Posta in arrivo.'
                : 'I ${widget.count} messaggi verranno riportati nella cartella Posta in arrivo.',
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const Key('junk-trust-sender'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _trust,
            onChanged: (v) => setState(() => _trust = v ?? false),
            title: Text(
              sender != null && sender.isNotEmpty
                  ? 'Considera sempre attendibile la posta proveniente da «$sender»'
                  : 'Considera sempre attendibile la posta proveniente da questi mittenti',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          key: const Key('junk-not-junk-ok'),
          onPressed: () => Navigator.pop(context, _trust),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// «Opzioni posta indesiderata» per account (5a), con le schede di Outlook: Opzioni (livello e cartella, 3b),
/// Mittenti attendibili (con «Considera attendibili anche i miei contatti»), Destinatari attendibili, Mittenti
/// bloccati. Le opzioni non modificano la casella: valgono per le mail che arrivano da adesso.
class JunkOptionsDialog extends StatefulWidget {
  const JunkOptionsDialog({super.key, required this.initialAccount});

  final String initialAccount;

  static Future<void> show(BuildContext context, {String? account}) {
    final model = context.read<MailboxModel>();
    final start = account ?? model.selectedAccount ?? model.accounts.firstOrNull?.id;
    if (start == null) return Future.value();
    return showDialog<void>(context: context, builder: (_) => JunkOptionsDialog(initialAccount: start));
  }

  @override
  State<JunkOptionsDialog> createState() => _JunkOptionsDialogState();
}

class _JunkOptionsDialogState extends State<JunkOptionsDialog> {
  /// Cartelle che non possono essere la posta indesiderata (il core risponde 400).
  static const _excludedRoles = {'inbox', 'sent', 'drafts', 'trash', 'outbox'};

  late String _account = widget.initialAccount;
  JunkOptions? _loaded;
  JunkLevel _level = JunkLevel.none;
  String? _folder;
  bool _trustContacts = true;
  final Map<JunkList, List<String>> _lists = {for (final l in JunkList.values) l: []};
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final options = await context.read<ApiClient>().forAccount(_account).getJunkOptions();
      if (!mounted) return;
      setState(() {
        _loaded = options;
        _level = options.level;
        _folder = options.folder;
        _trustContacts = options.trustContacts;
        for (final l in JunkList.values) {
          _lists[l] = [...options.entries(l)];
        }
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = 'Opzioni non lette: $e');
    }
  }

  /// Aggiunge o sostituisce una voce; come Outlook (e il core) un mittente bloccato non resta attendibile e viceversa.
  void _put(JunkList list, String entry, {String? replacing}) {
    setState(() {
      final entries = _lists[list]!;
      if (replacing != null) entries.remove(replacing);
      if (!entries.contains(entry)) entries.add(entry);
      final opposite = switch (list) {
        JunkList.safeSenders => JunkList.blockedSenders,
        JunkList.blockedSenders => JunkList.safeSenders,
        JunkList.safeRecipients => null,
      };
      if (opposite != null) _lists[opposite]!.remove(entry);
    });
  }

  Future<void> _ok() async {
    final model = context.read<MailboxModel>();
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().forAccount(_account).saveJunkOptions(
        JunkOptions(
          level: _level,
          folder: _folder,
          trustContacts: _trustContacts,
          safeSenders: _lists[JunkList.safeSenders]!,
          safeRecipients: _lists[JunkList.safeRecipients]!,
          blockedSenders: _lists[JunkList.blockedSenders]!,
        ),
      );
      await model.reloadFolders(_account); // la cartella con il ruolo "junk" può essere cambiata
      navigator.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      final field = e.fieldErrors.entries.firstOrNull;
      final list = JunkList.values.where((l) => l.field.toLowerCase() == field?.key).firstOrNull;
      setState(() {
        _saving = false;
        _error = field == null
            ? 'Opzioni non salvate: $e'
            : '${list == null ? '' : '${list.label}: '}${field.value.firstOrNull ?? 'valore non valido'}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final theme = Theme.of(context);
    final loaded = _loaded;
    // Anche con la finestra minima (640×480) titolo, schede e pulsanti restano visibili.
    final height = math.max(220.0, math.min(440.0, MediaQuery.sizeOf(context).height - 210));
    return AlertDialog(
      title: const Text('Opzioni posta indesiderata'),
      content: SizedBox(
        width: 580,
        height: height,
        child: loaded == null
            ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
            : DefaultTabController(
                length: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (model.accounts.length > 1)
                      DropdownButtonFormField<String>(
                        key: const Key('junk-account'),
                        initialValue: _account,
                        decoration: const InputDecoration(labelText: 'Account', isDense: true),
                        items: [for (final a in model.accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
                        onChanged: _saving
                            ? null
                            : (id) {
                                if (id == null || id == _account) return;
                                setState(() {
                                  _account = id;
                                  _loaded = null;
                                });
                                _load();
                              },
                      ),
                    const TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(text: 'Opzioni'),
                        Tab(text: 'Mittenti attendibili'),
                        Tab(text: 'Destinatari attendibili'),
                        Tab(text: 'Mittenti bloccati'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _optionsTab(model, loaded, theme),
                          for (final list in JunkList.values)
                            _JunkListTab(
                              key: ValueKey('$_account:${list.name}'),
                              list: list,
                              entries: _lists[list]!,
                              onPut: (entry, {replacing}) => _put(list, entry, replacing: replacing),
                              onRemove: (entry) => setState(() => _lists[list]!.remove(entry)),
                              trustContacts: list == JunkList.safeSenders ? _trustContacts : null,
                              onTrustContacts: (v) => setState(() => _trustContacts = v),
                            ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_error!, key: const Key('junk-error'), style: TextStyle(color: theme.colorScheme.error)),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          key: const Key('junk-ok'),
          onPressed: _saving || loaded == null ? null : _ok,
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _optionsTab(MailboxModel model, JunkOptions loaded, ThemeData theme) {
    final folders = [
      for (final f in model.foldersByAccount[_account] ?? const <MailFolder>[])
        if (!_excludedRoles.contains(f.role) || f.fullName == _folder) f,
    ];
    // Con «Automatica» la cartella la decide il core: quella del server o una riconosciuta dal nome.
    final automatic = loaded.folder == null ? loaded.junkFolder : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Le mail nuove della Posta in arrivo che sembrano posta indesiderata vengono spostate in una cartella '
            'speciale, mentre PostinoVip è aperto. Il giudizio è quello del server della posta. Scegli il livello di '
            'protezione:',
            style: theme.textTheme.bodySmall,
          ),
          RadioGroup<JunkLevel>(
            groupValue: _level,
            onChanged: (v) => setState(() => _level = v ?? JunkLevel.none),
            child: Column(
              children: [
                for (final level in JunkLevel.values)
                  RadioListTile<JunkLevel>(
                    key: Key('junk-level-${level.name}'),
                    dense: true,
                    value: level,
                    title: Text(level.label),
                    subtitle: Text(level.description),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            key: ValueKey('junk-folder:$_account'),
            initialValue: _folder,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Cartella della posta indesiderata', isDense: true),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  automatic != null ? 'Automatica: «$automatic»' : 'Automatica (nessuna cartella trovata)',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final f in folders)
                DropdownMenuItem<String?>(value: f.fullName, child: Text(f.fullName, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _saving ? null : (v) => setState(() => _folder = v),
          ),
          const SizedBox(height: 4),
          Text(
            'Automatica: quella indicata dal server, o una con «spam», «junk» o «indesiderata» nel nome. Per una '
            'cartella nuova: scheda Cartella → Nuova cartella, poi sceglila qui.',
            style: theme.textTheme.bodySmall,
          ),
          if (_level != JunkLevel.none && automatic == null && _folder == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Senza una cartella il filtro non sposta nessuna mail.',
                key: const Key('junk-no-folder-warning'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// Una scheda con un elenco (Mittenti attendibili, Destinatari attendibili, Mittenti bloccati): Aggiungi, Modifica,
/// Rimuovi, come Outlook.
class _JunkListTab extends StatefulWidget {
  const _JunkListTab({
    super.key,
    required this.list,
    required this.entries,
    required this.onPut,
    required this.onRemove,
    this.trustContacts,
    required this.onTrustContacts,
  });

  final JunkList list;
  final List<String> entries;
  final void Function(String entry, {String? replacing}) onPut;
  final ValueChanged<String> onRemove;

  /// Solo per i mittenti attendibili: «Considera attendibili anche i miei contatti».
  final bool? trustContacts;
  final ValueChanged<bool> onTrustContacts;

  @override
  State<_JunkListTab> createState() => _JunkListTabState();
}

class _JunkListTabState extends State<_JunkListTab> {
  String? _selected;

  /// Indirizzo («nome@dominio.it») o dominio («@dominio.it» o «dominio.it»); il core lo controlla di nuovo.
  static final _valid = RegExp(r'^([^\s@]+@|@)?[^\s@]+\.[^\s@]+$');

  Future<void> _edit({String? current}) async {
    final entry = await showDialog<String>(
      context: context,
      builder: (_) => _EntryDialog(list: widget.list, initial: current),
    );
    if (entry == null) return;
    widget.onPut(entry, replacing: current);
    setState(() => _selected = entry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = [...widget.entries]..sort();
    final selected = entries.contains(_selected) ? _selected : null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.list.description, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant)),
                    child: entries.isEmpty
                        ? Center(child: Text('Nessuna voce', style: TextStyle(color: theme.colorScheme.outline)))
                        : ListView(
                            key: Key('junk-list-${widget.list.name}'),
                            children: [
                              for (final e in entries)
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  selected: e == selected,
                                  title: Text(e),
                                  onTap: () => setState(() => _selected = e),
                                  onLongPress: () => _edit(current: e),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton(
                        key: Key('junk-add-${widget.list.name}'),
                        onPressed: () => _edit(),
                        child: const Text('Aggiungi…'),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        onPressed: selected == null ? null : () => _edit(current: selected),
                        child: const Text('Modifica…'),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        key: Key('junk-remove-${widget.list.name}'),
                        onPressed: selected == null ? null : () => widget.onRemove(selected),
                        child: const Text('Rimuovi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.trustContacts != null)
            CheckboxListTile(
              key: const Key('junk-trust-contacts'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: widget.trustContacts,
              onChanged: (v) => widget.onTrustContacts(v ?? false),
              title: const Text('Considera attendibili anche i miei contatti'),
            ),
        ],
      ),
    );
  }
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.list, this.initial});

  final JunkList list;
  final String? initial;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ok() {
    final value = _controller.text.trim().toLowerCase();
    if (!_JunkListTabState._valid.hasMatch(value)) {
      setState(() => _error = 'Scrivi un indirizzo (anna@esempio.it) o un dominio (@esempio.it).');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Aggiungi indirizzo o dominio' : 'Modifica indirizzo o dominio'),
    content: SizedBox(
      width: 420,
      child: TextField(
        key: const Key('junk-entry'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Indirizzo di posta o nome di dominio Internet',
          hintText: 'es. anna@esempio.it oppure @esempio.it',
          errorText: _error,
        ),
        onSubmitted: (_) => _ok(),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
      FilledButton(key: const Key('junk-entry-ok'), onPressed: _ok, child: const Text('OK')),
    ],
  );
}
