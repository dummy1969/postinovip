import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'single_account_core.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/attachments/file_saver.dart';
import 'package:postinovip/main.dart';

class FakeSaver implements FileSaver {
  FakeSaver({this.answer = '/tmp/scelto.pdf'});

  final String? answer; // null = l'utente annulla
  String? suggested;
  final written = <String, Uint8List>{};

  @override
  Future<String?> pickSaveLocation(String suggestedName) async {
    suggested = suggestedName;
    return answer;
  }

  @override
  Future<void> write(String path, Uint8List bytes) async => written[path] = bytes;
}

http.Response json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

MockClient fakeCore({bool attachmentMissing = false}) => MockClient((request) async {
      switch (request.url.path) {
        case '/folders':
          return json([{'fullName': 'INBOX', 'name': 'INBOX', 'count': 1}]);
        case '/folders/INBOX/messages':
          return json({'total': 1, 'offset': 0, 'limit': 50, 'items': [
            {'uid': 7, 'subject': 'Con allegato', 'from': 'Anna', 'date': null, 'seen': true}
          ]});
        case '/messages/INBOX/7':
          return json({
            'uid': 7, 'subject': 'Con allegato', 'from': 'Anna', 'to': [], 'cc': [], 'date': null,
            'textBody': 't', 'htmlBody': null, 'hasRemoteImages': false,
            'attachments': [{'index': 0, 'fileName': '../../.bashrc', 'contentType': 'application/pdf'}],
          });
        case '/messages/INBOX/7/attachments/0':
          if (attachmentMissing) return http.Response(jsonEncode({'title': 'Non trovato', 'detail': 'sparito'}), 404);
          expect(request.headers['authorization'], 'Bearer tok'); // con il token del core
          return http.Response.bytes([1, 2, 3], 200);
      }
      return http.Response('{}', 404);
    });

Future<void> openMessage(WidgetTester tester, MockClient core, FakeSaver saver) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(core), token: 'tok'), fileSaver: saver));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Con allegato').first);
  await tester.pumpAndSettle();
}

void main() {
  test('safeFileName', () {
    expect(safeFileName('../../.bashrc'), '.bashrc');
    expect(safeFileName(r'C:\Windows\system32\evil.dll'), 'evil.dll');
    expect(safeFileName('fattura:ottobre?.pdf'), 'fattura_ottobre_.pdf');
    expect(safeFileName('nome.\u0007.txt'), 'nome._.txt');
    expect(safeFileName('documento. . '), 'documento');
    expect(safeFileName('..'), 'allegato');
    expect(safeFileName(''), 'allegato');
    expect(safeFileName('${'a' * 300}.pdf').length, 200);
    expect(safeFileName('${'a' * 300}.pdf'), endsWith('.pdf')); // l'estensione resta
  });

  testWidgets('clic sull\'allegato: nome ripulito proposto, byte scritti nel percorso scelto', (tester) async {
    final saver = FakeSaver();
    await openMessage(tester, fakeCore(), saver);

    await tester.tap(find.text('../../.bashrc'));
    await tester.pumpAndSettle();

    expect(saver.suggested, '.bashrc');
    expect(saver.written['/tmp/scelto.pdf'], [1, 2, 3]);
    expect(find.text('Salvato in /tmp/scelto.pdf'), findsOneWidget);
  });

  testWidgets('annullando la finestra di salvataggio non si scarica nulla', (tester) async {
    final saver = FakeSaver(answer: null);
    await openMessage(tester, fakeCore(), saver);

    await tester.tap(find.text('../../.bashrc'));
    await tester.pumpAndSettle();

    expect(saver.written, isEmpty);
    expect(find.textContaining('Salvato'), findsNothing);
  });

  testWidgets('allegato non disponibile: messaggio d\'errore, nessun file', (tester) async {
    final saver = FakeSaver();
    await openMessage(tester, fakeCore(attachmentMissing: true), saver);

    await tester.tap(find.text('../../.bashrc'));
    await tester.pumpAndSettle();

    expect(saver.written, isEmpty);
    expect(find.textContaining('Allegato non scaricato'), findsOneWidget);
  });
}
