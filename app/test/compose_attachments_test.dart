import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'single_account_core.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/attachments/file_picker.dart';
import 'package:postinovip/main.dart';

class FakePicker implements FilePickerService {
  FakePicker(this.files);

  final List<PickedFile> files;

  @override
  Future<List<PickedFile>> pickFiles() async => files;

  @override
  Future<PickedFile?> pickFile({required String label, required List<String> extensions}) async => files.firstOrNull;
}

http.Response json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

/// Core finto con un messaggio con due allegati e la bozza di inoltro; registra i POST /send.
MockClient fakeCore(List<Map<String, dynamic>> sent) => MockClient((request) async {
      switch (request.url.path) {
        case '/folders':
          return json([{'fullName': 'INBOX', 'name': 'INBOX', 'count': 1}]);
        case '/folders/INBOX/messages':
          return json({'total': 1, 'offset': 0, 'limit': 50, 'items': [
            {'uid': 7, 'subject': 'Report', 'from': 'Anna', 'date': null, 'seen': true}
          ]});
        case '/messages/INBOX/7':
          return json({
            'uid': 7, 'subject': 'Report', 'from': 'Anna', 'to': [], 'cc': [], 'date': null,
            'textBody': 't', 'htmlBody': null, 'hasRemoteImages': false,
            'attachments': [
              {'index': 0, 'fileName': 'report.pdf', 'contentType': 'application/pdf'},
              {'index': 1, 'fileName': 'logo.png', 'contentType': 'image/png'},
            ],
          });
        case '/messages/INBOX/7/draft':
          return json({
            'to': [], 'cc': [], 'subject': 'Fwd: Report', 'body': '\n\n---------- Messaggio inoltrato ----------',
            'inReplyTo': null, 'references': [],
            'forwardAttachments': [
              {'index': 0, 'fileName': 'report.pdf', 'contentType': 'application/pdf'},
              {'index': 1, 'fileName': 'logo.png', 'contentType': 'image/png'},
            ],
          });
        case '/account':
          return json({'address': 'me@example.com'});
        case '/send':
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          return json({'serverResponse': '2.0.0 Ok', 'savedTo': 'Posta inviata'});
      }
      return http.Response('{}', 404);
    });

Future<void> start(WidgetTester tester, MockClient core, FilePickerService picker) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(core)), filePicker: picker));
  await tester.pumpAndSettle();
}

Future<void> confirmSend(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
  await tester.pumpAndSettle();
}

void main() {
  test('formatSize', () {
    expect(formatSize(500), '500 byte');
    expect(formatSize(340 * 1024), '340 KB');
    expect(formatSize((1.25 * 1024 * 1024).round()), '1,3 MB');
  });

  testWidgets('nuovo messaggio: file allegati, rimozione, base64 nel POST', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await start(tester, fakeCore(sent), FakePicker([
      PickedFile('nota.txt', Uint8List.fromList(utf8.encode('ciao'))),
      PickedFile('da_togliere.bin', Uint8List(10)),
    ]));
    await tester.tap(find.text('Nuovo messaggio'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Allega file'));
    await tester.pumpAndSettle();
    expect(find.text('nota.txt (4 byte)'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.widgetWithText(InputChip, 'da_togliere.bin (10 byte)'), matching: find.byTooltip('Rimuovi')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'a@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Oggetto'), 'Con file');
    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();
    expect(find.text('Allegati: 1, file dal disco 4 byte'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Invia')));
    await tester.pumpAndSettle();

    expect(sent.single['attachments'], [{'fileName': 'nota.txt', 'data': base64Encode(utf8.encode('ciao'))}]);
    expect(sent.single['forwardAttachments'], isNull);
  });

  testWidgets('allegati oltre 25 MB: avviso e nessun invio', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await start(tester, fakeCore(sent), FakePicker([PickedFile('grande.iso', Uint8List(26 * 1024 * 1024))]));
    await tester.tap(find.text('Nuovo messaggio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allega file'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'a@example.com');

    await tester.tap(find.widgetWithText(FilledButton, 'Invia'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Allegati troppo grandi'), findsOneWidget);
    expect(find.text('Inviare il messaggio?'), findsNothing);
    expect(sent, isEmpty);
  });

  testWidgets('inoltro: allegati dell\'originale inclusi, uno tolto, indici al core', (tester) async {
    final sent = <Map<String, dynamic>>[];
    await start(tester, fakeCore(sent), FakePicker([]));
    await tester.tap(find.text('Report').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Inoltra'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'report.pdf'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'logo.png'), findsOneWidget);
    await tester.tap(find.descendant(of: find.widgetWithText(InputChip, 'logo.png'), matching: find.byTooltip('Rimuovi')));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'A…'), 'b@example.com');
    await confirmSend(tester);

    expect(sent.single['forwardAttachments'], {'account': 'main', 'folder': 'INBOX', 'uid': 7, 'indexes': [0]});
    expect(sent.single['attachments'], isEmpty);
  });
}
