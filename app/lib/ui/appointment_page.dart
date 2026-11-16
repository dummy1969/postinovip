import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';
import '../l10n/language.dart';
import '../models/calendar.dart';
import '../settings/app_settings.dart';
import '../state/calendar_model.dart';
import 'ribbon_parts.dart';

/// Un calendario in cui si può creare l'appuntamento (menu «Calendario» della finestra).
class CalendarChoice {
  const CalendarChoice(this.account, this.calendarId, this.label);

  final String account;
  final String calendarId;
  final String label;
}

/// Finestra Appuntamento (K4b, scelta 1a): una pagina dentro l'app come la composizione, con la sua barra multifunzione.
/// Nuovo appuntamento ([initial] null), serie, o una sola occorrenza ([initial] con recurrenceId: niente Ricorrenza).
class AppointmentPage extends StatefulWidget {
  const AppointmentPage({
    super.key,
    required this.account,
    required this.calendarId,
    this.initial,
    this.start,
    this.end,
    this.allDay = false,
    this.choices = const [],
    this.readOnly = false,
  });

  /// Appuntamento di un calendario di sola lettura (G3, 2a, es. le festività di Google): si legge, niente modifiche.
  final bool readOnly;

  final String account;
  final String calendarId;
  final CalendarEventDetail? initial;

  /// Per un appuntamento nuovo: inizio, fine e giornata intera proposti.
  final DateTime? start;
  final DateTime? end;
  final bool allDay;

  /// Calendari tra cui scegliere (solo per un appuntamento nuovo).
  final List<CalendarChoice> choices;

  /// Promemoria offerti (minuti prima; null = nessuno), come Outlook.
  static const reminders = <int?>[null, 0, 5, 10, 15, 30, 60, 120, 24 * 60, 7 * 24 * 60];
  static const defaultReminder = 15;

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  late final _summary = TextEditingController(text: widget.initial?.summary ?? '');
  late final _location = TextEditingController(text: widget.initial?.location ?? '');
  late final _notes = TextEditingController(text: widget.initial?.description ?? '');
  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  late int? _reminder = widget.initial == null ? AppointmentPage.defaultReminder : widget.initial!.reminderMinutes;
  late CalendarRecurrence? _recurrence = widget.initial?.recurrence;
  late final String? _custom = widget.initial?.customRecurrence;
  bool _recurrenceChanged = false;
  late String _account = widget.account;
  late String _calendarId = widget.calendarId;
  bool _saving = false;
  bool _closing = false;
  String? _error;
  late String _snapshot;

  bool get _isNew => widget.initial == null;
  bool get _readOnly => widget.readOnly && !_isNew;
  bool get _occurrence => widget.initial?.recurrenceId != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    if (d != null) {
      _allDay = d.allDay;
      _start = DateTime.parse(d.start);
      _end = DateTime.parse(d.end);
    } else {
      _allDay = widget.allDay;
      final now = CalendarModel.now();
      _start = widget.start ?? DateTime(now.year, now.month, now.day, now.hour + 1);
      _end = widget.end ?? (_allDay ? _start : _start.add(const Duration(hours: 1)));
    }
    _snapshot = _state();
  }

  @override
  void dispose() {
    _summary.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _state() => [_summary.text, _location.text, _notes.text, _start, _end, _allDay, _reminder, _recurrenceChanged,
    _account, _calendarId].join('|');

  bool get _dirty => _state() != _snapshot;

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _dateTime(DateTime d) => '${_date(d)}T${_two(d.hour)}:${_two(d.minute)}';

  Map<String, dynamic> _body() => {
    'summary': _summary.text.trim(),
    'location': _location.text.trim(),
    'description': _notes.text,
    'allDay': _allDay,
    'start': _allDay ? _date(_start) : _dateTime(_start),
    'end': _allDay ? _date(_end) : _dateTime(_end),
    if (!_allDay && widget.initial != null && widget.initial!.timeZone.isNotEmpty) 'timeZone': widget.initial!.timeZone,
    'reminderMinutes': _reminder,
    if (!_occurrence) 'keepRecurrence': !_isNew && !_recurrenceChanged,
    if (!_occurrence && (_isNew || _recurrenceChanged)) 'recurrence': _recurrence?.toJson(),
  };

  Future<bool> _save() async {
    if (_readOnly) return false;
    if (_end.isBefore(_start)) {
      setState(() => _error = context.l10n.endBeforeStart);
      return false;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final model = context.read<CalendarModel>();
    final client = model.api.forAccount(_account);
    try {
      final d = widget.initial;
      if (d == null) {
        await client.createCalendarEvent(_calendarId, _body());
      } else if (d.recurrenceId != null) {
        await client.updateCalendarOccurrence(_calendarId, d.id, d.recurrenceId!, _body());
      } else {
        await client.updateCalendarEvent(_calendarId, d.id, _body());
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.fieldErrors.values.firstOrNull?.firstOrNull ?? e.message;
        });
      }
      return false;
    }
    await model.changed(_account);
    if (!mounted) return false;
    setState(() {
      _saving = false;
      _closing = true;
    });
    Navigator.of(context).pop(true);
    return true;
  }

  Future<void> _delete() async {
    final d = widget.initial;
    if (d == null || _readOnly) return;
    final ok = await confirmDelete(context, occurrence: d.recurrenceId != null);
    if (ok != true || !mounted) return;
    final model = context.read<CalendarModel>();
    try {
      final client = model.api.forAccount(_account);
      d.recurrenceId != null
          ? await client.deleteCalendarOccurrence(_calendarId, d.id, d.recurrenceId!)
          : await client.deleteCalendarEvent(_calendarId, d.id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }
    await model.changed(_account);
    if (!mounted) return;
    setState(() => _closing = true);
    Navigator.of(context).pop(true);
  }

  /// «Eliminare l'appuntamento?» (scelta 4a, «Annulla» predefinito).
  static Future<bool?> confirmDelete(BuildContext context, {required bool occurrence}) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(occurrence ? context.l10n.deleteOccurrenceQuestion : context.l10n.deleteAppointmentQuestion),
      content: Text(occurrence ? context.l10n.deleteOccurrenceContent : context.l10n.deleteSeriesContent),
      actions: [
        TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.l10n.delete),
        ),
      ],
    ),
  );

  Future<bool?> _confirmSave() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.saveChangesQuestion),
      content: Text(context.l10n.appointmentNotSavedContent),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.no)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.yes)),
      ],
    ),
  );

  Future<void> _editRecurrence() async {
    final result = await showDialog<RecurrenceChoice>(
      context: context,
      builder: (_) => RecurrenceDialog(initial: _recurrence, start: _start),
    );
    if (result == null) return;
    setState(() {
      _recurrence = result.recurrence;
      _recurrenceChanged = true;
    });
  }

  /// Nuovo inizio: la fine si sposta con la stessa durata, come Outlook.
  void _setStart(DateTime value) {
    final length = _end.difference(_start);
    setState(() {
      _start = value;
      _end = value.add(length);
    });
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(2200),
  );

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppSettings>();
    final theme = Theme.of(context);
    final title = _summary.text.trim().isEmpty ? context.l10n.untitled : _summary.text.trim();
    return PopScope(
      canPop: _closing || !_dirty || _readOnly,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        final save = await _confirmSave();
        if (save == null || !context.mounted) return;
        if (save) {
          await _save();
          return;
        }
        setState(() => _closing = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).pop());
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            if (!_saving && !_readOnly) _save();
          },
          const SingleActivator(LogicalKeyboardKey.f1, control: true): () => settings.setRibbonCollapsed(!settings.ribbonCollapsed),
        },
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 36,
                color: theme.colorScheme.primary,
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_occurrence ? context.l10n.occurrence : context.l10n.appointment} - $title',
                        key: const Key('appointment-title'),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimary),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.closeEsc,
                      icon: Icon(FluentIcons.dismiss_20_regular, color: theme.colorScheme.onPrimary),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ],
                ),
              ),
              RibbonFrame(
                tabs: [_occurrence ? context.l10n.occurrence : context.l10n.appointment],
                selected: 0,
                onSelect: (_) {},
                groups: _groups(),
              ),
              if (_saving) const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _form(theme)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _groups() => _readOnly
      ? [
          RibbonGroup(
            label: context.l10n.groupActions,
            children: [
              RibbonLargeButton(
                key: const Key('appointment-close'),
                icon: FluentIcons.dismiss_24_regular,
                label: context.l10n.close,
                tooltip: context.l10n.closeEsc,
                onPressed: () => Navigator.maybePop(context),
              ),
            ],
          ),
        ]
      : [
    RibbonGroup(
      label: context.l10n.groupActions,
      children: [
        RibbonLargeButton(
          key: const Key('appointment-save'),
          icon: FluentIcons.save_24_regular,
          label: context.l10n.saveAndClose,
          tooltip: context.l10n.saveAndCloseTooltip,
          onPressed: _saving ? null : _save,
        ),
        if (!_isNew)
          RibbonLargeButton(
            key: const Key('appointment-delete'),
            icon: FluentIcons.delete_24_regular,
            label: context.l10n.delete,
            tooltip: _occurrence ? context.l10n.deleteOnlyOccurrenceTooltip : context.l10n.deleteAppointmentTooltip,
            onPressed: _saving ? null : _delete,
          ),
      ],
    ),
    RibbonGroup(
      label: context.l10n.groupOptions,
      children: [
        if (!_occurrence)
          RibbonLargeButton(
            key: const Key('appointment-recurrence'),
            icon: FluentIcons.arrow_repeat_all_24_regular,
            label: context.l10n.recurrence,
            tooltip: context.l10n.recurrenceTooltip,
            selected: _recurrence != null || (_custom != null && !_recurrenceChanged),
            onPressed: _saving ? null : _editRecurrence,
          ),
        PopupMenuButton<int>(
          key: const Key('appointment-reminder'),
          tooltip: context.l10n.reminder,
          onSelected: (m) => setState(() => _reminder = m < 0 ? null : m),
          itemBuilder: (_) => [
            for (final m in AppointmentPage.reminders)
              CheckedPopupMenuItem(value: m ?? -1, checked: m == _reminder, child: Text(_reminderLabel(context.l10n, m))),
          ],
          // Pulsante standard della barra (come «Sposta»): segue la barra classica e la semplificata. Prima era una
          // colonna fatta a mano, che nella barra semplificata (più bassa) traboccava di 2 px (16/11/2026).
          child: RibbonLargeButton(
            icon: FluentIcons.alert_24_regular,
            label: context.l10n.reminderValue(_reminderLabel(context.l10n, _reminder)),
            enabled: true,
          ),
        ),
      ],
    ),
  ];

  static String _reminderLabel(AppLocalizations l, int? minutes) => switch (minutes) {
    null => l.reminderNone,
    0 => l.reminderAtStart,
    final m when m % (7 * 24 * 60) == 0 => l.durationWeeks(m ~/ (7 * 24 * 60)),
    final m when m % (24 * 60) == 0 => l.durationDays(m ~/ (24 * 60)),
    final m when m % 60 == 0 => l.durationHours(m ~/ 60),
    final m => l.durationMinutes(m),
  };

  Widget _form(ThemeData theme) {
    Widget label(String text) => SizedBox(width: 90, child: Text(text, style: theme.textTheme.bodyMedium));
    Widget line(String text, Widget child) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [label(text), Expanded(child: child)]),
    );
    final recurrenceText = _recurrence?.describe() ??
        (_custom != null && !_recurrenceChanged ? context.l10n.customRecurrence(_custom) : null);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, key: const Key('appointment-error'), style: TextStyle(color: theme.colorScheme.error)),
          ),
        if (_readOnly)
          Padding(
            key: const Key('appointment-readonly'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(FluentIcons.lock_closed_16_regular, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.l10n.calendarReadOnly(context.read<CalendarModel>().calendarName(_account, _calendarId)),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        line(context.l10n.columnSubject, TextField(key: const Key('appointment-summary'), controller: _summary, readOnly: _readOnly, autofocus: _isNew, onChanged: (_) => setState(() {}))),
        line(context.l10n.location, TextField(key: const Key('appointment-location'), controller: _location, readOnly: _readOnly, onChanged: (_) => setState(() {}))),
        if (_isNew && widget.choices.length > 1)
          line(
            context.l10n.optionsPageCalendar,
            DropdownButton<String>(
              key: const Key('appointment-calendar'),
              isExpanded: true,
              value: '$_account|$_calendarId',
              items: [for (final c in widget.choices) DropdownMenuItem(value: '${c.account}|${c.calendarId}', child: Text(c.label))],
              onChanged: (v) {
                if (v == null) return;
                final i = v.indexOf('|');
                setState(() {
                  _account = v.substring(0, i);
                  _calendarId = v.substring(i + 1);
                });
              },
            ),
          ),
        line(context.l10n.startTime, _dateTimeRow('start', _start, (d) => _setStart(d))),
        line(context.l10n.endTime, _dateTimeRow('end', _end, (d) => setState(() => _end = d))),
        Padding(
          padding: const EdgeInsets.only(left: 90),
          child: CheckboxListTile(
            key: const Key('appointment-all-day'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(context.l10n.allDayEvent),
            value: _allDay,
            onChanged: _readOnly ? null : (v) => setState(() {
              _allDay = v ?? false;
              if (_allDay) {
                _start = DateTime(_start.year, _start.month, _start.day);
                _end = DateTime(_end.year, _end.month, _end.day);
              } else {
                _start = DateTime(_start.year, _start.month, _start.day, 9);
                _end = DateTime(_end.year, _end.month, _end.day, 10);
              }
            }),
          ),
        ),
        if (recurrenceText != null)
          Padding(
            padding: const EdgeInsets.only(left: 90, bottom: 8),
            child: Row(
              children: [
                const Icon(FluentIcons.arrow_repeat_all_16_regular, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(context.l10n.recurrenceValue(recurrenceText), key: const Key('appointment-recurrence-text'))),
              ],
            ),
          ),
        if (_occurrence)
          Padding(
            padding: const EdgeInsets.only(left: 90, bottom: 8),
            child: Text(context.l10n.onlyThisOccurrenceHint, style: theme.textTheme.bodySmall),
          ),
        const Divider(),
        TextField(
          key: const Key('appointment-notes'),
          controller: _notes,
          readOnly: _readOnly,
          maxLines: null,
          minLines: 8,
          decoration: InputDecoration(hintText: context.l10n.notes, border: InputBorder.none),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  /// Data (finestra del calendario) e, se non è giornata intera, ora a passi di mezz'ora come Outlook.
  Widget _dateTimeRow(String key, DateTime value, ValueChanged<DateTime> onChanged) {
    final slots = [for (var m = 0; m < 24 * 60; m += 30) m];
    final minutes = value.hour * 60 + value.minute;
    if (!slots.contains(minutes)) {
      slots
        ..add(minutes)
        ..sort();
    }
    return Row(
      children: [
        OutlinedButton.icon(
          key: Key('appointment-$key-date'),
          icon: const Icon(FluentIcons.calendar_20_regular, size: 18),
          label: Text(formatWeekdayDate(value)),
          onPressed: _readOnly ? null : () async {
            final d = await _pickDate(value);
            if (d != null) onChanged(DateTime(d.year, d.month, d.day, value.hour, value.minute));
          },
        ),
        const SizedBox(width: 12),
        if (!_allDay)
          DropdownButton<int>(
            key: Key('appointment-$key-time'),
            value: minutes,
            items: [for (final m in slots) DropdownMenuItem(value: m, child: Text(formatMinutes(m)))],
            onChanged: _readOnly ? null : (m) {
              if (m != null) onChanged(DateTime(value.year, value.month, value.day, m ~/ 60, m % 60));
            },
          ),
      ],
    );
  }
}

/// Esito della finestra Ricorrenza: la regola scelta, o null = «Rimuovi ricorrenza».
class RecurrenceChoice {
  const RecurrenceChoice(this.recurrence);

  final CalendarRecurrence? recurrence;
}

/// Finestra «Ricorrenza appuntamento» come Outlook: tipo (giornaliera, settimanale, mensile, annuale), ogni quanto, giorni,
/// e la fine (nessuna, dopo N occorrenze, entro una data).
class RecurrenceDialog extends StatefulWidget {
  const RecurrenceDialog({super.key, required this.initial, required this.start});

  final CalendarRecurrence? initial;
  final DateTime start;

  @override
  State<RecurrenceDialog> createState() => _RecurrenceDialogState();
}

class _RecurrenceDialogState extends State<RecurrenceDialog> {
  static const _codes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  static Map<int, String> _weekNames(AppLocalizations l) =>
      {1: l.weekFirst, 2: l.weekSecond, 3: l.weekThird, 4: l.weekFourth, -1: l.weekLast};

  late String _frequency;
  late final _interval = TextEditingController();
  late Set<String> _days;
  bool _weekdays = false; // giornaliera «ogni giorno feriale»
  bool _byWeek = false; // mensile/annuale «il primo lunedì»
  late int _monthDay;
  late int _week;
  late String _weekDay;
  late int _month;
  String _end = 'none';
  late final _count = TextEditingController(text: '10');
  late DateTime _until;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    final start = widget.start;
    final startCode = _codes[start.weekday - 1];
    _frequency = r?.frequency ?? 'weekly';
    _interval.text = '${r?.interval ?? 1}';
    _days = {...?r?.days};
    if (_days.isEmpty) _days = {startCode};
    if (r != null && r.frequency == 'weekly' && r.interval == 1 && _days.length == 5 && !_days.contains('SA') && !_days.contains('SU')) {
      _frequency = 'daily';
      _weekdays = true;
    }
    _byWeek = r?.week != null;
    _monthDay = r?.monthDay ?? start.day;
    _week = r?.week ?? ((start.day - 1) ~/ 7 + 1).clamp(1, 4);
    _weekDay = r?.week != null && r!.days.isNotEmpty ? r.days.first : startCode;
    _month = r?.month ?? start.month;
    if (r?.count != null) {
      _end = 'count';
      _count.text = '${r!.count}';
    } else if (r?.until != null) {
      _end = 'until';
    }
    _until = DateTime.tryParse(r?.until ?? '') ?? DateTime(start.year, start.month + 3, start.day);
  }

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  CalendarRecurrence? _build() {
    final interval = int.tryParse(_interval.text.trim()) ?? 0;
    if (interval < 1 || interval > 999) {
      setState(() => _error = context.l10n.recurrenceBadInterval);
      return null;
    }
    int? count;
    String? until;
    if (_end == 'count') {
      count = int.tryParse(_count.text.trim());
      if (count == null || count < 1 || count > 999) {
        setState(() => _error = context.l10n.recurrenceBadCount);
        return null;
      }
    } else if (_end == 'until') {
      until = '${_until.year}-${_until.month.toString().padLeft(2, '0')}-${_until.day.toString().padLeft(2, '0')}';
    }
    switch (_frequency) {
      case 'daily':
        return _weekdays
            ? CalendarRecurrence(frequency: 'weekly', days: _codes.take(5).toList(), count: count, until: until)
            : CalendarRecurrence(frequency: 'daily', interval: interval, count: count, until: until);
      case 'weekly':
        if (_days.isEmpty) {
          setState(() => _error = context.l10n.recurrenceNoDays);
          return null;
        }
        return CalendarRecurrence(
          frequency: 'weekly', interval: interval, days: [for (final c in _codes) if (_days.contains(c)) c], count: count, until: until);
      case 'monthly':
        return _byWeek
            ? CalendarRecurrence(frequency: 'monthly', interval: interval, week: _week, days: [_weekDay], count: count, until: until)
            : CalendarRecurrence(frequency: 'monthly', interval: interval, monthDay: _monthDay, count: count, until: until);
      default:
        return _byWeek
            ? CalendarRecurrence(frequency: 'yearly', week: _week, days: [_weekDay], month: _month, count: count, until: until)
            : CalendarRecurrence(frequency: 'yearly', monthDay: _monthDay, month: _month, count: count, until: until);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget number(TextEditingController c, Key key) => SizedBox(
      width: 56,
      child: TextField(key: key, controller: c, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(isDense: true)),
    );
    DropdownButton<int> weekPicker() => DropdownButton<int>(
      value: _week,
      items: [for (final e in _weekNames(context.l10n).entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) => setState(() => _week = v ?? _week),
    );
    DropdownButton<String> dayPicker() => DropdownButton<String>(
      value: _weekDay,
      items: [for (final (i, c) in _codes.indexed) DropdownMenuItem(value: c, child: Text(CalendarModel.weekdayName(i + 1)))],
      onChanged: (v) => setState(() => _weekDay = v ?? _weekDay),
    );
    DropdownButton<int> monthPicker() => DropdownButton<int>(
      value: _month,
      items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(CalendarModel.monthName(m)))],
      onChanged: (v) => setState(() => _month = v ?? _month),
    );
    DropdownButton<int> monthDayPicker() => DropdownButton<int>(
      value: _monthDay,
      items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d'))],
      onChanged: (v) => setState(() => _monthDay = v ?? _monthDay),
    );
    // Scelta a pallino (come i pulsanti di opzione di Outlook) senza Radio, la cui API con groupValue è deprecata.
    // Tutta la riga sceglie l'opzione (anche il testo), come in Outlook.
    Widget option(bool selected, VoidCallback onTap, List<Widget> children) => InkWell(
      onTap: onTap,
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            isSelected: selected,
            icon: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
            onPressed: onTap,
          ),
          ...children,
        ],
      ),
    );
    final l = context.l10n;
    final interval = number(_interval, const Key('rec-interval'));
    final pattern = switch (_frequency) {
      'daily' => [
        option(!_weekdays, () => setState(() => _weekdays = false), fillTemplate(l.recurEveryNDays, {'n': interval})),
        option(_weekdays, () => setState(() => _weekdays = true), [Text(l.recurEveryWeekday)]),
      ],
      'weekly' => [
        Row(children: fillTemplate(l.recurEveryNWeeksOn, {'n': interval})),
        Wrap(
          spacing: 4,
          children: [
            for (final (i, c) in _codes.indexed)
              FilterChip(
                key: Key('rec-day-$c'),
                label: Text(CalendarModel.weekdayShort(i + 1)),
                selected: _days.contains(c),
                onSelected: (on) => setState(() => on ? _days.add(c) : _days.remove(c)),
              ),
          ],
        ),
      ],
      'monthly' => [
        option(!_byWeek, () => setState(() => _byWeek = false),
            fillTemplate(l.recurMonthlyDay, {'day': monthDayPicker(), 'n': interval})),
        option(_byWeek, () => setState(() => _byWeek = true),
            fillTemplate(l.recurMonthlyWeekday, {'week': weekPicker(), 'weekday': dayPicker()})),
      ],
      _ => [
        option(!_byWeek, () => setState(() => _byWeek = false), fillTemplate(l.recurYearlyDay, {'day': monthDayPicker(), 'month': monthPicker()})),
        option(_byWeek, () => setState(() => _byWeek = true),
            fillTemplate(l.recurYearlyWeekday, {'week': weekPicker(), 'weekday': dayPicker(), 'month': monthPicker()})),
      ],
    };
    return AlertDialog(
      key: const Key('recurrence-dialog'),
      title: Text(l.appointmentRecurrence),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.recurrencePattern, style: theme.textTheme.titleSmall),
            SegmentedButton<String>(
              key: const Key('rec-frequency'),
              segments: [
                ButtonSegment(value: 'daily', label: Text(l.recurDaily)),
                ButtonSegment(value: 'weekly', label: Text(l.recurWeekly)),
                ButtonSegment(value: 'monthly', label: Text(l.recurMonthly)),
                ButtonSegment(value: 'yearly', label: Text(l.recurYearly)),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) => setState(() => _frequency = s.first),
            ),
            const SizedBox(height: 8),
            ...pattern,
            const Divider(),
            Text(l.recurrenceRange, style: theme.textTheme.titleSmall),
            option(_end == 'none', () => setState(() => _end = 'none'), [Text(l.recurNoEnd)]),
            option(_end == 'count', () => setState(() => _end = 'count'),
                fillTemplate(l.recurEndAfter, {'n': number(_count, const Key('rec-count'))})),
            option(_end == 'until', () => setState(() => _end = 'until'), fillTemplate(l.recurEndBy, {
              'date': TextButton(
                key: const Key('rec-until'),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _until, firstDate: widget.start, lastDate: DateTime(2200));
                  if (d != null) setState(() => _until = d);
                },
                child: Text(formatDate(_until)),
              ),
            })),
            if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        if (widget.initial != null)
          TextButton(
            key: const Key('rec-remove'),
            onPressed: () => Navigator.pop(context, const RecurrenceChoice(null)),
            child: Text(l.removeRecurrence),
          ),
        FilledButton(
          key: const Key('rec-ok'),
          onPressed: () {
            final r = _build();
            if (r != null) Navigator.pop(context, RecurrenceChoice(r));
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
