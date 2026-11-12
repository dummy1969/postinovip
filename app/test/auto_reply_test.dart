import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/account/account_config.dart';
import 'package:postinovip/account/account_setup_page.dart';
import 'package:postinovip/account/accounts_page.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';

/// Core finto con un account e GET/PUT …/autoreply.
class AutoReplyCore {
  AutoReplyCore([Map<String, dynamic>? initial])
    : settings = initial ?? {'enabled': false, 'html': '', 'text': '', 'active': false};

  final sse = StreamController<List<int>>();
  Map<String, dynamic> settings;
  final puts = <Map<String, dynamic>>[];

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
      ]);
    }
    final rest = url.path.replaceFirst('/accounts/a1', '');
    if (rest == '/folders') {
      return json([
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 0, 'specialUse': 'inbox'},
      ]);
    }
    if (rest == '/autoreply' && request.method == 'GET') return json(settings);
    if (rest == '/autoreply' && request.method == 'PUT') {
      final put = jsonDecode(body) as Map<String, dynamic>;
      puts.add(put);
      settings = {...put, 'active': put['enabled'] == true && put['start'] == null};
      return json(settings);
    }
    if (rest.startsWith('/folders/') && rest.endsWith('/messages')) {
      return json({'total': 0, 'offset': 0, 'limit': 50, 'items': []});
    }
    return json({}, 404);
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<AutoReplyCore> start(WidgetTester tester, [Map<String, dynamic>? initial]) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = AutoReplyCore(initial);
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Risposte automatiche'));
  await tester.pumpAndSettle();
}

Future<void> typeMessage(WidgetTester tester, String text) async {
  final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
  editor.controller.replaceText(0, 0, text, null);
  await tester.pump();
}

void main() {
  testWidgets('attivazione con conferma, barra gialla, Disattiva', (tester) async {
    final core = await start(tester);
    expect(find.byKey(const Key('autoreply-strip')), findsNothing);
    await openDialog(tester);

    await tester.tap(find.byKey(const Key('autoreply-on')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('autoreply-ok')));
    await tester.pump();
    expect(find.text('Scrivi il messaggio della risposta automatica.'), findsOneWidget);

    await typeMessage(tester, 'Sono fuori sede fino a lunedì.');
    await tester.tap(find.byKey(const Key('autoreply-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Attivare le risposte automatiche?'), findsOneWidget);
    await tester.tap(find.text('Attiva'));
    await tester.pumpAndSettle();

    final put = core.puts.single;
    expect(put['enabled'], isTrue);
    expect(put['text'], 'Sono fuori sede fino a lunedì.');
    expect(put['html'], contains('Sono fuori sede fino a lunedì.'));
    expect(jsonDecode(put['document'] as String), isA<List>());
    expect(put['start'], isNull);
    expect(find.byKey(const Key('autoreply-strip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('autoreply-strip-off')));
    await tester.pumpAndSettle();
    expect(core.puts.last['enabled'], isFalse);
    expect(core.puts.last['text'], 'Sono fuori sede fino a lunedì.'); // il messaggio resta per la prossima volta
    expect(find.byKey(const Key('autoreply-strip')), findsNothing);
    await core.sse.close();
  });

  testWidgets('"Annulla" alla conferma: niente salvato', (tester) async {
    final core = await start(tester);
    await openDialog(tester);
    await tester.tap(find.byKey(const Key('autoreply-on')));
    await typeMessage(tester, 'Fuori sede');
    await tester.tap(find.byKey(const Key('autoreply-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla').last);
    await tester.pumpAndSettle();

    expect(core.puts, isEmpty);
    expect(find.text('Risposte automatiche'), findsWidgets); // la finestra resta aperta
    await core.sse.close();
  });

  testWidgets('intervallo di tempo: inizio e fine salvati; programmate nel futuro = niente barra', (tester) async {
    final core = await start(tester);
    await openDialog(tester);
    await tester.tap(find.byKey(const Key('autoreply-on')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('autoreply-period')));
    await typeMessage(tester, 'In ferie');
    await tester.tap(find.byKey(const Key('autoreply-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attiva'));
    await tester.pumpAndSettle();

    final put = core.puts.single;
    final from = DateTime.parse(put['start'] as String);
    final to = DateTime.parse(put['end'] as String);
    expect(from.isAfter(DateTime.now().toUtc()), isTrue); // dall'ora successiva
    expect(to.difference(from), const Duration(days: 1));
    expect(find.byKey(const Key('autoreply-strip')), findsNothing); // non ancora iniziate
    await core.sse.close();
  });

  testWidgets('già attive all\'avvio: barra gialla e messaggio riaperto nell\'editor', (tester) async {
    final core = await start(tester, {
      'enabled': true,
      'html': '<p>Torno lunedì</p>',
      'text': 'Torno lunedì',
      'document': null,
      'active': true,
    });
    expect(find.byKey(const Key('autoreply-strip')), findsOneWidget);

    await tester.tap(find.text('Modifica…'));
    await tester.pumpAndSettle();
    final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    expect(editor.controller.document.toPlainText(), contains('Torno lunedì'));
    await tester.tap(find.byKey(const Key('autoreply-ok')));
    await tester.pumpAndSettle();
    expect(find.text('Attivare le risposte automatiche?'), findsNothing); // erano già attive: nessuna domanda
    expect(core.puts.single['enabled'], isTrue);
    await core.sse.close();
  });

  testWidgets('OAuth2: l\'evento credentials-changed arriva a chi salva il portachiavi', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final core = AutoReplyCore();
    final updated = <(String, String)>[];
    await tester.pumpWidget(PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      windowPresenter: _NoWindow(),
      accountsEditing: AccountsEditing(
        accounts: const [],
        coreAddress: '',
        save: (_) async {},
        updateRefreshToken: (a, t) async => updated.add((a, t)),
      ),
    ));
    await tester.pumpAndSettle();

    core.sse.add(utf8.encode('data: ${jsonEncode({'type': 'credentials-changed', 'account': 'a1', 'refreshToken': 'RT-nuovo'})}\n\n'));
    await tester.pumpAndSettle();

    expect(updated, [('a1', 'RT-nuovo')]);
    await core.sse.close();
  });

  testWidgets('OAuth2: accesso scaduto, striscia sopra la lista con «Accedi di nuovo» (2a)', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final core = AutoReplyCore();
    await tester.pumpWidget(PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      windowPresenter: _NoWindow(),
      accountsEditing: AccountsEditing(
        accounts: const [
          AccountConfig(id: 'a1', email: 'io@gmail.com', password: '', imapHost: 'imap.gmail.com', smtpHost: 'smtp.gmail.com',
              oauthProvider: 'google', refreshToken: 'RT1'),
        ],
        coreAddress: '',
        save: (_) async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-expired-strip')), findsNothing);

    core.sse.add(utf8.encode('data: ${jsonEncode({'type': 'login-status', 'account': 'a1', 'needsLogin': true})}\n\n'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Accesso a Google scaduto'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-expired-signin')));
    await tester.pumpAndSettle();
    final page = tester.widget<AccountSetupPage>(find.byType(AccountSetupPage));
    expect((page.initial?.id, page.signInAgain), ('a1', true));
    Navigator.of(tester.element(find.byType(AccountSetupPage))).pop();
    await tester.pumpAndSettle();

    core.sse.add(utf8.encode('data: ${jsonEncode({'type': 'login-status', 'account': 'a1', 'needsLogin': false})}\n\n'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-expired-strip')), findsNothing);
    await core.sse.close();
  });
}
