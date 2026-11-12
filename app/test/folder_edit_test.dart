import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/models/favorite_folder.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';

/// Core finto con un account ("a1") che crea, rinomina ed elimina davvero le cartelle del suo elenco,
/// con le regole del core: nomi validati, "Esistente" già usato, cartelle con ruolo intoccabili.
class FolderEditCore {
  final sse = StreamController<List<int>>();
  final writes = <String>[];
  final folders = <String, String?>{
    'Archivio': null,
    'INBOX': 'inbox',
    'Posta eliminata': 'trash',
    'Posta inviata': 'sent',
  };

  late final client = MockClient.streaming((request, bodyStream) async {
    final path = Uri.decodeComponent(request.url.path);
    final body = await bodyStream.bytesToString();
    http.StreamedResponse json(Object value, [int status = 200]) => http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(value))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    http.StreamedResponse nameError(String message) => json({
      'title': 'Dati non validi',
      'errors': {
        'name': [message],
      },
    }, 400);

    if (path == '/events') return http.StreamedResponse(sse.stream, 200);
    if (path == '/accounts') {
      return json([
        {'id': 'a1', 'name': 'io@example.com', 'address': 'io@example.com', 'configured': true, 'online': true},
      ]);
    }
    if (path == '/accounts/a1/folders' && request.method == 'GET') {
      return json([
        for (final e in folders.entries)
          {'fullName': e.key, 'name': e.key.split('/').last, 'count': 0, 'unread': 0, 'specialUse': ?e.value},
      ]);
    }
    if (path.endsWith('/messages')) return json({'total': 0, 'offset': 0, 'limit': 50, 'items': []});

    if (request.method != 'GET') writes.add('${request.method} $path${body.isEmpty ? '' : ' $body'}');
    if (path == '/accounts/a1/folders' && request.method == 'POST') {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final name = (data['name'] as String).trim();
      if (name.isEmpty) return nameError('Scrivere il nome della cartella.');
      if (name == 'Esistente') return nameError('Esiste già una cartella "Esistente" qui.');
      final parent = data['parent'] as String?;
      final full = parent == null ? name : '$parent/$name';
      if (name != 'Invisibile') folders[full] = null; // «Invisibile»: confermata ma non elencata
      return json({'fullName': full, 'separator': '/'}, 201);
    }
    final rename = RegExp(r'^/accounts/a1/folders/(.+)/rename$').firstMatch(path);
    if (rename != null) {
      final from = rename[1]!;
      final name = (jsonDecode(body) as Map<String, dynamic>)['name'] as String;
      final cut = from.lastIndexOf('/');
      final to = cut < 0 ? name : '${from.substring(0, cut)}/$name';
      _move(from, to);
      return json({'fullName': to, 'separator': '/'});
    }
    final delete = RegExp(r'^/accounts/a1/folders/(.+)$').firstMatch(path);
    if (delete != null && request.method == 'DELETE') {
      final folder = delete[1]!;
      if (folders[folder] != null) return json({'title': 'Operazione non consentita'}, 409);
      if (folder.startsWith('Posta eliminata/')) {
        folders.removeWhere((k, _) => k == folder || k.startsWith('$folder/'));
        return json({'movedTo': null, 'permanent': true, 'separator': '/'});
      }
      final to = 'Posta eliminata/${folder.split('/').last}';
      _move(folder, to);
      return json({'movedTo': to, 'permanent': false, 'separator': '/'});
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  });

  void _move(String from, String to) {
    for (final k in folders.keys.toList()) {
      if (k == from || k.startsWith('$from/')) folders['$to${k.substring(from.length)}'] = folders.remove(k);
    }
  }
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<FolderEditCore> start(WidgetTester tester, AppSettings settings) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final core = FolderEditCore();
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

Finder row(String folder) => find.byKey(ValueKey('folder:a1:$folder'));

Future<void> menu(WidgetTester tester, Finder target, String command) async {
  await tester.tap(target, buttons: kSecondaryButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text(command));
  await tester.pumpAndSettle();
}

Future<void> typeAndEnter(WidgetTester tester, String text) async {
  await tester.enterText(nameField(), text);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// Il campo del nome nel riquadro cartelle (la casella "Cerca" della lista è l'altro TextField).
Finder nameField() => find.widgetWithText(TextField, 'Nome della cartella');

void main() {
  testWidgets('nuova cartella: sottocartella di quella del tasto destro, nome rifiutato resta da correggere', (
    tester,
  ) async {
    final core = await start(tester, AppSettings(MemorySettingsStore()));

    await menu(tester, row('Archivio'), 'Nuova cartella');
    expect(find.byKey(const ValueKey('new-folder')), findsOneWidget);

    await tester.enterText(nameField(), 'Esistente');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Esiste già una cartella "Esistente" qui.'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-folder')), findsOneWidget); // resta aperta per correggere

    await tester.enterText(nameField(), 'Clienti');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(core.writes.last, 'POST /accounts/a1/folders {"parent":"Archivio","name":"Clienti"}');
    expect(find.byKey(const ValueKey('new-folder')), findsNothing);
    expect(row('Archivio/Clienti'), findsOneWidget);

    // In cima all'account: tasto destro sul nome dell'account. Esc annulla senza richieste.
    final before = core.writes.length;
    await menu(tester, find.text('io@example.com'), 'Nuova cartella');
    await tester.enterText(nameField(), 'Mai creata');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-folder')), findsNothing);
    expect(core.writes.length, before);
    await core.sse.close();
  });

  testWidgets('F2 rinomina la cartella selezionata; Preferiti e selezione seguono il nuovo nome', (tester) async {
    final settings = AppSettings(MemorySettingsStore());
    await settings.setFavorites([const FavoriteFolder('a1', 'INBOX'), const FavoriteFolder('a1', 'Archivio')]);
    final core = await start(tester, settings);

    await tester.tap(row('Archivio'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(nameField()).controller!.text, 'Archivio');

    await typeAndEnter(tester, 'Storico');

    expect(core.writes.single, 'POST /accounts/a1/folders/Archivio/rename {"name":"Storico"}');
    expect(row('Storico'), findsOneWidget);
    expect(settings.favorites, [const FavoriteFolder('a1', 'INBOX'), const FavoriteFolder('a1', 'Storico')]);
    final tile = tester.widget<ListTile>(find.descendant(of: row('Storico'), matching: find.byType(ListTile)));
    expect(tile.selected, isTrue);

    // Le cartelle speciali non si rinominano: F2 su INBOX non apre niente, comandi disattivati.
    await tester.tap(row('INBOX'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(nameField(), findsNothing);
    await tester.tap(row('INBOX'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Rinomina cartella')).onPressed, isNull);
    expect(tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Elimina cartella')).onPressed, isNull);
    await core.sse.close();
  });

  testWidgets('elimina: prima in Posta eliminata, da lì definitiva con conferma esplicita', (tester) async {
    final settings = AppSettings(MemorySettingsStore());
    await settings.setFavorites([const FavoriteFolder('a1', 'Archivio')]);
    final core = await start(tester, settings);

    await menu(tester, row('Archivio'), 'Elimina cartella');
    expect(find.text('Eliminare la cartella?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Elimina'));
    await tester.pumpAndSettle();
    expect(core.writes.single, 'DELETE /accounts/a1/folders/Archivio');
    expect(row('Posta eliminata/Archivio'), findsOneWidget);
    expect(settings.favorites, [const FavoriteFolder('a1', 'Posta eliminata/Archivio')]);
    expect(find.text('Cartella "Archivio" spostata in Posta eliminata'), findsOneWidget);

    // Dentro Posta eliminata: definitiva. "Annulla" non fa nulla.
    await menu(tester, row('Posta eliminata/Archivio'), 'Elimina cartella');
    expect(find.text('Eliminare definitivamente la cartella?'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(core.writes.length, 1);

    await menu(tester, row('Posta eliminata/Archivio'), 'Elimina cartella');
    await tester.tap(find.text('Elimina definitivamente'));
    await tester.pumpAndSettle();
    expect(core.writes.last, 'DELETE /accounts/a1/folders/Posta eliminata/Archivio');
    expect(row('Posta eliminata/Archivio'), findsNothing);
    expect(settings.favorites, isEmpty);
    await core.sse.close();
  });

  testWidgets('scheda Cartella: comandi sulla cartella selezionata', (tester) async {
    final core = await start(tester, AppSettings(MemorySettingsStore()));

    await tester.tap(find.text('Cartella'));
    await tester.pumpAndSettle();
    await tester.tap(row('Archivio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rinomina cartella'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(nameField()).controller!.text, 'Archivio');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuova cartella'));
    await tester.pumpAndSettle();
    await typeAndEnter(tester, 'Sotto');
    expect(core.writes.single, 'POST /accounts/a1/folders {"parent":"Archivio","name":"Sotto"}');
    await core.sse.close();
  });

  testWidgets('nuova cartella confermata dal server ma non elencata: avviso, non silenzio', (tester) async {
    final core = await start(tester, AppSettings(MemorySettingsStore()));
    await menu(tester, row('INBOX'), 'Nuova cartella');
    await typeAndEnter(tester, 'Invisibile');
    expect(core.writes.last, 'POST /accounts/a1/folders {"parent":"INBOX","name":"Invisibile"}');
    expect(find.textContaining('Il server ha confermato la cartella «INBOX/Invisibile», ma non la mostra'), findsOneWidget);
    await core.sse.close();
  });

  // 10/11/2026: nell'app vera l'Invio non arrivava alla casella (lo prendeva la scorciatoia «Invio apre la mail»)
  // e la casella si chiudeva quando la finestra dell'app perdeva il fuoco. I test sopra usano receiveAction e non
  // potevano accorgersene: qui il tasto vero e il cambio di finestra.
  testWidgets('nuova cartella: l\'Invio arriva alla casella, la finestra in secondo piano non la chiude', (tester) async {
    final core = await start(tester, AppSettings(MemorySettingsStore()));
    await menu(tester, row('INBOX'), 'Nuova cartella');
    await tester.enterText(nameField(), 'Prova');
    await tester.pump();

    // Un'altra finestra in primo piano e poi di nuovo l'app: la casella resta, con il testo. Sul desktop Flutter
    // toglie il fuoco con l'app inattiva e lo ridà al ritorno (FocusManager._appLifecycleChange); nei test, che
    // girano come Android, non lo fa: qui si fa lo stesso a mano.
    final field = FocusManager.instance.primaryFocus!;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    field.unfocus();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    field.requestFocus();
    await tester.pumpAndSettle();
    expect(nameField(), findsOneWidget);
    expect(core.writes, isEmpty);

    // L'Invio non è preso dalle scorciatoie della pagina: va alla casella (sul desktop poi diventa l'azione «fatto»).
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(core.writes.last, 'POST /accounts/a1/folders {"parent":"INBOX","name":"Prova"}');
    expect(nameField(), findsNothing);
    await core.sse.close();
  });
}
