import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../models/contact.dart';
import 'address_list.dart';

/// Campo A/Cc con il completamento degli indirizzi (C3, scelta 3a, come Outlook): mentre si scrive un
/// destinatario compaiono i contatti di tutte le rubriche e gli indirizzi usati di recente; frecce e Invio
/// (o clic) scelgono, Esc chiude, la ✕ toglie un indirizzo recente dai suggerimenti.
class AddressField extends StatefulWidget {
  const AddressField({
    super.key,
    required this.controller,
    required this.decoration,
    required this.suggest,
    required this.removeRecent,
    this.enabled = true,
    this.autofocus = false,
    this.validator,
    this.onChanged,
    this.fieldKey,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final Future<List<AddressSuggestion>> Function(String query) suggest;
  final Future<void> Function(String address) removeRecent;
  final bool enabled;
  final bool autofocus;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;

  /// Attesa dopo l'ultima lettera prima di chiedere i suggerimenti al core.
  static Duration debounce = const Duration(milliseconds: 150);

  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  final _focus = FocusNode(debugLabel: 'Indirizzi');

  /// Tolti con la ✕ in questa finestra (il core li ha già dimenticati; qui spariscono subito).
  final _removed = <String>{};

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<Iterable<AddressSuggestion>> _options(TextEditingValue value) async {
    final cursor = value.selection.isValid ? value.selection.baseOffset : value.text.length;
    final query = currentRecipient(value.text, cursor).text;
    if (query.trim().isEmpty || query.contains('<')) return const [];
    await Future<void>.delayed(AddressField.debounce);
    if (widget.controller.value.text != value.text) return const []; // si è scritto ancora: risposta vecchia
    try {
      final present = addressesIn(value.text);
      return (await widget.suggest(query.trim()))
          .where((s) => !present.contains(s.address.toLowerCase()) && !_removed.contains(s.address.toLowerCase()))
          .toList();
    } on Exception {
      return const []; // senza suggerimenti si scrive come prima
    }
  }

  String _replace(AddressSuggestion s) {
    final value = widget.controller.value;
    final cursor = value.selection.isValid ? value.selection.baseOffset : value.text.length;
    return replaceCurrentRecipient(value.text, cursor, formatMailbox(s.name, s.address));
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<AddressSuggestion>(
    textEditingController: widget.controller,
    focusNode: _focus,
    optionsBuilder: _options,
    displayStringForOption: _replace,
    onSelected: (_) => widget.onChanged?.call(widget.controller.text),
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextFormField(
      key: widget.fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      decoration: widget.decoration,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: (_) => onSubmitted(),
    ),
    optionsViewBuilder: (context, onSelected, options) => _SuggestionList(
      options: options.toList(),
      onSelected: onSelected,
      onRemove: (s) async {
        _removed.add(s.address.toLowerCase());
        try {
          await widget.removeRecent(s.address);
        } on Exception {
          // non è grave: resta solo tolto da questa finestra
        }
      },
    ),
  );
}

class _SuggestionList extends StatefulWidget {
  const _SuggestionList({required this.options, required this.onSelected, required this.onRemove});

  final List<AddressSuggestion> options;
  final AutocompleteOnSelected<AddressSuggestion> onSelected;
  final Future<void> Function(AddressSuggestion) onRemove;

  @override
  State<_SuggestionList> createState() => _SuggestionListState();
}

class _SuggestionListState extends State<_SuggestionList> {
  final _hidden = <AddressSuggestion>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlighted = AutocompleteHighlightedOption.of(context);
    final shown = widget.options.where((o) => !_hidden.contains(o)).toList();
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        key: const Key('address-suggestions'),
        elevation: 6,
        borderRadius: BorderRadius.circular(4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300, maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            children: [
              for (final (i, o) in widget.options.indexed)
                if (!_hidden.contains(o))
                  ListTile(
                    key: Key('suggestion:${o.address}'),
                    dense: true,
                    selected: i == highlighted,
                    selectedTileColor: theme.colorScheme.secondaryContainer,
                    leading: Icon(
                      o.isRecent ? FluentIcons.history_20_regular : FluentIcons.person_20_regular,
                      size: 18,
                    ),
                    title: Text(o.name?.isNotEmpty == true ? o.name! : o.address, overflow: TextOverflow.ellipsis),
                    subtitle: o.name?.isNotEmpty == true ? Text(o.address, overflow: TextOverflow.ellipsis) : null,
                    trailing: o.isRecent
                        ? IconButton(
                            key: Key('suggestion-remove:${o.address}'),
                            tooltip: 'Non suggerire più questo indirizzo',
                            icon: const Icon(FluentIcons.dismiss_16_regular, size: 16),
                            onPressed: () {
                              setState(() => _hidden.add(o));
                              unawaited(widget.onRemove(o));
                            },
                          )
                        : null,
                    onTap: () => widget.onSelected(o),
                  ),
              if (shown.isEmpty)
                const ListTile(dense: true, title: Text('Nessun altro suggerimento')),
            ],
          ),
        ),
      ),
    );
  }
}
