import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/account/account_config.dart';
import 'package:postinovip/account/account_setup_page.dart';
import 'package:postinovip/account/accounts_page.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/models/calendar.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/state/calendar_model.dart';
import 'package:postinovip/ui/appointment_page.dart';
import 'package:postinovip/ui/calendar_view.dart';
import 'package:postinovip/ui/ribbon_parts.dart';

import 'multi_select_test.dart' as ms;

// Calendario K3 (app, sola lettura): modulo Calendario, viste Giorno / Settimana lavorativa / Settimana / Mese, navigazione,
// calendari visibili e colori, scheda in sola lettura, Opzioni, sezione «Calendario» dell'account. Core finto della
// selezione multipla più due calendari con appuntamenti fissi; oggi = mercoledì 11/11/2026 alle 10.
class CalendarCore {
  final core = ms.SelectCore();
  final requests = <String>[];

  /// Corpi delle scritture sugli appuntamenti ("METODO percorso" -> JSON).
  final bodies = <String, Map<String, dynamic>>{};
  Map<String, dynamic> status = {
    'enabled': true,
    'state': 'ok',
    'lastSync': '2026-11-11T08:00:00Z',
    'needsConfirmation': false,
    'pendingUpload': 0,
    'addressBook': '2 calendari',
  };

  /// Occorrenze in UTC (Roma = UTC+1 a novembre).
  final events = <Map<String, dynamic>>[
    occ('c1', 'e1', 'Riunione', '2026-11-11T09:00:00Z', '2026-11-11T10:00:00Z', recurring: true),
    occ('c1', 'e2', 'Pranzo', '2026-11-12T11:00:00Z', '2026-11-12T12:00:00Z'),
    occ('c2', 'e3', 'Ferie', '2026-11-13', '2026-11-13', allDay: true),
    occ('c2', 'e4', 'Fuori settimana', '2026-11-20T09:00:00Z', '2026-11-20T10:00:00Z'),
  ];

  static Map<String, dynamic> occ(String cal, String id, String summary, String start, String end,
      {bool allDay = false, bool recurring = false}) => {
    'calendarId': cal, 'eventId': id, 'uid': id, 'recurrenceId': recurring ? start : null, 'start': start, 'end': end,
    'allDay': allDay, 'summary': summary, 'location': cal == 'c1' ? 'Sala 1' : null, 'recurring': recurring,
    'reminderMinutes': recurring ? 15 : null,
  };

  /// G3: anche un calendario di sola lettura come le festività di Google, con un appuntamento giovedì 12.
  bool holidays = false;

  void event(Map<String, dynamic> e) => core.sse.add(utf8.encode('data: ${jsonEncode(e)}\n\n'));

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = request.url.path;
    http.StreamedResponse json(Object? value, [int status = 200]) => http.StreamedResponse(
      Stream.value(value == null ? <int>[] : utf8.encode(jsonEncode(value))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (path.startsWith('/accounts/a1/calendars')) requests.add('${request.method} $path');
    if (path == '/accounts/a1/calendars') {
      return json({
        'items': [
          {'id': 'c1', 'name': 'Calendario', 'synced': true, 'count': 3},
          {'id': 'c2', 'name': 'Lavoro', 'synced': true, 'count': 2},
          if (holidays) {'id': 'c3', 'name': 'Festività in Italia', 'synced': true, 'count': 1, 'readOnly': true},
        ],
      });
    }
    if (path == '/accounts/a1/calendars/sync' && request.method == 'GET') return json(status);
    if (path.startsWith('/accounts/a1/calendars/sync') && request.method == 'POST') {
      status = {...status, 'needsConfirmation': false, 'pendingUpload': 0, 'lastSync': '2026-11-11T09:00:00Z'};
      return json(null, 202);
    }
    if (path == '/accounts/a1/calendars/events') {
      final from = DateTime.parse(request.url.queryParameters['from']!);
      final to = DateTime.parse(request.url.queryParameters['to']!);
      return json({
        'items': [
          if (holidays) occ('c3', 'e5', 'Festa del paese', '2026-11-12T15:00:00Z', '2026-11-12T16:00:00Z'),
          for (final e in events)
            if (DateTime.parse(e['start'] as String).isBefore(to) && !DateTime.parse(e['end'] as String).isBefore(from)) e,
        ],
        'truncated': false,
      });
    }
    if (path.contains('/events') && path != '/accounts/a1/calendars/events' && request.method != 'GET') {
      final text = await bodyStream.bytesToString();
      final key = '${request.method} $path${request.url.query.isEmpty ? '' : '?${request.url.query}'}';
      requests.add(key);
      if (text.isNotEmpty) bodies[key] = jsonDecode(text) as Map<String, dynamic>;
      if (request.method == 'DELETE') return json(null, 204);
      return json({
        'id': 'nuovo', 'calendarId': 'c1', 'uid': 'u', 'summary': 'x', 'start': '2026-11-11T11:00', 'end': '2026-11-11T12:00',
        'allDay': false, 'timeZone': 'Europe/Rome',
      }, request.method == 'POST' ? 201 : 200);
    }
    if (path == '/accounts/a1/calendars/c3/events/e5' && request.method == 'GET') {
      return json({
        'id': 'e5', 'calendarId': 'c3', 'uid': 'e5', 'summary': 'Festa del paese', 'start': '2026-11-12T16:00',
        'end': '2026-11-12T17:00', 'allDay': false, 'timeZone': 'Europe/Rome', 'exceptions': 0, 'attendees': 0,
      });
    }
    if (path == '/accounts/a1/calendars/c1/events/e1/occurrence') {
      requests.add('GET occurrence ${request.url.queryParameters['recurrenceId']}');
      return json({
        'id': 'e1', 'calendarId': 'c1', 'uid': 'e1', 'summary': 'Riunione', 'location': 'Sala 1', 'start': '2026-11-11T10:00',
        'end': '2026-11-11T11:00', 'allDay': false, 'timeZone': 'Europe/Rome', 'reminderMinutes': 15,
        'recurrenceId': request.url.queryParameters['recurrenceId'],
      });
    }
    if (path == '/accounts/a1/calendars/c1/events/e1') {
      return json({
        'id': 'e1', 'calendarId': 'c1', 'uid': 'e1', 'summary': 'Riunione', 'location': 'Sala 1', 'description': 'Ordine del giorno',
        'start': '2026-11-11T10:00', 'end': '2026-11-11T11:00', 'allDay': false, 'timeZone': 'Europe/Rome', 'reminderMinutes': 15,
        'recurrence': {'frequency': 'weekly', 'interval': 1, 'days': ['WE'], 'count': 3}, 'customRecurrence': null,
        'exceptions': 0, 'attendees': 0,
      });
    }
    final forward = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = await bodyStream.toBytes();
    final response = await core.client.send(forward);
    if (path == '/accounts' && request.method == 'GET') {
      final list = jsonDecode(await response.stream.bytesToString()) as List;
      return json([for (final a in list) {...a as Map<String, dynamic>, 'calDav': true}]);
    }
    return response;
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<(CalendarCore, AppSettings)> start(WidgetTester tester, {AppSettings? settings, AccountsEditing? editing}) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  CalendarModel.now = () => DateTime(2026, 11, 11, 10);
  CalendarModel.followInterval = const Duration(milliseconds: 10);
  addTearDown(() => CalendarModel.now = DateTime.now);
  final fake = CalendarCore();
  final s = settings ?? AppSettings(MemorySettingsStore());
  await tester.pumpWidget(PostinoVipApp(
      api: ApiClient(httpClient: fake.client), settings: s, windowPresenter: _NoWindow(), accountsEditing: editing));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('module-calendar')));
  await tester.pumpAndSettle();
  return (fake, s);
}

String title(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('calendar-title'))).data!;

void main() {
  testWidgets('Settimana lavorativa di serie, appuntamenti, calendari, stato; Ctrl+1 / Ctrl+2', (tester) async {
    final (fake, _) = await start(tester);
    expect(title(tester), '9 – 13 novembre 2026');
    for (final d in [9, 10, 11, 12, 13]) {
      expect(find.byKey(Key('day-header:2026-11-$d')), findsOneWidget);
    }
    expect(find.byKey(const Key('day-header:2026-11-14')), findsNothing); // sabato: non lavorativo
    expect(find.textContaining('Riunione'), findsWidgets);
    expect(find.textContaining('Pranzo'), findsWidgets);
    expect(find.textContaining('Ferie'), findsWidgets); // in alto, giornata intera
    expect(find.textContaining('Fuori settimana'), findsNothing);
    expect(find.text('Elementi: 3'), findsOneWidget);
    expect(find.byKey(const Key('calendar:a1:c1')), findsOneWidget);
    expect(find.byKey(const Key('calendar:a1:c2')), findsOneWidget);
    expect(find.byKey(const Key('calendar-sync-status:a1')), findsOneWidget);
    expect(find.byKey(const Key('calendar-local-only:a1')), findsNothing); // sincronizzato
    expect(find.byKey(const Key('calendar-empty-hint')), findsNothing);
    expect(find.byKey(const Key('now-line')), findsOneWidget); // mercoledì 11, oggi

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-title')), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(title(tester), '9 – 13 novembre 2026');
    await fake.core.sse.close();
  });

  testWidgets('Account senza sincronizzazione e periodo vuoto: lo si dice', (tester) async {
    final (fake, _) = await start(tester);
    fake.status = {...fake.status, 'enabled': false, 'state': 'off'};
    fake.events.clear();
    fake.event({'type': 'calendars-changed', 'account': 'a1', 'count': 0});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-local-only:a1')), findsOneWidget);
    expect(find.byKey(const Key('calendar-empty-hint')), findsOneWidget);
    expect(find.textContaining('Sincronizza il calendario con il server (CalDAV)'), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('Viste, frecce, Oggi, Prossimi 7 giorni; vista ricordata', (tester) async {
    final (fake, settings) = await start(tester);
    await tester.tap(find.byKey(const Key('calendar-view-day')));
    await tester.pumpAndSettle();
    expect(title(tester), 'mercoledì 11 novembre 2026');
    expect(settings.calendar.view, CalendarViewKind.day);
    await tester.tap(find.byKey(const Key('calendar-next')));
    await tester.pumpAndSettle();
    expect(title(tester), 'giovedì 12 novembre 2026');

    await tester.tap(find.byKey(const Key('calendar-view-week')));
    await tester.pumpAndSettle();
    expect(title(tester), '9 – 15 novembre 2026');
    await tester.tap(find.byKey(const Key('calendar-view-month')));
    await tester.pumpAndSettle();
    expect(title(tester), 'novembre 2026');
    expect(find.byKey(const Key('month-day:2026-10-26')), findsOneWidget); // 6 settimane da lunedì 26/10
    expect(find.byKey(const Key('month-day:2026-12-6')), findsOneWidget);
    expect(find.textContaining('Fuori settimana'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-prev')));
    await tester.pumpAndSettle();
    expect(title(tester), 'ottobre 2026');
    await tester.tap(find.text('Oggi'));
    await tester.pumpAndSettle();
    expect(title(tester), 'novembre 2026');

    await tester.tap(find.text('Prossimi 7 giorni'));
    await tester.pumpAndSettle();
    expect(title(tester), '11 – 17 novembre 2026');

    // Ctrl+Alt+2 = Settimana lavorativa (come Outlook)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(settings.calendar.view, CalendarViewKind.workWeek);
    await fake.core.sse.close();
  });

  testWidgets('Calendario nascosto, colore col tasto destro, calendarietto', (tester) async {
    final (fake, settings) = await start(tester);
    await tester.tap(find.byKey(const Key('calendar:a1:c2')));
    await tester.pumpAndSettle();
    expect(settings.calendar.hidden, {'a1:c2'});
    expect(find.textContaining('Ferie'), findsNothing);
    expect(find.text('Elementi: 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar:a1:c1')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-color-5')));
    await tester.pumpAndSettle();
    expect(settings.calendar.colors['a1:c1'], 5);

    await tester.tap(find.byKey(const Key('mini-day:2026-11-25')));
    await tester.pumpAndSettle();
    expect(title(tester), '23 – 27 novembre 2026');
    await fake.core.sse.close();
  });

  Future<void> doubleTap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  final riunione = find.byKey(const Key('event:a1|c1|e1|2026-11-11T09:00:00Z'));

  testWidgets('Serie ricorrente: «Tutta la serie», finestra con ricorrenza, salvataggio che la conserva', (tester) async {
    final (fake, _) = await start(tester);
    await doubleTap(tester, riunione);
    expect(find.text('È un appuntamento ricorrente. Aprire solo questa occorrenza o tutta la serie?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('choose-series')));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentPage), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('appointment-title'))).data, 'Appuntamento - Riunione');
    expect(tester.widget<Text>(find.byKey(const Key('appointment-recurrence-text'))).data, 'Ricorrenza: Ogni settimana il mercoledì, 3 volte');
    expect(find.text('Promemoria: 15 minuti'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('appointment-summary')), 'Riunione cambiata');
    await tester.pump();
    await tester.tap(find.byKey(const Key('appointment-save')));
    await tester.pumpAndSettle();
    final body = fake.bodies['PUT /accounts/a1/calendars/c1/events/e1']!;
    expect((body['summary'], body['start'], body['end'], body['keepRecurrence'], body.containsKey('recurrence')),
        ('Riunione cambiata', '2026-11-11T10:00', '2026-11-11T11:00', true, false));
    expect(body['timeZone'], 'Europe/Rome');
    expect(find.byType(AppointmentPage), findsNothing);
    await fake.core.sse.close();
  });

  testWidgets('«Solo questa»: occorrenza aperta e salvata come eccezione', (tester) async {
    final (fake, _) = await start(tester);
    await doubleTap(tester, riunione);
    await tester.tap(find.byKey(const Key('choose-occurrence')));
    await tester.pumpAndSettle();
    expect(fake.requests, contains('GET occurrence 2026-11-11T09:00:00Z'));
    expect(tester.widget<Text>(find.byKey(const Key('appointment-title'))).data, 'Occorrenza - Riunione');
    expect(find.byKey(const Key('appointment-recurrence')), findsNothing); // niente Ricorrenza per un'occorrenza
    await tester.tap(find.byKey(const Key('appointment-start-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15:00').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appointment-save')));
    await tester.pumpAndSettle();
    final body = fake.bodies['PUT /accounts/a1/calendars/c1/events/e1/occurrence?recurrenceId=2026-11-11T09%3A00%3A00Z']!;
    expect((body['start'], body['end'], body.containsKey('keepRecurrence')), ('2026-11-11T15:00', '2026-11-11T16:00', false)); // la fine segue
    await fake.core.sse.close();
  });

  testWidgets('Nuovo appuntamento: Ctrl+N dall\'ora dopo, ricorrenza dalla finestra, calendario', (tester) async {
    final (fake, _) = await start(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentPage), findsOneWidget);
    await tester.enterText(find.byKey(const Key('appointment-summary')), 'Dentista');
    await tester.pump();
    await tester.tap(find.byKey(const Key('appointment-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lavoro').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appointment-recurrence')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recurrence-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rec-day-FR'))); // oltre a mercoledì, il giorno dell'inizio
    await tester.pumpAndSettle();
    await tester.tap(find.text('Termina dopo '));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rec-count')), '4');
    await tester.tap(find.byKey(const Key('rec-ok')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ogni settimana il mercoledì, venerdì, 4 volte'), findsOneWidget);
    await tester.tap(find.byKey(const Key('appointment-save')));
    await tester.pumpAndSettle();
    final body = fake.bodies['POST /accounts/a1/calendars/c2/events']!;
    expect((body['summary'], body['start'], body['end'], body['reminderMinutes'], body['allDay']),
        ('Dentista', '2026-11-11T11:00', '2026-11-11T12:00', 15, false));
    expect(body['recurrence'], {'frequency': 'weekly', 'interval': 1, 'days': ['WE', 'FR'], 'count': 4});
    await fake.core.sse.close();
  });

  testWidgets('Doppio clic su uno spazio vuoto e sul giorno del mese; Esc senza salvare', (tester) async {
    final (fake, _) = await start(tester);
    final slot = find.byKey(const Key('slot:2026-11-12'));
    final box = tester.getRect(slot);
    final at = Offset(box.center.dx, box.top + 14.5 * TimeGrid.hourHeight + 5); // 14:30
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentPage), findsOneWidget);
    await tester.enterText(find.byKey(const Key('appointment-summary')), 'Da non salvare');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Salvare le modifiche?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentPage), findsNothing);
    expect(fake.bodies, isEmpty);

    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appointment-save')));
    await tester.pumpAndSettle();
    expect((fake.bodies.values.single['start'], fake.bodies.values.single['end']), ('2026-11-12T14:30', '2026-11-12T15:30'));

    fake.bodies.clear();
    await tester.tap(find.byKey(const Key('calendar-view-month')));
    await tester.pumpAndSettle();
    await doubleTap(tester, find.byKey(const Key('month-day:2026-11-19')));
    await tester.tap(find.byKey(const Key('appointment-save')));
    await tester.pumpAndSettle();
    expect((fake.bodies.values.single['allDay'], fake.bodies.values.single['start'], fake.bodies.values.single['end']),
        (true, '2026-11-19', '2026-11-19'));
    await fake.core.sse.close();
  });

  testWidgets('Canc: conferma, e per un ricorrente «solo questa o la serie»', (tester) async {
    final (fake, _) = await start(tester);
    final pranzo = find.byKey(const Key('event:a1|c1|e2|'));
    await tester.ensureVisible(pranzo);
    await tester.tap(pranzo);
    await tester.pump(const Duration(milliseconds: 400)); // il clic semplice arriva dopo l'attesa del doppio clic
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text("Eliminare l'appuntamento?"), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(fake.requests.where((r) => r.startsWith('DELETE')), isEmpty);
    await tester.tap(find.byKey(const Key('calendar-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();
    expect(fake.requests, contains('DELETE /accounts/a1/calendars/c1/events/e2'));

    await tester.ensureVisible(riunione);
    await tester.tap(riunione);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('Eliminare solo questa occorrenza o tutta la serie?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('choose-occurrence')));
    await tester.pumpAndSettle();
    expect(fake.requests, contains('DELETE /accounts/a1/calendars/c1/events/e1/occurrence?recurrenceId=2026-11-11T09%3A00%3A00Z'));
    await fake.core.sse.close();
  });

  testWidgets('Calendario di sola lettura (G3, 2a): lucchetto, finestra senza modifiche, niente Canc né nuovo lì', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CalendarModel.now = () => DateTime(2026, 11, 11, 10);
    addTearDown(() => CalendarModel.now = DateTime.now);
    final fake = CalendarCore()..holidays = true;
    await tester.pumpWidget(PostinoVipApp(
        api: ApiClient(httpClient: fake.client), settings: AppSettings(MemorySettingsStore()), windowPresenter: _NoWindow()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('module-calendar')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('calendar:a1:c3')), matching: find.byKey(const Key('calendar-readonly'))),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('calendar:a1:c1')), matching: find.byKey(const Key('calendar-readonly'))),
        findsNothing);

    // Nuovo appuntamento: le festività non sono tra i calendari proposti.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    final menu = tester.widget<DropdownButton<String>>(find.byKey(const Key('appointment-calendar')));
    expect(menu.items!.map((i) => i.value), ['a1|c1', 'a1|c2']);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentPage), findsNothing);

    // Aperto: si legge, nessun Salva né Elimina, campi non modificabili; Esc chiude senza domande.
    final festa = find.byKey(const Key('event:a1|c3|e5|'));
    await doubleTap(tester, festa);
    expect(find.byKey(const Key('appointment-readonly')), findsOneWidget);
    expect(find.textContaining('«Festività in Italia» è di sola lettura'), findsOneWidget);
    expect(find.byKey(const Key('appointment-save')), findsNothing);
    expect(find.byKey(const Key('appointment-delete')), findsNothing);
    expect(find.byKey(const Key('appointment-recurrence')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('appointment-summary'))).readOnly, isTrue);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('appointment-all-day'))).onChanged, isNull);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appointment-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentPage), findsNothing);

    // Selezionato: Elimina spento, Canc non fa nulla.
    await tester.tap(festa);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.widget<RibbonLargeButton>(find.byKey(const Key('calendar-delete'))).onPressed, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text("Eliminare l'appuntamento?"), findsNothing);
    expect(fake.requests.where((r) => !r.startsWith('GET')), isEmpty);
    await fake.core.sse.close();
  });

  testWidgets('Gmail con il calendario senza permesso: striscia «Accedi di nuovo» nel Calendario (G3, 1a)', (tester) async {
    const error = "L'accesso con Google non comprende il permesso del calendario: usa «Accedi di nuovo» e permetti l'accesso "
        'al calendario.';
    final gmail = AccountConfig(
        id: 'a1', email: 'io@gmail.com', password: '', imapHost: 'imap.gmail.com', smtpHost: 'smtp.gmail.com',
        oauthProvider: 'google', refreshToken: 'RT1', calDavEnabled: true);
    final (fake, _) = await start(tester, editing: AccountsEditing(accounts: [gmail], coreAddress: '', save: (_) async {}));
    expect(find.byKey(const Key('caldav-relogin-strip')), findsNothing);
    fake.status = {...fake.status, 'state': 'error', 'error': error};
    fake.event({'type': 'calendars-changed', 'account': 'a1', 'count': 2});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('caldav-relogin-strip')), findsOneWidget);
    expect(find.textContaining('Il calendario non si sincronizza'), findsOneWidget);
    await tester.tap(find.byKey(const Key('caldav-relogin')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSetupPage), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('Prima volta: striscia e conferma; calendars-changed rilegge', (tester) async {
    final (fake, _) = await start(tester);
    fake.status = {...fake.status, 'needsConfirmation': true, 'pendingUpload': 2};
    fake.events.add(CalendarCore.occ('c1', 'e5', 'Nuovo dal server', '2026-11-10T13:00:00Z', '2026-11-10T14:00:00Z'));
    fake.event({'type': 'calendars-changed', 'account': 'a1', 'count': 1});
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('caldav-upload-strip:a1')), findsOneWidget);
    expect(find.textContaining('Nuovo dal server'), findsWidgets);
    await tester.tap(find.text('Carica sul server…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Carica sul server'));
    await tester.pumpAndSettle();
    expect(fake.requests, contains('POST /accounts/a1/calendars/sync/confirm'));
    await fake.core.sse.close();
  });

  testWidgets('Opzioni: primo giorno della settimana e giorni lavorativi', (tester) async {
    final (fake, settings) = await start(tester);
    await settings.setCalendar(settings.calendar.copyWith(firstDay: DateTime.sunday, workDays: {1, 2, 3}));
    await tester.tap(find.byKey(const Key('calendar-view-week')));
    await tester.pumpAndSettle();
    expect(title(tester), '8 – 14 novembre 2026');
    await tester.tap(find.byKey(const Key('calendar-view-workWeek')));
    await tester.pumpAndSettle();
    expect(title(tester), '9 – 11 novembre 2026'); // lun–mer
    await fake.core.sse.close();
  });

  testWidgets('Schermata dell\'account: sezione Calendario e «Verifica calendario»', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = ApiClient(
      httpClient: MockClient((request) async {
        http.Response json(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        if (request.url.path == '/account/test-caldav') return json({'ok': true, 'calendars': ['Calendario']});
        if (request.url.path == '/oauth/providers') return json([]);
        return http.Response('', 404);
      }),
    );
    AccountConfig? saved;
    final initial = AccountConfig(id: 'a1', email: 'io@example.com', password: 'x', imapHost: 'imap.example.com', smtpHost: 'smtp.example.com');
    await tester.pumpWidget(MaterialApp(home: AccountSetupPage(api: api, initial: initial, onSave: (a) async => saved = a)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('caldav-enabled')));
    await tester.tap(find.byKey(const Key('caldav-enabled')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('caldav-test')));
    await tester.tap(find.byKey(const Key('caldav-test')));
    await tester.pumpAndSettle();
    expect(find.text('Trovato: «Calendario»'), findsOneWidget);
    await tester.ensureVisible(find.text('Salva'));
    await tester.tap(find.text('Salva'));
    await tester.pump();
    expect(saved?.calDavEnabled, isTrue);
    expect(saved!.toCoreEnvironment(0)['Accounts__0__CalDav__Enabled'], 'true');
  });

  group('logica', () {
    CalendarOccurrence o(String id, int h1, int m1, int h2, int m2) => CalendarOccurrence(
      account: 'a', calendarId: 'c', eventId: id, start: DateTime(2026, 11, 11, h1, m1), end: DateTime(2026, 11, 11, h2, m2),
      allDay: false, summary: id);

    test('appuntamenti sovrapposti in colonne', () {
      final layout = layoutDay([o('a', 9, 0, 10, 0), o('b', 9, 30, 11, 0), o('c', 10, 0, 10, 30), o('d', 12, 0, 13, 0)], DateTime(2026, 11, 11));
      final byId = {for (final (x, col, cols) in layout) x.eventId: (col, cols)};
      expect(byId['a'], (0, 2));
      expect(byId['b'], (1, 2));
      expect(byId['c'], (0, 2)); // riusa la colonna di «a», finita alle 10
      expect(byId['d'], (0, 1)); // da solo
    });

    test('preferenze JSON e valori non validi', () {
      final p = CalendarPrefs.defaults.copyWith(view: CalendarViewKind.month, firstDay: 7, workDays: {1, 3}, colors: {'a:c': 2}, hidden: {'a:x'});
      final back = CalendarPrefs.fromJson(p.toJson());
      expect((back.view, back.firstDay), (CalendarViewKind.month, 7));
      expect(back.workDays, {1, 3});
      expect(back.colors, {'a:c': 2});
      expect(back.hidden, {'a:x'});
      final bad = CalendarPrefs.fromJson({'view': 'boh', 'firstDay': 9, 'workDays': [], 'workStart': 900, 'workEnd': 100});
      expect((bad.view, bad.firstDay, bad.workDays.length, bad.workStart, bad.workEnd), (CalendarViewKind.workWeek, 1, 5, 480, 1020));
    });

    test('descrizione delle ricorrenze', () {
      expect(const CalendarRecurrence(frequency: 'daily', interval: 2, until: '2026-12-31').describe(), 'Ogni 2 giorni, fino al 31/12/2026');
      expect(const CalendarRecurrence(frequency: 'monthly', week: 2, days: ['TU']).describe(), 'Ogni mese il secondo martedì');
      expect(const CalendarRecurrence(frequency: 'monthly', monthDay: 15, count: 6).describe(), 'Ogni mese il giorno 15, 6 volte');
      expect(const CalendarRecurrence(frequency: 'yearly', monthDay: 25, month: 12).describe(), 'Ogni anno il 25 dicembre');
      expect(const CalendarRecurrence(frequency: 'weekly', interval: 2, days: ['MO', 'WE']).describe(), 'Ogni 2 settimane il lunedì, mercoledì');
    });
  });
}
