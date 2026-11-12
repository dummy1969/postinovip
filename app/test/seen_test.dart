import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'single_account_core.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/ui/message_list_pane.dart';
import 'package:postinovip/settings/app_settings.dart';

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// Core finto con un messaggio NON letto; registra le PUT .../seen. Con [failPut] le rifiuta.
MockClient fakeCore(List<bool> puts, {bool failPut = false}) => MockClient((request) async {
      final path = request.url.path;
      if (path == '/folders') return json([{'fullName': 'INBOX', 'name': 'INBOX', 'count': 1}]);
      if (path == '/folders/INBOX/messages') {
        return json({
          'total': 1, 'offset': 0, 'limit': 50,
          'items': [{'uid': 5, 'subject': 'Nuova', 'from': 'Anna', 'date': null, 'seen': false}],
        });
      }
      if (path == '/messages/INBOX/5') {
        return json({
          'uid': 5, 'subject': 'Nuova', 'from': 'Anna', 'to': [], 'cc': [], 'date': null,
          'textBody': 'ciao', 'htmlBody': null, 'hasRemoteImages': false, 'attachments': [],
        });
      }
      if (path == '/messages/INBOX/5/seen' && request.method == 'PUT') {
        if (failPut) return json({'title': 'Errore del server mail', 'detail': 'NO STORE'}, 502);
        final seen = (jsonDecode(request.body) as Map<String, dynamic>)['seen'] as bool;
        puts.add(seen);
        return json({'seen': seen});
      }
      return json({}, 404);
    });

Future<void> start(WidgetTester tester, MockClient core, {AppSettings? settings}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(core)), settings: settings));
  await tester.pumpAndSettle();
}

FontWeight? senderWeight(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byKey(MessageListPane.messageListKey), matching: find.text('Anna')).first).style?.fontWeight;

void main() {
  testWidgets('aprire una mail non letta la segna come letta', (tester) async {
    final puts = <bool>[];
    await start(tester, fakeCore(puts));
    expect(senderWeight(tester), FontWeight.bold);

    await tester.tap(find.text('Nuova').first);
    await tester.pumpAndSettle();

    expect(puts, [true]);
    expect(senderWeight(tester), FontWeight.normal);
    expect(find.text('Segna come non letto'), findsOneWidget);
  });

  testWidgets('"Segna come non letto" toglie il flag e non viene rimesso', (tester) async {
    final puts = <bool>[];
    await start(tester, fakeCore(puts));
    await tester.tap(find.text('Nuova').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Segna come non letto'));
    await tester.pumpAndSettle();

    expect(puts, [true, false]);
    expect(senderWeight(tester), FontWeight.bold);
    expect(find.text('Segna come letto'), findsOneWidget);
  });

  testWidgets('errore del server: stato ripristinato e messaggio visibile', (tester) async {
    await start(tester, fakeCore([], failPut: true));

    await tester.tap(find.text('Nuova').first);
    await tester.pumpAndSettle();

    expect(senderWeight(tester), FontWeight.bold); // tornata non letta
    expect(find.textContaining('Stato letto/non letto non aggiornato'), findsOneWidget);
    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Stato letto/non letto non aggiornato'), findsNothing);
  });

  Future<AppSettings> settingsWith(ReadMode mode, {int delay = AppSettings.defaultReadDelay}) async {
    final settings = AppSettings(MemorySettingsStore());
    await settings.setReadMode(mode);
    await settings.setReadDelay(delay);
    return settings;
  }

  testWidgets('dopo N secondi: letta solo allo scadere', (tester) async {
    final puts = <bool>[];
    await start(tester, fakeCore(puts), settings: await settingsWith(ReadMode.afterDelay, delay: 5));

    await tester.tap(find.text('Nuova').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(puts, isEmpty);
    expect(senderWeight(tester), FontWeight.bold);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(puts, [true]);
    expect(senderWeight(tester), FontWeight.normal);
  });

  testWidgets('dopo N secondi: chiusa prima della scadenza resta non letta', (tester) async {
    final puts = <bool>[];
    await start(tester, fakeCore(puts), settings: await settingsWith(ReadMode.afterDelay, delay: 5));

    await tester.tap(find.text('Nuova').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Posta in arrivo').last); // riapre la cartella (nell'albero): il pannello di lettura si svuota
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));

    expect(puts, isEmpty);
    expect(senderWeight(tester), FontWeight.bold);
  });

  testWidgets('mai automaticamente: solo con il pulsante', (tester) async {
    final puts = <bool>[];
    await start(tester, fakeCore(puts), settings: await settingsWith(ReadMode.manual));

    await tester.tap(find.text('Nuova').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 120));
    expect(puts, isEmpty);

    await tester.tap(find.text('Segna come letto'));
    await tester.pumpAndSettle();
    expect(puts, [true]);
  });

  test('AppSettings: lettura predefinita "subito", ritardo 5 s, valori non validi ignorati', () async {
    final store = MemorySettingsStore();
    final s = AppSettings(store);
    await s.load();
    expect((s.readMode, s.readDelaySeconds), (ReadMode.immediately, 5));

    await s.setReadMode(ReadMode.afterDelay);
    await s.setReadDelay(12);
    final reloaded = AppSettings(store);
    await reloaded.load();
    expect((reloaded.readMode, reloaded.readDelaySeconds), (ReadMode.afterDelay, 12));

    for (final bad in ['0', '61', 'abc']) {
      await store.write('readDelaySeconds', bad);
      await reloaded.load();
      expect(reloaded.readDelaySeconds, 5, reason: bad);
    }
    await reloaded.setReadDelay(500);
    expect(reloaded.readDelaySeconds, 60);
  });

  testWidgets('impostazioni: il cursore dei secondi compare solo con "dopo alcuni secondi"', (tester) async {
    final settings = AppSettings(MemorySettingsStore());
    await start(tester, fakeCore([]), settings: settings);
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-tab-mail'))); // pagina Posta
    await tester.pumpAndSettle();
    // Nella finestra delle Opzioni: sotto resta il cursore dello zoom della barra di stato (P2).
    final slider = find.descendant(of: find.byKey(const Key('settings-dialog')), matching: find.byType(Slider));
    expect(slider, findsNothing);

    await tester.ensureVisible(find.text(ReadMode.afterDelay.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReadMode.afterDelay.label));
    await tester.pumpAndSettle();
    expect(settings.readMode, ReadMode.afterDelay);
    expect(slider, findsOneWidget);
    expect(find.text('5 s'), findsOneWidget);
  });
}
