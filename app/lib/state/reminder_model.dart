import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/account_info.dart';
import '../models/calendar.dart';
import '../notify/system_notifier.dart';
import '../settings/app_settings.dart';
import 'calendar_model.dart';

/// Un promemoria arrivato: l'occorrenza e l'ora in cui doveva suonare.
class Reminder {
  const Reminder(this.occurrence, this.at);

  final CalendarOccurrence occurrence;
  final DateTime at;

  /// Chiave per ignorare e rimandare: l'occorrenza e l'ora del promemoria (cambiando il promemoria, ne arriva uno nuovo).
  String get key => '${occurrence.key}|${at.toUtc().toIso8601String()}';
}

/// Promemoria degli appuntamenti (K5, scelta 3a): solo con l'app aperta, per i calendari di tutti gli account. Gli
/// appuntamenti dei prossimi giorni si rileggono ogni [refreshEvery] (e quando i calendari cambiano); ogni [checkEvery] si
/// guarda quali promemoria sono arrivati. Un promemoria nuovo fa partire la notifica del desktop e apre la finestra
/// «Promemoria»; Ignora e Rimanda sono ricordati su questo computer. Quelli arrivati con l'app chiusa compaiono alla
/// riapertura, se non più vecchi di [maxAge].
class ReminderModel extends ChangeNotifier {
  ReminderModel(this.api, this.settings, {this.notifier});

  final ApiClient api;
  final AppSettings settings;
  final MailNotifier? notifier;

  /// Account di cui leggere i calendari (quelli della posta, da [setAccounts]).
  List<AccountInfo> accounts = const [];

  static Duration refreshEvery = const Duration(minutes: 5);
  static Duration checkEvery = const Duration(seconds: 30);
  static const maxAge = Duration(days: 7);

  /// Il payload delle notifiche dei promemoria.
  static final payload = jsonEncode({'reminder': true});

  List<CalendarOccurrence> _upcoming = const [];
  List<Reminder> due = const [];
  final Set<String> _announced = {};
  Timer? _refresh;
  Timer? _check;
  bool _disposed = false;

  /// La finestra «Promemoria» va aperta (promemoria nuovo o clic sulla notifica); la mostra [ReminderHost].
  bool showRequested = false;

  /// Gli account della posta (chiamato a ogni cambiamento di MailboxModel): si rilegge solo se l'elenco cambia.
  void setAccounts(List<AccountInfo> list) {
    String ids(List<AccountInfo> l) => l.map((a) => a.id).join(',');
    if (ids(list) == ids(accounts)) return;
    accounts = list;
    unawaited(refresh());
  }

  /// Spento nei test che non riguardano i promemoria (le loro occorrenze di prova suonerebbero).
  static bool enabled = true;

  void start() {
    if (!enabled) return;
    _refresh?.cancel();
    _check?.cancel();
    _refresh = Timer.periodic(refreshEvery, (_) => unawaited(refresh()));
    _check = Timer.periodic(checkEvery, (_) => check());
    unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    _refresh?.cancel();
    _check?.cancel();
    super.dispose();
  }

  /// Rilegge gli appuntamenti con promemoria da [maxAge] fa a 8 giorni da adesso (un promemoria arriva al massimo una
  /// settimana prima) e controlla quelli arrivati.
  Future<void> refresh() async {
    if (!enabled || _disposed) return;
    final now = CalendarModel.now();
    final from = now.subtract(maxAge + const Duration(days: 1));
    final to = now.add(const Duration(days: 8));
    final list = <CalendarOccurrence>[];
    await Future.wait([
      for (final a in accounts)
        api.forAccount(a.id).getCalendarEvents(from, to).then(list.addAll).catchError((Object _) {}),
    ]);
    if (_disposed) return;
    _upcoming = [for (final o in list) if (o.reminderMinutes != null) o];
    check();
  }

  /// Promemoria arrivati e non ignorati né rimandati a più tardi; quelli nuovi suonano.
  void check() {
    if (_disposed) return;
    final now = CalendarModel.now();
    final state = settings.reminders;
    final list = <Reminder>[];
    for (final o in _upcoming) {
      final r = Reminder(o, o.start.subtract(Duration(minutes: o.reminderMinutes!)));
      if (r.at.isAfter(now) || now.difference(r.at) > maxAge) continue;
      if (state.dismissed.containsKey(r.key)) continue;
      final snoozed = state.snoozed[r.key];
      if (snoozed != null && DateTime.fromMillisecondsSinceEpoch(snoozed * 1000).isAfter(now)) continue;
      list.add(r);
    }
    list.sort((a, b) => a.occurrence.start.compareTo(b.occurrence.start));
    final fresh = [for (final r in list) if (_announced.add(r.key)) r];
    due = list;
    if (fresh.isNotEmpty) {
      showRequested = true;
      final n = notifier;
      if (n != null) {
        final first = fresh.first.occurrence;
        unawaited(n.show(
          fresh.length == 1 ? 'Promemoria: ${first.title}' : '${fresh.length} promemoria',
          fresh.length == 1 ? describe(first, now) : fresh.map((r) => r.occurrence.title).join(', '),
          payload: payload,
        ));
      }
    }
    notifyListeners();
  }

  /// Clic sulla notifica di un promemoria.
  void requestShow() {
    showRequested = true;
    notifyListeners();
  }

  void shown() => showRequested = false;

  /// «Tra 15 minuti», «Adesso», «Iniziato da 5 minuti», «Giornata intera, oggi».
  static String describe(CalendarOccurrence o, DateTime now) {
    String span(Duration d) {
      final m = d.inMinutes.abs();
      if (m < 60) return '$m minut${m == 1 ? 'o' : 'i'}';
      final h = d.inHours.abs();
      if (h < 24) return '$h or${h == 1 ? 'a' : 'e'}';
      final g = d.inDays.abs();
      return '$g giorn${g == 1 ? 'o' : 'i'}';
    }

    if (o.allDay) {
      final today = DateTime(now.year, now.month, now.day);
      final days = o.start.difference(today).inDays;
      return days == 0 ? 'Giornata intera, oggi' : days == 1 ? 'Giornata intera, domani' : days > 1 ? 'Giornata intera, tra $days giorni' : 'Giornata intera, iniziata da ${-days} giorn${days == -1 ? 'o' : 'i'}';
    }
    final diff = o.start.difference(now);
    if (diff.inMinutes.abs() < 1) return 'Adesso';
    return diff.isNegative ? 'Iniziato da ${span(diff)}' : 'Tra ${span(diff)}';
  }

  Future<void> dismiss(Iterable<Reminder> items) async {
    final state = settings.reminders;
    final now = CalendarModel.now();
    final dismissed = {...state.dismissed, for (final r in items) r.key: r.at.millisecondsSinceEpoch ~/ 1000};
    final snoozed = {...state.snoozed}..removeWhere((k, _) => items.any((r) => r.key == k));
    await settings.setReminders(ReminderState(dismissed: dismissed, snoozed: snoozed)
        .prune(now.subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000));
    check();
  }

  /// Rimanda: il promemoria torna dopo [delay] (e suona di nuovo).
  Future<void> snooze(Iterable<Reminder> items, Duration delay) async {
    final state = settings.reminders;
    final until = CalendarModel.now().add(delay).millisecondsSinceEpoch ~/ 1000;
    await settings.setReminders(ReminderState(dismissed: state.dismissed, snoozed: {...state.snoozed, for (final r in items) r.key: until}));
    for (final r in items) {
      _announced.remove(r.key);
    }
    check();
  }
}
