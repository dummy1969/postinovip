import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/models/mail_folder.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/html_body_view.dart';

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

/// Core finto della posta indesiderata (J2): INBOX con «Offerta» (2) e «Normale» (3), «Scarti» con «Sospetta» (7).
/// All'inizio nessuna cartella della posta indesiderata; scelta nelle Opzioni, «Scarti» ha il ruolo "junk".
class JunkCore {
  final sse = StreamController<List<int>>();
  final requests = <String, Map<String, dynamic>>{};
  String? junkFolder;
  Map<String, dynamic> options = {
    'level': 'None', 'folder': null, 'trustContacts': true,
    'safeSenders': <String>[], 'safeRecipients': <String>[], 'blockedSenders': <String>[],
  };
  final inbox = <int, String>{2: 'Offerta', 3: 'Normale'};
  final scarti = <int, String>{7: 'Sospetta'};

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = request.url.path;
    final raw = utf8.decode(await bodyStream.toBytes());
    final body = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
    final now = DateTime.now().toUtc().toIso8601String();
    http.StreamedResponse json(Object value, [int code = 200]) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(value))),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    Map<String, dynamic> page(Map<int, String> items) => {
      'total': items.length, 'offset': 0, 'limit': 50,
      'items': [
        for (final MapEntry(key: uid, value: subject) in items.entries)
          {'uid': uid, 'subject': subject, 'from': 'Anna', 'date': now, 'received': now, 'seen': true},
      ],
    };
    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'io@example.com', 'address': 'io@example.com', 'configured': true, 'online': true},
      ]);
    }
    if (path == '/accounts/a1/folders') {
      return json([
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': inbox.length, 'unread': 0, 'specialUse': 'inbox'},
        {'fullName': 'Posta inviata', 'name': 'Posta inviata', 'count': 0, 'unread': 0, 'specialUse': 'sent'},
        {'fullName': 'Scarti', 'name': 'Scarti', 'count': scarti.length, 'unread': 0, 'specialUse': junkFolder == 'Scarti' ? 'junk' : null},
      ]);
    }
    if (path == '/accounts/a1/folders/INBOX/messages') return json(page(inbox));
    if (path == '/accounts/a1/folders/Scarti/messages') return json(page(scarti));
    final detail = RegExp(r'^/accounts/a1/messages/(INBOX|Scarti)/(\d)$').firstMatch(path);
    if (detail != null) {
      return json({
        'uid': int.parse(detail.group(2)!), 'subject': 'x', 'from': 'Anna', 'fromAddress': 'anna@fornitore.it',
        'to': ['io@example.com'], 'cc': [], 'date': now, 'textBody': 'Ciao',
        'htmlBody': '<p>Ciao <a href="https://example.com/premio">premio</a> <img src="https://example.com/p.png"></p>',
        'hasRemoteImages': true, 'attachments': [],
      });
    }
    if (path == '/accounts/a1/junk') {
      if (request.method == 'PUT') {
        requests['PUT junk'] = body;
        options = body;
        junkFolder = body['folder'] as String?;
      }
      return json({...options, 'junkFolder': junkFolder});
    }
    final command = RegExp(r'^/accounts/a1/messages/(INBOX|Scarti)/(block|never-block|not-junk)$').firstMatch(path);
    if (command != null && request.method == 'POST') {
      requests['${command.group(1)} ${command.group(2)}'] = body;
      final uids = (body['uids'] as List).cast<int>();
      switch (command.group(2)) {
        case 'block':
          if (junkFolder == null) return json({'title': 'Operazione non consentita', 'detail': 'Nessuna cartella'}, 409);
          for (final u in uids) {
            scarti[u] = inbox.remove(u)!;
          }
          return json({'entries': ['anna@fornitore.it'], 'moved': uids, 'folder': junkFolder});
        case 'never-block':
          return json({'entries': ['@fornitore.it'], 'moved': <int>[], 'folder': null});
        default:
          for (final u in uids) {
            inbox[u] = scarti.remove(u)!;
          }
          return json({'entries': body['trustSenders'] == true ? ['anna@fornitore.it'] : <String>[], 'moved': uids, 'folder': 'INBOX'});
      }
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

Future<JunkCore> _start(WidgetTester tester, {String? junkFolder, Size size = const Size(1500, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = JunkCore()..junkFolder = junkFolder;
  if (junkFolder != null) core.options = {...core.options, 'folder': junkFolder};
  await tester.pumpWidget(
    PostinoVipApp(api: ApiClient(httpClient: core.client), settings: AppSettings(MemorySettingsStore()), windowPresenter: _NoWindow()),
  );
  await tester.pumpAndSettle();
  return core;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String item) async {
  await _tap(tester, find.byKey(const Key('ribbon-junk')));
  await _tap(tester, find.byKey(Key(item)));
}

void main() {
  test('Il ruolo della posta indesiderata viene dal core, non dal nome', () {
    expect(const MailFolder(fullName: 'Spam', name: 'Spam').role, isNull);
    expect(const MailFolder(fullName: 'Spam', name: 'Spam', specialUse: 'junk').role, 'junk');
    expect(const MailFolder(fullName: 'Posta inviata', name: 'Posta inviata').role, 'sent'); // gli altri dal nome, come prima
  });

  testWidgets('Blocca mittente senza cartella: niente modifiche, poi la si sceglie nelle Opzioni', (tester) async {
    final core = await _start(tester);
    await _tap(tester, find.text('Offerta'));
    await _menu(tester, 'junk-block');
    expect(find.byKey(const Key('junk-no-folder')), findsOneWidget);
    expect(core.requests, isEmpty); // il core non è stato toccato

    await _tap(tester, find.text('Opzioni posta indesiderata…').last);
    expect(find.text('Automatica (nessuna cartella trovata)'), findsOneWidget);
    // Posta in arrivo e Posta inviata non si possono scegliere.
    final shown = find.text('Posta inviata').evaluate().length; // nel riquadro delle cartelle
    await tester.ensureVisible(find.byKey(const ValueKey('junk-folder:a1'))); // la scheda Opzioni scorre
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('junk-folder:a1')));
    expect(find.text('Posta inviata'), findsNWidgets(shown)); // non tra le scelte
    await _tap(tester, find.text('Scarti').last);
    await tester.ensureVisible(find.byKey(const Key('junk-level-low')));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('junk-level-low')));
    await _tap(tester, find.byKey(const Key('junk-ok')));
    expect(core.requests['PUT junk']?['folder'], 'Scarti');
    expect(core.requests['PUT junk']?['level'], 'Low');
    expect(find.byType(AlertDialog), findsNothing);

    // Ora «Blocca mittente» sposta la mail.
    await _tap(tester, find.text('Offerta'));
    await _menu(tester, 'junk-block');
    expect(core.requests['INBOX block'], {'uids': [2]});
    expect(find.text('Offerta'), findsNothing);
    expect(find.textContaining('anna@fornitore.it bloccato'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('Nella posta indesiderata: striscia, collegamenti e immagini disattivati, Non è posta indesiderata', (tester) async {
    final core = await _start(tester, junkFolder: 'Scarti');
    await _tap(tester, find.text('Normale'));
    expect(find.byKey(const Key('junk-banner')), findsNothing);
    expect(tester.widget<HtmlBodyView>(find.byType(HtmlBodyView)).linksEnabled, isTrue);
    expect(find.text('Mostra immagini'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('ribbon-junk')));
    expect(tester.widget<MenuItemButton>(find.byKey(const Key('junk-not-junk'))).onPressed, isNull); // non è nella posta indesiderata
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Scarti').first);
    await _tap(tester, find.text('Sospetta'));
    expect(find.byKey(const Key('junk-banner')), findsOneWidget);
    final body = tester.widget<HtmlBodyView>(find.byType(HtmlBodyView));
    expect(body.linksEnabled, isFalse);
    expect(body.allowRemoteImages, isFalse);
    expect(find.text('Mostra immagini'), findsNothing);

    await _tap(tester, find.byKey(const Key('junk-banner-not-junk')));
    expect(find.textContaining('«anna@fornitore.it»'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('junk-not-junk-ok')));
    expect(core.requests['Scarti not-junk'], {'uids': [7], 'trustSenders': true});
    expect(find.text('Sospetta'), findsNothing);
    expect(find.textContaining('1 mail riportate in Posta in arrivo'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('Non bloccare mai il dominio: solo gli elenchi', (tester) async {
    final core = await _start(tester);
    await _tap(tester, find.text('Offerta'));
    await _menu(tester, 'junk-never-domain');
    expect(core.requests['INBOX never-block'], {'uids': [2], 'kind': 'Domain'});
    expect(find.text('Offerta'), findsOneWidget); // resta dov'è
    expect(find.textContaining('@fornitore.it aggiunto tra i mittenti attendibili'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('Opzioni: elenchi con Aggiungi e Rimuovi, una voce non è insieme bloccata e attendibile', (tester) async {
    final core = await _start(tester, junkFolder: 'Scarti');
    await _menu(tester, 'junk-options');
    expect(find.text('Automatica: «Scarti»'), findsNothing); // scelta, non automatica

    Future<void> tab(String label) async {
      await tester.ensureVisible(find.text(label)); // schede scorrevoli: con la finestra stretta non stanno tutte
      await tester.pumpAndSettle();
      await _tap(tester, find.text(label));
    }

    Future<void> add(String label, String list, String entry) async {
      await tab(label);
      await _tap(tester, find.byKey(Key('junk-add-$list')));
      await tester.enterText(find.byKey(const Key('junk-entry')), entry);
      await _tap(tester, find.byKey(const Key('junk-entry-ok')));
    }

    await add('Mittenti bloccati', 'blockedSenders', 'Spam@Esempio.it');
    await add('Mittenti bloccati', 'blockedSenders', 'non valido');
    expect(find.textContaining('Scrivi un indirizzo'), findsOneWidget);
    await _tap(tester, find.text('Annulla').last);
    await add('Mittenti attendibili', 'safeSenders', 'spam@esempio.it'); // passa dai bloccati agli attendibili
    await add('Destinatari attendibili', 'safeRecipients', '@lista.example');
    await tab('Mittenti attendibili');
    await _tap(tester, find.byKey(const Key('junk-trust-contacts')));

    await _tap(tester, find.byKey(const Key('junk-ok')));
    final saved = core.requests['PUT junk']!;
    expect(saved['safeSenders'], ['spam@esempio.it']);
    expect(saved['blockedSenders'], isEmpty);
    expect(saved['safeRecipients'], ['@lista.example']);
    expect(saved['trustContacts'], isFalse);
    expect(saved['folder'], 'Scarti');
    await core.sse.close();
  });

  testWidgets('Opzioni nella finestra minima (640×480): nessun trabocco, OK visibile', (tester) async {
    final core = await _start(tester, junkFolder: 'Scarti', size: const Size(640, 480));
    await _menu(tester, 'junk-options');
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('junk-ok')).hitTestable(), findsOneWidget);
    await core.sse.close();
  });
}
