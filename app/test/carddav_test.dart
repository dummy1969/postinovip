import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/account/account_config.dart';
import 'package:postinovip/account/account_setup_page.dart';
import 'package:postinovip/account/accounts_page.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/state/contacts_model.dart';

import 'people_test.dart' as pt;
import 'package:postinovip/l10n/app_localizations.dart';

// Contatti C4c: stato della sincronizzazione CardDAV nella vista Persone, «Sincronizza» e F9, conferma della
// prima volta, evento contacts-changed; impostazioni CardDAV dell'account (variabili per il core, JSON).
class CardDavCore {
  final people = pt.PeopleCore();
  final requests = <String>[];
  Map<String, dynamic> status = {
    'enabled': true,
    'state': 'ok',
    'lastSync': DateTime.now().toUtc().toIso8601String(),
    'error': null,
    'needsConfirmation': false,
    'pendingUpload': 0,
    'addressBook': 'Contatti',
  };

  /// Stato dopo la prossima sincronizzazione chiesta (POST sync o confirm).
  Map<String, dynamic> Function()? afterSync;

  void event(Map<String, dynamic> e) => people.core.sse.add(utf8.encode('data: ${jsonEncode(e)}\n\n'));

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = request.url.path;
    http.StreamedResponse json(Object? value, [int status = 200]) => http.StreamedResponse(
      Stream.value(value == null ? <int>[] : utf8.encode(jsonEncode(value))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (path == '/accounts/a1/contacts/sync' && request.method == 'GET') return json(status);
    if (path.startsWith('/accounts/a1/contacts/sync') || path == '/accounts/a1/receive') {
      requests.add('${request.method} $path');
      if (path != '/accounts/a1/receive') {
        status = {
          ...status,
          ...?afterSync?.call(),
          'state': 'ok',
          'lastSync': DateTime.now().toUtc().add(const Duration(seconds: 1)).toIso8601String(),
        };
      }
      return json(null, 202);
    }
    final forward = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = await bodyStream.toBytes();
    final response = await people.client.send(forward);
    if (path == '/accounts' && request.method == 'GET') {
      final list = jsonDecode(await response.stream.bytesToString()) as List;
      return json([
        for (final a in list) {...a as Map<String, dynamic>, 'cardDav': true},
      ]);
    }
    return response;
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<CardDavCore> start(WidgetTester tester, {AccountsEditing? editing, Map<String, dynamic>? status}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  ContactsModel.followInterval = const Duration(milliseconds: 10);
  final fake = CardDavCore();
  if (status != null) fake.status = {...fake.status, ...status};
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: fake.client),
      settings: AppSettings(MemorySettingsStore())..readMode = ReadMode.manual,
      windowPresenter: _NoWindow(),
      accountsEditing: editing,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('module-people')));
  await tester.pumpAndSettle();
  return fake;
}

final status = find.byKey(const Key('sync-status:a1'));
final strip = find.byKey(const Key('carddav-upload-strip'));

String text(WidgetTester tester, Finder f) => tester.widget<Text>(f).data!;

void main() {
  testWidgets('Stato sotto la rubrica e nella barra di stato; Sincronizza e F9', (tester) async {
    final fake = await start(tester);
    expect(text(tester, status), startsWith('Sincronizzata alle '));
    expect(find.textContaining(RegExp(r'Contatti: 2\s+Sincronizzata alle')), findsOneWidget);
    expect(strip, findsNothing);

    await tester.tap(find.text('Sincronizza'));
    await tester.pumpAndSettle();
    expect(fake.requests, ['POST /accounts/a1/contacts/sync']);

    fake.requests.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    expect(fake.requests, containsAll(['POST /accounts/a1/receive', 'POST /accounts/a1/contacts/sync']));

    // Errore: in rosso sotto la rubrica, «Sincronizza» resta per riprovare.
    fake.status = {...fake.status, 'state': 'error', 'error': 'Il server dei contatti ha rifiutato nome utente o password.'};
    fake.event({'type': 'contacts-changed', 'account': 'a1', 'count': 0});
    await tester.pumpAndSettle();
    expect(text(tester, status), 'Il server dei contatti ha rifiutato nome utente o password.');
    expect(tester.widget<Text>(status).style!.color, Theme.of(tester.element(status)).colorScheme.error);
    await fake.people.core.sse.close();
  });

  testWidgets('Prima volta: striscia, Annulla non carica, «Carica sul server» conferma', (tester) async {
    final fake = await start(tester);
    fake.status = {...fake.status, 'needsConfirmation': true, 'pendingUpload': 2};
    fake.event({'type': 'contacts-changed', 'account': 'a1', 'count': 0});
    await tester.pumpAndSettle();
    expect(strip, findsOneWidget);
    expect(find.textContaining('2 contatti sono solo su questo computer'), findsOneWidget);

    await tester.tap(find.text('Carica sul server…'));
    await tester.pumpAndSettle();
    expect(find.text('Caricare i contatti sul server?'), findsOneWidget);
    expect(find.textContaining('rubrica «Contatti» del server'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(fake.requests, isEmpty);
    expect(strip, findsOneWidget);

    fake.afterSync = () => {'needsConfirmation': false, 'pendingUpload': 0};
    await tester.tap(find.text('Carica sul server…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Carica sul server'));
    await tester.pumpAndSettle();
    expect(fake.requests, ['POST /accounts/a1/contacts/sync/confirm']);
    expect(strip, findsNothing);
    await fake.people.core.sse.close();
  });

  testWidgets('Gmail senza il permesso dei contatti (C4d): striscia con «Accedi di nuovo»', (tester) async {
    const error = 'L\'accesso con Google non comprende i contatti: nella schermata dell\'account usa «Accedi di nuovo» e '
        'permetti l\'accesso ai contatti.';
    final gmail = AccountConfig(
        id: 'a1', email: 'io@gmail.com', password: '', imapHost: 'imap.gmail.com', smtpHost: 'smtp.gmail.com',
        oauthProvider: 'google', refreshToken: 'RT1', cardDavEnabled: true);
    await start(tester,
        editing: AccountsEditing(accounts: [gmail], coreAddress: '', save: (_) async {}),
        status: {'state': 'error', 'error': error, 'errorCode': 'accountScopeMissingContacts', 'errorArgs': {'provider': 'Google'}});
    expect(find.byKey(const Key('carddav-relogin-strip')), findsOneWidget);
    expect(text(tester, status), error);
    await tester.tap(find.byKey(const Key('carddav-relogin')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSetupPage), findsOneWidget);
  });

  testWidgets('Account con password e un errore qualsiasi: nessuna striscia', (tester) async {
    await start(tester, status: {'state': 'error', 'error': 'Il server dei contatti ha risposto 500.'});
    expect(find.byKey(const Key('carddav-relogin-strip')), findsNothing);
  });

  testWidgets('contacts-changed rilegge la rubrica aperta', (tester) async {
    final fake = await start(tester);
    fake.people.contacts.add(pt.PeopleCore.contact('09', 'Elena', 'Blu', 'elena@example.com'));
    fake.event({'type': 'contacts-changed', 'account': 'a1', 'count': 1});
    await tester.pumpAndSettle();
    expect(find.descendant(of: pt.list, matching: find.text('Elena Blu')), findsOneWidget);
    expect(find.textContaining('Contatti: 3'), findsOneWidget);
    await fake.people.core.sse.close();
  });

  testWidgets('Schermata dell\'account: sezione Contatti, «Verifica rubrica», salvataggio senza nuova verifica', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tests = <Map<String, dynamic>>[];
    final api = ApiClient(
      httpClient: MockClient((request) async {
        http.Response json(Object body) =>
            http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        if (request.url.path == '/account/test-carddav') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          tests.add(body);
          return json(body['url'] == 'https://sbagliato.example/'
              ? {'ok': false, 'error': 'Nessuna rubrica trovata sul server dei contatti.'}
              : {'ok': true, 'addressBook': 'Contatti', 'url': 'https://imap.example.com/webdav/io/Contatti/'});
        }
        if (request.url.path == '/oauth/providers') return json([]);
        return http.Response('', 404);
      }),
    );
    AccountConfig? saved;
    final initial = AccountConfig(
      id: 'a1',
      email: 'io@example.com',
      password: 'segreta',
      imapHost: 'imap.example.com',
      smtpHost: 'smtp.example.com',
    );
    await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      home: AccountSetupPage(api: api, initial: initial, onSave: (a) async => saved = a),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sincronizza i contatti con il server (CardDAV)'), findsOneWidget);
    expect(find.byKey(const Key('carddav-url')), findsNothing); // spenta di serie

    await tester.tap(find.byKey(const Key('carddav-enabled')));
    await tester.pumpAndSettle();
    expect(find.text('Vuoto: cercato da solo su imap.example.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('carddav-test')));
    await tester.pumpAndSettle();
    expect(find.text('Trovata: «Contatti»'), findsOneWidget);
    expect(tests.single, {'email': 'io@example.com', 'password': 'segreta', 'host': 'imap.example.com'});

    await tester.enterText(find.byKey(const Key('carddav-url')), 'https://sbagliato.example/');
    await tester.pump();
    expect(find.byKey(const Key('carddav-result')), findsNothing); // cambiato l'indirizzo: esito tolto
    await tester.tap(find.byKey(const Key('carddav-test')));
    await tester.pumpAndSettle();
    expect(find.text('Nessuna rubrica trovata sul server dei contatti.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('carddav-url')), 'http://non-cifrato.example/');
    await tester.pump();
    await tester.tap(find.byKey(const Key('carddav-test')));
    await tester.pumpAndSettle();
    expect(find.text('Serve un indirizzo https://'), findsWidgets);
    expect(tests, hasLength(2)); // niente richiesta al core

    await tester.enterText(find.byKey(const Key('carddav-url')), '');
    await tester.pump();
    await tester.tap(find.text('Salva')); // account già verificato: «Salva» attivo senza nuova verifica
    await tester.pump(); // l'indicatore di salvataggio gira finché l'app non cambia pagina: niente pumpAndSettle
    expect((saved?.cardDavEnabled, saved?.cardDavUrl), (true, null));
  });

  group('impostazioni dell\'account', () {
    AccountConfig account({bool enabled = true, String? url}) => AccountConfig(
      id: 'a1',
      email: 'io@example.com',
      password: 'x',
      imapHost: 'imap.example.com',
      smtpHost: 'smtp.example.com',
      cardDavEnabled: enabled,
      cardDavUrl: url,
    );

    test('variabili per il core', () {
      expect(account().toCoreEnvironment(0)['Accounts__0__CardDav__Enabled'], 'true');
      expect(account().toCoreEnvironment(0).containsKey('Accounts__0__CardDav__Url'), isFalse);
      expect(account(url: 'https://dav.example.com/').toCoreEnvironment(0)['Accounts__0__CardDav__Url'], 'https://dav.example.com/');
      expect(account(enabled: false).toCoreEnvironment(0).keys.where((k) => k.contains('CardDav')), isEmpty);
    });

    test('JSON e account salvati prima', () {
      final back = AccountConfig.fromJson(account(url: 'https://dav.example.com/').toJson());
      expect((back.cardDavEnabled, back.cardDavUrl), (true, 'https://dav.example.com/'));
      final old = account(enabled: false).toJson()..remove('cardDavEnabled');
      expect(AccountConfig.fromJson(old).cardDavEnabled, isFalse);
      expect(account(url: 'https://x/').copyWith(cardDavUrl: '  ').cardDavUrl, isNull);
      expect(account().sameConnection(account(enabled: false)), isTrue); // nessuna nuova verifica della posta
    });
  });
}
