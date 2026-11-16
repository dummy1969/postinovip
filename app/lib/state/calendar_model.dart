import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../l10n/formats.dart' as formats;
import '../models/account_info.dart';
import '../models/calendar.dart';
import '../models/carddav.dart';
import '../settings/app_settings.dart';

/// Vista Calendario (K3, sola lettura): calendari di tutti gli account (scelta 4a), quelli visibili sovrapposti con i loro
/// colori, vista Giorno / Settimana lavorativa / Settimana / Mese (ricordata) attorno al giorno [anchor], occorrenze del
/// periodo chieste al core per ogni account.
class CalendarModel extends ChangeNotifier {
  CalendarModel(this.api, this.settings);

  final ApiClient api;
  final AppSettings settings;

  List<AccountInfo> accounts = const [];
  final Map<String, List<CalendarInfo>> calendars = {};
  final Map<String, CardDavStatus> syncStatus = {};
  List<CalendarOccurrence> occurrences = const [];
  bool loading = false;
  String? error;

  /// Giorno attorno a cui si mostra la vista (mezzanotte locale).
  DateTime anchor = _today();

  /// «Prossimi 7 giorni»: la settimana parte da [anchor] invece che dal primo giorno della settimana.
  bool sevenDays = false;

  /// Occorrenza selezionata ([CalendarOccurrence.key]).
  String? selectedKey;

  bool _active = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _poll;

  /// Intervallo con cui si segue una sincronizzazione appena chiesta (più corto nei test).
  static Duration followInterval = const Duration(seconds: 1);

  /// Chiamata dopo un salvataggio o un'eliminazione nell'app (i promemoria si rileggono).
  void Function()? onEventsChanged;

  /// Ora attuale, sostituibile nei test.
  static DateTime Function() now = DateTime.now;

  static DateTime _today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  CalendarPrefs get prefs => settings.calendar;
  CalendarViewKind get view => prefs.view;

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- giorni e periodo

  /// Primo giorno della settimana che contiene [d].
  DateTime weekStart(DateTime d) {
    final back = (d.weekday - prefs.firstDay + 7) % 7;
    return _day(d).subtract(Duration(days: back));
  }

  /// I giorni mostrati (per il mese 6 settimane intere, come Outlook).
  List<DateTime> get days {
    List<DateTime> from(DateTime start, int n) => [for (var i = 0; i < n; i++) DateTime(start.year, start.month, start.day + i)];
    switch (view) {
      case CalendarViewKind.day:
        return [anchor];
      case CalendarViewKind.workWeek:
        final week = from(sevenDays ? anchor : weekStart(anchor), 7);
        final work = week.where((d) => prefs.workDays.contains(d.weekday)).toList();
        return work.isEmpty ? week : work;
      case CalendarViewKind.week:
        return from(sevenDays ? anchor : weekStart(anchor), 7);
      case CalendarViewKind.month:
        return from(weekStart(DateTime(anchor.year, anchor.month, 1)), 42);
    }
  }

  /// Periodo chiesto al core: dal primo giorno mostrato alla mezzanotte dopo l'ultimo.
  (DateTime, DateTime) get range {
    final d = days;
    final last = d.last;
    return (d.first, DateTime(last.year, last.month, last.day + 1));
  }

  /// Nomi di mesi e giorni nella lingua dell'app (L5b).
  static String monthName(int month) => formats.monthName(month);
  static String weekdayName(int weekday) => formats.weekdayName(weekday);
  static String weekdayShort(int weekday) => formats.weekdayShortName(weekday);

  /// Titolo del periodo, come Outlook: «9 – 13 novembre 2026», «novembre 2026», «lunedì 9 novembre 2026».
  String get title {
    if (view == CalendarViewKind.month) return formats.formatMonthYear(anchor);
    final d = days;
    if (d.length == 1) return formats.formatFullDate(d.first);
    return formats.formatDayRange(d.first, d.last);
  }

  // ---------------------------------------------------------------- navigazione

  Future<void> setView(CalendarViewKind kind) async {
    sevenDays = false;
    await settings.setCalendar(prefs.copyWith(view: kind));
    unawaited(reloadEvents());
  }

  void goToday() => goTo(_today());

  /// «Prossimi 7 giorni» (Vai a): settimana da oggi.
  Future<void> showNextSevenDays() async {
    anchor = _today();
    if (view != CalendarViewKind.week) await settings.setCalendar(prefs.copyWith(view: CalendarViewKind.week));
    sevenDays = true;
    notifyListeners();
    unawaited(reloadEvents());
  }

  void goTo(DateTime day) {
    anchor = _day(day);
    notifyListeners();
    unawaited(reloadEvents());
  }

  /// Periodo precedente (-1) o successivo (+1).
  void move(int direction) {
    anchor = switch (view) {
      CalendarViewKind.day => DateTime(anchor.year, anchor.month, anchor.day + direction),
      CalendarViewKind.month => DateTime(anchor.year, anchor.month + direction, 1),
      _ => DateTime(anchor.year, anchor.month, anchor.day + 7 * direction),
    };
    notifyListeners();
    unawaited(reloadEvents());
  }

  // ---------------------------------------------------------------- calendari, colori

  bool isVisible(String account, String calendarId) => !prefs.hidden.contains(CalendarPrefs.keyOf(account, calendarId));

  Future<void> setVisible(String account, String calendarId, bool visible) async {
    final key = CalendarPrefs.keyOf(account, calendarId);
    final hidden = {...prefs.hidden};
    visible ? hidden.remove(key) : hidden.add(key);
    await settings.setCalendar(prefs.copyWith(hidden: hidden));
    notifyListeners();
  }

  /// Indice nella tavolozza: quello scelto, altrimenti in ordine tra tutti i calendari (scelta 3a).
  int colorIndex(String account, String calendarId) {
    final chosen = prefs.colors[CalendarPrefs.keyOf(account, calendarId)];
    if (chosen != null) return chosen;
    var i = 0;
    for (final a in accounts) {
      for (final c in calendars[a.id] ?? const <CalendarInfo>[]) {
        if (a.id == account && c.id == calendarId) return i;
        i++;
      }
    }
    return i;
  }

  Future<void> setColor(String account, String calendarId, int index) async {
    await settings.setCalendar(prefs.copyWith(colors: {...prefs.colors, CalendarPrefs.keyOf(account, calendarId): index}));
    notifyListeners();
  }

  /// Calendario di sola lettura sul server (G3, es. le festività di Google): niente modifiche né eliminazioni.
  bool isReadOnly(String account, String calendarId) =>
      calendars[account]?.where((c) => c.id == calendarId).firstOrNull?.readOnly ?? false;

  String calendarName(String account, String calendarId) =>
      calendars[account]?.where((c) => c.id == calendarId).firstOrNull?.name ?? formats.formatL10n.calendarSection;

  /// Le occorrenze dei calendari visibili.
  List<CalendarOccurrence> get visibleOccurrences => [
    for (final o in occurrences)
      if (isVisible(o.account, o.calendarId)) o,
  ];

  CalendarOccurrence? get selected => occurrences.where((o) => o.key == selectedKey).firstOrNull;

  void select(String? key) {
    selectedKey = key;
    notifyListeners();
  }

  // ---------------------------------------------------------------- caricamento

  /// Entrando nel Calendario: calendari, stato della sincronizzazione e occorrenze di tutti gli account.
  Future<void> activate(List<AccountInfo> list) async {
    accounts = list;
    _active = true;
    _poll?.cancel();
    if (accounts.any((a) => a.calDav)) {
      _poll = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(loadSyncStatuses()));
    }
    await reload();
  }

  void deactivate() {
    _active = false;
    _poll?.cancel();
  }

  Future<void> reload() async {
    await Future.wait([for (final a in accounts) _loadCalendars(a.id)]);
    unawaited(loadSyncStatuses());
    await reloadEvents();
  }

  Future<void> _loadCalendars(String account) async {
    try {
      calendars[account] = await api.forAccount(account).getCalendars();
    } on ApiException {
      calendars[account] = const []; // core senza calendari o account senza copia locale
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> reloadEvents() async {
    if (!_active || accounts.isEmpty) return;
    final generation = ++_generation;
    final (from, to) = range;
    loading = true;
    error = null;
    notifyListeners();
    final result = <CalendarOccurrence>[];
    String? failure;
    await Future.wait([
      for (final a in accounts)
        if ((calendars[a.id] ?? const []).isNotEmpty)
          api.forAccount(a.id).getCalendarEvents(from, to).then(result.addAll).catchError((Object e) {
            failure ??= e is ApiException ? e.message : '$e';
          }),
    ]);
    if (_disposed || generation != _generation) return; // risposta di un periodo vecchio
    result.sort((x, y) => x.start.compareTo(y.start));
    occurrences = result;
    loading = false;
    error = failure;
    if (selectedKey != null && !result.any((o) => o.key == selectedKey)) selectedKey = null;
    notifyListeners();
  }

  /// Dopo un salvataggio o un'eliminazione nell'app: calendari (numeri) e occorrenze riletti; con CalDAV la
  /// sincronizzazione parte da sola nel core, qui se ne segue lo stato.
  Future<void> changed(String account) async {
    onEventsChanged?.call();
    await _loadCalendars(account);
    await reloadEvents();
    if (accounts.any((a) => a.id == account && a.calDav)) _follow(account);
  }

  /// Evento calendars-changed: la sincronizzazione ha cambiato i calendari di un account (o serve la conferma).
  Future<void> calendarsChanged(String account) async {
    await loadSyncStatus(account);
    if (!_active) return;
    await _loadCalendars(account);
    await reloadEvents();
  }

  // ---------------------------------------------------------------- sincronizzazione

  CardDavStatus statusOf(String account) => syncStatus[account] ?? CardDavStatus.off;

  Future<void> loadSyncStatuses() =>
      Future.wait([for (final a in accounts) if (a.calDav) loadSyncStatus(a.id)]);

  Future<void> loadSyncStatus(String account) async {
    final CardDavStatus status;
    try {
      status = await api.forAccount(account).getCalendarsSync();
    } on ApiException {
      return;
    }
    if (_disposed) return;
    final before = syncStatus[account];
    syncStatus[account] = status;
    notifyListeners();
    if (_active && before != null && before.lastSync != status.lastSync && status.state == 'ok') {
      await _loadCalendars(account);
      await reloadEvents();
    }
  }

  /// «Sincronizza» (o F9 nel Calendario): tutti gli account con CalDAV.
  Future<void> syncNow() async {
    for (final a in accounts.where((a) => a.calDav)) {
      try {
        await api.forAccount(a.id).syncCalendars();
      } on ApiException {
        continue;
      }
      _follow(a.id);
    }
  }

  /// Conferma della prima volta: **modifica i calendari del server** caricando gli appuntamenti solo sul computer.
  Future<void> confirmUpload(String account) async {
    await api.forAccount(account).confirmCalendarsSync();
    _follow(account);
  }

  void _follow(String account) {
    final since = statusOf(account).lastSync;
    var left = 30;
    unawaited(() async {
      while (left-- > 0 && !_disposed) {
        await Future<void>.delayed(followInterval);
        if (_disposed) return;
        await loadSyncStatus(account);
        final s = statusOf(account);
        if (!s.busy && s.lastSync != since) return;
        if (s.state == 'error' || s.state == 'offline' || s.state == 'unavailable') return;
      }
    }());
  }
}
