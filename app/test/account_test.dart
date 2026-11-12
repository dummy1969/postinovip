import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/account/account_config.dart';
import 'package:postinovip/account/account_setup_page.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/core/core_gate.dart';
import 'package:postinovip/core/core_launcher.dart';

const account = AccountConfig(
    id: 'a1', email: 'io@example.com', password: 'segreta', imapHost: 'imap.example.com', smtpHost: 'smtp.example.com');

const second = AccountConfig(
    id: 'b2',
    name: 'Lavoro',
    email: 'lavoro@example.com',
    password: 'altra',
    imapHost: 'imap.lavoro.example',
    smtpHost: 'smtp.lavoro.example');

/// Simula il core: risulta configurato solo se è stato avviato con la password del primo account.
class FakeCores {
  final starts = <Map<String, String>>[];
  final tests = <Map<String, dynamic>>[];
  bool testOk = true;

  /// OAuth2 (O2): il core ha il client ID di Microsoft; l'accesso nel browser finisce alla seconda lettura dello stato.
  bool oauthConfigured = false;
  int oauthPolls = 0;
  final oauthRequests = <String>[];

  /// C4d: anche Gmail nei fornitori; l'accesso chiesto con i contatti dà RT2 e [grantContacts].
  bool googleConfigured = false;
  bool grantContacts = true;
  bool _contactsAsked = false;
  final cardDavTests = <Map<String, dynamic>>[];

  /// G3: l'accesso chiesto con il calendario dà RT2 e [grantCalendar].
  bool grantCalendar = true;
  bool _calendarAsked = false;
  final calDavTests = <Map<String, dynamic>>[];

  /// Se impostata: il server IMAP presenta un certificato non valido con questa impronta (4.1), accettato
  /// solo se la richiesta lo indica come certificato di cui fidarsi.
  String? imapCertificate;

  /// Dati locali di account rimossi (GET /cache/orphans) e richieste ricevute sulla cache.
  final orphans = <Map<String, dynamic>>[];
  final cacheRequests = <String>[];

  Future<CoreHandle> start(Map<String, String> env) async {
    starts.add(env);
    return CoreHandle.external(CoreConnection(baseUrl: 'http://127.0.0.1:${40000 + starts.length}', token: 't'));
  }

  ApiClient api(CoreConnection c) {
    final env = starts.last;
    return ApiClient(
        baseUrl: c.baseUrl,
        httpClient: MockClient((request) async {
          http.Response json(Object body) =>
              http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
          switch (request.url.path) {
            case '/account':
              return json({
                'address': env['Accounts__0__Imap__Username'] ?? env['Accounts__0__Pop3__Username'] ?? '',
                'configured': env.containsKey('Accounts__0__Imap__Password') ||
                    env.containsKey('Accounts__0__Pop3__Password') ||
                    env.containsKey('Accounts__0__OAuth__RefreshToken'),
              });
            case '/account/test':
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              tests.add(body);
              final cert = imapCertificate;
              if (cert != null && body['imapCertificateSha256'] != cert) {
                return json({
                  'imap': {
                    'ok': false,
                    'error': 'Il certificato del server non è valido: autofirmato.',
                    'certificate': {
                      'host': body['imapHost'], 'port': body['imapPort'], 'subject': 'CN=posta.locale',
                      'issuer': 'CN=posta.locale', 'notBefore': '2026-01-01T00:00:00+00:00',
                      'notAfter': '2027-01-01T00:00:00+00:00', 'sha256': cert,
                      'problems': ["non firmato da un'autorità riconosciuta (es. autofirmato)"],
                    },
                  },
                  'smtp': {'ok': true},
                });
              }
              return json(testOk
                  ? {
                      'imap': {'ok': true},
                      'smtp': {'ok': true},
                    }
                  : {
                      'imap': {'ok': false, 'error': 'Autenticazione rifiutata: controllare indirizzo e password.'},
                      'smtp': {'ok': true},
                    });
            case '/folders':
              return json([]);
            case '/oauth/providers':
              return json([
                {'id': 'microsoft', 'name': 'Microsoft', 'configured': oauthConfigured},
                if (googleConfigured) {'id': 'google', 'name': 'Google', 'configured': true},
              ]);
            case '/account/test-carddav':
              cardDavTests.add(jsonDecode(request.body) as Map<String, dynamic>);
              return json({'ok': true, 'addressBook': 'Address Book', 'url': 'https://www.googleapis.com/carddav/v1/x/lists/default/'});
            case '/account/test-caldav':
              calDavTests.add(jsonDecode(request.body) as Map<String, dynamic>);
              return json({'ok': true, 'calendars': ['io@gmail.com', 'Festività in Italia']});
            case '/oauth/start':
              oauthRequests.add('start ${request.body}');
              final asked = jsonDecode(request.body) as Map<String, dynamic>;
              _contactsAsked = asked['contacts'] == true;
              _calendarAsked = asked['calendar'] == true;
              return json({'id': 'f1', 'authorizationUrl': 'https://login.example/authorize?x=1'});
            case '/oauth/flows/f1':
              if (request.method == 'DELETE') {
                oauthRequests.add('cancel');
                return http.Response('', 204);
              }
              return json(++oauthPolls < 2
                  ? {'status': 'pending'}
                  : {
                      'status': 'done', 'email': 'io@outlook.it', 'refreshToken': _contactsAsked || _calendarAsked ? 'RT2' : 'RT1',
                      if (_contactsAsked) 'contacts': grantContacts,
                      if (_calendarAsked) 'calendar': grantCalendar,
                      'servers': {
                        'imapHost': 'outlook.office365.com', 'imapPort': 993, 'smtpHost': 'smtp.office365.com',
                        'smtpPort': 587, 'pop3Host': 'outlook.office365.com', 'pop3Port': 995,
                      },
                    });
            case '/cache/orphans':
              return json(orphans);
          }
          if (request.method == 'DELETE' && request.url.path.startsWith('/cache/orphans/')) {
            cacheRequests.add('DELETE ${request.url.path}');
            orphans.removeWhere((o) => o['id'] == request.url.pathSegments.last);
            return http.Response('', 204);
          }
          if (request.method == 'POST' && request.url.path.endsWith('/cache/rebuild')) {
            cacheRequests.add('POST ${request.url.path}');
            return http.Response('', 202);
          }
          return http.Response('{}', 404);
        }));
  }
}

Future<void> pumpGate(WidgetTester tester, FakeCores cores, AccountStore store) async {
  tester.view.physicalSize = const Size(1400, 1700); // il modulo POP3 è lungo: tutto visibile
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(CoreGate(start: cores.start, apiFactory: cores.api, accountStore: store));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String label, String text, {int index = 0}) =>
    tester.enterText(find.widgetWithText(TextFormField, label).at(index), text);

Future<void> fill(WidgetTester tester, [AccountConfig a = account]) async {
  await type(tester, 'Indirizzo email (anche nome utente)', a.email);
  await type(tester, 'Password', a.password);
  await type(tester, 'Server', a.imapHost);
  await type(tester, 'Server', a.smtpHost, index: 1);
  await tester.pump();
}

FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(of: find.text('Salva'), matching: find.byWidgetPredicate((w) => w is FilledButton)));

/// Dall'app principale: File -> Opzioni -> "Gestisci…" -> finestra Account.
Future<void> openAccountsPage(WidgetTester tester) async {
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Opzioni'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gestisci…'));
  await tester.pumpAndSettle();
}

void main() {
  group('AccountConfig', () {
    test('variabili per il core: un blocco Accounts__N__ per account, nell\'ordine', () {
      final env = AccountConfig.coreEnvironment([account, second]);
      expect(account.toCoreEnvironment(0), {
        'Accounts__0__Id': 'a1', 'Accounts__0__Name': '',
        'Accounts__0__Imap__Host': 'imap.example.com', 'Accounts__0__Imap__Port': '993',
        'Accounts__0__Imap__Username': 'io@example.com', 'Accounts__0__Imap__Password': 'segreta',
        'Accounts__0__Smtp__Host': 'smtp.example.com', 'Accounts__0__Smtp__Port': '587',
        'Accounts__0__Smtp__Username': 'io@example.com', 'Accounts__0__Smtp__Password': 'segreta',
        'Accounts__0__Cache__BodyMonths': '12',
        'Accounts__0__Imap__Security': 'SslOnConnect', 'Accounts__0__Smtp__Security': 'StartTls',
        'Accounts__0__Smtp__RequireAuth': 'true',
      });
      expect(env['Accounts__1__Id'], 'b2');
      expect(env['Accounts__1__Name'], 'Lavoro');
      expect(env['Accounts__1__Imap__Host'], 'imap.lavoro.example');
      expect(AccountConfig.coreEnvironment([]), isEmpty); // in sviluppo: user-secrets
    });

    test('JSON andata e ritorno; voce a un account senza id', () {
      final back = AccountConfig.fromJson(jsonDecode(jsonEncode(second.toJson())) as Map<String, dynamic>);
      expect(back.toCoreEnvironment(0), second.toCoreEnvironment(0));

      final legacy = account.toJson()
        ..remove('id')
        ..remove('name');
      final migrated = AccountConfig.fromJson(legacy, fallbackId: 'xyz');
      expect((migrated.id, migrated.name, migrated.email), ('xyz', '', 'io@example.com'));

      // Account salvati prima dell'8b-3: senza limite -> 12 mesi.
      final before8b3 = second.toJson()..remove('bodyMonths');
      expect(AccountConfig.fromJson(before8b3).bodyMonths, 12);
      final all = second.copyWith(bodyMonths: 0);
      expect(AccountConfig.fromJson(jsonDecode(jsonEncode(all.toJson())) as Map<String, dynamic>).bodyMonths, 0);
      expect(all.toCoreEnvironment(1)['Accounts__1__Cache__BodyMonths'], '0');
      expect(all.sameConnection(second), isTrue); // non è un dato di connessione
    });

    test('id casuali di 8 caratteri e diversi da quelli esistenti', () {
      final id = AccountConfig.newId();
      expect(id, matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(AccountConfig.newId([id]), isNot(id));
    });

    test('nome mostrato: nome se presente, altrimenti indirizzo', () {
      expect(account.displayName, 'io@example.com');
      expect(second.displayName, 'Lavoro');
    });
  });

  testWidgets('primo avvio: configurazione, verifica, salvataggio e riavvio del core', (tester) async {
    final cores = FakeCores();
    final store = MemoryAccountStore();
    await pumpGate(tester, cores, store);

    expect(find.text('Benvenuto in PostinoVip'), findsOneWidget);
    expect(cores.starts.single, isEmpty); // nessun account salvato
    await fill(tester);
    expect(saveButton(tester).onPressed, isNull); // prima della verifica

    await tester.tap(find.text('Verifica connessione'));
    await tester.pumpAndSettle();
    expect(cores.tests.single['imapHost'], 'imap.example.com');
    expect(cores.tests.single['imapPort'], 993);
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(store.accounts.single.password, 'segreta');
    expect(store.accounts.single.id, matches(RegExp(r'^[0-9a-f]{8}$')));
    expect(cores.starts, hasLength(2)); // riavviato con i nuovi dati
    expect(cores.starts.last['Accounts__0__Imap__Password'], 'segreta');
    expect(find.text('Nuovo messaggio'), findsOneWidget); // app principale
  });

  testWidgets('verifica fallita: errore sul server, "Salva" resta disattivato', (tester) async {
    final cores = FakeCores()..testOk = false;
    await pumpGate(tester, cores, MemoryAccountStore());
    await fill(tester);

    await tester.tap(find.text('Verifica connessione'));
    await tester.pumpAndSettle();

    expect(find.text('Autenticazione rifiutata: controllare indirizzo e password.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('modifica dopo la verifica: va rifatta', (tester) async {
    final cores = FakeCores();
    await pumpGate(tester, cores, MemoryAccountStore());
    await fill(tester);
    await tester.tap(find.text('Verifica connessione'));
    await tester.pumpAndSettle();
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'altra');
    await tester.pump();

    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('account già salvati: core avviato con tutti, nessuna schermata', (tester) async {
    final cores = FakeCores();
    await pumpGate(tester, cores, MemoryAccountStore([account, second]));

    expect(cores.starts.single['Accounts__0__Smtp__Host'], 'smtp.example.com');
    expect(cores.starts.single['Accounts__1__Smtp__Host'], 'smtp.lavoro.example');
    expect(find.text('Benvenuto in PostinoVip'), findsNothing);
    expect(find.text('Nuovo messaggio'), findsOneWidget);
  });

  group('pagina Account', () {
    testWidgets('aggiungi: verifica, salvataggio in coda all\'elenco, riavvio con due account', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore([account]);
      await pumpGate(tester, cores, store);
      await openAccountsPage(tester);
      expect(find.descendant(of: find.byKey(const Key('accounts-dialog')), matching: find.text('io@example.com')), findsOneWidget);

      await tester.tap(find.text('Aggiungi account'));
      await tester.pumpAndSettle();
      expect(find.text('Nuovo account'), findsOneWidget);
      await type(tester, 'Nome (facoltativo)', 'Lavoro');
      await fill(tester, second);
      await tester.tap(find.text('Verifica connessione'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      // In sospeso nella finestra Account (1a): niente salvato né riavviato finché non si preme OK.
      expect(find.text('Lavoro'), findsOneWidget);
      expect(find.byTooltip('Ricostruisci cache'), findsOneWidget); // solo per quello già salvato
      expect(store.accounts, hasLength(1));
      expect(cores.starts, hasLength(1));
      await tester.tap(find.byKey(const Key('accounts-ok')));
      await tester.pumpAndSettle();

      expect(store.accounts.map((a) => a.displayName), ['io@example.com', 'Lavoro']);
      expect(store.accounts.first.id, 'a1'); // il primo resta invariato
      expect(cores.starts, hasLength(2));
      expect(cores.starts.last['Accounts__1__Imap__Username'], 'lavoro@example.com');
      expect(find.text('Nuovo messaggio'), findsOneWidget); // app ricreata
    });

    testWidgets('«Annulla» scarta le modifiche in sospeso e riporta alle Opzioni', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore([account, second]);
      await pumpGate(tester, cores, store);
      await openAccountsPage(tester);
      expect(find.byKey(const Key('accounts-dialog')), findsOneWidget);
      await tester.tap(find.byTooltip('Rimuovi dall\'app').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rimuovi'));
      await tester.pumpAndSettle();
      expect(find.text('Lavoro'), findsNothing);
      expect(find.textContaining('Modifiche non ancora salvate'), findsOneWidget);

      await tester.tap(find.byKey(const Key('accounts-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-dialog')), findsOneWidget); // di nuovo nelle Opzioni
      expect(store.accounts, hasLength(2)); // niente rimosso
      expect(cores.starts, hasLength(1));
      await tester.tap(find.text('Gestisci…'));
      await tester.pumpAndSettle();
      expect(find.text('Lavoro'), findsOneWidget);
    });

    testWidgets('Nuovo account: «Annulla» chiude la finestra senza aggiungere', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore([account]);
      await pumpGate(tester, cores, store);
      await openAccountsPage(tester);
      await tester.tap(find.text('Aggiungi account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-setup-dialog')), findsOneWidget);
      await fill(tester, second);
      await tester.tap(find.byKey(const Key('account-setup-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-setup-dialog')), findsNothing);
      expect(find.byKey(const Key('accounts-dialog')), findsOneWidget);
      expect(find.text('lavoro@example.com'), findsNothing);
      expect(find.textContaining('Modifiche non ancora salvate'), findsNothing);
    });

    testWidgets('aggiungi un indirizzo già presente: "Salva" resta disattivato', (tester) async {
      final cores = FakeCores();
      await pumpGate(tester, cores, MemoryAccountStore([account]));
      await openAccountsPage(tester);
      await tester.tap(find.text('Aggiungi account'));
      await tester.pumpAndSettle();

      await fill(tester); // stesso indirizzo del primo account
      await tester.tap(find.text('Verifica connessione'));
      await tester.pumpAndSettle();

      expect(find.text('Questo account è già presente'), findsOneWidget);
      expect(cores.tests, isEmpty); // la verifica non parte nemmeno
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('modifica solo il nome: niente verifica, stesso id', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore([account, second]);
      await pumpGate(tester, cores, store);
      await openAccountsPage(tester);

      await tester.tap(find.byTooltip('Modifica').first);
      await tester.pumpAndSettle();
      expect(find.text('Modifica account'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull); // dati già verificati al salvataggio

      await type(tester, 'Nome (facoltativo)', 'Personale');
      await tester.pump();
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accounts-ok')));
      await tester.pumpAndSettle();

      expect(cores.tests, isEmpty);
      expect(store.accounts.map((a) => (a.id, a.displayName)), [('a1', 'Personale'), ('b2', 'Lavoro')]);
    });

    testWidgets('cambia solo le mail scaricate: niente verifica, core riavviato con il nuovo limite', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore([account, second]);
      await pumpGate(tester, cores, store);
      await openAccountsPage(tester);
      expect(find.textContaining('Mail scaricate: ultimi 12 mesi'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Modifica').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ultimi 12 mesi (consigliato)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tutte').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accounts-ok')));
      await tester.pumpAndSettle();

      expect(cores.tests, isEmpty);
      expect(store.accounts.map((a) => a.bodyMonths), [12, 0]);
      expect(cores.starts, hasLength(2));
      expect(cores.starts.last['Accounts__1__Cache__BodyMonths'], '0');
      expect(cores.starts.last['Accounts__0__Cache__BodyMonths'], '12');
    });

    testWidgets('dati di account rimossi: elenco con lo spazio, eliminazione solo dopo conferma', (tester) async {
      final cores = FakeCores()
        ..orphans.addAll([
          {'id': 'old1', 'name': 'Vecchio', 'address': 'vecchio@example.com', 'sizeBytes': 13 * 1024 * 1024},
          {'id': 'main', 'name': null, 'address': null, 'sizeBytes': 2048},
        ]);
      await pumpGate(tester, cores, MemoryAccountStore([account]));
      await openAccountsPage(tester);

      expect(find.text('Dati di account rimossi'), findsOneWidget);
      expect(find.text('vecchio@example.com'), findsOneWidget);
      expect(find.text('13,0 MB'), findsOneWidget);
      expect(find.text('account main'), findsOneWidget); // senza indirizzo noto

      await tester.tap(find.text('Elimina dati locali').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Sul server non viene modificato nulla'), findsOneWidget);
      await tester.tap(find.text('Annulla').last); // quello della conferma, sopra la finestra Account
      await tester.pumpAndSettle();
      expect(cores.cacheRequests, isEmpty);

      await tester.tap(find.text('Elimina dati locali').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
      await tester.pumpAndSettle();

      expect(cores.cacheRequests, ['DELETE /cache/orphans/old1']); // il primo dell'elenco
      expect(find.text('vecchio@example.com'), findsNothing); // elenco riletto dal core
      expect(find.text('account main'), findsOneWidget);
      expect(cores.starts, hasLength(1)); // nessun riavvio del core
    });

    testWidgets('nessun dato di account rimossi: nessuna sezione', (tester) async {
      await pumpGate(tester, FakeCores(), MemoryAccountStore([account]));
      await openAccountsPage(tester);

      expect(find.text('Dati di account rimossi'), findsNothing);
    });

    testWidgets('ricostruisci cache: conferma che spiega, poi richiesta per quell\'account', (tester) async {
      final cores = FakeCores();
      await pumpGate(tester, cores, MemoryAccountStore([account, second]));
      await openAccountsPage(tester);

      await tester.tap(find.byTooltip('Ricostruisci cache').last);
      await tester.pumpAndSettle();
      expect(find.text('Ricostruire la copia locale?'), findsOneWidget);
      expect(find.textContaining('Sul server non viene modificato nulla'), findsOneWidget);
      await tester.tap(find.text('Ricostruisci'));
      await tester.pumpAndSettle();

      expect(cores.cacheRequests, ['POST /accounts/b2/cache/rebuild']);
      expect(find.textContaining('Ricostruzione della copia locale di «Lavoro» avviata'), findsOneWidget);
      expect(cores.starts, hasLength(1));
    });

    testWidgets('rimuovi: conferma che spiega, solo locale; "Annulla" non cambia nulla', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore([account, second]);
      await pumpGate(tester, cores, store);
      await openAccountsPage(tester);

      await tester.tap(find.byTooltip('Rimuovi dall\'app').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Sul server non viene modificato nulla'), findsOneWidget);
      await tester.tap(find.text('Annulla').last); // quello della conferma, sopra la finestra Account
      await tester.pumpAndSettle();
      expect(store.accounts, hasLength(2));
      expect(cores.starts, hasLength(1));

      await tester.tap(find.byTooltip('Rimuovi dall\'app').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rimuovi'));
      await tester.pumpAndSettle();
      expect(store.accounts, hasLength(2)); // in sospeso fino a OK
      await tester.tap(find.byKey(const Key('accounts-ok')));
      await tester.pumpAndSettle();

      expect(store.accounts.map((a) => a.id), ['a1']);
      expect(cores.starts, hasLength(2));
      expect(cores.starts.last.containsKey('Accounts__1__Id'), isFalse);
    });
  });

  group('crittografia e certificati (4.1)', () {
    final sha = 'AB' * 32;

    test('JSON: account salvati prima della 4.1 secondo la porta; andata e ritorno', () {
      final old = account.toJson()
        ..remove('imapSecurity')
        ..remove('smtpSecurity')
        ..remove('smtpRequireAuth');
      final back = AccountConfig.fromJson(old);
      expect((back.imapSecurity, back.smtpSecurity, back.smtpRequireAuth), (MailSecurity.ssl, MailSecurity.startTls, true));

      const custom = AccountConfig(
          id: 'c3', email: 'x@lan', password: 'p', imapHost: 'lan', imapPort: 143, smtpHost: 'lan', smtpPort: 25,
          smtpSecurity: MailSecurity.none, smtpRequireAuth: false, imapCertificateSha256: 'FF');
      expect(custom.imapSecurity, MailSecurity.startTls); // dalla porta 143
      final again = AccountConfig.fromJson(jsonDecode(jsonEncode(custom.toJson())) as Map<String, dynamic>);
      expect(again.sameConnection(custom), isTrue);
      final env = custom.toCoreEnvironment(0);
      expect(env['Accounts__0__Imap__Security'], 'StartTls');
      expect(env['Accounts__0__Smtp__Security'], 'None');
      expect(env['Accounts__0__Smtp__RequireAuth'], 'false');
      expect(env['Accounts__0__Imap__CertificateSha256'], 'FF');
      expect(env.containsKey('Accounts__0__Smtp__CertificateSha256'), isFalse);
      expect(custom.hasUnencrypted, isTrue);
      expect(custom.sameConnection(AccountConfig.fromJson({...custom.toJson(), 'smtpRequireAuth': true})), isFalse);
    });

    testWidgets('porta nota -> crittografia proposta; autenticazione SMTP facoltativa', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore();
      await pumpGate(tester, cores, store);
      await fill(tester);
      await type(tester, 'Porta', '143');
      await type(tester, 'Porta', '465', index: 1);
      await tester.pump();
      expect(find.text('STARTTLS'), findsOneWidget); // IMAP 143
      expect(find.text('SSL/TLS'), findsOneWidget); // SMTP 465

      await tester.tap(find.byKey(const Key('smtp-auth')));
      await tester.pump();
      await tester.tap(find.text('Verifica connessione'));
      await tester.pumpAndSettle();

      final sent = cores.tests.single;
      expect((sent['imapSecurity'], sent['smtpSecurity'], sent['smtpRequireAuth']), ('StartTls', 'SslOnConnect', false));
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect(store.accounts.single.smtpRequireAuth, isFalse);
      expect(cores.starts.last['Accounts__0__Smtp__Security'], 'SslOnConnect');
    });

    testWidgets('crittografia cambiata -> porta standard; porta personalizzata invariata', (tester) async {
      final cores = FakeCores();
      await pumpGate(tester, cores, MemoryAccountStore());
      await fill(tester);
      String port(int i) =>
          tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Porta').at(i)).controller!.text;
      Future<void> choose(String current, String label, {int index = 0}) async {
        await tester.tap(find.text(current).at(index));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await choose('SSL/TLS', 'STARTTLS'); // IMAP 993 -> 143
      expect(port(0), '143');
      await choose('STARTTLS', 'SSL/TLS', index: 1); // SMTP 587 -> 465 (index 1: la prima è IMAP)
      expect(port(1), '465');
      await choose('SSL/TLS', 'Nessuna'); // SMTP è ora SSL/TLS, l'unico
      expect(port(1), '25');

      await type(tester, 'Porta', '1143');
      await tester.pump();
      await choose('STARTTLS', 'SSL/TLS');
      expect(port(0), '1143'); // personalizzata: resta
    });

    testWidgets('certificato non valido: "Fidarsi?", poi verifica ripetuta con l\'impronta e salvata', (tester) async {
      final cores = FakeCores()..imapCertificate = sha;
      final store = MemoryAccountStore();
      await pumpGate(tester, cores, store);
      await fill(tester);

      await tester.tap(find.text('Verifica connessione'));
      await tester.pumpAndSettle();
      expect(find.text('Fidarsi di questo certificato?'), findsOneWidget);
      expect(find.text(List.filled(32, 'AB').join(':')), findsOneWidget);
      expect(find.textContaining('autofirmato'), findsWidgets);

      await tester.tap(find.text('Fidati del certificato'));
      await tester.pumpAndSettle();
      expect(cores.tests, hasLength(2));
      expect(cores.tests.last['imapCertificateSha256'], sha);
      expect(find.textContaining('Certificato del server accettato da te'), findsOneWidget);

      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect(store.accounts.single.imapCertificateSha256, sha);
      expect(cores.starts.last['Accounts__0__Imap__CertificateSha256'], sha);
    });

    testWidgets('certificato non valido e "Annulla": nessuna nuova prova, "Salva" disattivato', (tester) async {
      final cores = FakeCores()..imapCertificate = sha;
      await pumpGate(tester, cores, MemoryAccountStore());
      await fill(tester);

      await tester.tap(find.text('Verifica connessione'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(cores.tests, hasLength(1));
      expect(find.text('Il certificato del server non è valido: autofirmato.'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    });

    testWidgets('"Nessuna": avviso rosso e conferma esplicita prima di salvare', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore();
      await pumpGate(tester, cores, store);
      await fill(tester);
      await type(tester, 'Porta', '25', index: 1);
      await tester.pump();

      await tester.tap(find.text('STARTTLS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nessuna').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('viaggiano in chiaro'), findsOneWidget);

      await tester.tap(find.text('Verifica connessione'));
      await tester.pumpAndSettle();
      expect(cores.tests.single['smtpSecurity'], 'None');

      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      expect(find.text('Connessione senza crittografia'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(store.accounts, isEmpty);

      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva senza crittografia'));
      await tester.pumpAndSettle();
      expect(store.accounts.single.smtpSecurity, MailSecurity.none);
      expect(cores.starts.last['Accounts__0__Smtp__Security'], 'None');
    });
  });

  group('POP3 (4.2c)', () {
    const pop3 = AccountConfig(
        id: 'p3', type: AccountType.pop3, email: 'pop@example.com', password: 'pw', imapHost: 'pop.example.com',
        imapPort: 995, smtpHost: 'smtp.example.com', removeAfterDays: 30, removeWhenDeleted: true, checkMinutes: 5);

    test('variabili per il core: sezione Pop3, nessuna Imap; JSON andata e ritorno', () {
      final env = pop3.toCoreEnvironment(0);
      expect(env['Accounts__0__Type'], 'Pop3');
      expect(env['Accounts__0__Pop3__Host'], 'pop.example.com');
      expect(env['Accounts__0__Pop3__Port'], '995');
      expect(env['Accounts__0__Pop3__Security'], 'SslOnConnect');
      expect(env['Accounts__0__Pop3__Password'], 'pw');
      expect(env['Accounts__0__Pop3__LeaveOnServer'], 'true');
      expect(env['Accounts__0__Pop3__RemoveAfterDays'], '30');
      expect(env['Accounts__0__Pop3__RemoveWhenDeleted'], 'true');
      expect(env['Accounts__0__Pop3__CheckMinutes'], '5');
      expect(env['Accounts__0__Smtp__Username'], 'pop@example.com');
      expect(env.keys.where((k) => k.contains('__Imap__')), isEmpty);
      expect(pop3.copyWith(removeAfter: false).toCoreEnvironment(0)['Accounts__0__Pop3__RemoveAfterDays'], '0');
      expect(const AccountConfig(id: 'x', type: AccountType.pop3, email: 'a@b', password: 'p', imapHost: 'h', imapPort: 110,
              smtpHost: 'h').imapSecurity, MailSecurity.startTls);

      final back = AccountConfig.fromJson(jsonDecode(jsonEncode(pop3.toJson())) as Map<String, dynamic>);
      expect(back.toCoreEnvironment(0), env);
      expect(back.sameConnection(pop3.copyWith(removeAfterDays: 7, checkMinutes: 60)), isTrue); // opzioni: niente verifica
      expect(AccountConfig.fromJson(account.toJson()..remove('type')).type, AccountType.imap); // salvati prima della 4.2
    });

    testWidgets('nuovo account POP3: porta 995, opzioni di Outlook, prova con type Pop3', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore();
      await pumpGate(tester, cores, store);
      await tester.tap(find.byKey(const Key('account-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POP3').last);
      await tester.pumpAndSettle();

      expect(find.text('POP3 (posta in arrivo)'), findsOneWidget);
      expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Porta').first).controller!.text, '995');
      expect(find.text('Mail scaricate sul computer'), findsNothing); // vale solo per IMAP
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('pop3-leave'))).value, isTrue);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('pop3-remove-after'))).value, isTrue);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('pop3-remove-deleted'))).value, isFalse);

      await fill(tester);
      await tester.enterText(find.byKey(const Key('pop3-remove-days')), '30');
      await tester.ensureVisible(find.byKey(const Key('pop3-remove-deleted')));
      await tester.tap(find.byKey(const Key('pop3-remove-deleted')));
      await tester.pump();
      await tester.tap(find.text('Verifica connessione'));
      await tester.pumpAndSettle();
      expect(cores.tests.single['type'], 'Pop3');
      expect(cores.tests.single['imapPort'], 995);

      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      final saved = store.accounts.single;
      expect((saved.type, saved.removeAfterDays, saved.removeWhenDeleted, saved.leaveOnServer), (AccountType.pop3, 30, true, true));
      expect(cores.starts.last['Accounts__0__Pop3__RemoveAfterDays'], '30');
    });

    testWidgets('lascia una copia spenta: le altre rimozioni si disattivano e compare l\'avviso', (tester) async {
      await pumpGate(tester, FakeCores(), MemoryAccountStore());
      await tester.tap(find.byKey(const Key('account-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POP3').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('pop3-leave')));
      await tester.tap(find.byKey(const Key('pop3-leave')));
      await tester.pump();

      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('pop3-remove-after'))).onChanged, isNull);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('pop3-remove-deleted'))).onChanged, isNull);
      expect(find.textContaining('tolta dal server subito dopo'), findsOneWidget);
    });

    testWidgets('stessa casella IMAP e POP3: permesso con avviso; stesso tipo no', (tester) async {
      final cores = FakeCores();
      await pumpGate(tester, cores, MemoryAccountStore([account]));
      await openAccountsPage(tester);
      await tester.tap(find.text('Aggiungi account'));
      await tester.pumpAndSettle();
      await fill(tester); // stesso indirizzo di "account", IMAP
      await tester.tap(find.text('Verifica connessione'));
      await tester.pumpAndSettle();
      expect(find.text('Questo account è già presente'), findsOneWidget);

      await tester.tap(find.byKey(const Key('account-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POP3').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verifica connessione'));
      await tester.pumpAndSettle();
      expect(find.text('Questo account è già presente'), findsNothing);
      expect(find.textContaining('già configurata come IMAP'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('modifica di un POP3: tipo non modificabile, opzioni senza nuova verifica', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore([pop3]);
      await pumpGate(tester, cores, store);
      await openAccountsPage(tester);
      expect(find.byTooltip('Ricostruisci cache'), findsNothing); // 5a
      expect(find.textContaining('copia sul server per 30 giorni'), findsOneWidget);

      await tester.tap(find.byTooltip('Modifica'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-type')), findsNothing);
      expect(find.text('Tipo di account: POP3'), findsOneWidget);
      // La finestra scorre e costruisce le righe solo quando si vedono.
      await tester.scrollUntilVisible(find.byKey(const Key('pop3-remove-days')), 200,
          scrollable: find.descendant(of: find.byKey(const Key('account-setup-dialog')), matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pop3-remove-days')), '60');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accounts-ok')));
      await tester.pumpAndSettle();

      expect(cores.tests, isEmpty);
      expect(store.accounts.single.removeAfterDays, 60);
      expect(cores.starts.last['Accounts__0__Pop3__RemoveAfterDays'], '60');
    });

    testWidgets('dati di un account POP3 rimosso: per eliminarli si scrive l\'indirizzo', (tester) async {
      final cores = FakeCores()
        ..orphans.add({'id': 'old1', 'name': null, 'address': 'pop@example.com', 'sizeBytes': 2048, 'localOnly': true});
      await pumpGate(tester, cores, MemoryAccountStore([account]));
      await openAccountsPage(tester);
      expect(find.textContaining('l\'unica copia è questa'), findsOneWidget);

      await tester.tap(find.text('Elimina dati locali'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminare per sempre le mail?'), findsOneWidget);
      FilledButton button() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Elimina per sempre'));
      expect(button().onPressed, isNull);
      await tester.enterText(find.byKey(const Key('confirm-address')), 'pop@example');
      await tester.pump();
      expect(button().onPressed, isNull);
      await tester.enterText(find.byKey(const Key('confirm-address')), 'POP@example.com');
      await tester.pump();
      await tester.tap(find.text('Elimina per sempre'));
      await tester.pumpAndSettle();

      expect(cores.cacheRequests, ['DELETE /cache/orphans/old1']);
    });
  });

  group('OAuth2 (O2)', () {
    const ms = AccountConfig(
        id: 'o1', email: 'io@outlook.it', password: '', imapHost: 'outlook.office365.com', smtpHost: 'smtp.office365.com',
        oauthProvider: 'microsoft', refreshToken: 'RT1');

    test('variabili: token al posto della password; il token che cambia non chiede una verifica', () {
      final env = ms.toCoreEnvironment(0);
      expect(env['Accounts__0__OAuth__Provider'], 'microsoft');
      expect(env['Accounts__0__OAuth__RefreshToken'], 'RT1');
      expect(env.keys.where((k) => k.endsWith('__Password')), isEmpty);
      expect(ms.copyWith(refreshToken: 'RT2').sameConnection(ms), isTrue);
      final back = AccountConfig.fromJson(jsonDecode(jsonEncode(ms.toJson())) as Map<String, dynamic>);
      expect((back.usesOAuth, back.refreshToken), (true, 'RT1'));
      expect(account.usesOAuth, isFalse);
      expect(account.toCoreEnvironment(0).containsKey('Accounts__0__OAuth__Provider'), isFalse);
    });

    Future<List<Uri>> signIn(WidgetTester tester, FakeCores cores, MemoryAccountStore store) async {
      final opened = <Uri>[];
      tester.view.physicalSize = const Size(1400, 1700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(CoreGate(start: cores.start, apiFactory: cores.api, accountStore: store));
      await tester.pumpAndSettle();
      // Il CoreGate costruisce la pagina senza openUrl: la si sostituisce ricostruendo la stessa pagina nei test.
      final api = cores.api(const CoreConnection(baseUrl: 'http://127.0.0.1:40001', token: 't'));
      await tester.pumpWidget(MaterialApp(
        home: AccountSetupPage(api: api, onSave: (a) async => store.accounts = [a], openUrl: (u) async {
          opened.add(u);
          return true;
        }),
      ));
      await tester.pumpAndSettle();
      return opened;
    }

    /// Scelta 1a: il servizio si sceglie in "Tipo di account".
    Future<void> chooseService(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(const Key('account-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('"Accedi con Microsoft": browser, attesa, indirizzo e server compilati, verifica con il token', (tester) async {
      final cores = FakeCores()..oauthConfigured = true;
      final store = MemoryAccountStore();
      final opened = await signIn(tester, cores, store);
      expect(find.byKey(const Key('oauth-microsoft')), findsNothing); // con IMAP: password e server, nessun pulsante
      await chooseService(tester, 'Outlook.com / Microsoft 365');
      expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);
      expect(find.text('SMTP (posta in uscita)'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Indirizzo email (anche nome utente)'), findsNothing); // arriva dall'accesso

      await tester.tap(find.byKey(const Key('oauth-microsoft')));
      await tester.pump();
      expect(opened.single.toString(), 'https://login.example/authorize?x=1');
      expect(find.byKey(const Key('oauth-waiting')), findsOneWidget);

      await tester.pump(AccountSetupPage.oauthPollInterval);
      await tester.pump();
      expect(find.byKey(const Key('oauth-waiting')), findsOneWidget); // ancora in attesa
      await tester.pump(AccountSetupPage.oauthPollInterval);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('oauth-linked')), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);
      expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Indirizzo email (anche nome utente)')).controller!.text,
          'io@outlook.it');
      final sent = cores.tests.single;
      expect((sent['oauthProvider'], sent['refreshToken'], sent['password']), ('microsoft', 'RT1', ''));
      expect((sent['imapHost'], sent['imapPort'], sent['smtpHost'], sent['smtpPort']),
          ('outlook.office365.com', 993, 'smtp.office365.com', 587));

      await tester.tap(find.text('Salva'));
      await tester.pump(); // qui la pagina resta in attesa (nell'app la sostituisce il riavvio del core)
      final saved = store.accounts.single;
      expect((saved.usesOAuth, saved.refreshToken, saved.password), (true, 'RT1', ''));
    });

    testWidgets('«Accedi di nuovo» dalla striscia: l\'accesso parte da solo con il fornitore dell\'account', (tester) async {
      final cores = FakeCores()..oauthConfigured = true;
      await signIn(tester, cores, MemoryAccountStore());
      final api = cores.api(const CoreConnection(baseUrl: 'http://127.0.0.1:40001', token: 't'));
      final opened = <Uri>[];
      await tester.pumpWidget(MaterialApp(
        home: AccountSetupPage(key: const Key('again'), api: api, initial: ms, signInAgain: true, onSave: (_) async {}, openUrl: (u) async {
          opened.add(u);
          return true;
        }),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(opened, hasLength(1)); // nessun clic: è partito da solo
      expect(find.text('Tipo di account: Outlook.com / Microsoft 365'), findsOneWidget);
      expect(find.byKey(const Key('oauth-waiting')), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
    });

    final gm = AccountConfig(
        id: 'g1', email: 'io@gmail.com', password: '', imapHost: 'imap.gmail.com', smtpHost: 'smtp.gmail.com',
        oauthProvider: 'google', refreshToken: 'RT1');

    Future<(FakeCores, List<Uri>, List<AccountConfig>)> gmailPage(WidgetTester tester, AccountConfig initial,
        {bool grant = true, bool grantCalendar = true}) async {
      final cores = FakeCores()
        ..oauthConfigured = true
        ..googleConfigured = true
        ..grantContacts = grant
        ..grantCalendar = grantCalendar;
      await signIn(tester, cores, MemoryAccountStore());
      final api = cores.api(const CoreConnection(baseUrl: 'http://127.0.0.1:40001', token: 't'));
      final opened = <Uri>[];
      final saved = <AccountConfig>[];
      await tester.pumpWidget(MaterialApp(
        home: AccountSetupPage(key: Key('gm-${initial.id}'), api: api, initial: initial, onSave: (a) async => saved.add(a), openUrl: (u) async {
          opened.add(u);
          return true;
        }),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('carddav-enabled')));
      await tester.pumpAndSettle();
      return (cores, opened, saved);
    }

    bool checked(WidgetTester tester) => tester.widget<CheckboxListTile>(find.byKey(const Key('carddav-enabled'))).value ?? false;

    testWidgets('Gmail (C4d, 1a): la casella dei contatti apre l\'accesso con il permesso dei contatti', (tester) async {
      final (cores, opened, saved) = await gmailPage(tester, gm);
      expect(find.text('Sincronizza i contatti con Google (CardDAV)'), findsOneWidget);
      expect(find.byKey(const Key('carddav-url')), findsNothing); // indirizzo di Google: niente da scrivere
      await tester.tap(find.byKey(const Key('carddav-enabled')));
      await tester.pump();
      expect(opened, hasLength(1));
      expect(cores.oauthRequests.single, contains('"contacts":true'));
      expect(checked(tester), isFalse); // finché l'accesso non riesce
      expect(find.byKey(const Key('carddav-oauth-waiting')), findsOneWidget);
      await tester.pump(AccountSetupPage.oauthPollInterval);
      await tester.pump(AccountSetupPage.oauthPollInterval);
      await tester.pumpAndSettle();
      expect(checked(tester), isTrue);

      await tester.ensureVisible(find.byKey(const Key('carddav-test')));
      await tester.tap(find.byKey(const Key('carddav-test')));
      await tester.pumpAndSettle();
      expect(find.text('Trovata: «Address Book»'), findsOneWidget);
      final sent = cores.cardDavTests.single;
      expect((sent['oauthProvider'], sent['refreshToken'], sent['password']), ('google', 'RT2', ''));

      await tester.ensureVisible(find.text('Salva'));
      await tester.tap(find.text('Salva'));
      await tester.pump();
      final account = saved.single;
      expect((account.cardDavEnabled, account.refreshToken), (true, 'RT2')); // token nuovo, con i contatti
      expect(account.toCoreEnvironment(0)['Accounts__0__CardDav__Enabled'], 'true');
    });

    testWidgets('Gmail: permesso dei contatti non concesso -> casella spenta e spiegazione', (tester) async {
      await gmailPage(tester, gm, grant: false);
      await tester.tap(find.byKey(const Key('carddav-enabled')));
      await tester.pump();
      await tester.pump(AccountSetupPage.oauthPollInterval);
      await tester.pump(AccountSetupPage.oauthPollInterval);
      await tester.pumpAndSettle();
      expect(checked(tester), isFalse);
      expect(find.textContaining('senza il permesso dei contatti'), findsOneWidget);
    });

    testWidgets('Gmail con i contatti già accesi: «Accedi di nuovo» chiede ancora i contatti; Microsoft no', (tester) async {
      final (cores, _, _) = await gmailPage(tester, gm.copyWith(cardDavEnabled: true));
      expect(checked(tester), isTrue);
      await tester.ensureVisible(find.text('Accedi di nuovo'));
      await tester.tap(find.text('Accedi di nuovo'));
      await tester.pump();
      expect(cores.oauthRequests.single, contains('"contacts":true'));
      await tester.tap(find.text('Annulla').first);
      await tester.pumpAndSettle();

      await gmailPage(tester, ms);
      expect(checked(tester), isFalse);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('carddav-enabled'))).onChanged, isNull);
      expect(find.text('Per gli account Microsoft non è ancora disponibile.'), findsNWidgets(2)); // contatti e calendario
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('caldav-enabled'))).onChanged, isNull);
    });

    bool calChecked(WidgetTester tester) => tester.widget<CheckboxListTile>(find.byKey(const Key('caldav-enabled'))).value ?? false;

    Future<void> finishLogin(WidgetTester tester) async {
      await tester.pump(AccountSetupPage.oauthPollInterval);
      await tester.pump(AccountSetupPage.oauthPollInterval);
      await tester.pumpAndSettle();
    }

    testWidgets('Gmail (G3, 1a): la casella del calendario apre l\'accesso con il permesso del calendario', (tester) async {
      final (cores, opened, saved) = await gmailPage(tester, gm);
      await tester.ensureVisible(find.byKey(const Key('caldav-enabled')));
      await tester.pumpAndSettle();
      expect(find.text('Sincronizza il calendario con Google (CalDAV)'), findsOneWidget);
      expect(find.byKey(const Key('caldav-url')), findsNothing);
      await tester.tap(find.byKey(const Key('caldav-enabled')));
      await tester.pump();
      expect(opened, hasLength(1));
      expect(cores.oauthRequests.single, contains('"calendar":true'));
      expect(cores.oauthRequests.single, isNot(contains('"contacts"'))); // contatti spenti: non chiesti
      expect(calChecked(tester), isFalse);
      expect(find.byKey(const Key('caldav-oauth-waiting')), findsOneWidget);
      await finishLogin(tester);
      expect(calChecked(tester), isTrue);
      expect(find.byKey(const Key('caldav-url')), findsNothing); // indirizzo di Google: niente da scrivere

      await tester.ensureVisible(find.byKey(const Key('caldav-test')));
      await tester.tap(find.byKey(const Key('caldav-test')));
      await tester.pumpAndSettle();
      expect(find.text('Trovati: «io@gmail.com», «Festività in Italia»'), findsOneWidget);
      final sent = cores.calDavTests.single;
      expect(sent['oauthProvider'], 'google');
      expect(sent['refreshToken'], 'RT2');
      expect(sent['password'], '');

      await tester.ensureVisible(find.text('Salva'));
      await tester.tap(find.text('Salva'));
      await tester.pump();
      final account = saved.single;
      expect((account.calDavEnabled, account.cardDavEnabled, account.refreshToken), (true, false, 'RT2'));
      expect(account.toCoreEnvironment(0)['Accounts__0__CalDav__Enabled'], 'true');
    });

    testWidgets('Gmail con i contatti accesi: un solo accesso con contatti e calendario; senza permesso casella spenta',
        (tester) async {
      final (cores, _, _) = await gmailPage(tester, gm.copyWith(cardDavEnabled: true), grantCalendar: false);
      await tester.ensureVisible(find.byKey(const Key('caldav-enabled')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('caldav-enabled')));
      await tester.pump();
      expect(cores.oauthRequests.single, allOf(contains('"contacts":true'), contains('"calendar":true')));
      await finishLogin(tester);
      expect(calChecked(tester), isFalse);
      expect(checked(tester), isTrue); // i contatti concessi restano accesi
      expect(find.textContaining('senza il permesso del calendario'), findsOneWidget);
    });

    testWidgets('Gmail con il calendario acceso: «Accedi di nuovo» chiede ancora il calendario', (tester) async {
      final (cores, _, _) = await gmailPage(tester, gm.copyWith(calDavEnabled: true));
      expect(calChecked(tester), isTrue);
      await tester.ensureVisible(find.text('Accedi di nuovo'));
      await tester.tap(find.text('Accedi di nuovo'));
      await tester.pump();
      expect(cores.oauthRequests.single, contains('"calendar":true'));
      await tester.tap(find.text('Annulla').first);
      await tester.pumpAndSettle();
    });

    testWidgets('senza client ID nessun pulsante; Annulla interrompe l\'attesa', (tester) async {
      final cores = FakeCores();
      await signIn(tester, cores, MemoryAccountStore());
      await tester.tap(find.byKey(const Key('account-type')));
      await tester.pumpAndSettle();
      expect(find.text('Outlook.com / Microsoft 365'), findsNothing); // senza client ID la voce non c'è
      await tester.tap(find.text('IMAP').last);
      await tester.pumpAndSettle();

      final cores2 = FakeCores()..oauthConfigured = true;
      await signIn(tester, cores2, MemoryAccountStore());
      await chooseService(tester, 'Outlook.com / Microsoft 365');
      await tester.tap(find.byKey(const Key('oauth-microsoft')));
      await tester.pump();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(cores2.oauthRequests.last, 'cancel');
      expect(find.byKey(const Key('oauth-microsoft')), findsOneWidget);

      // Tornando a IMAP ricompaiono password e server.
      await chooseService(tester, 'IMAP');
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    });

    testWidgets('token rinnovato dal core: salvato nel portachiavi senza riavviare il core', (tester) async {
      final cores = FakeCores();
      final store = MemoryAccountStore([ms]);
      await pumpGate(tester, cores, store);
      expect(cores.starts.single['Accounts__0__OAuth__RefreshToken'], 'RT1');

      final app = tester.widget<PostinoVipApp>(find.byType(PostinoVipApp));
      await app.accountsEditing!.updateRefreshToken!('o1', 'RT2');
      await tester.pumpAndSettle();

      expect(store.accounts.single.refreshToken, 'RT2');
      expect(cores.starts, hasLength(1));
      final again = tester.widget<PostinoVipApp>(find.byType(PostinoVipApp));
      expect(again.accountsEditing!.accounts.single.refreshToken, 'RT2'); // la pagina Account vede quello nuovo
    });
  });
}
