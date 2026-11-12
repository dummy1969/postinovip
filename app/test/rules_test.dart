import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/models/mail_rule.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/rules_dialog.dart';

/// Core finto con due account, cartelle, una mail e le regole (GET/PUT …/rules).
class RulesCore {
  final sse = StreamController<List<int>>();
  final rules = <String, List<Map<String, dynamic>>>{'a1': [], 'b2': []};
  final puts = <String, List<dynamic>>{};

  /// "Esegui regole ora": richieste ricevute, avanzamento simulato (una mail a ogni lettura) e interruzione.
  final runs = <Map<String, dynamic>>[];
  int runTotal = 3, runChecked = 0;
  bool runCancelled = false;

  late final client = MockClient.streaming((request, bodyStream) async {
    final url = request.url;
    final body = await utf8.decodeStream(bodyStream);
    http.StreamedResponse json(Object value, [int status = 200]) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(value))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (url.path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (url.path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'Personale', 'address': 'io@example.com', 'configured': true},
        {'id': 'b2', 'name': 'Lavoro', 'address': 'io@lavoro.example', 'configured': true},
      ]);
    }
    final m = RegExp(r'^/accounts/(\w+)(/.*)$').firstMatch(url.path);
    if (m == null) return json({}, 404);
    final (account, rest) = (m[1]!, m[2]!);
    if (rest == '/folders') {
      return json([
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 1, 'specialUse': 'inbox'},
        {'fullName': 'Archivio', 'name': 'Archivio', 'count': 0},
        {'fullName': 'Archivio/Fatture', 'name': 'Fatture', 'count': 0},
        {'fullName': 'Posta eliminata', 'name': 'Posta eliminata', 'count': 0, 'specialUse': 'trash'},
      ]);
    }
    if (rest == '/rules' && request.method == 'GET') return json(rules[account]!);
    if (rest == '/rules' && request.method == 'PUT') {
      final list = jsonDecode(body) as List;
      puts[account] = list;
      var n = 0;
      rules[account] = [
        for (final r in list.cast<Map<String, dynamic>>())
          {...r, 'id': (r['id'] as String).isEmpty ? 'id${n++}' : r['id']},
      ];
      return json(rules[account]!);
    }
    if (rest == '/rules/run' && request.method == 'POST') {
      runs.add(jsonDecode(body) as Map<String, dynamic>);
      return json({'id': 'job1', 'folders': ['INBOX']}, 202);
    }
    if (rest == '/rules/run/job1' && request.method == 'GET') {
      if (!runCancelled && runChecked < runTotal) runChecked++;
      final done = runCancelled || runChecked == runTotal;
      return json({
        'id': 'job1', 'checked': runChecked, 'total': runTotal, 'applied': runChecked == runTotal ? 1 : 0,
        'failed': 0, 'done': done, 'cancelled': runCancelled, 'error': null,
      });
    }
    if (rest == '/rules/run/job1' && request.method == 'DELETE') {
      runCancelled = true;
      return http.StreamedResponse(const Stream.empty(), 202);
    }
    if (rest.startsWith('/folders/') && rest.endsWith('/messages')) {
      return json({
        'total': 1,
        'offset': 0,
        'limit': 50,
        'items': [
          {'uid': 7, 'subject': 'Fattura ottobre', 'from': 'Anna Rossi', 'date': null, 'seen': true},
        ],
      });
    }
    if (RegExp(r'^/messages/[^/]+/\d+$').hasMatch(rest)) {
      return json({
        'uid': 7,
        'subject': 'Fattura ottobre',
        'from': 'Anna Rossi',
        'fromAddress': 'anna@fornitore.it',
        'to': ['io@example.com'],
        'cc': <String>[],
        'date': null,
        'textBody': 'In allegato',
        'htmlBody': null,
        'hasRemoteImages': false,
        'attachments': [],
      });
    }
    return json({}, 404);
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<RulesCore> start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = RulesCore();
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

Future<void> openRules(WidgetTester tester) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gestisci regole e avvisi'));
  await tester.pumpAndSettle();
}

Future<void> tapTab(WidgetTester tester, String tab) async {
  await tester.tap(find.widgetWithText(Tab, tab));
  await tester.pumpAndSettle();
}

void main() {
  test('descrizione leggibile della regola', () {
    final settings = AppSettings(MemorySettingsStore());
    const rule = MailRule(
      name: 'Fatture',
      conditions: RuleConditions(from: ['fornitore.it', 'altro.it'], hasAttachments: true),
      exceptions: RuleConditions(subjectContains: ['urgente']),
      actions: RuleActions(moveTo: 'Archivio/Fatture', markRead: true, category: 4, stopProcessing: true),
    );
    expect(
      RulesUi.describe(rule, settings),
      'Se da «fornitore.it» o «altro.it» e con allegati, tranne se oggetto contiene «urgente» '
      '→ sposta in Archivio/Fatture, segna come letta, categoria ${settings.categoryName(4)}, nessun\'altra regola',
    );
    expect(
      RulesUi.describe(const MailRule(name: 'x', actions: RuleActions(flag: true)), settings),
      'Tutte le mail → contrassegna',
    );
  });

  testWidgets('nuova regola: condizione, cartella dall\'albero, salvata con OK', (tester) async {
    final core = await start(tester);
    await openRules(tester);
    expect(find.text('Regole e avvisi'), findsOneWidget);
    expect(find.textContaining('Nessuna regola'), findsOneWidget);

    await tester.tap(find.text('Nuova regola…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rule-name')), 'Fatture');
    await tester.enterText(find.byKey(const Key('cond-from-text')), 'fornitore.it; altro.it');
    await tester.pump();
    await tapTab(tester, 'Azioni');
    await tester.tap(find.byKey(const Key('act-move-folder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-to:Archivio/Fatture')));
    await tester.pump();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('act-read')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rule-ok')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Se da «fornitore.it» o «altro.it» → sposta in Archivio/Fatture, segna come letta'),
      findsOneWidget,
    );
    expect(core.puts, isEmpty); // si salva solo con OK
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    final saved = core.puts['a1']!.single as Map<String, dynamic>;
    expect(saved['name'], 'Fatture');
    expect(saved['conditions']['from'], ['fornitore.it', 'altro.it']);
    expect(saved['actions']['moveTo'], 'Archivio/Fatture');
    expect(saved['actions']['markRead'], isTrue);
    expect(find.text('Regole e avvisi'), findsNothing);
    await core.sse.close();
  });

  testWidgets('controlli: nome, azione, cartella; senza condizioni chiede conferma', (tester) async {
    final core = await start(tester);
    await openRules(tester);
    await tester.tap(find.text('Nuova regola…'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rule-ok')));
    await tester.pump();
    expect(find.text('Scrivi il nome della regola.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('rule-name')), 'Tutte');
    await tester.tap(find.byKey(const Key('rule-ok')));
    await tester.pump();
    expect(find.textContaining('almeno un\'azione'), findsOneWidget);

    await tapTab(tester, 'Azioni');
    await tester.tap(find.byKey(const Key('act-move')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rule-ok')));
    await tester.pump();
    expect(find.text('Scegli la cartella in cui spostare o copiare.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('act-move')));
    await tester.tap(find.byKey(const Key('act-flag')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('rule-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Regola per tutte le mail'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('Nuova regola'), findsOneWidget); // resta aperta
    await tester.tap(find.byKey(const Key('rule-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sì'));
    await tester.pumpAndSettle();
    expect(find.text('Tutte le mail → contrassegna'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('elenco: attiva/disattiva, ordine, elimina con conferma, altro account', (tester) async {
    final core = await start(tester);
    core.rules['a1'] = [
      for (final n in ['Prima', 'Seconda', 'Terza'])
        MailRule(name: n, actions: const RuleActions(flag: true)).toJson()..['id'] = n.toLowerCase(),
    ];
    core.rules['b2'] = [(const MailRule(name: 'Lavoro', actions: RuleActions(markRead: true)).toJson())..['id'] = 'l'];
    await openRules(tester);

    await tester.tap(find.text('Terza'));
    await tester.pump();
    await tester.tap(find.byTooltip('Sposta su'));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).first); // "Prima" disattivata
    await tester.pump();
    await tester.tap(find.text('Seconda'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Elimina'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare la regola?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rules-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Posta in arrivo - Lavoro').last);
    await tester.pumpAndSettle();
    expect(find.text('Lavoro'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    final saved = core.puts['a1']!.cast<Map<String, dynamic>>();
    expect(saved.map((r) => r['name']), ['Prima', 'Terza']);
    expect(saved.first['enabled'], isFalse);
    expect(core.puts.containsKey('b2'), isFalse); // non modificato: non salvato
    await core.sse.close();
  });

  testWidgets('"Crea regola…" sulla mail aperta: mittente attivo, oggetto pronto da attivare', (tester) async {
    final core = await start(tester);
    core.rules['a1'] = [(const MailRule(name: 'Esistente', actions: RuleActions(flag: true)).toJson())..['id'] = 'e'];
    await tester.tap(find.text('Fattura ottobre').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Regole'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crea regola…'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byKey(const Key('rule-name'))).controller!.text, 'Fattura ottobre');
    expect(tester.widget<TextField>(find.byKey(const Key('cond-from-text'))).controller!.text, 'anna@fornitore.it');
    expect(tester.widget<Checkbox>(find.byKey(const Key('cond-from'))).value, isTrue);
    expect(tester.widget<TextField>(find.byKey(const Key('cond-subject-text'))).controller!.text, 'Fattura ottobre');
    expect(tester.widget<Checkbox>(find.byKey(const Key('cond-subject'))).value, isFalse);

    await tapTab(tester, 'Azioni');
    await tester.tap(find.byKey(const Key('act-category')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rule-ok')));
    await tester.pumpAndSettle();

    final saved = core.puts['a1']!.cast<Map<String, dynamic>>();
    expect(saved.map((r) => r['name']), ['Esistente', 'Fattura ottobre']); // aggiunta in fondo
    expect(saved.last['conditions']['from'], ['anna@fornitore.it']);
    expect(saved.last['conditions']['subjectContains'], isNull);
    expect(saved.last['actions']['category'], 1);
    expect(find.textContaining('Regola «Fattura ottobre» creata'), findsOneWidget);
    await core.sse.close();
  });

  group('Esegui regole ora (R3)', () {
    List<Map<String, dynamic>> twoRules() => [
      (const MailRule(name: 'Fatture', actions: RuleActions(flag: true)).toJson())..['id'] = 'f',
      (const MailRule(name: 'Vecchia', enabled: false, actions: RuleActions(markRead: true)).toJson())..['id'] = 'v',
    ];

    testWidgets('scelte, avanzamento e esito; poi le cartelle si ricaricano', (tester) async {
      final core = await start(tester);
      core.rules['a1'] = twoRules();
      await openRules(tester);
      await tester.tap(find.byKey(const Key('rules-run-now')));
      await tester.pumpAndSettle();

      expect(find.text('Vecchia (disattivata)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('run-rule:f'))); // tolta "Fatture"
      await tester.tap(find.byKey(const Key('run-subfolders')));
      await tester.tap(find.byKey(const Key('run-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Messaggi da leggere').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-start')));
      await tester.pump();

      expect(core.runs.single, {'ruleIds': ['v'], 'folder': 'INBOX', 'includeSubfolders': true, 'filter': 'Unread'});
      expect(find.text('Interrompi'), findsOneWidget);
      await tester.pump(RunRulesDialog.pollInterval);
      await tester.pump();
      expect(find.text('Esaminate 1 mail su 3'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.pump(RunRulesDialog.pollInterval);
        await tester.pump();
      }
      expect(find.text('Fatto: esaminate 3 mail, 1 spostate o modificate.'), findsOneWidget);
      expect(find.text('Interrompi'), findsNothing);
      await tester.tap(find.text('Chiudi'));
      await tester.pumpAndSettle();
      expect(find.text('Regole e avvisi'), findsOneWidget);
      await core.sse.close();
    });

    testWidgets('Interrompi: il core si ferma e l\'esito lo dice', (tester) async {
      final core = await start(tester)
        ..runTotal = 100;
      core.rules['a1'] = twoRules();
      await openRules(tester);
      await tester.tap(find.byKey(const Key('rules-run-now')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-start')));
      await tester.pump();
      await tester.pump(RunRulesDialog.pollInterval);
      await tester.pump();

      await tester.tap(find.text('Interrompi'));
      await tester.pump();
      await tester.pump(RunRulesDialog.pollInterval);
      await tester.pump();

      expect(core.runCancelled, isTrue);
      expect(find.textContaining('Interrotta: esaminate 1 mail su 100'), findsOneWidget);
      await tester.tap(find.text('Chiudi'));
      await tester.pumpAndSettle();
      await core.sse.close();
    });

    testWidgets('con modifiche non salvate le salva prima di eseguire', (tester) async {
      final core = await start(tester);
      core.rules['a1'] = twoRules();
      await openRules(tester);
      await tester.tap(find.byType(Checkbox).first); // "Fatture" disattivata, non salvata
      await tester.pump();

      await tester.tap(find.byKey(const Key('rules-run-now')));
      await tester.pumpAndSettle();

      expect(core.puts['a1']!.cast<Map<String, dynamic>>().first['enabled'], isFalse);
      expect(find.text('Fatture (disattivata)'), findsOneWidget);
      await tester.tap(find.text('Annulla').last); // quella della finestra "Esegui regole ora", sopra
      await tester.pumpAndSettle();
      await core.sse.close();
    });
  });
}
