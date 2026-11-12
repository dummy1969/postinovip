import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/message_list_pane.dart';

import 'drag_drop_test.dart' show drag, folderRow;
import 'multi_select_test.dart' as ms;

/// Core finto della selezione multipla (INBOX "Mail 5"…"Mail 1" da leggere, Archivio, Posta eliminata)
/// con Posta inviata e le conversazioni: 1 = INBOX 5 + Posta inviata 20 + INBOX 3, 2 = INBOX 4 da
/// sola, 3 = INBOX 2 + INBOX 1. Le conversazioni si calcolano dalle mail presenti in quel momento.
class ConversationCore {
  ConversationCore() {
    core.mail['Posta inviata'] = [ms.SelectCore.header(20, 'Risposta')];
  }

  final core = ms.SelectCore();
  final conversationRequests = <String>[];

  static const threads = [
    [('INBOX', 5), ('Posta inviata', 20), ('INBOX', 3)],
    [('INBOX', 4)],
    [('INBOX', 2), ('INBOX', 1)],
  ];

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = Uri.decodeComponent(request.url.path);
    final list = RegExp(r'^/accounts/a1/folders/(.+)/conversations$').firstMatch(path);
    if (list != null) {
      final folder = list[1]!;
      conversationRequests.add(folder);
      final items = [
        for (final (i, thread) in threads.indexed)
          if ([
                for (final (f, uid) in thread)
                  if (core.mail[f]?.where((m) => m['uid'] == uid).firstOrNull case final m?)
                    {'folder': f, 'message': m},
              ]
              case final members when members.any((m) => m['folder'] == folder))
            {
              'id': i + 1,
              'count': members.length,
              'unread': members.where((m) => (m['message'] as Map)['seen'] != true).length,
              'hasAttachments': false,
              'messages': members,
            },
      ];
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'total': items.length, 'offset': 0, 'limit': 50, 'items': items}))),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final forward = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = await bodyStream.toBytes();
    return core.client.send(forward);
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<(ConversationCore, AppSettings)> start(WidgetTester tester, {bool conversations = true}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = ConversationCore();
  final settings = AppSettings(MemorySettingsStore())..readMode = ReadMode.manual;
  if (conversations) await settings.setConversations(true);
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: fake.client),
      settings: settings,
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return (fake, settings);
}

Finder inList(String text) =>
    find.descendant(of: find.byKey(MessageListPane.messageListKey), matching: find.text(text));
Finder conversationRow(int id) => find.byKey(ValueKey('conversation:$id'));

Future<void> expand(WidgetTester tester, int id) async {
  await tester.tap(
    find.descendant(of: conversationRow(id), matching: find.byTooltip('Mostra tutte le mail della conversazione')),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Visualizza → "Mostra come conversazioni" solo per questa cartella', (tester) async {
    final (fake, settings) = await start(tester, conversations: false);
    expect(inList('Mail 3'), findsOneWidget); // lista semplice
    expect(fake.conversationRequests, isEmpty);

    await tester.tap(find.text('Visualizza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostra come conversazioni'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Applicare a "INBOX"'), findsOneWidget);
    await tester.tap(find.text('Questa cartella'));
    await tester.pumpAndSettle();

    expect(fake.conversationRequests, ['INBOX']);
    expect(settings.showsConversations('a1', 'INBOX'), isTrue);
    expect(settings.showsConversations('a1', 'Archivio'), isFalse);
    // Una riga per conversazione: la più recente in vista, le altre chiuse sotto il triangolo.
    expect(conversationRow(1), findsOneWidget);
    expect(conversationRow(3), findsOneWidget);
    expect(inList('Mail 5'), findsOneWidget);
    expect(inList('Mail 3'), findsNothing);
    expect(inList('Mail 1'), findsNothing);
    expect(inList('Mail 4'), findsOneWidget); // da sola: riga normale, senza triangolo
    expect(find.descendant(of: conversationRow(1), matching: find.text('3')), findsOneWidget);
    expect(find.text('Conversazioni'), findsOneWidget); // etichetta sopra la lista: la vista è attiva

    // Un'altra cartella resta com'era.
    await tester.tap(folderRow('Archivio'));
    await tester.pumpAndSettle();
    expect(fake.conversationRequests, ['INBOX']);
    expect(find.text('Conversazioni'), findsNothing);
    await fake.core.sse.close();
  });

  testWidgets('"Tutte le cartelle": vale anche per le altre; spegnendo torna la lista semplice', (tester) async {
    final (fake, settings) = await start(tester, conversations: false);
    await tester.tap(find.text('Visualizza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostra come conversazioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutte le cartelle'));
    await tester.pumpAndSettle();
    expect(settings.conversationsEverywhere, isTrue);

    await tester.tap(folderRow('Posta inviata'));
    await tester.pumpAndSettle();
    expect(fake.conversationRequests, ['INBOX', 'Posta inviata']);
    expect(conversationRow(1), findsOneWidget); // la risposta con le due mail di INBOX

    await tester.tap(find.text('Mostra come conversazioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Questa cartella'));
    await tester.pumpAndSettle();
    expect(settings.showsConversations('a1', 'Posta inviata'), isFalse);
    expect(settings.showsConversations('a1', 'INBOX'), isTrue);
    expect(conversationRow(1), findsNothing);
    expect(inList('Risposta'), findsOneWidget);

    // L'etichetta "Conversazioni" in INBOX riapre la stessa scelta.
    await tester.tap(folderRow('INBOX'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conversazioni'));
    await tester.pumpAndSettle();
    expect(find.text('Non mostrare come conversazioni'), findsOneWidget);
    await tester.tap(find.text('Questa cartella'));
    await tester.pumpAndSettle();
    expect(settings.showsConversations('a1', 'INBOX'), isFalse);
    expect(find.text('Conversazioni'), findsNothing);
    await fake.core.sse.close();
  });

  testWidgets('triangolo: le mail della conversazione rientrate, anche di Posta inviata', (tester) async {
    final (fake, _) = await start(tester);

    await expand(tester, 1);
    expect(inList('Mail 3'), findsOneWidget);
    expect(inList('Risposta'), findsOneWidget);
    expect(inList('Posta inviata'), findsOneWidget); // la cartella accanto alla mail che sta altrove
    expect(inList('Mail 5'), findsNWidgets(2)); // riga della conversazione e sua mail

    // La mail di Posta inviata si apre come le altre.
    await tester.tap(inList('Risposta'));
    await tester.pumpAndSettle();
    expect(find.text('testo'), findsOneWidget);

    await tester.tap(find.byTooltip('Chiudi la conversazione'));
    await tester.pumpAndSettle();
    expect(inList('Risposta'), findsNothing);
    expect(fake.core.writes, isEmpty);
    await fake.core.sse.close();
  });

  testWidgets('riga della conversazione: si legge la più recente, i comandi valgono per tutte quelle della cartella', (
    tester,
  ) async {
    final (fake, _) = await start(tester);

    await tester.tap(inList('Mail 5'));
    await tester.pumpAndSettle();
    expect(find.text('testo'), findsOneWidget); // riquadro di lettura invariato, non "2 elementi selezionati"
    expect(find.text('2 elementi selezionati'), findsNothing);

    await tester.tap(find.text('Segna come letto'));
    await tester.pumpAndSettle();
    expect(fake.core.writes.last, 'PUT /accounts/a1/messages/INBOX/seen {"uids":[3,5],"seen":true}');
    expect(find.text('Segna come non letto'), findsOneWidget);

    await tester.tap(find.text('Elimina').first);
    await tester.pumpAndSettle();
    expect(fake.core.writes.last, 'POST /accounts/a1/messages/INBOX/delete {"uids":[3,5],"permanent":false}');
    expect(conversationRow(1), findsNothing);
    expect(inList('Mail 4'), findsOneWidget);
    expect(find.text('Seleziona un messaggio'), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('tasto destro e trascinamento sulla riga chiusa: tutta la conversazione', (tester) async {
    final (fake, _) = await start(tester);

    await tester.tap(inList('Mail 2'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Segna come letto'));
    await tester.pumpAndSettle();
    expect(fake.core.writes.last, 'PUT /accounts/a1/messages/INBOX/seen {"uids":[1,2],"seen":true}');

    await drag(tester, inList('Mail 5'), folderRow('Archivio'));
    expect(fake.core.writes.last, 'POST /accounts/a1/messages/INBOX/move {"uids":[3,5],"destination":"Archivio"}');
    expect(find.text('2 mail spostate in "Archivio"'), findsOneWidget);
    expect(conversationRow(1), findsNothing);
    await fake.core.sse.close();
  });

  testWidgets('frecce: righe delle conversazioni e, se aperte, le loro mail', (tester) async {
    final (fake, _) = await start(tester);
    await expand(tester, 1);
    await tester.tap(inList('Mail 4'));
    await tester.pumpAndSettle();

    // Su: le mail aperte della conversazione 1, dal fondo; poi la sua riga.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(ms.selected(tester, 'Risposta'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.text('testo'), findsOneWidget);
    expect(
      tester.widget<Material>(find.descendant(of: conversationRow(1), matching: find.byType(Material)).first).color,
      isNot(Colors.transparent),
    );

    // Giù fino alla conversazione 3 (chiusa, l'ultima riga: oltre non si va); Canc la toglie tutta.
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(fake.core.writes.last, 'POST /accounts/a1/messages/INBOX/delete {"uids":[1,2],"permanent":false}');
    await fake.core.sse.close();
  });

  test('impostazioni: salvate, rilette e rinominate con la cartella', () async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    await settings.setConversations(true, account: 'a1', folder: 'Clienti');
    await settings.setConversations(false, account: 'a1', folder: 'INBOX');
    await settings.renameConversationFolders('a1', (f) => f == 'Clienti' ? 'Archivio/Clienti' : null);

    final again = AppSettings(store);
    await again.load();
    expect(again.conversationsEverywhere, isFalse);
    expect(again.showsConversations('a1', 'Archivio/Clienti'), isTrue);
    expect(again.showsConversations('a1', 'Clienti'), isFalse);
    expect(again.showsConversations('a2', 'Clienti'), isFalse);

    // "Tutte le cartelle" cancella le scelte delle singole cartelle.
    await again.setConversations(true);
    expect(again.showsConversations('a1', 'INBOX'), isTrue);
    expect(again.conversationFolders, isEmpty);
  });
}
