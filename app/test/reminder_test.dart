import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/models/calendar.dart';
import 'package:postinovip/notify/system_notifier.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/state/calendar_model.dart';
import 'package:postinovip/state/reminder_model.dart';
import 'package:postinovip/ui/appointment_page.dart';

import 'calendar_test.dart' as ct;

// Promemoria K5: notifica del desktop e finestra «Promemoria» con Ignora / Rimanda / Apri elemento, ricordati su questo
// computer. Core finto del calendario: «Riunione» (ricorrente, promemoria 15 minuti) alle 10 di mercoledì 11/11/2026,
// «Pranzo» senza promemoria; adesso = 10:00, quindi il promemoria della riunione è già arrivato (alle 9:45).
class _Notifier implements MailNotifier {
  final shown = <(String, String, String?)>[];
  final _clicks = StreamController<String?>.broadcast();

  @override
  Future<void> show(String title, String body, {String? payload}) async => shown.add((title, body, payload));

  @override
  Stream<String?> get clicks => _clicks.stream;

  void click(String? payload) => _clicks.add(payload);
}

class _NoWindow implements WindowPresenter {
  int presented = 0;

  @override
  Future<void> present() async => presented++;
}

DateTime clock = DateTime(2026, 11, 11, 10);

Future<(_Notifier, AppSettings, _NoWindow)> start(WidgetTester tester, {AppSettings? settings}) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  clock = DateTime(2026, 11, 11, 10);
  CalendarModel.now = () => clock;
  ReminderModel.enabled = true;
  addTearDown(() {
    CalendarModel.now = DateTime.now;
    ReminderModel.enabled = false;
  });
  final notifier = _Notifier();
  final window = _NoWindow();
  final s = settings ?? AppSettings(MemorySettingsStore());
  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: ct.CalendarCore().client), settings: s, notifier: notifier, windowPresenter: window));
  await tester.pumpAndSettle();
  return (notifier, s, window);
}

const riunione = Key('reminder:a1|c1|e1|2026-11-11T09:00:00Z');

void main() {
  testWidgets('Promemoria arrivato: notifica e finestra; Rimanda lo fa tornare dopo', (tester) async {
    final (notifier, settings, _) = await start(tester);
    expect(find.byKey(const Key('reminder-dialog')), findsOneWidget);
    expect(find.text('1 promemoria'), findsOneWidget);
    expect(find.byKey(riunione), findsOneWidget);
    expect(find.byKey(const Key('reminder-due:a1|c1|e1|2026-11-11T09:00:00Z')).evaluate().isNotEmpty, true);
    expect(find.text('Adesso'), findsOneWidget);
    expect(find.textContaining('Pranzo'), findsNothing); // senza promemoria
    expect(notifier.shown.single.$1, 'Promemoria: Riunione');
    expect(notifier.shown.single.$3, ReminderModel.payload);

    await tester.tap(find.byKey(const Key('reminder-snooze'))); // 5 minuti
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-dialog')), findsNothing);
    expect(settings.reminders.snoozed.length, 1);

    clock = clock.add(const Duration(minutes: 3));
    await tester.pump(ReminderModel.checkEvery);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-dialog')), findsNothing); // non ancora

    clock = clock.add(const Duration(minutes: 3));
    await tester.pump(ReminderModel.checkEvery);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-dialog')), findsOneWidget);
    expect(find.text('Iniziato da 6 minuti'), findsOneWidget);
    expect(notifier.shown.length, 2); // suona di nuovo
  });

  testWidgets('Ignora: non torna più, nemmeno riaprendo l\'app', (tester) async {
    final (notifier, settings, _) = await start(tester);
    await tester.tap(find.byKey(const Key('reminder-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-dialog')), findsNothing);
    expect(settings.reminders.dismissed.length, 1);

    clock = clock.add(const Duration(minutes: 10));
    await tester.pump(ReminderModel.checkEvery);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-dialog')), findsNothing);

    await tester.pumpWidget(const SizedBox()); // app chiusa
    final (again, _, _) = await start(tester, settings: settings);
    expect(find.byKey(const Key('reminder-dialog')), findsNothing);
    expect(again.shown, isEmpty);
    expect(notifier.shown.length, 1);
  });

  testWidgets('Chiudi e clic sulla notifica: la finestra torna; Apri elemento apre l\'appuntamento', (tester) async {
    final (notifier, _, window) = await start(tester);
    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-dialog')), findsNothing);

    clock = clock.add(const Duration(minutes: 1));
    await tester.pump(ReminderModel.checkEvery);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-dialog')), findsNothing); // già annunciato: non si riapre da solo

    notifier.click(ReminderModel.payload);
    await tester.pumpAndSettle();
    expect(window.presented, 1);
    expect(find.byKey(const Key('reminder-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminder-open')));
    await tester.pumpAndSettle();
    expect(find.text('È un appuntamento ricorrente. Aprire solo questa occorrenza o tutta la serie?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('choose-series')));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentPage), findsOneWidget);
  });

  test('Descrizione della scadenza', () {
    final now = DateTime(2026, 11, 11, 10);
    CalendarOccurrence at(DateTime start, {bool allDay = false}) => CalendarOccurrence.fromJson('a', {
      'calendarId': 'c', 'eventId': 'e', 'uid': 'e', 'summary': 'x', 'recurring': false, 'allDay': allDay,
      'start': allDay ? start.toIso8601String().substring(0, 10) : start.toUtc().toIso8601String(),
      'end': allDay ? '2026-11-12' : start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
    });
    expect(ReminderModel.describe(at(now.add(const Duration(minutes: 15))), now), 'Tra 15 minuti');
    expect(ReminderModel.describe(at(now.add(const Duration(minutes: 1))), now), 'Tra 1 minuto');
    expect(ReminderModel.describe(at(now.add(const Duration(seconds: 20))), now), 'Adesso');
    expect(ReminderModel.describe(at(now.subtract(const Duration(hours: 2))), now), 'Iniziato da 2 ore');
    expect(ReminderModel.describe(at(now.add(const Duration(days: 1))), now), 'Tra 1 giorno');
    expect(ReminderModel.describe(at(DateTime(2026, 11, 12), allDay: true), now), 'Giornata intera, domani');
    expect(ReminderModel.describe(at(DateTime(2026, 11, 11), allDay: true), now), 'Giornata intera, oggi');
  });

  test('Stato dei promemoria: JSON e voci vecchie tolte', () {
    final s = ReminderState.fromJson({'dismissed': {'a': 100, 'b': 5, 'x': 'no'}, 'snoozed': {'c': 200}});
    expect(s.dismissed, {'a': 100, 'b': 5});
    expect(s.snoozed, {'c': 200});
    final p = s.prune(50);
    expect(p.dismissed, {'a': 100});
    expect(p.snoozed, {'c': 200});
    expect(ReminderState.fromJson(p.toJson()).dismissed, {'a': 100});
    expect(ReminderState.fromJson(const {}).snoozed, isEmpty);
  });
}
