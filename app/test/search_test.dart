import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/models/search_result.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/state/mailbox_model.dart';
import 'package:postinovip/ui/message_list_pane.dart';

Map<String, dynamic> hit(String folder, int uid, String subject, String date, {bool seen = true, String? snippet}) => {
  'folder': folder,
  'uid': uid,
  'subject': subject,
  'from': 'Anna',
  'date': date,
  'seen': seen,
  'snippet': snippet,
  'bodySearched': true,
};

/// Core finto con due account ("a1" Personale, "b2" Lavoro): INBOX e Archivio, più la ricerca.
class SearchCore {
  SearchCore({this.pop3 = const {}});

  /// Account POP3 (4.2c): tutte le mail nell'indice locale, niente ricerca sul server.
  final Set<String> pop3;

  final sse = StreamController<List<int>>();
  final requests = <Uri>[];

  /// Risultati per account, restituiti a pagine come farebbe il core.
  final results = {
    'a1': [
      hit('INBOX', 3, 'Fattura ottobre', '2026-10-20T10:00:00+02:00', snippet: 'la \u0002fattura\u0003 di ottobre'),
      hit(
        'Archivio',
        7,
        'Fattura vecchia',
        '2026-03-01T10:00:00+01:00',
        seen: false,
        snippet: '\u0002fattura\u0003 n. 12',
      ),
    ],
    'b2': [hit('INBOX', 20, 'Fattura lavoro', '2026-10-25T10:00:00+02:00', snippet: 'una \u0002fattura\u0003')],
  };

  List<Uri> get searches => [
    for (final u in requests)
      if (u.path.endsWith('/search')) u,
  ];
  List<Uri> get serverSearches => [
    for (final u in requests)
      if (u.path.endsWith('/search/server')) u,
  ];

  /// Risultati del server: uno già trovato in locale (INBOX/3) e uno nuovo, vecchio (INBOX/2).
  final serverResults = {
    'a1': [
      {...hit('INBOX', 3, 'Fattura ottobre', '2026-10-20T10:00:00+02:00'), 'fromServer': true},
      {...hit('INBOX', 2, 'Fattura del 2019', '2019-05-01T10:00:00+02:00'), 'fromServer': true},
    ],
    'b2': <Map<String, dynamic>>[],
  };

  late final client = MockClient.streaming((request, bodyStream) async {
    final url = request.url;
    requests.add(url);
    http.StreamedResponse json(Object body) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    if (url.path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (url.path == '/accounts') {
      return json([
        {
          'id': 'a1',
          'name': 'Personale',
          'address': 'io@example.com',
          'configured': true,
          'type': pop3.contains('a1') ? 'Pop3' : 'Imap',
        },
        {
          'id': 'b2',
          'name': 'Lavoro',
          'address': 'io@lavoro.example',
          'configured': true,
          'type': pop3.contains('b2') ? 'Pop3' : 'Imap',
        },
      ]);
    }
    final m = RegExp(r'^/accounts/(\w+)(/.*)$').firstMatch(url.path);
    if (m == null) return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
    final (account, rest) = (m[1]!, m[2]!);

    if (rest == '/folders') {
      return json([
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 1, 'specialUse': 'inbox'},
        {'fullName': 'Archivio', 'name': 'Archivio', 'count': 1},
        {'fullName': 'Posta eliminata', 'name': 'Posta eliminata', 'count': 0, 'specialUse': 'trash'},
      ]);
    }
    if (rest.endsWith('/messages') && rest.startsWith('/folders/')) {
      return json({
        'total': 1,
        'offset': 0,
        'limit': 50,
        'items': [
          {'uid': 1, 'subject': 'Mail in cartella ($account)', 'from': 'Bruno', 'date': null, 'seen': true},
        ],
      });
    }
    if (rest == '/receive' && request.method == 'POST') return http.StreamedResponse(const Stream.empty(), 202);
    if (rest == '/search/server') {
      final items = serverResults[account]!;
      return json({'total': items.length, 'offset': 0, 'limit': 200, 'items': items});
    }
    if (rest == '/search') {
      final q = url.queryParameters;
      final folder = q['folder'];
      final all = [
        for (final h in results[account]!)
          if (folder == null || h['folder'] == folder) h,
      ];
      final offset = int.parse(q['offset']!), limit = int.parse(q['limit']!);
      return json({
        'total': all.length,
        'offset': offset,
        'limit': limit,
        'items': all.skip(offset).take(limit).toList(),
      });
    }
    if (RegExp(r'^/messages/[^/]+/\d+/seen$').hasMatch(rest)) return json({'seen': true});
    if (request.method == 'DELETE') return json({'movedTo': 'Posta eliminata'});
    if (RegExp(r'^/messages/[^/]+/\d+$').hasMatch(rest)) {
      final uid = int.parse(rest.split('/').last);
      return json({
        'uid': uid,
        'subject': 'Aperta $uid',
        'from': 'Anna',
        'to': <String>[],
        'cc': <String>[],
        'date': null,
        'textBody': 'Testo della mail $uid',
        'htmlBody': null,
        'hasRemoteImages': false,
        'attachments': [],
      });
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<SearchCore> start(WidgetTester tester, {Set<String> pop3 = const {}}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = SearchCore(pop3: pop3);
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

Finder get searchBox => find.widgetWithText(TextField, 'Cerca');

/// Scrive nella casella e aspetta che la ricerca parta (dopo l'attesa) e finisca.
Future<void> typeSearch(WidgetTester tester, String text) async {
  await tester.enterText(searchBox, text);
  await tester.pump(MailboxModel.searchDelay);
  await tester.pumpAndSettle();
}

Future<void> chooseScope(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<SearchScope>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cerca nella cartella aperta dopo una breve attesa; estratto con le parole in grassetto', (tester) async {
    final core = await start(tester);

    await tester.enterText(searchBox, 'fattura');
    await tester.pump(const Duration(milliseconds: 100));
    expect(core.searches, isEmpty); // si sta ancora scrivendo
    await tester.pump(MailboxModel.searchDelay);
    await tester.pumpAndSettle();

    final q = core.searches.single;
    expect(q.path, '/accounts/a1/search');
    expect(q.queryParameters, {'q': 'fattura', 'folder': 'INBOX', 'offset': '0', 'limit': '50'});
    expect(find.text('1 risultato in INBOX'), findsOneWidget);
    expect(find.text('Fattura ottobre'), findsOneWidget);
    expect(find.text('Mail in cartella (a1)'), findsNothing); // la lista della cartella è nascosta

    final snippet = tester.widget<RichText>(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == 'la fattura di ottobre'),
    );
    final spans = (snippet.text as TextSpan).children!.single as TextSpan; // Text.rich avvolge lo span
    final parts = spans.children!.cast<TextSpan>();
    expect(parts.map((s) => s.text), ['la ', 'fattura', ' di ottobre']);
    expect(parts[1].style?.fontWeight, FontWeight.bold);
    await core.sse.close();
  });

  testWidgets('Invio cerca subito; X chiude la ricerca e torna alla cartella', (tester) async {
    final core = await start(tester);
    await tester.enterText(searchBox, 'fattura');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(core.searches, hasLength(1));
    expect(find.text('Fattura ottobre'), findsOneWidget);

    await tester.tap(find.byTooltip('Chiudi la ricerca'));
    await tester.pumpAndSettle();
    expect(find.text('Mail in cartella (a1)'), findsOneWidget);
    expect(tester.widget<TextField>(searchBox).controller!.text, isEmpty);
    await tester.pump(MailboxModel.searchDelay);
    expect(core.searches, hasLength(1)); // nessuna ricerca in ritardo
    await core.sse.close();
  });

  testWidgets('tutte le cartelle: senza "folder", con la cartella di ogni risultato', (tester) async {
    final core = await start(tester);
    await chooseScope(tester, 'Tutte le cartelle');
    await typeSearch(tester, 'fattura');

    expect(core.searches.single.queryParameters.containsKey('folder'), isFalse);
    expect(find.text('2 risultati in tutte le cartelle di Personale'), findsOneWidget);
    expect(find.text('Posta in arrivo'), findsWidgets);
    expect(find.text('Archivio'), findsWidgets);
    await core.sse.close();
  });

  testWidgets('tutti gli account: una richiesta per account, risultati mescolati per data', (tester) async {
    final core = await start(tester);
    await chooseScope(tester, 'Tutti gli account');
    await typeSearch(tester, 'fattura');

    expect(core.searches.map((u) => u.path).toSet(), {'/accounts/a1/search', '/accounts/b2/search'});
    expect(find.text('3 risultati in tutti gli account'), findsOneWidget);
    final order = [
      for (final s in ['Fattura lavoro', 'Fattura ottobre', 'Fattura vecchia']) tester.getTopLeft(find.text(s)).dy,
    ];
    expect(order, [...order]..sort()); // dal più recente
    expect(find.text('Lavoro · INBOX'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('risultato di un\'altra cartella: aperto, segnato letto ed eliminato dalla sua casella', (tester) async {
    final core = await start(tester);
    await chooseScope(tester, 'Tutte le cartelle');
    await typeSearch(tester, 'fattura');

    await tester.tap(find.text('Fattura vecchia'));
    await tester.pumpAndSettle();
    expect(find.text('Testo della mail 7'), findsOneWidget);
    expect(core.requests.map((u) => u.path), contains('/accounts/a1/messages/Archivio/7'));
    expect(core.requests.map((u) => u.path), contains('/accounts/a1/messages/Archivio/7/seen'));

    await tester.tap(find.text('Elimina').first);
    await tester.pumpAndSettle();
    expect(core.requests.map((u) => u.path), contains('/accounts/a1/messages/Archivio/7'));
    expect(find.text('Fattura vecchia'), findsNothing); // tolto dai risultati
    expect(find.text('1 risultato in tutte le cartelle di Personale'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('cambiare cartella chiude la ricerca', (tester) async {
    final core = await start(tester);
    await typeSearch(tester, 'fattura');
    expect(find.text('Fattura ottobre'), findsOneWidget);

    await tester.tap(find.text('Archivio').first);
    await tester.pumpAndSettle();

    expect(find.text('Fattura ottobre'), findsNothing);
    expect(find.text('Mail in cartella (a1)'), findsOneWidget);
    expect(tester.widget<TextField>(searchBox).controller!.text, isEmpty);
    await core.sse.close();
  });

  testWidgets('"Cerca anche sul server": stessa ricerca e ambito, aggiunge solo le mail nuove', (tester) async {
    final core = await start(tester);
    await typeSearch(tester, 'fattura');
    expect(core.serverSearches, isEmpty); // solo su richiesta

    await tester.tap(find.text('Cerca anche sul server'));
    await tester.pumpAndSettle();

    expect(core.serverSearches.single.path, '/accounts/a1/search/server');
    expect(core.serverSearches.single.queryParameters['folder'], 'INBOX');
    expect(core.serverSearches.single.queryParameters['q'], 'fattura');
    expect(find.text('Fattura ottobre'), findsOneWidget); // non ripetuta
    expect(find.text('Fattura del 2019'), findsOneWidget);
    expect(find.byTooltip('Trovata sul server'), findsOneWidget);
    expect(find.textContaining('Il server ha trovato 1 mail in più'), findsOneWidget);
    expect(find.text('Cerca anche sul server'), findsNothing); // una volta per ricerca
    // In fondo, dopo la più recente: ordine per data.
    expect(
      tester.getTopLeft(find.text('Fattura del 2019')).dy,
      greaterThan(tester.getTopLeft(find.text('Fattura ottobre')).dy),
    );

    await tester.tap(find.text('Fattura del 2019'));
    await tester.pumpAndSettle();
    expect(find.text('Testo della mail 2'), findsOneWidget);

    await typeSearch(tester, 'fattura 2'); // nuova ricerca: il pulsante torna
    expect(find.text('Cerca anche sul server'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('nessun risultato locale: si può cercare sul server', (tester) async {
    final core = await start(tester);
    core.results['a1'] = [];
    await typeSearch(tester, 'fattura');
    expect(find.text('Nessun risultato nella cache locale'), findsOneWidget);

    await tester.tap(find.text('Cerca anche sul server'));
    await tester.pumpAndSettle();

    expect(find.text('Fattura del 2019'), findsOneWidget);
    expect(find.textContaining('Il server ha trovato 2 mail in più'), findsOneWidget);
    await core.sse.close();
  });

  test('estratto: parole tra U+0002 e U+0003 in grassetto, spazi ridotti', () {
    final span = highlightedSnippet('${SearchHit.highlightStart}Ciao${SearchHit.highlightEnd}\n\n  a tutti', null);
    expect(span.children!.map((s) => (s as TextSpan).text), ['Ciao', ' a tutti']);
    expect((span.children!.first as TextSpan).style?.fontWeight, FontWeight.bold);
  });

  testWidgets('POP3 (4.2c): niente "Cerca anche sul server"; F9 chiede al core di controllare il server', (
    tester,
  ) async {
    final core = await start(tester, pop3: {'a1'});
    await typeSearch(tester, 'fattura');

    expect(find.text('Fattura ottobre'), findsOneWidget);
    expect(find.text('Cerca anche sul server'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    final receives = [
      for (final u in core.requests)
        if (u.path.endsWith('/receive')) u.path,
    ];
    expect(receives, ['/accounts/a1/receive']); // solo l'account POP3
    await core.sse.close();
  });

  testWidgets('POP3 e IMAP in "Tutti gli account": sul server si cerca solo nell\'account IMAP', (tester) async {
    final core = await start(tester, pop3: {'a1'});
    await typeSearch(tester, 'fattura');
    await chooseScope(tester, 'Tutti gli account');

    await tester.tap(find.text('Cerca anche sul server'));
    await tester.pumpAndSettle();

    expect(core.serverSearches.map((u) => u.path), ['/accounts/b2/search/server']);
    await core.sse.close();
  });
}
