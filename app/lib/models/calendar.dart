/// Calendari e appuntamenti come li dà il core (K2): GET …/calendars, …/calendars/events, …/calendars/{cal}/events/{id}.
library;

import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';

/// Un calendario di un account: il primo è quello predefinito; [synced] = collegato a un calendario del server (CalDAV).
class CalendarInfo {
  const CalendarInfo({required this.id, required this.name, this.synced = false, this.count = 0, this.readOnly = false});

  final String id;
  final String name;
  final bool synced;
  final int count;

  /// Calendario del server di sola lettura (G2/G3, es. le festività di Google): si vede, non si modifica.
  final bool readOnly;

  factory CalendarInfo.fromJson(Map<String, dynamic> json) => CalendarInfo(
    id: json['id'] as String,
    name: json['name'] as String? ?? formatL10n.calendarSection,
    synced: json['synced'] as bool? ?? false,
    count: json['count'] as int? ?? 0,
    readOnly: json['readOnly'] as bool? ?? false,
  );
}

/// Un'occorrenza in un periodo. Orari in ora locale (dal core arrivano in UTC); giornata intera: [start] e [end] sono
/// date a mezzanotte, [end] compresa.
class CalendarOccurrence {
  const CalendarOccurrence({
    required this.account,
    required this.calendarId,
    required this.eventId,
    required this.start,
    required this.end,
    required this.allDay,
    required this.summary,
    this.location,
    this.recurring = false,
    this.recurrenceId,
    this.reminderMinutes,
  });

  final String account;
  final String calendarId;
  final String eventId;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String summary;
  final String? location;
  final bool recurring;
  final String? recurrenceId;
  final int? reminderMinutes;

  /// Chiave dell'occorrenza (la stessa serie ha più occorrenze).
  String get key => '$account|$calendarId|$eventId|${recurrenceId ?? ''}';

  /// Chiave del calendario, per colori e visibilità.
  String get calendarKey => CalendarPrefs.keyOf(account, calendarId);

  String get title => summary.trim().isEmpty ? '(nessun oggetto)' : summary;

  static DateTime _parse(String value, bool allDay) {
    if (allDay) {
      final d = DateTime.parse(value);
      return DateTime(d.year, d.month, d.day);
    }
    return DateTime.parse(value).toLocal();
  }

  factory CalendarOccurrence.fromJson(String account, Map<String, dynamic> json) {
    final allDay = json['allDay'] as bool? ?? false;
    return CalendarOccurrence(
      account: account,
      calendarId: json['calendarId'] as String,
      eventId: json['eventId'] as String,
      start: _parse(json['start'] as String, allDay),
      end: _parse(json['end'] as String, allDay),
      allDay: allDay,
      summary: json['summary'] as String? ?? '',
      location: json['location'] as String?,
      recurring: json['recurring'] as bool? ?? false,
      recurrenceId: json['recurrenceId'] as String?,
      reminderMinutes: json['reminderMinutes'] as int?,
    );
  }

  /// I giorni che l'occorrenza tocca (per la vista mese e la riga della giornata intera).
  bool touches(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (allDay) return !d.isBefore(start) && !d.isAfter(end);
    final next = d.add(const Duration(days: 1));
    return start.isBefore(next) && (end.isAfter(d) || (end == start && !start.isBefore(d)));
  }
}

/// Ricorrenza come la finestra «Ricorrenza» di Outlook (vedi EventRecurrence nel core).
class CalendarRecurrence {
  const CalendarRecurrence({
    required this.frequency,
    this.interval = 1,
    this.days = const [],
    this.monthDay,
    this.week,
    this.month,
    this.count,
    this.until,
  });

  final String frequency;
  final int interval;
  final List<String> days;
  final int? monthDay;
  final int? week;
  final int? month;
  final int? count;
  final String? until;

  factory CalendarRecurrence.fromJson(Map<String, dynamic> json) => CalendarRecurrence(
    frequency: json['frequency'] as String,
    interval: json['interval'] as int? ?? 1,
    days: [for (final d in json['days'] as List? ?? const []) d as String],
    monthDay: json['monthDay'] as int?,
    week: json['week'] as int?,
    month: json['month'] as int?,
    count: json['count'] as int?,
    until: json['until'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'frequency': frequency,
    'interval': interval,
    if (days.isNotEmpty) 'days': days,
    'monthDay': ?monthDay,
    'week': ?week,
    'month': ?month,
    'count': ?count,
    'until': ?until,
  };

  static const _dayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  static String _dayName(String code) {
    final i = _dayCodes.indexOf(code);
    return i < 0 ? code : weekdayName(i + 1);
  }

  static String _ordinal(AppLocalizations l, int? week) => switch (week) {
    1 => l.recurOrdinalFirst,
    2 => l.recurOrdinalSecond,
    3 => l.recurOrdinalThird,
    4 => l.recurOrdinalFourth,
    -1 => l.recurOrdinalLast,
    _ => '',
  };

  /// Descrizione come quella di Outlook, nella lingua dell'app: «Ogni settimana il lunedì, 3 volte».
  String describe() {
    final l = formatL10n;
    final dayList = days.map(_dayName).join(', ');
    final which = week != null && days.isNotEmpty ? '${_ordinal(l, week)} ${_dayName(days.first)}' : null;
    final text = switch (frequency) {
      'daily' => l.recurDescDaily(interval),
      'weekly' => dayList.isEmpty ? l.recurDescWeekly(interval) : l.recurDescWeeklyOn(l.recurDescWeekly(interval), dayList),
      'monthly' =>
        which != null
            ? l.recurDescMonthlyWhich(l.recurDescMonthly(interval), which)
            : monthDay == null
            ? l.recurDescMonthly(interval)
            : l.recurDescMonthlyDay(l.recurDescMonthly(interval), monthDay!),
      'yearly' => which != null
          ? l.recurDescYearlyWhich(which, _monthName(month))
          : l.recurDescYearlyDay('${monthDay ?? ''}', _monthName(month)).trim(),
      _ => l.recurDescRecurring,
    };
    final end = count != null ? l.recurDescTimes(count!) : until != null ? l.recurDescUntil(_date(until!)) : '';
    return '$text$end';
  }

  static String _monthName(int? m) => m != null && m >= 1 && m <= 12 ? monthName(m) : '';

  static String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : formatDate(d);
  }
}

/// La serie di un appuntamento (scheda in sola lettura del K3, finestra Appuntamento del K4).
class CalendarEventDetail {
  const CalendarEventDetail({
    required this.id,
    required this.calendarId,
    required this.summary,
    required this.start,
    required this.end,
    required this.allDay,
    required this.timeZone,
    this.location,
    this.description,
    this.reminderMinutes,
    this.recurrence,
    this.customRecurrence,
    this.exceptions = 0,
    this.attendees = 0,
    this.recurrenceId,
  });

  /// Una sola occorrenza (K4a), null per la serie.
  final String? recurrenceId;

  final String id;
  final String calendarId;
  final String summary;

  /// Ora locale nel fuso [timeZone] («aaaa-mm-ggThh:mm»), o date per la giornata intera.
  final String start;
  final String end;
  final bool allDay;
  final String timeZone;
  final String? location;
  final String? description;
  final int? reminderMinutes;
  final CalendarRecurrence? recurrence;
  final String? customRecurrence;
  final int exceptions;
  final int attendees;

  factory CalendarEventDetail.fromJson(Map<String, dynamic> json) => CalendarEventDetail(
    id: json['id'] as String,
    calendarId: json['calendarId'] as String,
    summary: json['summary'] as String? ?? '',
    start: json['start'] as String,
    end: json['end'] as String,
    allDay: json['allDay'] as bool? ?? false,
    timeZone: json['timeZone'] as String? ?? '',
    location: json['location'] as String?,
    description: json['description'] as String?,
    reminderMinutes: json['reminderMinutes'] as int?,
    recurrence: json['recurrence'] == null ? null : CalendarRecurrence.fromJson(json['recurrence'] as Map<String, dynamic>),
    customRecurrence: json['customRecurrence'] as String?,
    exceptions: json['exceptions'] as int? ?? 0,
    attendees: json['attendees'] as int? ?? 0,
    recurrenceId: json['recurrenceId'] as String?,
  );
}

/// Esito di «Verifica calendario» (POST /account/test-caldav): i calendari trovati o il motivo.
class CalDavTestResult {
  const CalDavTestResult({required this.ok, this.error, this.calendars = const []});

  final bool ok;
  final String? error;
  final List<String> calendars;

  factory CalDavTestResult.fromJson(Map<String, dynamic> json) => CalDavTestResult(
    ok: json['ok'] as bool? ?? false,
    error: json['error'] as String?,
    calendars: [for (final c in json['calendars'] as List? ?? const []) c as String],
  );
}

/// Vista del calendario (scelta 1a): Giorno, Settimana lavorativa, Settimana, Mese.
enum CalendarViewKind {
  day,
  workWeek,
  week,
  month;

  String label(AppLocalizations l) => switch (this) {
    CalendarViewKind.day => l.viewDay,
    CalendarViewKind.workWeek => l.viewWorkWeek,
    CalendarViewKind.week => l.viewWeek,
    CalendarViewKind.month => l.viewMonth,
  };
}

/// Preferenze del calendario su questo computer (K3: scelte 1a, 2b, 3a): vista ricordata, primo giorno della settimana
/// (DateTime.monday..sunday), giorni lavorativi, orario lavorativo in minuti, colori scelti e calendari nascosti
/// (chiavi «account:calendario»).
class CalendarPrefs {
  const CalendarPrefs({
    this.view = CalendarViewKind.workWeek,
    this.firstDay = DateTime.monday,
    this.workDays = const {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday},
    this.workStart = 8 * 60,
    this.workEnd = 17 * 60,
    this.colors = const {},
    this.hidden = const {},
  });

  static const defaults = CalendarPrefs();

  final CalendarViewKind view;
  final int firstDay;
  final Set<int> workDays;
  final int workStart;
  final int workEnd;
  final Map<String, int> colors;
  final Set<String> hidden;

  static String keyOf(String account, String calendarId) => '$account:$calendarId';

  CalendarPrefs copyWith({
    CalendarViewKind? view,
    int? firstDay,
    Set<int>? workDays,
    int? workStart,
    int? workEnd,
    Map<String, int>? colors,
    Set<String>? hidden,
  }) => CalendarPrefs(
    view: view ?? this.view,
    firstDay: firstDay ?? this.firstDay,
    workDays: workDays ?? this.workDays,
    workStart: workStart ?? this.workStart,
    workEnd: workEnd ?? this.workEnd,
    colors: colors ?? this.colors,
    hidden: hidden ?? this.hidden,
  );

  Map<String, dynamic> toJson() => {
    'view': view.name,
    'firstDay': firstDay,
    'workDays': (workDays.toList()..sort()),
    'workStart': workStart,
    'workEnd': workEnd,
    'colors': colors,
    'hidden': hidden.toList(),
  };

  /// Valori mancanti o non validi (file modificato a mano): quelli predefiniti.
  factory CalendarPrefs.fromJson(Map<String, dynamic> json) {
    int minutes(Object? v, int fallback) => v is int && v >= 0 && v <= 24 * 60 ? v : fallback;
    final days = {for (final d in json['workDays'] as List? ?? const []) if (d is int && d >= 1 && d <= 7) d};
    final start = minutes(json['workStart'], defaults.workStart);
    final end = minutes(json['workEnd'], defaults.workEnd);
    final first = json['firstDay'];
    return CalendarPrefs(
      view: CalendarViewKind.values.where((v) => v.name == json['view']).firstOrNull ?? defaults.view,
      firstDay: first is int && first >= 1 && first <= 7 ? first : defaults.firstDay,
      workDays: days.isEmpty ? defaults.workDays : days,
      workStart: start < end ? start : defaults.workStart,
      workEnd: start < end ? end : defaults.workEnd,
      colors: {
        for (final e in (json['colors'] as Map? ?? const {}).entries)
          if (e.key is String && e.value is int) e.key as String: e.value as int,
      },
      hidden: {for (final h in json['hidden'] as List? ?? const []) if (h is String) h},
    );
  }
}

/// Promemoria ignorati e rimandati (K5), su questo computer: chiave del promemoria (occorrenza + ora del promemoria) ->
/// secondi Unix (ora del promemoria ignorato, o fino a quando è rimandato). Le voci vecchie si tolgono da sole.
class ReminderState {
  const ReminderState({this.dismissed = const {}, this.snoozed = const {}});

  final Map<String, int> dismissed;
  final Map<String, int> snoozed;

  Map<String, dynamic> toJson() => {'dismissed': dismissed, 'snoozed': snoozed};

  factory ReminderState.fromJson(Map<String, dynamic> json) {
    Map<String, int> read(Object? v) => {
      for (final e in (v as Map? ?? const {}).entries)
        if (e.key is String && e.value is int) e.key as String: e.value as int,
    };
    return ReminderState(dismissed: read(json['dismissed']), snoozed: read(json['snoozed']));
  }

  /// Senza le voci più vecchie di [before] (secondi Unix).
  ReminderState prune(int before) => ReminderState(
    dismissed: {for (final e in dismissed.entries) if (e.value >= before) e.key: e.value},
    snoozed: {for (final e in snoozed.entries) if (e.value >= before) e.key: e.value},
  );
}
