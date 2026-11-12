import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/state/mailbox_model.dart';
import 'package:postinovip/ui/message_list_pane.dart';

/// Core finto con un account e INBOX da [count] mail (UID count..1), più la ricerca sulle stesse.
class PagedCore {
  PagedCore(this.count);

  final int count;
  final sse = StreamController<List<int>>();
  final pages = <String>[]; // "offset" delle pagine chieste, lista e ricerca
  bool failNextPage = false;

  Map<String, dynamic> _header(int uid) => {'uid': uid, 'subject': 'Mail $uid', 'from': 'Anna', 'date': null, 'seen': true};

  late final client = MockClient.streaming((request, _) async {
    final url = request.url;
    http.StreamedResponse json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    if (url.path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (url.path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'Personale', 'address': 'io@example.com', 'configured': true},
      ]);
    }
    if (url.path == '/accounts/a1/folders') {
      return json([
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': count, 'specialUse': 'inbox'},
      ]);
    }
    final isList = url.path == '/accounts/a1/folders/INBOX/messages';
    final isSearch = url.path == '/accounts/a1/search';
    if (isList || isSearch) {
      final offset = int.parse(url.queryParameters['offset']!), limit = int.parse(url.queryParameters['limit']!);
      // La prima pagina INBOX la chiede anche il controllo della posta nuova (limit 10): non conta.
      if (limit != 10) pages.add('${isSearch ? 'ricerca' : 'lista'} $offset');
      if (offset > 0 && failNextPage) {
        failNextPage = false;
        return json({'title': 'Errore interno', 'detail': 'pagina non disponibile'}, 500);
      }
      final uids = [for (var u = count - offset; u > count - offset - limit && u > 0; u--) u];
      final items = [
        for (final u in uids)
          if (isList) _header(u) else {..._header(u), 'folder': 'INBOX', 'snippet': null, 'bodySearched': true},
      ];
      return json({'total': count, 'offset': offset, 'limit': limit, 'items': items});
    }
    return json({}, 404);
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<PagedCore> start(WidgetTester tester, int count) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = PagedCore(count);
  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: core.client), windowPresenter: _NoWindow()));
  await tester.pumpAndSettle();
  return core;
}

/// Scorre la lista [list] fino a [text] (le pagine si caricano da sole durante lo scorrimento).
Future<void> scrollTo(WidgetTester tester, String text, {Key list = MessageListPane.messageListKey}) async {
  final scrollable = find.descendant(of: find.byKey(list), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(find.text(text), 400, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('scorrendo si caricano da sole le pagine successive, senza pulsanti', (tester) async {
    final core = await start(tester, 130);
    expect(core.pages, ['lista 0']);
    expect(find.textContaining('Carica altri'), findsNothing);

    await scrollTo(tester, 'Mail 1'); // la più vecchia, nella terza pagina

    expect(core.pages, ['lista 0', 'lista 50', 'lista 100']);
    expect(find.byType(CircularProgressIndicator), findsNothing); // finite: niente indicatore in fondo
    await core.sse.close();
  });

  testWidgets('pagina non caricata: "Riprova" e nessun nuovo tentativo da solo', (tester) async {
    final core = await start(tester, 130);
    core.failNextPage = true;

    await scrollTo(tester, 'Riprova');
    await tester.pump(const Duration(seconds: 2));
    expect(core.pages, ['lista 0', 'lista 50']);

    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();
    expect(core.pages, ['lista 0', 'lista 50', 'lista 50']);
    expect(find.text('Riprova'), findsNothing);
    await core.sse.close();
  });

  testWidgets('anche i risultati della ricerca si caricano scorrendo', (tester) async {
    final core = await start(tester, 120);
    await tester.enterText(find.widgetWithText(TextField, 'Cerca'), 'mail');
    await tester.pump(MailboxModel.searchDelay);
    await tester.pumpAndSettle();
    expect(core.pages.where((p) => p.startsWith('ricerca')), ['ricerca 0']);

    // In fondo, dopo tutti i risultati locali.
    await scrollTo(tester, 'Cerca anche sul server', list: MessageListPane.searchResultsKey);

    expect(core.pages.where((p) => p.startsWith('ricerca')), ['ricerca 0', 'ricerca 50', 'ricerca 100']);
    expect(find.text('Mail 1'), findsOneWidget);
    await core.sse.close();
  });
}
