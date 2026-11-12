import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/models/favorite_folder.dart';
import 'package:postinovip/models/mail_folder.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/folder_pane.dart';

/// Core finto con un account ("a1") e le cartelle tipiche, con ruoli SPECIAL-USE.
class FolderCore {
  final sse = StreamController<List<int>>();

  late final client = MockClient.streaming((request, _) async {
    final path = Uri.decodeComponent(request.url.path);
    http.StreamedResponse json(Object body) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'io@example.com', 'address': 'io@example.com', 'configured': true, 'online': true},
      ]);
    }
    if (path == '/accounts/a1/folders') {
      return json([
        {'fullName': 'Archivio', 'name': 'Archivio', 'count': 5, 'unread': 0},
        {'fullName': 'Bozze', 'name': 'Bozze', 'count': 3, 'unread': 3, 'specialUse': 'drafts'},
        {'fullName': 'INBOX', 'name': 'INBOX', 'count': 10, 'unread': 2, 'specialUse': 'inbox'},
        {'fullName': 'Posta eliminata', 'name': 'Posta eliminata', 'count': 7, 'unread': 1, 'specialUse': 'trash'},
        {'fullName': 'Posta indesiderata', 'name': 'Posta indesiderata', 'count': 4, 'unread': 4, 'specialUse': 'junk'},
        {'fullName': 'Posta inviata', 'name': 'Posta inviata', 'count': 9, 'unread': 0, 'specialUse': 'sent'},
      ]);
    }
    if (path.startsWith('/accounts/a1/folders/') && path.endsWith('/messages')) {
      return json({'total': 0, 'offset': 0, 'limit': 50, 'items': []});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<FolderCore> start(WidgetTester tester, AppSettings settings) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = FolderCore();
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      settings: settings,
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

/// Nomi dei Preferiti mostrati, dall'alto in basso.
List<String> favoriteNames(WidgetTester tester) {
  final rows = find.byWidgetPredicate(
    (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('favorite:'),
  );
  return [for (final e in rows.evaluate()) ((e.widget.key! as ValueKey<String>).value.split(':').last)];
}

/// Testi della riga di una cartella nell'albero: [nome] o [nome, numero].
List<String?> rowTexts(WidgetTester tester, String folder) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: find.byKey(ValueKey('folder:a1:$folder')), matching: find.byType(Text)),
  ))
    t.data,
];

Future<void> rightClick(WidgetTester tester, Finder finder) async {
  await tester.tap(finder, buttons: kSecondaryButton);
  await tester.pumpAndSettle();
}

void main() {
  test('numero accanto alla cartella: da leggere, ma il totale tra [] per Bozze e Indesiderata', () {
    MailFolder f(String name, {int? count, int? unread, String? role}) =>
        MailFolder(fullName: name, name: name, count: count, unread: unread, specialUse: role);

    expect(folderBadge(f('INBOX', count: 10, unread: 2, role: 'inbox')), (text: '2', unread: true));
    expect(folderBadge(f('Archivio', count: 5, unread: 0)), isNull);
    expect(folderBadge(f('Archivio', count: 5)), isNull); // non letti non noti
    expect(folderBadge(f('Bozze', count: 3, unread: 3, role: 'drafts')), (text: '[3]', unread: false));
    expect(folderBadge(f('Spam', count: 4, unread: 1, role: 'junk')), (text: '[4]', unread: false));
    // J2: il ruolo della posta indesiderata lo dà il core, non il nome.
    expect(folderBadge(f('Spam', count: 4, unread: 1)), (text: '1', unread: true));
    expect(folderBadge(f('Bozze', count: 0, role: 'drafts')), isNull);
  });

  testWidgets('Preferiti predefiniti e conteggi nel riquadro', (tester) async {
    final settings = AppSettings(MemorySettingsStore());
    final core = await start(tester, settings);

    expect(find.text('Preferiti'), findsOneWidget);
    expect(favoriteNames(tester), ['INBOX', 'Posta inviata', 'Posta eliminata']);
    expect(settings.favorites, isNull); // finché l'utente non li cambia restano quelli predefiniti

    expect(rowTexts(tester, 'INBOX'), ['Posta in arrivo', '2']);
    expect(tester.widget<Text>(find.text('Posta in arrivo').last).style?.fontWeight, FontWeight.bold);
    expect(rowTexts(tester, 'Archivio'), ['Archivio']);
    expect(tester.widget<Text>(find.text('Archivio')).style?.fontWeight, isNot(FontWeight.bold));
    expect(rowTexts(tester, 'Bozze'), ['Bozze', '[3]']);
    expect(rowTexts(tester, 'Posta indesiderata'), ['Posta indesiderata', '[4]']);
    expect(rowTexts(tester, 'Posta eliminata'), ['Posta eliminata', '1']);
    await core.sse.close();
  });

  testWidgets('tasto destro: aggiungi, sposta e rimuovi dai Preferiti; scelte salvate', (tester) async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    final core = await start(tester, settings);

    await rightClick(tester, find.byKey(const ValueKey('folder:a1:Archivio')));
    await tester.tap(find.text('Mostra nei Preferiti'));
    await tester.pumpAndSettle();
    expect(favoriteNames(tester), ['INBOX', 'Posta inviata', 'Posta eliminata', 'Archivio']);
    expect(settings.favorites, [
      const FavoriteFolder('a1', 'INBOX'),
      const FavoriteFolder('a1', 'Posta inviata'),
      const FavoriteFolder('a1', 'Posta eliminata'),
      const FavoriteFolder('a1', 'Archivio'),
    ]);

    // Sulla riga nei Preferiti: "Sposta su" (il primo non sale).
    await rightClick(tester, find.byKey(const ValueKey('favorite:a1:Archivio')));
    await tester.tap(find.text('Sposta su'));
    await tester.pumpAndSettle();
    expect(favoriteNames(tester), ['INBOX', 'Posta inviata', 'Archivio', 'Posta eliminata']);
    await rightClick(tester, find.byKey(const ValueKey('favorite:a1:INBOX')));
    expect(tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Sposta su')).onPressed, isNull);
    await tester.tap(find.text('Rimuovi dai Preferiti'));
    await tester.pumpAndSettle();
    expect(favoriteNames(tester), ['Posta inviata', 'Archivio', 'Posta eliminata']);

    // Sulla riga dell'albero di una cartella già nei Preferiti il menu offre di toglierla.
    await rightClick(tester, find.byKey(const ValueKey('folder:a1:Archivio')));
    expect(find.text('Mostra nei Preferiti'), findsNothing);
    await tester.tap(find.text('Rimuovi dai Preferiti'));
    await tester.pumpAndSettle();
    expect(favoriteNames(tester), ['Posta inviata', 'Posta eliminata']);

    // Salvati: un nuovo avvio li ritrova.
    final again = AppSettings(store);
    await again.load();
    expect(again.favorites, [
      const FavoriteFolder('a1', 'Posta inviata'),
      const FavoriteFolder('a1', 'Posta eliminata'),
    ]);

    // Il clic su un Preferito apre la cartella.
    await tester.tap(find.byKey(const ValueKey('favorite:a1:Posta eliminata')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(
            find.descendant(
              of: find.byKey(const ValueKey('folder:a1:Posta eliminata')),
              matching: find.byType(ListTile),
            ),
          )
          .selected,
      isTrue,
    );
    await core.sse.close();
  });

  testWidgets('sezione Preferiti chiusa e ricordata; Preferiti di cartelle sparite nascosti', (tester) async {
    final store = MemorySettingsStore();
    await store.write(
      'favoriteFolders',
      jsonEncode([
        {'account': 'a1', 'folder': 'Sparita'},
        {'account': 'altro', 'folder': 'INBOX'},
        {'account': 'a1', 'folder': 'Archivio'},
      ]),
    );
    final settings = AppSettings(store);
    await settings.load();
    final core = await start(tester, settings);

    expect(favoriteNames(tester), ['Archivio']);

    await tester.tap(find.text('Preferiti'));
    await tester.pumpAndSettle();
    expect(favoriteNames(tester), isEmpty);
    expect(await store.read('favoritesCollapsed'), 'true');

    // Toglierne uno visibile non cancella quelli nascosti.
    await tester.tap(find.text('Preferiti'));
    await tester.pumpAndSettle();
    await rightClick(tester, find.byKey(const ValueKey('favorite:a1:Archivio')));
    await tester.tap(find.text('Rimuovi dai Preferiti'));
    await tester.pumpAndSettle();
    expect(settings.favorites, [const FavoriteFolder('a1', 'Sparita'), const FavoriteFolder('altro', 'INBOX')]);
    await core.sse.close();
  });
}
