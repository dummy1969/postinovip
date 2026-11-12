import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/system_notifier.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';

Map<String, dynamic> header(int uid, String subject, {bool seen = true}) =>
    {'uid': uid, 'subject': subject, 'from': 'Anna', 'date': null, 'seen': seen};

/// Core finto con due caselle: "a1" (Personale) e "b2" (Lavoro), con INBOX e Archivio ciascuna.
class TwoAccountCore {
  final sse = StreamController<List<int>>();
  final inbox = {
    'a1': [header(10, 'Mail personale')],
    'b2': [header(20, 'Mail di lavoro', seen: false)],
  };
  final requests = <String>[];
  final sent = <(String path, Map<String, dynamic> body)>[];

  void push(Map<String, dynamic> e) => sse.add(utf8.encode('data: ${jsonEncode(e)}\n\n'));

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = request.url.path;
    requests.add('${request.method} $path');
    http.StreamedResponse json(Object body) => http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(body))),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'Personale', 'address': 'io@example.com', 'configured': true},
        {'id': 'b2', 'name': 'Lavoro', 'address': 'io@lavoro.example', 'configured': true},
      ]);
    }
    final m = RegExp(r'^/accounts/(\w+)(/.*)$').firstMatch(path);
    if (m == null) return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
    final (account, rest) = (m[1]!, m[2]!);
    final items = inbox[account]!;

    if (rest == '/folders') {
      return json([
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': items.length, 'specialUse': 'inbox'},
        {'fullName': 'Archivio', 'name': 'Archivio', 'count': 0},
      ]);
    }
    if (rest == '/folders/INBOX/messages') {
      return json({'total': items.length, 'offset': 0, 'limit': 50, 'items': items});
    }
    if (rest == '/folders/Archivio/messages') return json({'total': 0, 'offset': 0, 'limit': 50, 'items': []});
    if (RegExp(r'^/messages/INBOX/\d+/seen$').hasMatch(rest)) return json({'seen': true});
    if (RegExp(r'^/messages/INBOX/\d+/draft$').hasMatch(rest)) {
      return json({
        'to': ['anna@example.com'],
        'cc': [],
        'subject': 'Re: x',
        'body': '',
        'references': [],
        'forwardAttachments': [
          {'index': 0, 'fileName': 'fattura.pdf', 'contentType': 'application/pdf'},
        ],
      });
    }
    if (RegExp(r'^/messages/INBOX/\d+$').hasMatch(rest)) {
      final uid = int.parse(rest.split('/').last);
      final h = items.firstWhere((i) => i['uid'] == uid);
      return json({...h, 'to': <String>[], 'cc': <String>[], 'textBody': 'Testo ${h['subject']}', 'attachments': []});
    }
    if (rest == '/send') {
      final body = jsonDecode(utf8.decode(await bodyStream.toBytes())) as Map<String, dynamic>;
      sent.add((path, body));
      return json({'serverResponse': '250 OK', 'savedTo': 'Posta inviata'});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

class FakeNotifier implements MailNotifier {
  final shown = <(String, String)>[];
  final payloads = <String?>[];
  final _clicks = StreamController<String?>.broadcast();

  @override
  Future<void> show(String title, String body, {String? payload}) async {
    shown.add((title, body));
    payloads.add(payload);
  }

  @override
  Stream<String?> get clicks => _clicks.stream;

  void click(int index) => _clicks.add(payloads[index]);
}

class FakePresenter implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<TwoAccountCore> start(WidgetTester tester, {AppSettings? settings, MailNotifier? notifier}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = TwoAccountCore();
  await tester.pumpWidget(PostinoVipApp(
    api: ApiClient(httpClient: core.client),
    settings: settings,
    notifier: notifier,
    windowPresenter: FakePresenter(),
  ));
  await tester.pumpAndSettle();
  return core;
}

/// La riga "Posta in arrivo" (INBOX) dell'account in posizione [accountIndex] nell'albero.
Finder inboxOf(int accountIndex) => find.text('Posta in arrivo').at(accountIndex);

/// "Invia" e poi "Invia" nella finestra di conferma.
Future<void> sendWithConfirm(WidgetTester tester) async {
  await tester.tap(find.text('Invia'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Invia').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('albero: due account con le loro cartelle; all\'avvio INBOX del primo', (tester) async {
    final core = await start(tester);

    expect(find.text('Personale'), findsWidgets);
    expect(find.text('Lavoro'), findsOneWidget);
    expect(find.text('Posta in arrivo'), findsNWidgets(2));
    expect(find.text('Mail personale'), findsOneWidget);
    expect(find.text('Elementi: 1'), findsOneWidget);
    expect(core.requests, contains('GET /accounts/a1/folders/INBOX/messages'));
    await core.sse.close();
  });

  testWidgets('cartella del secondo account: richieste a /accounts/b2, lettura e "letto" sulla sua casella',
      (tester) async {
    final core = await start(tester);

    await tester.tap(inboxOf(1));
    await tester.pumpAndSettle();
    expect(find.text('Elementi: 1'), findsOneWidget);
    expect(find.text('Mail di lavoro'), findsOneWidget);
    expect(find.text('Mail personale'), findsNothing);

    await tester.tap(find.text('Mail di lavoro'));
    await tester.pumpAndSettle();
    expect(find.text('Testo Mail di lavoro'), findsOneWidget);
    expect(core.requests, contains('PUT /accounts/b2/messages/INBOX/20/seen'));
    await core.sse.close();
  });

  testWidgets('risposta da una mail del secondo account: bozza e invio da quella casella', (tester) async {
    final core = await start(tester);
    await tester.tap(inboxOf(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mail di lavoro'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Rispondi'));
    await tester.pumpAndSettle();
    expect(core.requests, contains('GET /accounts/b2/messages/INBOX/20/draft'));
    expect(find.text('Lavoro <io@lavoro.example>'), findsOneWidget); // "Da:" = account della mail

    await sendWithConfirm(tester);
    expect(core.sent.single.$1, '/accounts/b2/send');
    await core.sse.close();
  });

  testWidgets('"Nuovo" propone l\'account della cartella aperta; "Da:" lo cambia', (tester) async {
    final core = await start(tester);
    await tester.tap(inboxOf(1)); // cartella del secondo account
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuovo messaggio'));
    await tester.pumpAndSettle();
    expect(find.text('Lavoro <io@lavoro.example>'), findsOneWidget); // proposto

    await tester.tap(find.text('Lavoro <io@lavoro.example>'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personale <io@example.com>').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'dest@example.com');
    await tester.pump();

    await tester.tap(find.text('Invia'));
    await tester.pumpAndSettle();
    expect(find.text('Da: Personale <io@example.com>'), findsOneWidget); // nel riepilogo
    await tester.tap(find.widgetWithText(FilledButton, 'Invia').last);
    await tester.pumpAndSettle();
    expect(core.sent.single.$1, '/accounts/a1/send');
    await core.sse.close();
  });

  testWidgets('inoltro con mittente cambiato: allegati dalla casella originale', (tester) async {
    final core = await start(tester);
    await tester.tap(inboxOf(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mail di lavoro'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Inoltra'));
    await tester.pumpAndSettle();
    expect(find.text('Lavoro <io@lavoro.example>'), findsOneWidget); // parte dall'account della mail
    await tester.tap(find.text('Lavoro <io@lavoro.example>'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personale <io@example.com>').last);
    await tester.pumpAndSettle();
    await sendWithConfirm(tester);

    final (path, body) = core.sent.single;
    expect(path, '/accounts/a1/send');
    expect(body['forwardAttachments'], {'account': 'b2', 'folder': 'INBOX', 'uid': 20, 'indexes': [0]});
    await core.sse.close();
  });

  testWidgets('account chiuso: cartelle nascoste e scelta ricordata al riavvio', (tester) async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    final core = await start(tester, settings: settings);

    await tester.tap(find.text('Lavoro'));
    await tester.pumpAndSettle();
    expect(find.text('Posta in arrivo'), findsOneWidget); // solo quella del primo account
    expect(await store.read('collapsedAccounts'), 'b2');
    await core.sse.close();

    final reloaded = AppSettings(store);
    await reloaded.load();
    expect(reloaded.collapsedAccounts, {'b2'});

    await reloaded.setAccountExpanded('b2', true);
    expect(await store.read('collapsedAccounts'), '');
  });

  testWidgets('aggiornamento automatico: avviso solo accanto all\'account non collegato', (tester) async {
    final core = await start(tester);
    core.push({'type': 'watch-status', 'account': 'a1', 'connected': true});
    core.push({'type': 'watch-status', 'account': 'b2', 'connected': false});
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.sync_disabled), findsOneWidget);
    expect(find.byTooltip('Aggiornamento automatico non attivo per io@lavoro.example: '
        'le nuove mail compaiono solo con "Aggiorna"'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('posta nuova nel secondo account: notifica con il suo nome, clic apre la sua INBOX', (tester) async {
    final notifier = FakeNotifier();
    final core = await start(tester, notifier: notifier);

    // Punto di partenza di b2: la sua INBOX viene interrogata al primo cambiamento.
    core.push({'type': 'mailbox-changed', 'account': 'b2', 'folder': 'INBOX', 'count': 1});
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(notifier.shown, isEmpty);

    core.inbox['b2'] = [header(21, 'Urgente', seen: false), ...core.inbox['b2']!];
    core.push({'type': 'mailbox-changed', 'account': 'b2', 'folder': 'INBOX', 'count': 2});
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(notifier.shown, [('Nuova mail da Anna · Lavoro', 'Urgente')]);

    notifier.click(0);
    await tester.pumpAndSettle();
    expect(find.text('Elementi: 2'), findsOneWidget);
    expect(find.text('Testo Urgente'), findsOneWidget);
    await core.sse.close();
  });
}
