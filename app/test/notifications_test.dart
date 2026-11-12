import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'single_account_core.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/models/message_header.dart';
import 'package:postinovip/notify/new_mail_notifications.dart';
import 'package:postinovip/notify/system_notifier.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';

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

  /// Simula il clic dell'utente sulla notifica [index].
  void click(int index) => _clicks.add(payloads[index]);
}

class FakePresenter implements WindowPresenter {
  int presented = 0;

  @override
  Future<void> present() async => presented++;
}

MessageHeader mail(int uid, String from, String subject) =>
    MessageHeader(uid: uid, subject: subject, from: from, date: null, seen: false);

Map<String, dynamic> header(int uid, String subject, {bool seen = false}) => {
  'uid': uid,
  'subject': subject,
  'from': 'Anna',
  'date': null,
  'seen': seen,
};

/// Core finto con INBOX e Archivio; eventi SSE spinti dal test.
class FakeCore {
  final sse = StreamController<List<int>>();
  final seenPuts = <String>[];
  List<Map<String, dynamic>> inbox = [header(2, 'Vecchia 2', seen: true), header(1, 'Vecchia 1')];

  void push(Map<String, dynamic> e) => sse.add(utf8.encode('data: ${jsonEncode(e)}\n\n'));

  late final client = MockClient.streaming((request, _) async {
    http.StreamedResponse json(Object body) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    switch (request.url.path) {
      case '/events':
        return http.StreamedResponse(sse.stream, 200);
      case '/folders':
        return json([
          {'fullName': 'Archivio', 'name': 'Archivio', 'count': 0},
          {'fullName': 'INBOX', 'name': 'INBOX', 'count': inbox.length, 'specialUse': 'inbox'},
        ]);
      case '/folders/INBOX/messages':
        return json({'total': inbox.length, 'offset': 0, 'limit': 50, 'items': inbox});
      case '/folders/Archivio/messages':
        return json({'total': 0, 'offset': 0, 'limit': 50, 'items': []});
    }
    final detail = RegExp(r'^/messages/INBOX/(\d+)(/seen)?$').firstMatch(request.url.path);
    if (detail != null) {
      final uid = int.parse(detail[1]!);
      if (detail[2] != null) {
        seenPuts.add(request.url.path);
        return json({'seen': true});
      }
      final h = inbox.firstWhere((m) => m['uid'] == uid);
      return json({...h, 'to': <String>[], 'cc': <String>[], 'textBody': 'Testo ${h['subject']}', 'attachments': []});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

void main() {
  group('NewMailNotifications', () {
    Future<FakeNotifier> run(
      NotifyMode mode, {
      required bool focused,
      required List<MessageHeader> mails,
      String account = 'main',
      String? label,
    }) async {
      final settings = AppSettings(MemorySettingsStore());
      await settings.setNotifyMode(mode);
      final notifier = FakeNotifier();
      await NewMailNotifications(settings: settings, notifier: notifier, isWindowFocused: () => focused)
          .handle(mails, account: account, accountLabel: label);
      return notifier;
    }

    final one = [mail(5, 'Mario', 'Fattura')];

    test('Sempre: notifica anche con la finestra in primo piano', () async {
      expect((await run(NotifyMode.always, focused: true, mails: one)).shown, [('Nuova mail da Mario', 'Fattura')]);
    });

    test('Solo senza focus: nessuna notifica con la finestra in primo piano', () async {
      expect((await run(NotifyMode.unfocused, focused: true, mails: one)).shown, isEmpty);
      expect((await run(NotifyMode.unfocused, focused: false, mails: one)).shown, hasLength(1));
    });

    test('payload: una mail -> account, cartella e UID; più mail -> account e cartella', () async {
      final single = await run(NotifyMode.always, focused: false, mails: one, account: 'b2');
      final target = NotificationTarget.decode(single.payloads.single)!;
      expect((target.account, target.folder, target.uid), ('b2', 'INBOX', 5));

      final many = await run(NotifyMode.always, focused: false, mails: [mail(1, 'A', 'a'), mail(2, 'B', 'b')]);
      final t2 = NotificationTarget.decode(many.payloads.single)!;
      expect((t2.account, t2.folder, t2.uid), ('main', 'INBOX', null));

      // Notifica di una versione precedente (senza account): primo account.
      expect(NotificationTarget.decode('{"folder":"INBOX","uid":3}')!.account, isNull);

      expect(NotificationTarget.decode(null), isNull); // "Prova notifica"
      expect(NotificationTarget.decode('non json'), isNull);
    });

    test('più account: nome dell\'account nel titolo', () async {
      final n = await run(NotifyMode.always, focused: false, mails: one, account: 'b2', label: 'Lavoro');
      expect(n.shown, [('Nuova mail da Mario · Lavoro', 'Fattura')]);
    });

    test('Mai: nessuna notifica', () async {
      expect((await run(NotifyMode.never, focused: false, mails: one)).shown, isEmpty);
    });

    test('più mail: una sola notifica riassuntiva', () async {
      final mails = [for (var i = 1; i <= 5; i++) mail(i, 'M$i', 'O$i')];
      final shown = (await run(NotifyMode.always, focused: true, mails: mails)).shown.single;
      expect(shown.$1, '5 nuove mail');
      expect(shown.$2, 'M1: O1\nM2: O2\nM3: O3\n…e altre 2');
    });
  });

  test('AppSettings: predefinito Sempre, salvataggio e valore sconosciuto', () async {
    final store = MemorySettingsStore();
    final s = AppSettings(store);
    await s.load();
    expect(s.notifyMode, NotifyMode.always);

    await s.setNotifyMode(NotifyMode.unfocused);
    final reloaded = AppSettings(store);
    await reloaded.load();
    expect(reloaded.notifyMode, NotifyMode.unfocused);

    await store.write('notifyMode', 'valore-di-una-versione-futura');
    await reloaded.load();
    expect(reloaded.notifyMode, NotifyMode.always);
  });

  Future<(FakeCore, FakeNotifier)> start(WidgetTester tester, {WindowPresenter? presenter}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final core = FakeCore();
    final notifier = FakeNotifier();
    await tester.pumpWidget(
      PostinoVipApp(
        api: ApiClient(httpClient: SingleAccountCore(core.client)),
        notifier: notifier,
        windowPresenter: presenter ?? FakePresenter(),
      ),
    );
    await tester.pumpAndSettle();
    return (core, notifier);
  }

  Future<void> arrive(WidgetTester tester, FakeCore core, Map<String, dynamic> newHeader) async {
    core.inbox = [newHeader, ...core.inbox];
    core.push({'type': 'mailbox-changed', 'folder': 'INBOX', 'count': core.inbox.length});
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('avvio senza notifiche; mail nuova non letta -> notifica', (tester) async {
    final (core, notifier) = await start(tester);
    expect(notifier.shown, isEmpty); // "Vecchia 1" è non letta ma c'era già

    await arrive(tester, core, header(3, 'Benvenuto'));
    expect(notifier.shown, [('Nuova mail da Anna', 'Benvenuto')]);

    // Già letta altrove (es. dal telefono) prima che l'app la veda: nessuna notifica.
    await arrive(tester, core, header(4, 'Letta altrove', seen: true));
    expect(notifier.shown, hasLength(1));
    await core.sse.close();
  });

  testWidgets('con un\'altra cartella aperta la notifica arriva lo stesso', (tester) async {
    final (core, notifier) = await start(tester);
    await tester.tap(find.text('Archivio'));
    await tester.pumpAndSettle();

    await arrive(tester, core, header(3, 'Mentre ero in Archivio'));

    expect(notifier.shown, [('Nuova mail da Anna', 'Mentre ero in Archivio')]);
    await core.sse.close();
  });

  testWidgets('impostazioni: "Mai" disattiva le notifiche', (tester) async {
    final (core, notifier) = await start(tester);

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-tab-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('Notifiche di nuova posta'), findsOneWidget);
    await tester.tap(find.text('Mai'));
    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();

    await arrive(tester, core, header(3, 'Silenziosa'));
    expect(notifier.shown, isEmpty);
    expect(find.text('Silenziosa'), findsOneWidget); // la lista si aggiorna comunque
    await core.sse.close();
  });

  testWidgets('clic sulla notifica: primo piano, INBOX e mail aperta (quindi letta)', (tester) async {
    final presenter = FakePresenter();
    final (core, notifier) = await start(tester, presenter: presenter);
    await tester.tap(find.text('Archivio'));
    await tester.pumpAndSettle();
    await arrive(tester, core, header(3, 'Da aprire'));

    notifier.click(0);
    await tester.pumpAndSettle();

    expect(presenter.presented, 1);
    expect(find.text('Testo Da aprire'), findsOneWidget); // pannello di lettura
    expect(core.seenPuts, ['/messages/INBOX/3/seen']);
    await core.sse.close();
  });

  testWidgets('clic sulla notifica di prova (senza payload): solo primo piano', (tester) async {
    final presenter = FakePresenter();
    final (core, notifier) = await start(tester, presenter: presenter);
    await tester.tap(find.text('Archivio'));
    await tester.pumpAndSettle();

    await notifier.show('PostinoVip', 'prova');
    notifier.click(0);
    await tester.pumpAndSettle();

    expect(presenter.presented, 1);
    expect(find.text('Vecchia 1'), findsNothing); // resta in Archivio: INBOX non aperta
    expect(core.seenPuts, isEmpty);
    await core.sse.close();
  });
}
