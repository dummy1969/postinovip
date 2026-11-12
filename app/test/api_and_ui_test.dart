import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'single_account_core.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';

/// Core finto: risponde come l'Api reale e registra gli URL richiesti.
MockClient fakeCore(List<Uri> calls) => MockClient((request) async {
      calls.add(request.url);
      final path = request.url.path;
      if (path == '/folders') {
        return http.Response(
            jsonEncode([
              {'fullName': 'INBOX', 'name': 'INBOX', 'count': 2},
              {'fullName': 'INBOX/Sent', 'name': 'Sent', 'count': 0},
            ]),
            200);
      }
      if (path.startsWith('/folders/INBOX/messages')) {
        return http.Response(
            jsonEncode({
              'total': 2,
              'offset': 0,
              'limit': 50,
              'items': [
                {'uid': 2, 'subject': 'Fattura ottobre', 'from': 'Mario Rossi', 'date': null, 'seen': false},
                {'uid': 1, 'subject': 'Benvenuto', 'from': 'Anna', 'date': null, 'seen': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (path == '/messages/INBOX/1') {
        return http.Response(
            jsonEncode({
              'uid': 1,
              'subject': 'Benvenuto',
              'from': 'Anna',
              'to': [],
              'cc': [],
              'date': null,
              'textBody': null,
              'htmlBody': '<p>Ciao <b>Marcello</b></p><img src="https://tracker.example/p.gif">',
              'hasRemoteImages': true,
              'attachments': [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (path == '/messages/INBOX/2') {
        return http.Response(
            jsonEncode({
              'uid': 2,
              'subject': 'Fattura ottobre',
              'from': 'Mario Rossi',
              'to': ['"Io" <io@example.com>'],
              'cc': [],
              'date': '2026-10-29T10:00:00+00:00',
              'textBody': 'In allegato la fattura.',
              'htmlBody': null,
              'attachments': [
                {'index': 0, 'fileName': 'fattura.pdf', 'contentType': 'application/pdf'},
                {'index': 1, 'fileName': 'foto.jpg', 'contentType': 'image/jpeg'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response(jsonEncode({'title': 'Non trovato', 'detail': 'boh'}), 404);
    });

void main() {
  test('getMessages codifica "/" nel nome cartella', () async {
    final calls = <Uri>[];
    final api = ApiClient(httpClient: fakeCore(calls));

    await expectLater(api.getMessages('INBOX/Sent', offset: 10, limit: 5), throwsA(isA<ApiException>()));
    expect(calls.single.toString(), 'http://127.0.0.1:5080/folders/INBOX%2FSent/messages?offset=10&limit=5');
  });

  test('errore ProblemDetails diventa ApiException leggibile', () async {
    final api = ApiClient(httpClient: fakeCore([]));

    await expectLater(
      api.getMessages('Inesistente'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 404)
          .having((e) => e.message, 'message', 'Non trovato: boh')),
    );
  });

  testWidgets('mostra cartelle e lista INBOX', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(fakeCore([])))));
    await tester.pumpAndSettle();

    expect(find.text('Sent'), findsNWidgets(2)); // nei Preferiti e nell'albero
    expect(find.text('Fattura ottobre'), findsOneWidget);
    expect(find.text('Benvenuto'), findsOneWidget);

    // La non letta è in grassetto.
    final unread = tester.widget<Text>(find.text('Mario Rossi'));
    expect(unread.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('clic su un messaggio apre il pannello di lettura', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final calls = <Uri>[];
    await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(fakeCore(calls)))));
    await tester.pumpAndSettle();
    expect(find.text('Seleziona un messaggio'), findsOneWidget);

    await tester.tap(find.text('Fattura ottobre'));
    await tester.pumpAndSettle();

    // Apertura del messaggio, poi (era non letto) segna come letto.
    expect(calls.map((u) => u.path), containsAllInOrder(['/messages/INBOX/2', '/messages/INBOX/2/seen']));
    expect(find.text('In allegato la fattura.'), findsOneWidget);
    expect(find.text('fattura.pdf'), findsOneWidget);

    // Solo l'immagine ha la miniatura, caricata dal core locale.
    final thumbs = tester.widgetList<Image>(find.byType(Image)).map((i) => i.image).whereType<ResizeImage>();
    expect(thumbs.map((r) => (r.imageProvider as NetworkImage).url),
        ['http://127.0.0.1:5080/accounts/main/messages/INBOX/2/attachments/1']);
  });

  testWidgets('mail HTML: rendering, immagini bloccate, passaggio a testo', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(fakeCore([])))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Benvenuto'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Marcello', findRichText: true), findsOneWidget);
    expect(find.text('Mostra immagini'), findsOneWidget);

    await tester.tap(find.text('Testo'));
    await tester.pumpAndSettle();

    expect(find.text('Messaggio solo HTML: mostrato come testo semplificato.'), findsOneWidget);
    expect(find.text('Ciao Marcello'), findsOneWidget);
    expect(find.text('Mostra immagini'), findsNothing);
  });

  test('risposta in formato vecchio diventa ApiException, non un crash', () async {
    // Allegati come stringhe: formato del core prima dell'endpoint allegati.
    final oldCore = MockClient((_) async => http.Response(
        jsonEncode({
          'uid': 5, 'subject': 's', 'from': 'f', 'to': [], 'cc': [], 'date': null,
          'textBody': 't', 'htmlBody': null, 'attachments': ['foto.jpg'],
        }),
        200));

    await expectLater(
      ApiClient(httpClient: oldCore).getMessage('INBOX', 5),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('formato inatteso'))),
    );
  });

  test('il token viene inviato come Authorization: Bearer', () async {
    final headers = <Map<String, String>>[];
    final core = MockClient((request) async {
      headers.add(request.headers);
      return http.Response('[]', 200);
    });

    await ApiClient(httpClient: core, token: 'abc').getFolders();

    expect(headers.single['authorization'], 'Bearer abc');
  });
}
