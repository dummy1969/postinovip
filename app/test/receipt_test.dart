import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

/// Core finto: INBOX con una mail che chiede la conferma (uid 2), una già trattata (3) e una senza richiesta (4);
/// Posta indesiderata con una che la chiede (5).
class ReceiptCore {
  final sse = StreamController<List<int>>();
  final answers = <String, Map<String, dynamic>>{};
  int status = 200;

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = request.url.path;
    final body = await bodyStream.toBytes();
    final now = DateTime.now().toUtc().toIso8601String();
    http.StreamedResponse json(Object value, [int code = 200]) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(value))),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    Map<String, dynamic> item(int uid, String subject) =>
        {'uid': uid, 'subject': subject, 'from': 'Anna', 'date': now, 'received': now, 'seen': true};
    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'io@example.com', 'address': 'io@example.com', 'configured': true, 'online': true},
      ]);
    }
    if (path == '/accounts/a1/folders') {
      return json([
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 3, 'unread': 0, 'specialUse': 'inbox'},
        {'fullName': 'Spam', 'name': 'Spam', 'count': 1, 'unread': 0, 'specialUse': 'junk'},
      ]);
    }
    if (path == '/accounts/a1/folders/INBOX/messages') {
      return json({
        'total': 3, 'offset': 0, 'limit': 50,
        'items': [item(2, 'Richiesta'), item(3, 'Trattata'), item(4, 'Normale')],
      });
    }
    if (path == '/accounts/a1/folders/Spam/messages') {
      return json({'total': 1, 'offset': 0, 'limit': 50, 'items': [item(5, 'Sospetta')]});
    }
    final detail = RegExp(r'^/accounts/a1/messages/(INBOX|Spam)/(\d)$').firstMatch(path);
    if (detail != null) {
      final uid = int.parse(detail.group(2)!);
      return json({
        'uid': uid, 'subject': 'x', 'from': 'Anna', 'to': ['io@example.com'], 'cc': [], 'date': now,
        'textBody': 'Ciao', 'htmlBody': null, 'hasRemoteImages': false, 'attachments': [],
        'receiptTo': uid == 4 ? null : 'anna@example.com',
        'receiptHandled': uid == 3,
      });
    }
    final receipt = RegExp(r'^/accounts/a1/messages/INBOX/(\d)/receipt$').firstMatch(path);
    if (receipt != null && request.method == 'POST') {
      answers[receipt.group(1)!] = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
      if (status != 200) return json({'title': 'Non connesso', 'detail': 'Server non raggiungibile'}, status);
      return json({'sent': answers[receipt.group(1)!]!['send']});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

Future<(ReceiptCore, AppSettings)> _start(WidgetTester tester, {ReceiptMode mode = ReceiptMode.ask}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = ReceiptCore();
  final settings = AppSettings(MemorySettingsStore());
  await settings.setReceiptMode(mode);
  await tester.pumpWidget(
    PostinoVipApp(api: ApiClient(httpClient: core.client), settings: settings, windowPresenter: _NoWindow()),
  );
  await tester.pumpAndSettle();
  return (core, settings);
}

Future<void> _open(WidgetTester tester, String subject) async {
  await tester.tap(find.text(subject));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('«Chiedi ogni volta»: striscia con Invia e Non inviare, una sola risposta', (tester) async {
    final (core, _) = await _start(tester);
    await _open(tester, 'Richiesta');
    expect(find.byKey(const Key('receipt-banner')), findsOneWidget);
    expect(find.text('Anna ha chiesto una conferma di lettura.'), findsOneWidget);
    expect(core.answers, isEmpty); // niente da solo

    await tester.tap(find.byKey(const Key('receipt-send')));
    await tester.pumpAndSettle();
    expect(core.answers['2'], {'send': true});
    expect(find.byKey(const Key('receipt-banner')), findsNothing);

    // Riaperta: già trattata, nessuna striscia. Mail già trattata o senza richiesta: niente.
    await _open(tester, 'Normale');
    expect(find.byKey(const Key('receipt-banner')), findsNothing);
    await _open(tester, 'Richiesta');
    expect(find.byKey(const Key('receipt-banner')), findsNothing);
    await _open(tester, 'Trattata');
    expect(find.byKey(const Key('receipt-banner')), findsNothing);
    expect(core.answers.keys, ['2']);
    await core.sse.close();
  });

  testWidgets('«Non inviare» e errore del core: striscia di nuovo, con l\'errore', (tester) async {
    final (core, _) = await _start(tester);
    core.status = 503;
    await _open(tester, 'Richiesta');
    await tester.tap(find.byKey(const Key('receipt-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Conferma di lettura non inviata'), findsOneWidget);
    expect(find.byKey(const Key('receipt-banner')), findsOneWidget); // si può riprovare

    core.status = 200;
    await tester.tap(find.byKey(const Key('receipt-decline')));
    await tester.pumpAndSettle();
    expect(core.answers['2'], {'send': false});
    expect(find.byKey(const Key('receipt-banner')), findsNothing);
    await core.sse.close();
  });

  testWidgets('«Invia sempre»: inviata da sola all\'apertura, senza striscia', (tester) async {
    final (core, settings) = await _start(tester, mode: ReceiptMode.always);
    await _open(tester, 'Richiesta');
    expect(core.answers['2'], {'send': true, 'automatic': true});
    expect(find.byKey(const Key('receipt-banner')), findsNothing);
    await _open(tester, 'Trattata');
    await _open(tester, 'Normale');
    expect(core.answers.keys, ['2']);
    expect(settings.receiptMode, ReceiptMode.always);
    await core.sse.close();
  });

  testWidgets('«Non inviare mai»: registrata da sola come non inviata', (tester) async {
    final (core, _) = await _start(tester, mode: ReceiptMode.never);
    await _open(tester, 'Richiesta');
    expect(core.answers['2'], {'send': false, 'automatic': true});
    expect(find.byKey(const Key('receipt-banner')), findsNothing);
    await core.sse.close();
  });

  testWidgets('Posta indesiderata: mai la striscia né la risposta', (tester) async {
    final (core, _) = await _start(tester, mode: ReceiptMode.always);
    await tester.tap(find.text('Spam'));
    await tester.pumpAndSettle();
    await _open(tester, 'Sospetta');
    expect(find.byKey(const Key('receipt-banner')), findsNothing);
    expect(core.answers, isEmpty);
    await core.sse.close();
  });

  testWidgets('File → Opzioni: «Conferme di lettura»', (tester) async {
    final (core, settings) = await _start(tester);
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-tab-mail')));
    await tester.pumpAndSettle();
    final request = find.byKey(const Key('settings-request-receipt'));
    await tester.ensureVisible(request);
    await tester.pumpAndSettle();
    await tester.tap(request);
    await tester.pumpAndSettle();
    final never = find.byKey(const Key('settings-receipt-never'));
    await tester.ensureVisible(never);
    await tester.pumpAndSettle();
    await tester.tap(never);
    await tester.pumpAndSettle();
    expect((settings.requestReadReceipt, settings.receiptMode), (true, ReceiptMode.never));
    await core.sse.close();
  });

  test('opzioni ricordate; valore illeggibile = «Chiedi ogni volta»', () async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    await settings.setRequestReadReceipt(true);
    await settings.setReceiptMode(ReceiptMode.never);
    final again = AppSettings(store);
    await again.load();
    expect((again.requestReadReceipt, again.receiptMode), (true, ReceiptMode.never));
    await store.write('receiptMode', 'boh');
    await again.load();
    expect(again.receiptMode, ReceiptMode.ask);
  });
}
