import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message_tags.dart';
import '../settings/app_settings.dart';
import '../state/mailbox_model.dart';
import 'categories.dart';
import 'follow_up.dart';

/// Messaggi su cui agiscono "Categorizza" e "Completa": la mail aperta (barra multifunzione, tasto
/// destro), una riga della lista (bandierina) o tutte le mail selezionate ([many], 3.5a).
class TagTarget {
  const TagTarget({required this.account, required this.folder, required this.uid, required this.tags}) : many = false;

  /// Tutte le mail selezionate; [tags] = contrassegno e categorie comuni a tutte.
  const TagTarget.selection(this.tags) : account = '', folder = '', uid = 0, many = true;

  final String account;
  final String folder;
  final int uid;
  final MessageTags tags;
  final bool many;

  /// La mail aperta, se ce n'è una con il dettaglio caricato, oppure le mail selezionate se più d'una.
  static TagTarget? open(MailboxModel model) {
    if (model.multiSelection) return TagTarget.selection(model.selectionTags);
    final (account, folder, uid, detail) = (model.openAccount, model.openFolder, model.selectedUid, model.detail);
    if (account == null || folder == null || uid == null || detail == null) return null;
    return TagTarget(account: account, folder: folder, uid: uid, tags: detail.tags);
  }
}

/// Voci dei menu "Categorizza" e "Completa" (3.3), uguali nella barra multifunzione e nel menu del
/// tasto destro. Ogni voce MODIFICA la casella; [TagMenus.categoryItems] e [TagMenus.followUpItems]
/// con target null mostrano le voci disattivate (nessuna mail aperta o senza connessione).
class TagMenus {
  TagMenus._();

  static Future<void> _apply(
    BuildContext context,
    TagTarget t, {
    String? followUp,
    DateTime? due,
    List<int>? categories,
    List<int>? addCategories,
    List<int>? removeCategories,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (t.many) {
      // Più mail: le categorie si aggiungono o tolgono a tutte, senza toccare le altre di ciascuna.
      final error = await context.read<MailboxModel>().updateTagsSelected(
        followUp: followUp,
        due: due,
        addCategories: addCategories,
        removeCategories: removeCategories,
      );
      if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final error = await context.read<MailboxModel>().updateTags(
      account: t.account,
      folder: t.folder,
      uid: t.uid,
      followUp: followUp,
      due: due,
      categories: categories,
    );
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  /// Clic sulla bandierina della riga, come in Outlook: senza contrassegno -> "Oggi";
  /// contrassegnato -> completato; completato -> di nuovo contrassegnato per oggi.
  static Future<void> toggleFlag(BuildContext context, TagTarget t) => t.tags.flagged
      ? _apply(context, t, followUp: 'completed')
      : _apply(context, t, followUp: 'flagged', due: FollowUpChoice.today.dueFrom(DateTime.now()));

  static List<Widget> categoryItems(BuildContext context, TagTarget? t) {
    final settings = context.read<AppSettings>();
    final current = t?.tags.categories ?? const <int>[];
    return [
      for (var n = 1; n <= CategoryColors.colors.length; n++)
        MenuItemButton(
          leadingIcon: CategorySwatch(n, size: 14),
          trailingIcon: current.contains(n) ? const Icon(FluentIcons.checkmark_16_regular, size: 16) : null,
          onPressed: t == null
              ? null
              : t.many
              // Come Outlook: se tutte ce l'hanno la si toglie a tutte, altrimenti la si aggiunge a tutte.
              ? () => current.contains(n)
                    ? _apply(context, t, removeCategories: [n])
                    : _apply(context, t, addCategories: [n])
              : () => _apply(
                  context,
                  t,
                  categories: current.contains(n) ? [...current.where((c) => c != n)] : ([...current, n]..sort()),
                ),
          child: Text(settings.categoryName(n)),
        ),
      const Divider(height: 8),
      MenuItemButton(
        onPressed: t == null || (current.isEmpty && !t.many)
            ? null
            : t.many
            ? () => _apply(context, t, removeCategories: [for (var n = 1; n <= CategoryColors.colors.length; n++) n])
            : () => _apply(context, t, categories: const []),
        child: const Text('Cancella tutte le categorie'),
      ),
      MenuItemButton(
        onPressed: () => showDialog<void>(context: context, builder: (_) => CategoryNamesDialog(settings: settings)),
        child: const Text('Tutte le categorie…'),
      ),
    ];
  }

  static List<Widget> followUpItems(BuildContext context, TagTarget? t) {
    return [
      for (final choice in FollowUpChoice.values)
        MenuItemButton(
          leadingIcon: const Icon(FluentIcons.flag_16_regular, size: 16),
          onPressed: t == null
              ? null
              : () => _apply(context, t, followUp: 'flagged', due: choice.dueFrom(DateTime.now())),
          child: Text(choice.label),
        ),
      MenuItemButton(
        leadingIcon: const Icon(FluentIcons.calendar_20_regular, size: 16),
        onPressed: t == null ? null : () => _pickDate(context, t),
        child: const Text('Data personalizzata…'),
      ),
      const Divider(height: 8),
      MenuItemButton(
        leadingIcon: const Icon(FluentIcons.checkmark_16_regular, size: 16),
        onPressed: t == null || (t.tags.completed && !t.many) ? null : () => _apply(context, t, followUp: 'completed'),
        child: const Text('Contrassegna come completato'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(FluentIcons.flag_off_20_regular, size: 16),
        onPressed: t == null || !(t.tags.flagged || t.tags.completed || t.many)
            ? null
            : () => _apply(context, t, followUp: 'none'),
        child: const Text('Cancella contrassegno'),
      ),
    ];
  }

  static Future<void> _pickDate(BuildContext context, TagTarget t) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = await showDatePicker(
      context: context,
      initialDate: t.tags.due ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5, 12, 31),
      helpText: 'Completare entro',
    );
    if (day != null && context.mounted) await _apply(context, t, followUp: 'flagged', due: day);
  }
}

/// "Tutte le categorie": rinomina le sei categorie (i nomi valgono solo su questo computer).
class CategoryNamesDialog extends StatefulWidget {
  const CategoryNamesDialog({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<CategoryNamesDialog> createState() => _CategoryNamesDialogState();
}

class _CategoryNamesDialogState extends State<CategoryNamesDialog> {
  late final _fields = [for (final name in widget.settings.categoryNames) TextEditingController(text: name)];

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Categorie'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, field) in _fields.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CategorySwatch(i + 1, size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: field,
                        maxLength: 40,
                        decoration: const InputDecoration(isDense: true, counterText: ''),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'I nomi valgono solo su questo computer; sul server ogni categoria è salvata con il suo colore.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            for (final (i, f) in _fields.indexed) {
              f.text = AppSettings.defaultCategoryNames[i];
            }
          },
          child: const Text('Nomi predefiniti'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          onPressed: () {
            widget.settings.setCategoryNames([for (final f in _fields) f.text]);
            Navigator.pop(context);
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
