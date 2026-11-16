import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/language.dart';
import '../models/contact.dart';
import '../state/contacts_model.dart';

/// Finestra «Contatto» (C2, scelta 10a, come Outlook): nome, cognome, nome mostrato, società, indirizzi e
/// telefoni con etichetta e «+ Aggiungi», note. «Salva e chiudi» salva nella rubrica di [account]; gli
/// errori del core (indirizzo non valido, contatto vuoto…) restano nella finestra.
class ContactDialog extends StatefulWidget {
  const ContactDialog({super.key, required this.account, this.accountLabel, this.initial = const Contact()});

  final String account;

  /// «Contatti – nome account», mostrato solo con più account.
  final String? accountLabel;
  final Contact initial;

  /// Apre la finestra; restituisce il contatto salvato, null con Annulla.
  static Future<Contact?> show(
    BuildContext context, {
    required String account,
    String? accountLabel,
    Contact initial = const Contact(),
  }) => showDialog<Contact>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ContactDialog(account: account, accountLabel: accountLabel, initial: initial),
  );

  @override
  State<ContactDialog> createState() => _ContactDialogState();
}

class _Row {
  _Row(String text, this.label) : controller = TextEditingController(text: text);

  final TextEditingController controller;
  String? label;
}

class _ContactDialogState extends State<ContactDialog> {
  late final _given = TextEditingController(text: widget.initial.givenName);
  late final _family = TextEditingController(text: widget.initial.familyName);
  late final _display = TextEditingController(text: widget.initial.displayName);
  late final _company = TextEditingController(text: widget.initial.company);
  late final _notes = TextEditingController(text: widget.initial.notes);
  late final _emails = [for (final e in widget.initial.emails) _Row(e.address, e.label)];
  late final _phones = [for (final p in widget.initial.phones) _Row(p.number, p.label)];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_emails.isEmpty) _emails.add(_Row('', null));
    if (_phones.isEmpty) _phones.add(_Row('', 'mobile'));
  }

  @override
  void dispose() {
    for (final c in [
      _given,
      _family,
      _display,
      _company,
      _notes,
      ..._emails.map((r) => r.controller),
      ..._phones.map((r) => r.controller),
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Contact get _contact => Contact(
    id: widget.initial.id,
    givenName: _text(_given),
    familyName: _text(_family),
    displayName: _text(_display),
    company: _text(_company),
    notes: _text(_notes),
    emails: [
      for (final r in _emails)
        if (r.controller.text.trim().isNotEmpty) ContactEmail(r.controller.text.trim(), r.label),
    ],
    phones: [
      for (final r in _phones)
        if (r.controller.text.trim().isNotEmpty) ContactPhone(r.controller.text.trim(), r.label),
    ],
  );

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await context.read<ContactsModel>().save(_contact, account: widget.account);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      setState(() {
        _saving = false;
        _error = e.fieldErrors.values.expand((m) => m).join('\n').ifEmpty(e.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(FluentIcons.person_24_regular),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.initial.id.isEmpty ? context.l10n.newContact : context.l10n.contact)),
          if (widget.accountLabel case final label?) Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _field(_given, context.l10n.firstName, const Key('contact-given'), autofocus: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_family, context.l10n.lastName, const Key('contact-family'))),
                ],
              ),
              _field(_display, context.l10n.displayAs, const Key('contact-display')),
              _field(_company, context.l10n.company, const Key('contact-company')),
              const SizedBox(height: 12),
              Text(context.l10n.emailSection, style: theme.textTheme.titleSmall),
              for (final (i, r) in _emails.indexed) _valueRow('email', i, r, _emails, emailLabels(context.l10n), context.l10n.linkAddress),
              _addButton('contact-add-email', context.l10n.addAddress, () => _emails.add(_Row('', null))),
              Text(context.l10n.phoneSection, style: theme.textTheme.titleSmall),
              for (final (i, r) in _phones.indexed) _valueRow('phone', i, r, _phones, phoneLabels(context.l10n), context.l10n.phoneNumber),
              _addButton('contact-add-phone', context.l10n.addPhone, () => _phones.add(_Row('', 'mobile'))),
              TextField(
                key: const Key('contact-notes'),
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(labelText: context.l10n.notes, border: const OutlineInputBorder()),
              ),
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error,
                    key: const Key('contact-error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
        FilledButton.icon(
          key: const Key('contact-save'),
          onPressed: _saving ? null : _save,
          icon: const Icon(FluentIcons.save_20_regular, size: 18),
          label: Text(context.l10n.saveAndClose),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, Key key, {bool autofocus = false}) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextField(
      key: key,
      controller: c,
      autofocus: autofocus,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
    ),
  );

  // ObjectKey sulla riga: togliendone una, menu e campo restano legati alla propria voce.
  Widget _valueRow(String kind, int i, _Row r, List<_Row> rows, Map<String, String> labels, String hint) => Padding(
    key: ObjectKey(r),
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<String?>(
            key: Key('contact-$kind-label-$i'),
            initialValue: labels.containsKey(r.label) ? r.label : null,
            isDense: true,
            isExpanded: true, // il testo dell'etichetta si accorcia invece di uscire dal riquadro
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              for (final e in labels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => r.label = v,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: Key('contact-$kind-$i'),
            controller: r.controller,
            keyboardType: kind == 'email' ? TextInputType.emailAddress : TextInputType.phone,
            decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder(), isDense: true),
          ),
        ),
        IconButton(
          tooltip: context.l10n.takeOut,
          icon: const Icon(FluentIcons.dismiss_16_regular, size: 16),
          onPressed: () => setState(() {
            rows.removeAt(i).controller.dispose();
          }),
        ),
      ],
    ),
  );

  Widget _addButton(String key, String label, VoidCallback add) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: Key(key),
      onPressed: () => setState(add),
      icon: const Icon(FluentIcons.add_16_regular, size: 16),
      label: Text(label),
    ),
  );
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
