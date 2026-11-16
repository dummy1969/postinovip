import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/language.dart';
import '../compose/address_list.dart';
import '../models/account_info.dart';
import '../models/contact.dart';

/// Destinatari scelti nella Rubrica: da aggiungere ai campi A e Cc.
typedef AddressBookChoice = ({List<String> to, List<String> cc, List<String> bcc});

/// Finestra «Rubrica» (C3, pulsanti «A…», «Cc…» e «Ccn…» della composizione, come Outlook): contatti di tutte
/// le rubriche o di una sola, ricerca, un clic seleziona (Ctrl/Maiusc non servono: ogni clic aggiunge o toglie),
/// «A ->», «Cc ->» e «Ccn ->» li mettono nelle caselle sotto, OK li porta nella mail.
class AddressBookDialog extends StatefulWidget {
  const AddressBookDialog({super.key, required this.api, required this.accounts, this.target = 'to'});

  final ApiClient api;
  final List<AccountInfo> accounts;

  /// Campo da cui è stata aperta ("to", "cc", "bcc"): lì va il doppio clic.
  final String target;

  static Future<AddressBookChoice?> show(
    BuildContext context, {
    required ApiClient api,
    required List<AccountInfo> accounts,
    String target = 'to',
  }) => showDialog<AddressBookChoice>(
    context: context,
    builder: (_) => AddressBookDialog(api: api, accounts: accounts, target: target),
  );

  @override
  State<AddressBookDialog> createState() => _AddressBookDialogState();
}

/// Un indirizzo di un contatto (un contatto con due indirizzi = due righe, come in Outlook).
typedef _Entry = ({String book, Contact contact, ContactEmail email});

class _AddressBookDialogState extends State<AddressBookDialog> {
  final _search = TextEditingController();
  final Map<String, List<Contact>> _books = {};
  String? _book; // null = tutte le rubriche
  String? _error;
  bool _loading = true;
  final _selected = <_Entry>{};
  final _to = <String>[];
  final _cc = <String>[];
  final _bcc = <String>[];
  DateTime? _lastTap;
  _Entry? _lastEntry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final lists = await Future.wait([for (final a in widget.accounts) widget.api.forAccount(a.id).getContacts()]);
      for (final (i, a) in widget.accounts.indexed) {
        _books[a.id] = lists[i];
      }
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  String _bookName(String id) {
    final a = widget.accounts.where((x) => x.id == id).firstOrNull;
    return widget.accounts.length > 1 && a != null ? '${context.l10n.contacts} - ${a.name}' : context.l10n.contacts;
  }

  List<_Entry> get _entries {
    final words = foldText(_search.text).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final result = <_Entry>[];
    for (final MapEntry(key: book, value: contacts) in _books.entries) {
      if (_book != null && book != _book) continue;
      for (final c in contacts) {
        for (final e in c.emails) {
          final hay = foldText('${c.name} ${e.address} ${c.company ?? ''}');
          if (words.every(hay.contains)) result.add((book: book, contact: c, email: e));
        }
      }
    }
    result.sort((a, b) => foldText(a.contact.name).compareTo(foldText(b.contact.name)));
    return result;
  }

  void _add(List<String> target) {
    setState(() {
      for (final e in _entries.where(_selected.contains)) {
        final mailbox = formatMailbox(e.contact.name, e.email.address);
        if (!target.contains(mailbox)) target.add(mailbox);
      }
      _selected.clear();
    });
  }

  void _tap(_Entry e) {
    final now = DateTime.now();
    final again = _lastEntry == e && _lastTap != null && now.difference(_lastTap!) < const Duration(milliseconds: 450);
    _lastEntry = e;
    _lastTap = now;
    setState(() {
      if (again) {
        // Doppio clic: aggiunto subito al campo da cui è stata aperta.
        _selected
          ..clear()
          ..add(e);
        _lastTap = null;
      } else if (!_selected.remove(e)) {
        _selected.add(e);
      }
    });
    if (again) _add(switch (widget.target) { 'cc' => _cc, 'bcc' => _bcc, _ => _to });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(FluentIcons.book_contacts_24_regular),
          const SizedBox(width: 8),
          Text(context.l10n.addressBook),
        ],
      ),
      content: SizedBox(
        width: 640,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('book-search'),
                    controller: _search,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.l10n.addressBookSearch,
                      prefixIcon: const Icon(FluentIcons.search_20_regular, size: 18),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                if (widget.accounts.length > 1) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      key: const Key('book-choice'),
                      initialValue: _book,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: context.l10n.addressBook, isDense: true, border: const OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(value: null, child: Text(context.l10n.allAddressBooks)),
                        for (final a in widget.accounts) DropdownMenuItem(value: a.id, child: Text(_bookName(a.id))),
                      ],
                      onChanged: (v) => setState(() => _book = v),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant)),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(context.l10n.contactsNotAvailable('$_error')))
                    : entries.isEmpty
                    ? Center(
                        child: Text(
                          _books.values.every((l) => l.isEmpty) ? context.l10n.noContactsWithAddress : context.l10n.noContactsFound,
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      )
                    : ListView(
                        key: const Key('book-list'),
                        children: [
                          for (final e in entries)
                            ListTile(
                              key: Key('book-entry:${e.email.address}'),
                              dense: true,
                              selected: _selected.contains(e),
                              selectedTileColor: theme.colorScheme.secondaryContainer,
                              title: Text(e.contact.name, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                [
                                  e.email.address,
                                  ?e.contact.company,
                                  if (widget.accounts.length > 1 && _book == null) _bookName(e.book),
                                ].join(' · '),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _tap(e),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            _targetRow('${context.l10n.headerTo} ->', 'book-to', _to),
            const SizedBox(height: 6),
            _targetRow('${context.l10n.headerCc} ->', 'book-cc', _cc),
            const SizedBox(height: 6),
            _targetRow('${context.l10n.bcc} ->', 'book-bcc', _bcc),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
        FilledButton(
          key: const Key('book-ok'),
          onPressed: () =>
              Navigator.pop<AddressBookChoice>(context, (to: List.of(_to), cc: List.of(_cc), bcc: List.of(_bcc))),
          child: const Text('OK'),
        ),
      ],
    );
  }

  /// «A ->» / «Cc ->» con i destinatari già scelti (✕ per toglierli).
  Widget _targetRow(String label, String key, List<String> target) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 80,
        child: OutlinedButton(
          key: Key(key),
          onPressed: _selected.isEmpty ? null : () => _add(target),
          child: Text(label),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final m in target)
              InputChip(
                label: Text(m, overflow: TextOverflow.ellipsis),
                onDeleted: () => setState(() => target.remove(m)),
                deleteButtonTooltipMessage: context.l10n.takeOut,
              ),
          ],
        ),
      ),
    ],
  );
}
