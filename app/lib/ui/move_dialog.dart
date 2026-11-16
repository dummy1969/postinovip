import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../models/mail_folder.dart';
import 'folder_pane.dart';

/// "Sposta elementi" (Ctrl+Maiusc+V, scelta 3.5b-2a): albero delle cartelle dell'account con un campo
/// per filtrarle per nome. Restituisce il nome completo della cartella scelta (null = annullato).
/// Doppio clic su una cartella = OK.
class MoveDialog extends StatefulWidget {
  const MoveDialog({super.key, required this.folders, required this.count, this.title, this.message});

  /// Destinazioni possibili (già senza la cartella di partenza).
  final List<MailFolder> folders;

  /// Mail da spostare, per il testo della finestra.
  final int count;

  /// Per altri usi (es. la cartella di una regola, R2): titolo e testo al posto di "Sposta elementi".
  final String? title;
  final String? message;

  @override
  State<MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<MoveDialog> {
  final _filter = TextEditingController();
  String? _chosen;
  DateTime? _lastTap;

  /// Un clic sceglie la cartella; un secondo clic sulla stessa entro mezzo secondo = OK (doppio clic).
  /// Misurato qui e non con onDoubleTap, che farebbe aspettare ogni clic semplice.
  void _tap(String folder) {
    final now = DateTime.now();
    final again =
        folder == _chosen && _lastTap != null && now.difference(_lastTap!) < const Duration(milliseconds: 500);
    _lastTap = now;
    if (again) {
      Navigator.pop(context, folder);
    } else {
      setState(() => _chosen = folder);
    }
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _filter.text.trim().toLowerCase();
    // Filtrando si vedono solo le cartelle il cui nome contiene il testo, senza rientri (come una ricerca).
    final shown = [
      for (final f in widget.folders)
        if (query.isEmpty || f.displayName(context.l10n).toLowerCase().contains(query) || f.name.toLowerCase().contains(query)) f,
    ];
    return AlertDialog(
      title: Text(widget.title ?? context.l10n.moveItems),
      content: SizedBox(
        width: 380,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.message ??
                  context.l10n.moveItemsTo(widget.count),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _filter,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                hintText: context.l10n.searchFolder,
                prefixIcon: const Icon(Icons.search, size: 18),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {
                if (!shown.any((f) => f.fullName == _chosen)) _chosen = null;
              }),
              // Invio con una sola cartella trovata: la sceglie.
              onSubmitted: (_) {
                if (shown.length == 1) Navigator.pop(context, shown.single.fullName);
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
                child: shown.isEmpty
                    ? Center(child: Text(context.l10n.noFolderWithName))
                    : ListView(
                        children: [
                          for (final f in shown)
                            ListTile(
                              key: ValueKey('move-to:${f.fullName}'),
                              dense: true,
                              contentPadding: EdgeInsets.only(left: 8.0 + (query.isEmpty ? f.depth * 16 : 0), right: 8),
                              leading: Icon(folderIcon(f), size: 20),
                              title: Text(query.isEmpty ? f.displayName(context.l10n) : f.fullName, overflow: TextOverflow.ellipsis),
                              selected: f.fullName == _chosen,
                              onTap: () => _tap(f.fullName),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
        FilledButton(
          onPressed: _chosen == null ? null : () => Navigator.pop(context, _chosen),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
