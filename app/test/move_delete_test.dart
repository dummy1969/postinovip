import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'single_account_core.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/settings/app_settings.dart';

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> header(int uid, String subject, {bool seen = true}) =>
    {'uid': uid, 'subject': subject, 'from': 'Anna', 'date': null, 'seen': seen};

/// Core finto: INBOX (2 messaggi da leggere), Archivio, Posta eliminata (ruolo trash, 1 messaggio letto).
/// Registra le richieste di scrittura in [writes]; con [fail] le rifiuta.
MockClient fakeCore(List<String> writes, {bool fail = false}) => MockClient((request) async {
      final path = Uri.decodeComponent(request.url.path);
      if (path == '/folders') {
        return json([
          {'fullName': 'Archivio', 'name': 'Archivio', 'count': 0, 'unread': 0},
          {'fullName': 'INBOX', 'name': 'INBOX', 'count': 2, 'unread': 2, 'specialUse': 'inbox'},
          {'fullName': 'Posta eliminata', 'name': 'Posta eliminata', 'count': 1, 'unread': 0, 'specialUse': 'trash'},
        ]);
      }
      if (path == '/folders/INBOX/messages') {
        return json({'total': 2, 'offset': 0, 'limit': 50, 'items': [header(6, 'Sei', seen: false), header(5, 'Cinque', seen: false)]});
      }
      if (path == '/folders/Posta eliminata/messages') {
        return json({'total': 1, 'offset': 0, 'limit': 50, 'items': [header(9, 'Vecchia')]});
      }
      final detail = RegExp(r'^/messages/[^/]+/(\d+)$').firstMatch(path);
      if (detail != null && request.method == 'GET') {
        return json({
          'uid': int.parse(detail[1]!), 'subject': 'x', 'from': 'Anna', 'to': [], 'cc': [], 'date': null,
          'textBody': 'testo', 'htmlBody': null, 'hasRemoteImages': false, 'attachments': [],
        });
      }
      if (request.method == 'DELETE' || path.endsWith('/move')) {
        writes.add('${request.method} ${request.url}${request.body.isEmpty ? '' : ' ${request.body}'}');
        if (fail) return json({'title': 'Operazione non consentita', 'detail': 'NO'}, 409);
        if (request.method == 'DELETE') {
          final permanent = request.url.queryParameters['permanent'] == 'true';
          return json({'movedTo': permanent ? null : 'Posta eliminata', 'permanent': permanent});
        }
        return json({'movedTo': (jsonDecode(request.body) as Map)['destination'], 'permanent': false});
      }
      return json({}, 404);
    });

Future<void> start(WidgetTester tester, MockClient core) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Niente "letto" automatico all'apertura: la mail spostata resta da leggere e porta con sé il conteggio.
  final settings = AppSettings(MemorySettingsStore())..readMode = ReadMode.manual;
  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(core)), settings: settings));
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, String subject) async {
  await tester.tap(find.text(subject));
  await tester.pumpAndSettle();
}

/// Numero accanto alla cartella [name] nell'albero (non nei Preferiti); null se non c'è.
String? folderCount(WidgetTester tester, String name) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: find.byKey(ValueKey('folder:main:$name')), matching: find.byType(Text)),
  );
  return texts.length > 1 ? texts.last.data : null;
}

void main() {
  testWidgets('Elimina in INBOX sposta in Posta eliminata e aggiorna lista e conteggi', (tester) async {
    final writes = <String>[];
    await start(tester, fakeCore(writes));
    await open(tester, 'Cinque');

    await tester.tap(find.text('Elimina').first);
    await tester.pumpAndSettle();

    expect(writes, ['DELETE http://127.0.0.1:5080/messages/INBOX/5']); // nessun permanent
    expect(find.text('Cinque'), findsNothing);
    expect(find.text('Seleziona un messaggio'), findsOneWidget);
    expect(find.text('Spostato in "Posta eliminata"'), findsOneWidget);
    expect(folderCount(tester, 'INBOX'), '1'); // da leggere: Cinque è uscita
    expect(folderCount(tester, 'Posta eliminata'), '1'); // ed è entrata qui
  });

  testWidgets('Sposta: menu delle cartelle senza quella corrente', (tester) async {
    final writes = <String>[];
    await start(tester, fakeCore(writes));
    await open(tester, 'Sei');

    await tester.tap(find.text('Sposta').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PopupMenuItem<String>, 'INBOX'), findsNothing);
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Archivio'));
    await tester.pumpAndSettle();

    expect(writes.single, contains('POST http://127.0.0.1:5080/messages/INBOX/6/move'));
    expect(writes.single, contains('"destination":"Archivio"'));
    expect(find.text('Sei'), findsNothing);
    expect(folderCount(tester, 'Archivio'), '1');
    expect(folderCount(tester, 'INBOX'), '1');
  });

  testWidgets('in Posta eliminata: eliminazione definitiva solo dopo conferma', (tester) async {
    final writes = <String>[];
    await start(tester, fakeCore(writes));
    await tester.tap(find.text('Posta eliminata').last); // la prima è nei Preferiti
    await tester.pumpAndSettle();
    await open(tester, 'Vecchia');

    expect(find.text('Elimina'), findsOneWidget); // resta solo il nome del gruppo: il comando cambia nome
    await tester.tap(find.text('Elimina definitivamente'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare definitivamente?'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(writes, isEmpty); // annullato: nessuna richiesta
    expect(find.text('Vecchia'), findsOneWidget);

    await tester.tap(find.text('Elimina definitivamente'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Elimina definitivamente')));
    await tester.pumpAndSettle();

    expect(writes, ['DELETE http://127.0.0.1:5080/messages/Posta%20eliminata/9?permanent=true']);
    expect(find.text('Vecchia'), findsNothing);
    expect(find.text('Eliminato definitivamente'), findsOneWidget);
  });

  testWidgets('errore del core: messaggio resta, banner con il motivo', (tester) async {
    await start(tester, fakeCore([], fail: true));
    await open(tester, 'Cinque');

    await tester.tap(find.text('Elimina').first);
    await tester.pumpAndSettle();

    expect(find.text('Cinque'), findsWidgets);
    expect(find.textContaining('Operazione non riuscita: NO'), findsOneWidget);
    expect(find.textContaining('HTTP 409'), findsNothing);
    expect(folderCount(tester, 'INBOX'), '2');
  });
}
