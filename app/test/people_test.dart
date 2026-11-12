import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/attachments/file_picker.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';

import 'compose_attachments_test.dart' show FakePicker;
import 'multi_select_test.dart' as ms;
import 'save_attachment_test.dart' show FakeSaver;

// Vista Persone (C2): barra di navigazione, rubrica, scheda, finestra «Contatto», importa/esporta,
// «Aggiungi il mittente a Contatti». Core finto della selezione multipla + rubrica in memoria.
class PeopleCore {
  final core = ms.SelectCore();
  final requests = <String>[];
  var nextId = 3;
  final recent = <String>['marta@example.net'];
  final contacts = <Map<String, dynamic>>[
    contact('01', 'Mario', 'Rossi', 'mario@example.com', company: 'ACME'),
    contact('02', 'Luca', 'Nicolò', 'luca@example.org'),
  ];

  static Map<String, dynamic> contact(String id, String given, String family, String email, {String? company}) => {
    'id': id,
    'name': '$given $family',
    'givenName': given,
    'familyName': family,
    'emails': [
      {'address': email, 'label': 'work'},
    ],
    'phones': [
      {'number': '333 1', 'label': 'mobile'},
    ],
    'company': company,
    'notes': null,
  };

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = request.url.path;
    final bytes = await bodyStream.toBytes();
    final text = utf8.decode(bytes);
    http.StreamedResponse json(Object? value, [int status = 200]) => http.StreamedResponse(
      Stream.value(value == null ? <int>[] : utf8.encode(jsonEncode(value))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (path.startsWith('/accounts/a1/contacts')) {
      requests.add('${request.method} $path $text');
      final body = text.isEmpty ? null : jsonDecode(text) as Map<String, dynamic>;
      if (path == '/accounts/a1/contacts' && request.method == 'GET') {
        final sorted = [...contacts]..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        return json({'items': sorted});
      }
      if (path == '/accounts/a1/contacts' && request.method == 'POST') {
        final emails = body!['emails'] as List;
        if (emails.any((e) => !(e['address'] as String).contains('@'))) {
          return json({
            'title': 'Dati non validi',
            'errors': {
              'emails': ['Indirizzo non valido: ${emails.first['address']}'],
            },
          }, 400);
        }
        final c = {
          ...body,
          'id': '0${nextId++}',
          'name': [body['givenName'], body['familyName']].whereType<String>().join(' '),
        };
        contacts.add(c);
        return json(c, 201);
      }
      if (path == '/accounts/a1/contacts/import') {
        contacts.add(contact('0${nextId++}', 'Importato', 'Uno', 'imp@example.com'));
        return json({'imported': 1, 'duplicates': 2, 'invalid': 0});
      }
      if (path == '/accounts/a1/contacts/export') {
        return http.StreamedResponse(Stream.value(utf8.encode('BEGIN:VCARD')), 200);
      }
      final id = path.split('/').last;
      final i = contacts.indexWhere((c) => c['id'] == id);
      if (request.method == 'PUT') {
        contacts[i] = {
          ...body!,
          'id': id,
          'name': body['displayName'] ?? [body['givenName'], body['familyName']].whereType<String>().join(' '),
        };
        return json(contacts[i]);
      }
      if (request.method == 'DELETE') {
        contacts.removeAt(i);
        return json(null, 204);
      }
    }
    // Completamento (C3): contatti il cui nome o indirizzo comincia con la ricerca, più un indirizzo recente.
    if (path == '/addresses/suggest') {
      requests.add('GET $path ${request.url.query}');
      final q = (request.url.queryParameters['q'] ?? '').toLowerCase();
      return json({
        'items': [
          for (final r in recent)
            if (r.startsWith(q)) {'address': r, 'name': null, 'source': 'recent', 'accountId': 'a1'},
          for (final c in contacts)
            for (final e in c['emails'] as List)
              if ((c['name'] as String).toLowerCase().split(' ').any((w) => w.startsWith(q)) ||
                  (e['address'] as String).startsWith(q))
                {'address': e['address'], 'name': c['name'], 'source': 'contact', 'accountId': 'a1', 'contactId': c['id']},
        ],
      });
    }
    // Invio (Ccn): il corpo della richiesta resta da controllare.
    if (path == '/accounts/a1/send') {
      requests.add('POST $path $text');
      return json({'serverResponse': '250 OK'});
    }
    if (path == '/addresses/recent' && request.method == 'DELETE') {
      requests.add('DELETE $path ${request.url.query}');
      recent.remove(request.url.queryParameters['address']);
      return json(null, 204);
    }
    final forward = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = bytes;
    final response = await core.client.send(forward);
    // Il dettaglio della mail con l'indirizzo del mittente (per «Aggiungi il mittente a Contatti»).
    if (RegExp(r'^/accounts/a1/messages/INBOX/\d+$').hasMatch(path) && request.method == 'GET') {
      final detail = jsonDecode(await response.stream.bytesToString()) as Map<String, dynamic>;
      return json({...detail, 'from': 'Anna Bianchi', 'fromAddress': 'anna@example.com'});
    }
    return response;
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<PeopleCore> start(WidgetTester tester, {FakePicker? picker, FakeSaver? saver}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = PeopleCore();
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: fake.client),
      settings: AppSettings(MemorySettingsStore())..readMode = ReadMode.manual,
      windowPresenter: _NoWindow(),
      filePicker: picker,
      fileSaver: saver,
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<void> people(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('module-people')));
  await tester.pumpAndSettle();
}

final card = find.byKey(const Key('contact-card'));
final list = find.byKey(const Key('contact-list'));

void main() {
  testWidgets('Persone dalla barra di navigazione; Ctrl+1 / Ctrl+3; barra multifunzione e stato', (tester) async {
    final fake = await start(tester);
    expect(find.text('Mail 5'), findsWidgets);
    await people(tester);
    expect(find.text('I miei contatti'), findsOneWidget);
    expect(find.text('Nuovo contatto'), findsOneWidget);
    expect(find.text('Invia/Ricevi'), findsNothing); // nella vista Persone solo Home e Visualizza
    expect(find.text('Contatti: 2'), findsOneWidget);
    expect(find.descendant(of: list, matching: find.text('Luca Nicolò')), findsOneWidget);
    // Il primo contatto è selezionato e la sua scheda è a destra.
    expect(find.descendant(of: card, matching: find.text('luca@example.org')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Cellulare')), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('I miei contatti'), findsNothing);
    expect(find.text('Mail 5'), findsWidgets);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('I miei contatti'), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('Cerca contatti senza accenti; clic = scheda', (tester) async {
    final fake = await start(tester);
    await people(tester);
    await tester.tap(find.descendant(of: list, matching: find.text('Mario Rossi')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: card, matching: find.text('ACME')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('contact-search')), 'nicolo');
    await tester.pumpAndSettle();
    expect(find.descendant(of: list, matching: find.text('Mario Rossi')), findsNothing);
    expect(find.descendant(of: list, matching: find.text('Luca Nicolò')), findsOneWidget);
    expect(find.text('Contatti: 2      Trovati: 1'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('contact-search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nessun contatto trovato.'), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('Nuovo contatto (Ctrl+N): errore del core nella finestra, poi salvato e selezionato', (tester) async {
    final fake = await start(tester);
    await people(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Nuovo contatto'), findsWidgets);
    await tester.enterText(find.byKey(const Key('contact-given')), 'Carla');
    await tester.enterText(find.byKey(const Key('contact-email-0')), 'non valido');
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect(find.text('Indirizzo non valido: non valido'), findsOneWidget); // la finestra resta aperta

    await tester.enterText(find.byKey(const Key('contact-email-0')), 'carla@example.com');
    await tester.tap(find.byKey(const Key('contact-add-email')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('contact-email-1')), 'carla@casa.example');
    await tester.enterText(find.byKey(const Key('contact-phone-0')), '347 9');
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-save')), findsNothing);
    final post = jsonDecode(fake.requests.lastWhere((r) => r.startsWith('POST')).split(' ').skip(2).join(' '));
    expect(post['givenName'], 'Carla');
    expect([for (final e in post['emails'] as List) e['address']], ['carla@example.com', 'carla@casa.example']);
    expect(post['phones'], [
      {'number': '347 9', 'label': 'mobile'},
    ]);
    expect(find.descendant(of: card, matching: find.text('Carla')), findsOneWidget);
    expect(find.text('Contatti: 3'), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('doppio clic apre il contatto e lo modifica; Canc lo elimina dopo la conferma', (tester) async {
    final fake = await start(tester);
    await people(tester);
    final mario = find.descendant(of: list, matching: find.text('Mario Rossi'));
    await tester.tap(mario);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(mario);
    await tester.pumpAndSettle();
    expect(find.text('Contatto'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('contact-display')), 'Il Mario');
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect(fake.requests.where((r) => r.startsWith('PUT /accounts/a1/contacts/01')), hasLength(1));
    expect(find.descendant(of: card, matching: find.text('Il Mario')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('Eliminare il contatto?'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(fake.requests.where((r) => r.startsWith('DELETE')), isEmpty);
    await tester.tap(find.widgetWithText(InkWell, 'Elimina').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();
    expect(fake.requests.where((r) => r.startsWith('DELETE /accounts/a1/contacts/01')), hasLength(1));
    expect(find.descendant(of: list, matching: find.text('Il Mario')), findsNothing);
    expect(find.text('Contatti: 1'), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('Importa… mostra l\'esito; Esporta… salva il file scelto', (tester) async {
    final saver = FakeSaver(answer: '/tmp/contatti.vcf');
    final fake = await start(
      tester,
      picker: FakePicker([PickedFile('rubrica.csv', Uint8List.fromList(utf8.encode('First Name\nX')))]),
      saver: saver,
    );
    await people(tester);
    await tester.tap(find.text('Importa…'));
    await tester.pumpAndSettle();
    expect(find.text('Importazione completata'), findsOneWidget);
    expect(find.textContaining('1 contatto aggiunto'), findsOneWidget);
    expect(find.textContaining('2 già presenti'), findsOneWidget);
    final import = jsonDecode(fake.requests.firstWhere((r) => r.startsWith('POST /accounts/a1/contacts/import')).split(' ').skip(2).join(' '));
    expect(import['format'], 'csv');
    expect(utf8.decode(base64Decode(import['data'] as String)), 'First Name\nX');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Contatti: 3'), findsOneWidget);

    await tester.tap(find.text('Esporta…'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-vcf')));
    await tester.pumpAndSettle();
    expect(saver.suggested, 'Contatti.vcf');
    expect(utf8.decode(saver.written['/tmp/contatti.vcf']!), 'BEGIN:VCARD');
    await fake.core.sse.close();
  });

  testWidgets('«Aggiungi il mittente a Contatti» dal tasto destro: finestra già compilata', (tester) async {
    final fake = await start(tester);
    final row = find.text('Mail 5').first;
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(row, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aggiungi il mittente a Contatti'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('contact-given'))).controller!.text, 'Anna');
    expect(tester.widget<TextField>(find.byKey(const Key('contact-family'))).controller!.text, 'Bianchi');
    expect(tester.widget<TextField>(find.byKey(const Key('contact-email-0'))).controller!.text, 'anna@example.com');
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect(find.text('«Anna Bianchi» salvato in Contatti'), findsOneWidget);
    expect(fake.contacts.where((c) => c['givenName'] == 'Anna'), hasLength(1));

    // Di nuovo: l'indirizzo c'è già, si apre quel contatto (modifica), niente doppione.
    await tester.tap(row, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aggiungi il mittente a Contatti'));
    await tester.pumpAndSettle();
    expect(find.text('Contatto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact-save')));
    await tester.pumpAndSettle();
    expect(fake.contacts.where((c) => c['givenName'] == 'Anna'), hasLength(1));
    await fake.core.sse.close();
  });
}
