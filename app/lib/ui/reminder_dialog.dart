import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';

import '../state/calendar_model.dart';
import '../state/reminder_model.dart';
import 'calendar_view.dart';

/// Apre la finestra «Promemoria» quando [ReminderModel] lo chiede (promemoria nuovo o clic sulla notifica), una sola
/// alla volta; sta sotto il Navigator dell'app.
class ReminderHost extends StatefulWidget {
  const ReminderHost({super.key, required this.child});

  final Widget child;

  @override
  State<ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends State<ReminderHost> {
  ReminderModel? _model;
  bool _open = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final model = context.read<ReminderModel>();
    if (!identical(model, _model)) {
      _model?.removeListener(_changed);
      _model = model..addListener(_changed);
    }
  }

  @override
  void dispose() {
    _model?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final model = _model!;
    if (_open || !model.showRequested || !mounted) return;
    model.shown();
    if (model.due.isEmpty) return;
    _open = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _open = false;
        return;
      }
      await showDialog<void>(context: context, builder: (_) => const ReminderDialog());
      _open = false;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Finestra «Promemoria» come Outlook classico: elenco con oggetto, inizio e scadenza; Ignora tutto, Apri elemento,
/// Ignora; «Rimanda» con l'intervallo scelto (predefinito 5 minuti). Si chiude da sola quando non resta nulla.
class ReminderDialog extends StatefulWidget {
  const ReminderDialog({super.key});

  /// Intervalli di «Rimanda», come Outlook.
  static const snoozes = <(Duration, String)>[
    (Duration(minutes: 5), '5 minuti'),
    (Duration(minutes: 10), '10 minuti'),
    (Duration(minutes: 15), '15 minuti'),
    (Duration(minutes: 30), '30 minuti'),
    (Duration(hours: 1), '1 ora'),
    (Duration(hours: 2), '2 ore'),
    (Duration(hours: 4), '4 ore'),
    (Duration(days: 1), '1 giorno'),
    (Duration(days: 2), '2 giorni'),
    (Duration(days: 7), '1 settimana'),
  ];

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  String? _selected;
  Duration _snooze = ReminderDialog.snoozes.first.$1;
  bool _closing = false;

  static String _when(Reminder r) {
    final s = r.occurrence.start;
    return r.occurrence.allDay ? CalendarActions.date(s) : '${CalendarActions.date(s)} ${CalendarActions.time(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ReminderModel>();
    final due = model.due;
    if (due.isEmpty) {
      if (!_closing) {
        _closing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
      return const SizedBox.shrink();
    }
    final selected = due.where((r) => r.key == _selected).firstOrNull ?? due.first;
    final now = CalendarModel.now();
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('reminder-dialog'),
      title: Text(due.length == 1 ? '1 promemoria' : '${due.length} promemoria'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(FluentIcons.calendar_clock_24_regular),
              const SizedBox(width: 8),
              Expanded(child: Text(selected.occurrence.title, style: theme.textTheme.titleSmall!.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis)),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 2, bottom: 8),
              child: Text('Inizio: ${_when(selected)}'
                  '${(selected.occurrence.location ?? '').isEmpty ? '' : '    Luogo: ${selected.occurrence.location}'}'),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(border: Border.all(color: theme.dividerColor)),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in due)
                    ListTile(
                      key: Key('reminder:${r.occurrence.key}'),
                      dense: true,
                      selected: r.key == selected.key,
                      selectedTileColor: theme.colorScheme.primaryContainer,
                      leading: const Icon(FluentIcons.calendar_ltr_20_regular, size: 18),
                      title: Text(r.occurrence.title, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_when(r)),
                      trailing: Text(ReminderModel.describe(r.occurrence, now), key: Key('reminder-due:${r.occurrence.key}')),
                      onTap: () => setState(() => _selected = r.key),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton(key: const Key('reminder-dismiss-all'), onPressed: () => model.dismiss(due), child: const Text('Ignora tutto')),
              const Spacer(),
              TextButton(
                key: const Key('reminder-open'),
                onPressed: () async {
                  // Come Outlook: si apre l'appuntamento, il promemoria resta e la finestra torna dopo.
                  final o = selected.occurrence;
                  final nav = Navigator.of(context);
                  nav.pop();
                  if (!nav.context.mounted) return;
                  await CalendarActions.open(nav.context, o);
                  if (model.due.isNotEmpty) model.requestShow();
                },
                child: const Text('Apri elemento'),
              ),
              const SizedBox(width: 8),
              FilledButton(key: const Key('reminder-dismiss'), onPressed: () => model.dismiss([selected]), child: const Text('Ignora')),
            ]),
            const SizedBox(height: 12),
            const Text('Fare clic su Rimanda per ricevere un nuovo promemoria tra:'),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: DropdownButton<Duration>(
                  key: const Key('reminder-snooze-choice'),
                  isExpanded: true,
                  value: _snooze,
                  items: [for (final (d, label) in ReminderDialog.snoozes) DropdownMenuItem(value: d, child: Text(label))],
                  onChanged: (d) => setState(() => _snooze = d ?? _snooze),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(key: const Key('reminder-snooze'), onPressed: () => model.snooze([selected], _snooze), child: const Text('Rimanda')),
            ]),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Chiudi'))],
    );
  }
}
