import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/attachments/file_picker.dart';
import 'package:postinovip/attachments/file_saver.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/ui/eml_view.dart';

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

class _Saver implements FileSaver {
  final saved = <String, Uint8List>{};

  @override
  Future<String?> pickSaveLocation(String suggestedName) async => '/tmp/finto/$suggestedName';

  @override
  Future<void> write(String path, Uint8List bytes) async => saved[path] = bytes;
}

class _Picker implements FilePickerService {
  PickedFile? next;
  List<String>? extensions;

  @override
  Future<List<PickedFile>> pickFiles() async => [];

  @override
  Future<PickedFile?> pickFile({required String label, required List<String> extensions}) async {
    this.extensions = extensions;
    return next;
  }
}

final _raw = utf8.encode('From: anna@example.com\nSubject: Verbale\n\nCorpo\n');
final _inner = utf8.encode('From: luca@example.com\r\nSubject: Dentro\r\n\r\nMail allegata\r\n');
final _pdf = utf8.encode('%PDF-1.4\n');

/// Core finto: una mail in INBOX con un PDF e una mail allegati; i file .eml aperti hanno id e1, e2, …
class EmlCore {
  final sse = StreamController<List<int>>();
  final opened = <List<int>>[];
  final openTypes = <String?>[];
  final closed = <String>[];
  final paths = <String>[];

  static Map<String, dynamic> detail(String subject, {bool attachments = true}) => {
    'uid': 7, 'subject': subject, 'from': 'Anna', 'to': ['io@example.com'], 'cc': [],
    'date': DateTime.now().toUtc().toIso8601String(), 'textBody': 'Ecco il verbale.', 'htmlBody': null,
    'hasRemoteImages': false,
    'attachments': attachments
        ? [
            {'index': 0, 'fileName': 'verbale.pdf', 'contentType': 'application/pdf'},
            {'index': 1, 'fileName': 'Dentro.eml', 'contentType': 'message/rfc822'},
          ]
        : [],
  };

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = request.url.path;
    paths.add('${request.method} $path');
    final body = await bodyStream.toBytes();
    http.StreamedResponse json(Object value) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(value))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    http.StreamedResponse bytes(List<int> value) => http.StreamedResponse(Stream.value(value), 200);
    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'io@example.com', 'address': 'io@example.com', 'configured': true, 'online': true},
      ]);
    }
    if (path == '/accounts/a1/folders') {
      return json([
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 1, 'unread': 0, 'specialUse': 'inbox'},
      ]);
    }
    if (path == '/accounts/a1/folders/INBOX/messages') {
      final now = DateTime.now().toUtc().toIso8601String();
      return json({
        'total': 1, 'offset': 0, 'limit': 50,
        'items': [
          {'uid': 7, 'subject': 'Verbale', 'from': 'Anna', 'date': now, 'received': now, 'seen': true, 'hasAttachments': true},
        ],
      });
    }
    if (path == '/accounts/a1/messages/INBOX/7') return json(detail('Verbale'));
    if (path == '/accounts/a1/messages/INBOX/7/raw') return bytes(_raw);
    if (path == '/accounts/a1/messages/INBOX/7/attachments/1') return bytes(_inner);
    if (path == '/eml' && request.method == 'POST') {
      final text = utf8.decode(body);
      if (!text.contains('Subject:')) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'title': 'Richiesta non valida',
            'errors': {'file': ['Il file non è una mail (.eml) leggibile.']},
          }))),
          400,
          headers: {'content-type': 'application/problem+json; charset=utf-8'},
        );
      }
      opened.add(body);
      openTypes.add(request.headers['content-type']);
      final subject = RegExp(r'Subject: (\w+)').firstMatch(text)!.group(1)!;
      return json({'id': 'e${opened.length}', 'message': detail(subject, attachments: subject == 'Verbale')});
    }
    if (path == '/eml/e1/attachments/0') return bytes(_pdf);
    if (path == '/eml/e1/attachments/1') return bytes(_inner);
    if (path == '/accounts/a1/eml/e1/draft') {
      return json({
        'to': [], 'cc': [], 'subject': 'Fwd: Verbale', 'body': '', 'inReplyTo': null, 'references': [],
        'quoteHtml': '<p>-----Messaggio originale-----</p><p>Ecco il verbale.</p>',
        'forwardAttachments': [
          {'index': 0, 'fileName': 'verbale.pdf', 'contentType': 'application/pdf'},
        ],
      });
    }
    if (request.method == 'DELETE' && path.startsWith('/eml/')) {
      closed.add(path.substring('/eml/'.length));
      return http.StreamedResponse(const Stream.empty(), 204);
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

Future<(EmlCore, _Saver, _Picker)> _start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = EmlCore();
  final saver = _Saver();
  final picker = _Picker();
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      windowPresenter: _NoWindow(),
      fileSaver: saver,
      filePicker: picker,
    ),
  );
  await tester.pumpAndSettle();
  return (core, saver, picker);
}

Future<void> _fileMenu(WidgetTester tester, String item) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('file-$item')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Salva con nome (File e F12): byte originali in <oggetto>.eml; senza mail aperta disattivato', (tester) async {
    final (core, saver, _) = await _start(tester);
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('file-save-eml'))).enabled, isFalse);
    expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('file-open-eml'))).enabled, isTrue);
    await tester.tapAt(const Offset(1400, 800));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verbale').first);
    await tester.pumpAndSettle();
    await _fileMenu(tester, 'save-eml');
    expect(saver.saved['/tmp/finto/Verbale.eml'], _raw);
    expect(find.text('Salvato in /tmp/finto/Verbale.eml'), findsOneWidget);

    saver.saved.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.f12);
    await tester.pumpAndSettle();
    expect(saver.saved['/tmp/finto/Verbale.eml'], _raw);
    expect(core.paths.where((p) => p.contains('/raw')), hasLength(2));
    await core.sse.close();
  });

  testWidgets('Apri file .eml: finestra di sola lettura, mail allegata, Salva con nome, Esc chiude nel core', (tester) async {
    final (core, saver, picker) = await _start(tester);
    picker.next = PickedFile('verbale.eml', Uint8List.fromList(_raw));
    await _fileMenu(tester, 'open-eml');
    expect(picker.extensions, ['eml']);
    expect(core.opened.single, _raw);
    expect(core.openTypes.single, 'message/rfc822');
    expect(find.byType(EmlPage), findsOneWidget);
    expect(find.text('verbale.eml'), findsOneWidget);
    expect(find.text('Sola lettura'), findsOneWidget);
    expect(find.text('Ecco il verbale.'), findsOneWidget);

    // La mail allegata si apre in un'altra finestra uguale.
    await tester.tap(find.byKey(const Key('attachment-open-1')));
    await tester.pumpAndSettle();
    expect(core.opened.last, _inner);
    expect(find.byType(EmlPage, skipOffstage: false), findsNWidgets(2)); // la prima resta sotto
    await tester.tap(find.byKey(const Key('eml-save')).last);
    await tester.pumpAndSettle();
    expect(saver.saved['/tmp/finto/Dentro.eml'], _inner);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(core.closed, ['e2']);

    await tester.tap(find.byKey(const Key('eml-close')));
    await tester.pumpAndSettle();
    expect(find.byType(EmlPage), findsNothing);
    expect(core.closed, ['e2', 'e1']);
    await core.sse.close();
  });

  testWidgets('Inoltra da un file .eml: citazione e allegati già nella composizione', (tester) async {
    final (core, _, picker) = await _start(tester);
    picker.next = PickedFile('verbale.eml', Uint8List.fromList(_raw));
    await _fileMenu(tester, 'open-eml');
    await tester.tap(find.text('Inoltra'));
    await tester.pumpAndSettle();
    expect(core.paths, contains('GET /accounts/a1/eml/e1/draft'));
    expect(core.paths, contains('GET /eml/e1/attachments/0'));
    expect(find.text('Fwd: Verbale'), findsWidgets);
    expect(find.textContaining('verbale.pdf'), findsWidgets);
    await core.sse.close();
  });

  testWidgets('un file che non è una mail: avviso con il motivo, nessuna finestra', (tester) async {
    final (core, _, picker) = await _start(tester);
    picker.next = PickedFile('note.eml', Uint8List.fromList(utf8.encode('solo testo')));
    await _fileMenu(tester, 'open-eml');
    expect(find.byType(EmlPage), findsNothing);
    expect(find.text('note.eml non aperto: Il file non è una mail (.eml) leggibile.'), findsOneWidget);
    await core.sse.close();
  });
}
