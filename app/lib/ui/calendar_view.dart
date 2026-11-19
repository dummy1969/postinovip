import 'dart:async';
import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';
import '../l10n/language.dart';
import '../models/calendar.dart';
import '../settings/app_settings.dart';
import '../state/calendar_model.dart';
import '../state/mailbox_model.dart';
import 'appointment_page.dart';
import 'home_page.dart';
import 'module_bar.dart';
import 'people_view.dart';
import 'ribbon_parts.dart';
import 'keys.dart';

/// Colori dei calendari (K3, scelta 3a): tinte della palette condivisa di Fluent, leggibili su temi chiari e scuri.
class CalendarColors {
  CalendarColors._();

  static const colors = [
    Color(0xFF0078D4), // blu
    Color(0xFF13A10E), // verde
    Color(0xFFCA5010), // arancione
    Color(0xFF8764B8), // viola
    Color(0xFF038387), // verde acqua
    Color(0xFFE3008C), // rosa
    Color(0xFFC19C00), // oro
    Color(0xFF69797E), // grigio
  ];
  static List<String> names(AppLocalizations l) =>
      [l.colorBlue, l.colorGreen, l.colorOrange, l.colorPurple, l.colorTeal, l.colorPink, l.colorGold, l.colorGray];

  static Color of(int index) => colors[index % colors.length];
}

/// Comandi del Calendario, comuni a barra multifunzione e scorciatoie.
class CalendarActions {
  CalendarActions._();

  static String bookLabel(MailboxModel mail, String account) {
    final info = mail.accounts.where((a) => a.id == account).firstOrNull;
    return info?.name ?? account;
  }

  static String time(DateTime t) => formatTime(t);
  static String date(DateTime d) => formatWeekdayDate(d);

  /// «lun 09/11/2026 09:00 – 10:00», «da lun 09/11 a mer 11/11 (giornata intera)».
  static String when(CalendarOccurrence o) {
    final l = formatL10n;
    if (o.allDay) {
      return o.start == o.end ? l.whenAllDay(date(o.start)) : l.whenAllDayRange(date(o.start), date(o.end));
    }
    final sameDay = o.start.year == o.end.year && o.start.month == o.end.month && o.start.day == o.end.day;
    return sameDay ? '${date(o.start)} ${time(o.start)} – ${time(o.end)}' : '${date(o.start)} ${time(o.start)} – ${date(o.end)} ${time(o.end)}';
  }

  /// Calendari in cui creare un appuntamento (menu «Calendario» della finestra), il predefinito del primo account per primo;
  /// mai quelli di sola lettura (G3, 2a).
  static List<CalendarChoice> choices(BuildContext context) {
    final model = context.read<CalendarModel>();
    final mail = context.read<MailboxModel>();
    return [
      for (final a in model.accounts)
        for (final c in model.calendars[a.id] ?? const <CalendarInfo>[])
          if (!c.readOnly) CalendarChoice(a.id, c.id, mail.multipleAccounts ? '${c.name} - ${bookLabel(mail, a.id)}' : c.name),
    ];
  }

  /// Nuovo appuntamento (scelta 2a): dall'ora successiva per un'ora, o nello spazio/giorno indicato.
  static Future<void> newAppointment(BuildContext context, {DateTime? start, DateTime? end, bool allDay = false}) async {
    final list = choices(context);
    if (list.isEmpty) return;
    final first = list.first;
    await Navigator.of(context).push(MaterialPageRoute<bool>(
      builder: (_) => AppointmentPage(account: first.account, calendarId: first.calendarId, start: start, end: end, allDay: allDay, choices: list),
    ));
  }

  /// «Aprire solo questa occorrenza o tutta la serie?» (scelta 3a). null = Annulla.
  static Future<bool?> askOccurrence(BuildContext context, {required bool delete}) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(delete ? context.l10n.deleteRecurringTitle : context.l10n.openRecurringTitle),
      content: Text(delete ? context.l10n.deleteRecurringQuestion : context.l10n.openRecurringQuestion),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
        TextButton(key: const Key('choose-series'), onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.entireSeries)),
        FilledButton(key: const Key('choose-occurrence'), autofocus: true, onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.justThisOne)),
      ],
    ),
  );

  /// Doppio clic: la finestra Appuntamento (per un ricorrente, prima «solo questa o la serie»).
  static Future<void> open(BuildContext context, CalendarOccurrence o) async {
    final model = context.read<CalendarModel>();
    model.select(o.key);
    var occurrence = false;
    if (o.recurring && o.recurrenceId != null) {
      final choice = await askOccurrence(context, delete: false);
      if (choice == null || !context.mounted) return;
      occurrence = choice;
    }
    final CalendarEventDetail detail;
    try {
      final client = model.api.forAccount(o.account);
      detail = occurrence
          ? await client.getCalendarOccurrence(o.calendarId, o.eventId, o.recurrenceId!)
          : await client.getCalendarEvent(o.calendarId, o.eventId);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.appointmentNotAvailable(e.message))));
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<bool>(
      builder: (_) => AppointmentPage(
        account: o.account,
        calendarId: o.calendarId,
        initial: detail,
        readOnly: model.isReadOnly(o.account, o.calendarId),
      ),
    ));
  }

  /// Elimina l'appuntamento selezionato (Canc), con conferma (scelta 4a) e, se ricorrente, «solo questa o la serie».
  static Future<void> deleteSelected(BuildContext context) async {
    final model = context.read<CalendarModel>();
    final o = model.selected;
    if (o == null || model.isReadOnly(o.account, o.calendarId)) return; // sola lettura (G3): Canc non fa nulla
    var occurrence = false;
    if (o.recurring && o.recurrenceId != null) {
      final choice = await askOccurrence(context, delete: true);
      if (choice == null || !context.mounted) return;
      occurrence = choice;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.deleteAppointmentQuestion),
          content: Text(context.l10n.deleteAppointmentContent(o.title)),
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
      if (ok != true || !context.mounted) return;
    }
    try {
      final client = model.api.forAccount(o.account);
      occurrence
          ? await client.deleteCalendarOccurrence(o.calendarId, o.eventId, o.recurrenceId!)
          : await client.deleteCalendarEvent(o.calendarId, o.eventId);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.appointmentNotDeleted(e.message))));
      return;
    }
    model.select(null);
    await model.changed(o.account);
  }

  /// Conferma della prima volta: **modifica i calendari del server**.
  static Future<void> confirmUpload(BuildContext context, String account) async {
    final model = context.read<CalendarModel>();
    final n = model.statusOf(account).pendingUpload;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.uploadAppointmentsQuestion),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(context.l10n.uploadAppointmentsContent(n)),
        ),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.uploadToServer)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await model.confirmUpload(account);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.appointmentsNotUploaded(e.message))));
      }
    }
  }

  /// Gruppi della scheda Home nel Calendario (scelta 1a).
  static List<Widget> ribbonGroups(BuildContext context) {
    final model = context.watch<CalendarModel>();
    final mail = context.watch<MailboxModel>();
    RibbonLargeButton view(CalendarViewKind kind, IconData icon, String shortcut) => RibbonLargeButton(
      key: Key('calendar-view-${kind.name}'),
      icon: icon,
      label: kind.label(context.l10n),
      tooltip: '${kind.label(context.l10n)} ($shortcut)',
      selected: model.view == kind && !(kind == CalendarViewKind.week && model.sevenDays),
      onPressed: () => model.setView(kind),
    );
    return [
      RibbonGroup(
        label: context.l10n.groupNew,
        children: [
          RibbonLargeButton(
            key: const Key('calendar-new'),
            icon: FluentIcons.calendar_add_24_regular,
            label: context.l10n.newAppointment,
            tooltip: keyLabel(context.l10n.newAppointmentTooltip),
            onPressed: model.calendars.values.any((l) => l.any((c) => !c.readOnly)) ? () => newAppointment(context) : null,
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.delete,
        children: [
          RibbonLargeButton(
            key: const Key('calendar-delete'),
            icon: FluentIcons.delete_24_regular,
            label: context.l10n.delete,
            tooltip: keyLabel(context.l10n.deleteSelectedAppointmentTooltip),
            onPressed: model.selected != null && !model.isReadOnly(model.selected!.account, model.selected!.calendarId)
                ? () => deleteSelected(context)
                : null,
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.groupGoTo,
        children: [
          RibbonLargeButton(
            icon: FluentIcons.calendar_today_24_regular,
            label: context.l10n.today,
            tooltip: context.l10n.todayTooltip,
            onPressed: model.goToday,
          ),
          RibbonLargeButton(
            icon: FluentIcons.calendar_week_numbers_24_regular,
            label: context.l10n.next7Days,
            tooltip: context.l10n.next7DaysTooltip,
            selected: model.sevenDays,
            onPressed: model.showNextSevenDays,
          ),
        ],
      ),
      RibbonGroup(
        label: context.l10n.groupArrange,
        children: [
          view(CalendarViewKind.day, FluentIcons.calendar_day_24_regular, keyLabel('Ctrl+Alt+1')),
          view(CalendarViewKind.workWeek, FluentIcons.calendar_work_week_24_regular, keyLabel('Ctrl+Alt+2')),
          view(CalendarViewKind.week, FluentIcons.calendar_week_start_24_regular, keyLabel('Ctrl+Alt+3')),
          view(CalendarViewKind.month, FluentIcons.calendar_month_24_regular, keyLabel('Ctrl+Alt+4')),
        ],
      ),
      if (mail.accounts.any((a) => a.calDav))
        RibbonGroup(
          label: context.l10n.groupSync,
          children: [
            RibbonLargeButton(
              icon: FluentIcons.arrow_sync_24_regular,
              label: context.l10n.sync,
              tooltip: context.l10n.syncCalendarsTooltip,
              onPressed: model.syncNow,
            ),
          ],
        ),
    ];
  }
}

/// Vista Calendario (K3, scelta 1a): a sinistra calendarietto e «I miei calendari», al centro la vista scelta.
class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final model = context.watch<CalendarModel>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: settings.folderPaneWidth, child: const _CalendarsPane()),
        PaneDivider(
          axis: Axis.horizontal,
          onDrag: (delta, {required save}) =>
              settings.setPaneLayout(folderWidth: settings.folderPaneWidth + delta, save: save),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final a in model.accounts) ...[
                if (model.statusOf(a.id).needsConfirmation) _UploadStrip(account: a.id),
                if (ReloginStrip.needed(context, a.id, model.statusOf(a.id))) ReloginStrip(account: a.id, calendar: true),
              ],
              const _Header(),
              if (model.loading) const LinearProgressIndicator(minHeight: 2),
              if (!model.loading && model.error == null && model.visibleOccurrences.isEmpty) const _EmptyHint(),
              if (model.error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(context.l10n.appointmentsNotAvailable('${model.error}'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Expanded(
                child: model.view == CalendarViewKind.month ? const MonthGrid() : const TimeGrid(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UploadStrip extends StatelessWidget {
  const _UploadStrip({required this.account});

  final String account;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CalendarModel>();
    final n = model.statusOf(account).pendingUpload;
    final name = CalendarActions.bookLabel(context.watch<MailboxModel>(), account);
    return Container(
      key: Key('caldav-upload-strip:$account'),
      color: const Color(0xFFFFF4CE),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          const Icon(FluentIcons.info_16_regular, size: 16, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.uploadStrip(name, n),
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          TextButton(onPressed: () => CalendarActions.confirmUpload(context, account), child: Text(context.l10n.uploadToServerEllipsis)),
        ],
      ),
    );
  }
}

/// Nessun appuntamento nel periodo: lo si dice, e si spiega come vedere quelli del server o crearne di nuovi.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CalendarModel>();
    final theme = Theme.of(context);
    final synced = model.accounts.any((a) => model.statusOf(a.id).enabled);
    return Container(
      key: const Key('calendar-empty-hint'),
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.info_16_regular, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.calendarEmpty + (synced ? '' : context.l10n.calendarEmptySyncHint) + keyLabel(context.l10n.calendarEmptyCreate),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CalendarModel>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('calendar-prev'),
            tooltip: context.l10n.previous,
            icon: const Icon(FluentIcons.chevron_left_20_regular),
            onPressed: () => model.move(-1),
          ),
          IconButton(
            key: const Key('calendar-next'),
            tooltip: context.l10n.next,
            icon: const Icon(FluentIcons.chevron_right_20_regular),
            onPressed: () => model.move(1),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(model.title, key: const Key('calendar-title'), style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- riquadro di sinistra

class _CalendarsPane extends StatelessWidget {
  const _CalendarsPane();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CalendarModel>();
    final mail = context.watch<MailboxModel>();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MiniMonth(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(context.l10n.myCalendars, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final a in model.accounts) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(CalendarActions.bookLabel(mail, a.id), style: theme.textTheme.labelLarge, overflow: TextOverflow.ellipsis),
                  ),
                  if (!model.statusOf(a.id).enabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                      child: Tooltip(
                        message: context.l10n.localOnlyTooltip,
                        child: Text(
                          context.l10n.localOnly,
                          key: Key('calendar-local-only:${a.id}'),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  if (PeopleActions.syncLabel(context.l10n, model.statusOf(a.id)) case final sync?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                      child: Text(
                        sync.text,
                        key: Key('calendar-sync-status:${a.id}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: sync.error ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final c in model.calendars[a.id] ?? const <CalendarInfo>[]) _CalendarRow(account: a.id, calendar: c),
                ],
              ],
            ),
          ),
          ...ModuleBar.bottomOf(context),
        ],
      ),
    );
  }
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow({required this.account, required this.calendar});

  final String account;
  final CalendarInfo calendar;

  Future<void> _menu(BuildContext context, Offset position) async {
    final model = context.read<CalendarModel>();
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final chosen = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        PopupMenuItem<int>(enabled: false, child: Text(context.l10n.color)),
        for (final (i, name) in CalendarColors.names(context.l10n).indexed)
          PopupMenuItem(
            key: Key('calendar-color-$i'),
            value: i,
            child: Row(
              children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(color: CalendarColors.of(i), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Text(name),
                if (model.colorIndex(account, calendar.id) % CalendarColors.colors.length == i) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          ),
      ],
    );
    if (chosen != null) await model.setColor(account, calendar.id, chosen);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CalendarModel>();
    final color = CalendarColors.of(model.colorIndex(account, calendar.id));
    final visible = model.isVisible(account, calendar.id);
    return GestureDetector(
      onSecondaryTapUp: (d) => _menu(context, d.globalPosition),
      child: CheckboxListTile(
        key: Key('calendar:$account:${calendar.id}'),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: color,
        side: BorderSide(color: color, width: 2),
        value: visible,
        onChanged: (v) => model.setVisible(account, calendar.id, v ?? true),
        title: Text(calendar.name, overflow: TextOverflow.ellipsis),
        secondary: calendar.readOnly
            ? Tooltip(
                message: context.l10n.calendarReadOnlyTooltip,
                child: const Icon(FluentIcons.lock_closed_16_regular, key: Key('calendar-readonly'), size: 16),
              )
            : calendar.synced
            ? Tooltip(message: context.l10n.syncedWithServer, child: const Icon(FluentIcons.cloud_16_regular, size: 16))
            : null,
      ),
    );
  }
}

/// Calendarietto del mese (scelta 1a): frecce per il mese, clic su un giorno per andarci.
class MiniMonth extends StatefulWidget {
  const MiniMonth({super.key});

  @override
  State<MiniMonth> createState() => _MiniMonthState();
}

class _MiniMonthState extends State<MiniMonth> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CalendarModel>();
    final theme = Theme.of(context);
    final shown = _month ?? DateTime(model.anchor.year, model.anchor.month);
    final start = model.weekStart(DateTime(shown.year, shown.month, 1));
    final today = CalendarModel.now();
    final selected = model.days.toSet();
    final first = model.prefs.firstDay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: context.l10n.previousMonth,
                icon: const Icon(FluentIcons.chevron_left_16_regular, size: 16),
                onPressed: () => setState(() => _month = DateTime(shown.year, shown.month - 1)),
              ),
              Expanded(
                child: Text(formatMonthYear(shown), textAlign: TextAlign.center,
                    key: const Key('mini-month-title'), style: theme.textTheme.titleSmall),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: context.l10n.nextMonth,
                icon: const Icon(FluentIcons.chevron_right_16_regular, size: 16),
                onPressed: () => setState(() => _month = DateTime(shown.year, shown.month + 1)),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(CalendarModel.weekdayShort((first - 1 + i) % 7 + 1).substring(0, 2), textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
            ],
          ),
          for (var w = 0; w < 6; w++)
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final d = DateTime(start.year, start.month, start.day + w * 7 + i);
                      final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
                      final inMonth = d.month == shown.month;
                      return InkWell(
                        key: Key('mini-day:${d.year}-${d.month}-${d.day}'),
                        onTap: () {
                          setState(() => _month = null);
                          model.goTo(d);
                        },
                        child: Container(
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected.contains(d) ? theme.colorScheme.primary.withValues(alpha: 0.15) : null,
                            border: isToday ? Border.all(color: theme.colorScheme.primary, width: 1.5) : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${d.day}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: inMonth ? null : theme.colorScheme.outline,
                              fontWeight: isToday ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- appuntamenti

/// Un appuntamento nella vista: colore del calendario, oggetto, ora; clic seleziona, doppio clic apre la scheda.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.occurrence, this.compact = false});

  final CalendarOccurrence occurrence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CalendarModel>();
    final o = occurrence;
    final color = CalendarColors.of(model.colorIndex(o.account, o.calendarId));
    final selected = model.selectedKey == o.key;
    final theme = Theme.of(context);
    final label = o.allDay || compact ? o.title : '${CalendarActions.time(o.start)} ${o.title}';
    return Tooltip(
      message: [o.title, CalendarActions.when(o), ?o.location, model.calendarName(o.account, o.calendarId)].join('\n'),
      waitDuration: const Duration(milliseconds: 600),
      child: GestureDetector(
        key: Key('event:${o.key}'),
        onTap: () => model.select(o.key),
        onDoubleTap: () => CalendarActions.open(context, o),
        child: Container(
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Color.alphaBlend(color.withValues(alpha: 0.22), theme.colorScheme.surface),
            border: Border(
              left: BorderSide(color: color, width: 4),
              top: BorderSide(color: selected ? theme.colorScheme.onSurface : Colors.transparent),
              right: BorderSide(color: selected ? theme.colorScheme.onSurface : Colors.transparent),
              bottom: BorderSide(color: selected ? theme.colorScheme.onSurface : Colors.transparent),
            ),
          ),
          child: Text(
            label + (o.recurring ? ' ⟳' : ''),
            maxLines: compact ? 1 : 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Viste Giorno e Settimana: righe da mezz'ora, orario lavorativo evidenziato, giornata intera in alto (scelte 1a, 2b).
class TimeGrid extends StatefulWidget {
  const TimeGrid({super.key});

  static const hourHeight = 48.0;
  static const labelWidth = 52.0;

  @override
  State<TimeGrid> createState() => _TimeGridState();
}

class _TimeGridState extends State<TimeGrid> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: context.read<CalendarModel>().prefs.workStart / 60 * TimeGrid.hourHeight,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CalendarModel>();
    final theme = Theme.of(context);
    final days = model.days;
    final events = model.visibleOccurrences;
    bool banner(CalendarOccurrence o) => o.allDay || o.end.difference(o.start) >= const Duration(hours: 24);
    final today = CalendarModel.now();
    bool isToday(DateTime d) => d.year == today.year && d.month == today.month && d.day == today.day;
    final allDay = [for (final d in days) events.where((o) => banner(o) && o.touches(d)).toList()];
    final maxAllDay = allDay.fold<int>(0, (m, l) => math.max(m, l.length));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // intestazione dei giorni
        Row(
          children: [
            const SizedBox(width: TimeGrid.labelWidth),
            for (final d in days)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant))),
                  child: Text(
                    '${CalendarModel.weekdayShort(d.weekday)} ${d.day}',
                    key: Key('day-header:${d.year}-${d.month}-${d.day}'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isToday(d) ? theme.colorScheme.primary : null,
                      fontWeight: isToday(d) ? FontWeight.bold : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // giornata intera
        if (maxAllDay > 0)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: TimeGrid.labelWidth),
              for (final list in allDay)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant))),
                    child: Column(children: [for (final o in list) EventTile(occurrence: o, compact: true)]),
                  ),
                ),
            ],
          ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('time-grid'),
            controller: _scroll,
            child: SizedBox(
              height: 24 * TimeGrid.hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: TimeGrid.labelWidth,
                    child: Stack(
                      children: [
                        for (var h = 1; h < 24; h++)
                          Positioned(
                            top: h * TimeGrid.hourHeight - 7,
                            right: 6,
                            child: Text(formatHour(h), style: theme.textTheme.labelSmall),
                          ),
                      ],
                    ),
                  ),
                  for (final d in days)
                    Expanded(
                      child: _DayColumn(
                        day: d,
                        events: [for (final o in events) if (!banner(o) && o.touches(d)) o],
                        work: model.prefs.workDays.contains(d.weekday),
                        workStart: model.prefs.workStart,
                        workEnd: model.prefs.workEnd,
                        today: isToday(d),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.events,
    required this.work,
    required this.workStart,
    required this.workEnd,
    required this.today,
  });

  final DateTime day;
  final List<CalendarOccurrence> events;
  final bool work;
  final int workStart;
  final int workEnd;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const h = TimeGrid.hourHeight;
    final dayStart = DateTime(day.year, day.month, day.day);
    double minutesOf(DateTime t) => t.isBefore(dayStart)
        ? 0
        : math.min(24 * 60, t.difference(dayStart).inMinutes).toDouble();
    final layout = layoutDay(events, dayStart);
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      final now = CalendarModel.now();
      return Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant))),
        child: Stack(
          children: [
            // Doppio clic su uno spazio vuoto: nuovo appuntamento di mezz'ora... un'ora da lì (scelta 2a).
            Positioned.fill(
              child: _EmptySlot(day: dayStart),
            ),
            if (work)
              Positioned(
                top: workStart / 60 * h,
                height: (workEnd - workStart) / 60 * h,
                left: 0,
                right: 0,
                // IgnorePointer: lo sfondo (ColoredBox è «opaco» ai clic) non deve togliere il doppio clic allo spazio vuoto
                child: IgnorePointer(child: ColoredBox(color: theme.colorScheme.primary.withValues(alpha: 0.05))),
              ),
            for (var i = 1; i < 48; i++)
              Positioned(
                top: i * h / 2,
                left: 0,
                right: 0,
                child: IgnorePointer(child: Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: i.isEven ? 0.9 : 0.4))),
              ),
            for (final (o, column, columns) in layout)
              Positioned(
                top: minutesOf(o.start) / 60 * h,
                height: math.max(h / 2 - 2, (minutesOf(o.end) - minutesOf(o.start)) / 60 * h),
                left: width * column / columns,
                width: width / columns,
                child: EventTile(occurrence: o),
              ),
            if (today) ...[
              Positioned(
                top: (now.hour * 60 + now.minute) / 60 * h,
                left: 0,
                right: 0,
                child: Tooltip(
                  message: context.l10n.nowAt(CalendarActions.time(now)),
                  child: Container(key: const Key('now-line'), height: 2, color: theme.colorScheme.error),
                ),
              ),
              Positioned(
                top: (now.hour * 60 + now.minute) / 60 * h - 4,
                left: -1,
                child: Container(width: 10, height: 10, decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle)),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Spazio vuoto di un giorno nella griglia: il doppio clic crea un appuntamento di un'ora alla mezz'ora cliccata.
class _EmptySlot extends StatefulWidget {
  const _EmptySlot({required this.day});

  final DateTime day;

  @override
  State<_EmptySlot> createState() => _EmptySlotState();
}

class _EmptySlotState extends State<_EmptySlot> {
  double _y = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: Key('slot:${widget.day.year}-${widget.day.month}-${widget.day.day}'),
    behavior: HitTestBehavior.translucent,
    onDoubleTapDown: (d) => _y = d.localPosition.dy,
    onDoubleTap: () {
      final half = (_y / (TimeGrid.hourHeight / 2)).floor().clamp(0, 47);
      final start = DateTime(widget.day.year, widget.day.month, widget.day.day).add(Duration(minutes: half * 30));
      CalendarActions.newAppointment(context, start: start, end: start.add(const Duration(hours: 1)));
    },
  );
}

/// Colonne degli appuntamenti sovrapposti di un giorno: (occorrenza, colonna, colonne del gruppo), come Outlook.
List<(CalendarOccurrence, int, int)> layoutDay(List<CalendarOccurrence> events, DateTime dayStart) {
  final sorted = [...events]..sort((a, b) {
    final c = a.start.compareTo(b.start);
    return c != 0 ? c : b.end.compareTo(a.end);
  });
  DateTime endOf(CalendarOccurrence o) {
    // un appuntamento di durata zero occupa comunque mezz'ora sulla griglia
    final min = o.start.add(const Duration(minutes: 30));
    return o.end.isAfter(min) ? o.end : min;
  }
  final result = <(CalendarOccurrence, int, int)>[];
  var group = <(CalendarOccurrence, int)>[];
  var columnsEnd = <DateTime>[];
  DateTime? groupEnd;
  void flush() {
    for (final (o, c) in group) {
      result.add((o, c, columnsEnd.length));
    }
    group = [];
    columnsEnd = [];
    groupEnd = null;
  }
  for (final o in sorted) {
    if (groupEnd != null && !o.start.isBefore(groupEnd!)) flush();
    var column = columnsEnd.indexWhere((end) => !o.start.isBefore(end));
    if (column < 0) {
      column = columnsEnd.length;
      columnsEnd.add(endOf(o));
    } else {
      columnsEnd[column] = endOf(o);
    }
    group.add((o, column));
    final e = endOf(o);
    groupEnd = groupEnd == null || e.isAfter(groupEnd!) ? e : groupEnd;
  }
  flush();
  return result;
}

/// Vista Mese: sei settimane, per ogni giorno gli appuntamenti che ci stanno e «+N altri».
class MonthGrid extends StatelessWidget {
  const MonthGrid({super.key});

  static const maxPerDay = 3;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<CalendarModel>();
    final theme = Theme.of(context);
    final days = model.days;
    final events = model.visibleOccurrences;
    final today = CalendarModel.now();
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(CalendarModel.weekdayName(days[i].weekday), textAlign: TextAlign.center, style: theme.textTheme.labelMedium),
                ),
              ),
          ],
        ),
        for (var w = 0; w < 6; w++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final d = days[w * 7 + i];
                      final list = events.where((o) => o.touches(d)).toList()
                        ..sort((a, b) => a.allDay == b.allDay ? a.start.compareTo(b.start) : (a.allDay ? -1 : 1));
                      final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
                      return GestureDetector(
                        key: Key('month-day:${d.year}-${d.month}-${d.day}'),
                        onDoubleTap: () => CalendarActions.newAppointment(context, start: d, end: d, allDay: true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: d.month == model.anchor.month ? null : theme.colorScheme.surfaceContainerLow,
                            border: Border(
                              left: BorderSide(color: theme.colorScheme.outlineVariant),
                              top: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                d.day == 1 ? '${d.day} ${CalendarModel.monthName(d.month).substring(0, 3)}' : '${d.day}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: isToday ? theme.colorScheme.primary : (d.month == model.anchor.month ? null : theme.colorScheme.outline),
                                  fontWeight: isToday ? FontWeight.bold : null,
                                ),
                              ),
                              for (final o in list.take(maxPerDay)) EventTile(occurrence: o, compact: true),
                              if (list.length > maxPerDay)
                                Text(context.l10n.moreItems(list.length - maxPerDay), style: theme.textTheme.labelSmall),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
