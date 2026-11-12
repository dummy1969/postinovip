import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/ribbon_parts.dart';

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

/// Core finto di Archivia (A2): INBOX con «Offerta» (2) e «Normale» (3), «Vecchie» con «Antica» (7). Con
/// [withArchivio] c'è la cartella «Archivio», proposta dal core; la cartella scelta ha il ruolo "archive".
class ArchiveCore {
  ArchiveCore({this.withArchivio = true});

  final bool withArchivio;
  final sse = StreamController<List<int>>();
  final requests = <String>[];
  String? archive;
  final created = <String>[];
  final inbox = <int, String>{2: 'Offerta', 3: 'Normale'};
  final archived = <int, String>{};
  final old = <int, String>{7: 'Antica'};

  List<String> get _extra => [if (withArchivio) 'Archivio', ...created];

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = Uri.decodeComponent(request.url.path);
    final raw = utf8.decode(await bodyStream.toBytes());
    final body = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
    final now = DateTime.now().toUtc().toIso8601String();
    http.StreamedResponse json(Object value, [int code = 200]) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(value))),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    Map<String, dynamic> page(Map<int, String> items) => {
      'total': items.length,
      'offset': 0,
      'limit': 50,
      'items': [
        for (final MapEntry(key: uid, value: subject) in items.entries)
          {'uid': uid, 'subject': subject, 'from': 'Anna', 'date': now, 'received': now, 'seen': true},
      ],
    };
    Map<String, dynamic> folder(String name, int count, [String? role]) => {
      'fullName': name,
      'name': name,
      'count': count,
      'unread': 0,
      'specialUse': name == archive ? 'archive' : role,
    };
    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'io@example.com', 'address': 'io@example.com', 'configured': true, 'online': true},
      ]);
    }
    if (path == '/accounts/a1/folders' && request.method == 'GET') {
      return json([
        folder('INBOX', inbox.length, 'inbox'),
        folder('Posta inviata', 0, 'sent'),
        folder('Vecchie', old.length),
        for (final f in _extra) folder(f, f == archive ? archived.length : 0),
      ]);
    }
    if (path == '/accounts/a1/folders' && request.method == 'POST') {
      requests.add('POST folders ${jsonEncode(body)}');
      created.add(body['name'] as String);
      return json({'fullName': body['name'], 'separator': '/'}, 201);
    }
    if (path == '/accounts/a1/folders/INBOX/messages') return json(page(inbox));
    if (path == '/accounts/a1/folders/Vecchie/messages') return json(page(old));
    if (path.startsWith('/accounts/a1/folders/') && path.endsWith('/messages')) return json(page(archived));
    final detail = RegExp(r'^/accounts/a1/messages/([^/]+)/(\d)$').firstMatch(path);
    if (detail != null) {
      return json({
        'uid': int.parse(detail.group(2)!),
        'subject': 'x',
        'from': 'Anna',
        'fromAddress': 'anna@fornitore.it',
        'to': ['io@example.com'],
        'cc': [],
        'date': now,
        'textBody': 'Ciao',
        'attachments': [],
      });
    }
    if (path == '/accounts/a1/archive') {
      if (request.method == 'PUT') {
        requests.add('PUT archive ${jsonEncode(body)}');
        archive = body['folder'] as String?;
      }
      return json({'folder': archive, 'suggested': withArchivio ? 'Archivio' : null});
    }
    final command = RegExp(r'^/accounts/a1/messages/([^/]+)/archive$').firstMatch(path);
    if (command != null && request.method == 'POST') {
      requests.add('POST ${command.group(1)}/archive ${jsonEncode(body)}');
      final uids = (body['uids'] as List).cast<int>();
      for (final u in uids) {
        archived[u] = (command.group(1) == 'INBOX' ? inbox : old).remove(u)!;
      }
      return json({'movedTo': archive, 'permanent': false, 'uids': uids});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

Future<ArchiveCore> _start(WidgetTester tester, {bool withArchivio = true, String? archive}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = ArchiveCore(withArchivio: withArchivio)..archive = archive;
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      settings: AppSettings(MemorySettingsStore()),
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

VoidCallback? _onPressed(WidgetTester tester, Key key) => tester.widget<RibbonLargeButton>(find.byKey(key)).onPressed;

void main() {
  testWidgets('la prima volta si sceglie la cartella proposta, poi Archivia e Backspace spostano subito', (tester) async {
    final core = await _start(tester);
    await _tap(tester, find.text('Offerta'));
    await _tap(tester, find.byKey(const Key('ribbon-archive')));
    expect(find.byKey(const Key('archive-dialog')), findsOneWidget);
    expect(core.requests, isEmpty); // niente toccato prima della scelta

    // Proposta del core già scelta; Posta in arrivo e Posta inviata non si possono scegliere.
    final shown = find.text('Posta inviata').evaluate().length; // nel riquadro delle cartelle
    await _tap(tester, find.byKey(const ValueKey('archive-folder:a1')));
    expect(find.text('Posta inviata'), findsNWidgets(shown));
    await _tap(tester, find.text('Archivio').last);
    await _tap(tester, find.byKey(const Key('archive-ok')));
    expect(core.requests, ['PUT archive {"folder":"Archivio"}', 'POST INBOX/archive {"uids":[2]}']);
    expect(find.text('Offerta'), findsNothing);
    expect(find.text('1 mail archiviata'), findsOneWidget);

    // Ora la cartella c'è: Backspace archivia senza chiedere.
    await _tap(tester, find.text('Normale'));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('archive-dialog')), findsNothing);
    expect(core.requests.last, 'POST INBOX/archive {"uids":[3]}');
    expect(find.text('Normale'), findsNothing);
    await core.sse.close();
  });

  testWidgets('senza cartelle adatte si crea «Archivio»; Annulla non tocca niente', (tester) async {
    final core = await _start(tester, withArchivio: false);
    await _tap(tester, find.text('Offerta'));
    await _tap(tester, find.byKey(const Key('ribbon-archive')));
    await _tap(tester, find.text('Annulla'));
    expect(core.requests, isEmpty);
    expect(find.text('Offerta'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('ribbon-archive')));
    expect(tester.widget<TextField>(find.byKey(const Key('archive-new-name'))).controller!.text, 'Archivio');
    await _tap(tester, find.byKey(const Key('archive-ok')));
    expect(core.requests, [
      'POST folders {"name":"Archivio"}',
      'PUT archive {"folder":"Archivio"}',
      'POST INBOX/archive {"uids":[2]}',
    ]);
    expect(find.text('Offerta'), findsNothing);
    await core.sse.close();
  });

  testWidgets('nell\'archivio il comando è disattivato; Backspace mentre si scrive non archivia', (tester) async {
    final core = await _start(tester, archive: 'Archivio');
    await _tap(tester, find.text('Offerta'));
    expect(_onPressed(tester, const Key('ribbon-archive')), isNotNull);

    // Backspace nella casella di ricerca cancella un carattere e basta.
    await tester.enterText(find.byType(TextField).first, 'ab');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'a'); // gestito dalla casella
    expect(core.requests, isEmpty);
    expect(find.text('Offerta'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();

    core.archived[9] = 'Archiviata';
    await _tap(tester, find.text('Archivio').first);
    await _tap(tester, find.text('Archiviata'));
    expect(_onPressed(tester, const Key('ribbon-archive')), isNull);
    await core.sse.close();
  });

  testWidgets('scheda Cartella: Imposta cartella di archiviazione cambia la scelta', (tester) async {
    final core = await _start(tester, archive: 'Archivio');
    await _tap(tester, find.text('Vecchie').first);
    await _tap(tester, find.text('Cartella'));
    await _tap(tester, find.byKey(const Key('ribbon-archive-folder')));
    expect(find.text('OK'), findsOneWidget); // non «OK e archivia»
    await _tap(tester, find.byKey(const ValueKey('archive-folder:a1')));
    await _tap(tester, find.text('Vecchie').last);
    await _tap(tester, find.byKey(const Key('archive-ok')));
    expect(core.requests, ['PUT archive {"folder":"Vecchie"}']);
    expect(find.byKey(const Key('archive-dialog')), findsNothing);
    await core.sse.close();
  });
}
