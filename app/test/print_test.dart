import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/attachments/file_saver.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/models/attachment_info.dart';
import 'package:postinovip/models/mail_importance.dart';
import 'package:postinovip/models/message_detail.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/print/message_pdf.dart';
import 'package:postinovip/print/print_actions.dart';

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

class _Saver implements FileSaver {
  String? path;
  Uint8List? bytes;

  @override
  Future<String?> pickSaveLocation(String suggestedName) async => path = '/tmp/finto/$suggestedName';

  @override
  Future<void> write(String path, Uint8List bytes) async => this.bytes = bytes;
}

/// Una mail HTML lunga (circa tre pagine) con priorità alta e un allegato.
final _html = [for (var i = 1; i <= 120; i++) '<p>Paragrafo numero $i della mail di prova.</p>'].join();

http.Client _core() {
  final today = DateTime.now().toUtc().toIso8601String();
  final sse = StreamController<List<int>>();
  http.StreamedResponse json(Object body) =>
      http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  return MockClient.streaming((request, _) async {
    final path = request.url.path;
    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'Mario Rossi', 'address': 'mario@example.com', 'configured': true, 'online': true},
      ]);
    }
    if (path == '/accounts/a1/folders') {
      return json([
        {'name': 'INBOX', 'fullName': 'INBOX', 'count': 1, 'unread': 0, 'specialUse': 'inbox'},
      ]);
    }
    if (path == '/accounts/a1/folders/INBOX/messages') {
      return json({
        'total': 1, 'offset': 0, 'limit': 50,
        'items': [
          {'uid': 7, 'subject': 'Verbale riunione', 'from': 'Anna', 'date': today, 'received': today, 'seen': true},
        ],
      });
    }
    if (path == '/accounts/a1/messages/INBOX/7') {
      return json({
        'uid': 7, 'subject': 'Verbale riunione', 'from': 'Anna', 'to': ['mario@example.com'], 'cc': [], 'date': today,
        'textBody': null, 'htmlBody': _html, 'hasRemoteImages': false, 'attachments': [], 'importance': 'high',
      });
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

MessageDetail _message({String subject = 'Prova', String? html, String? text}) => MessageDetail(
  uid: 1,
  subject: subject,
  from: 'Anna',
  fromAddress: 'anna@example.com',
  to: const ['mario@example.com', 'luca@example.com'],
  cc: const [],
  date: DateTime(2026, 11, 9, 10, 5),
  textBody: text,
  htmlBody: html,
  hasRemoteImages: false,
  attachments: const [AttachmentInfo(index: 0, fileName: 'verbale.docx', contentType: 'application/octet-stream')],
  importance: MailImportance.high,
);

void main() {
  group('pageCuts', () {
    test('senza righe da rispettare: pagine piene', () {
      expect(pageCuts(250, 100, 100, []), [100, 200]);
      expect(pageCuts(100, 100, 100, []), isEmpty); // sta in una pagina
      expect(pageCuts(250, 40, 100, []), [40, 140, 240]); // prima pagina più corta (intestazioni)
    });

    test('il taglio risale all\'inizio della riga, ma non sopra metà pagina', () {
      expect(pageCuts(250, 100, 100, [(90, 110)]), [89, 189]); // un pixel sopra la riga
      expect(pageCuts(250, 100, 100, [(85, 97), (95, 105)]), [84, 184]); // righe sovrapposte: risale due volte
      expect(pageCuts(250, 100, 100, [(85, 95), (95, 105)]), [95, 195]); // righe attaccate: tra le due, senza il pixel
      expect(pageCuts(250, 100, 100, [(30, 130)]), [100, 200]); // immagine più alta di mezza pagina: si taglia
    });
  });

  test('data come «Inviato:» di Outlook e testo per Helvetica', () {
    expect(MessagePdf.formatPrintDate(DateTime(2026, 11, 9, 10, 5)), 'lunedì 9 novembre 2026 10:05');
    expect(MessagePdf.latin1Only('Città Ω 😀'), 'Città ? ?');
  });

  testWidgets('PDF di una mail lunga: più pagine, tagli tra le righe', (tester) async {
    final view = tester.view;
    await tester.runAsync(() async {
      final slices = await renderBody(
        view: view,
        body: MessagePdf.bodyWidget(_message(html: _html)),
        width: MessagePdf.bodyWidthPx,
        first: 600,
        other: 900,
      );
      expect(slices.length, greaterThan(1));
      expect(slices.first.heightPx, lessThanOrEqualTo(600));
      expect(slices.first.heightPx, greaterThan(300)); // tagliato poco sopra il limite, tra due righe
      expect(slices.first.width, (MessagePdf.bodyWidthPx * MessagePdf.pixelRatio).ceil());
      expect(slices.first.rgba.length, slices.first.width * slices.first.height * 4);

      // Helvetica di serie: caratteri fuori Latin-1 nell'oggetto non fanno fallire il PDF.
      final pdf = await MessagePdf.build(message: _message(subject: 'Ω 😀', html: _html), account: 'Mario', view: view);
      expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');

      // Con un carattere del sistema, se c'è (sul PC di sviluppo sì); testo semplice.
      final fonts = await PrintFonts.load();
      final plain = await MessagePdf.build(
        message: _message(text: 'Riga uno\nRiga due'),
        account: 'Mario',
        view: view,
        fonts: fonts,
      );
      expect(ascii.decode(plain.sublist(0, 5)), '%PDF-');
      expect(await PrintFonts.load([('/non/esiste.ttf', '/non/esiste-b.ttf')]), isNull);
    });
  });

  testWidgets('File → Stampa e Ctrl+P aprono il PDF; Salva come PDF lo scrive; senza mail disattivati', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <Uri>[];
    PrintActions.openFile = (uri) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => PrintActions.openFile = (uri) async => false);
    final saver = _Saver();
    await tester.pumpWidget(
      PostinoVipApp(api: ApiClient(httpClient: _core()), windowPresenter: _NoWindow(), fileSaver: saver),
    );
    await tester.pumpAndSettle();

    // Il PDF si crea in parte con tempi veri (immagini, file) e in parte con attese del tempo finto dei test:
    // si fanno avanzare tutti e due.
    Future<void> settle() async {
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
    }

    Future<void> fileMenu(String item) async {
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('file-$item')));
      await settle();
    }

    // Nessuna mail aperta: voci disattivate.
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    expect(tester.widget<PopupMenuItem<String>>(find.byKey(const Key('file-print'))).enabled, isFalse);
    await tester.tapAt(const Offset(1400, 800));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verbale riunione'));
    await tester.pumpAndSettle();
    await fileMenu('print');
    expect(opened, hasLength(1));
    final file = File.fromUri(opened.single);
    addTearDown(() => file.parent.deleteSync(recursive: true));
    expect(file.parent.path, contains(PrintActions.tempPrefix));
    expect(file.path, endsWith('Verbale riunione.pdf'));
    expect(ascii.decode(file.readAsBytesSync().sublist(0, 5)), '%PDF-');
    expect(find.textContaining('visualizzatore PDF'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle();
    expect(opened, hasLength(2));
    addTearDown(() => File.fromUri(opened.last).parent.deleteSync(recursive: true));

    await fileMenu('pdf');
    expect(saver.path, '/tmp/finto/Verbale riunione.pdf');
    expect(ascii.decode(saver.bytes!.sublist(0, 5)), '%PDF-');
  });
}
