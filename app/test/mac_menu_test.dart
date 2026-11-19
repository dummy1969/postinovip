import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/ui/keys.dart';
import 'package:postinovip/ui/ribbon.dart';

// Stesso core finto della selezione multipla: INBOX con "Mail 5"…"Mail 1" (UID 5–1, da leggere).
import 'multi_select_test.dart' as ms;

/// Tappa «Mac», M2a: barra dei menu del Mac e scorciatoie con ⌘ (lib/ui/mac_menu_bar.dart, lib/ui/keys.dart).
/// I test girano come Android: per il Mac si cambia la piattaforma con debugDefaultTargetPlatformOverride, da
/// rimettere a null prima della fine del test.

Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {bool meta = false, bool shift = false, bool control = false}) async {
  if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

/// Tasto e modificatori di una scorciatoia (SingleActivator non ha l'uguaglianza).
String describe(SingleActivator a) =>
    [a.trigger.keyLabel.isEmpty ? a.trigger.debugName : 'Key ${a.trigger.keyLabel}', if (a.control) 'ctrl', if (a.meta) 'meta', if (a.shift) 'shift']
        .join(' ');

/// Voce di menu con [label] nella struttura mandata da Flutter con Menu.setMenus.
Map<Object?, Object?>? findItem(Object? node, String label) {
  if (node is Map) {
    if (node['label'] == label) return node;
    for (final value in node.values) {
      final found = findItem(value, label);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final value in node) {
      final found = findItem(value, label);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  test('etichette dei tasti: invariate su Linux e Windows, simboli del Mac sul Mac', () {
    const texts = [
      'Altra cartella… (Ctrl+Maiusc+V)',
      'Elemento precedente (Ctrl+,)',
      'Ingrandisci o riduci il testo della mail (Ctrl+rotella, Ctrl++, Ctrl+-, Ctrl+0)',
      'Vorheriges Element (Strg+,)',
      'Sposta nella cartella di archiviazione (Backspace)',
      'Elimina il contatto selezionato (Canc)',
      'Mostra solo le schede (Ctrl+F1)',
    ];
    for (final t in texts) {
      expect(keyLabel(t), t);
    }
    expect(describe(cmd(LogicalKeyboardKey.keyN)), 'Key N ctrl');

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      expect(
        texts.map(keyLabel).toList(),
        [
          'Altra cartella… (⇧⌘V)',
          'Elemento precedente (⌘[)',
          'Ingrandisci o riduci il testo della mail (⌘ + rotella, ⌘+, ⌘-, ⌘0)',
          'Vorheriges Element (⌘[)',
          'Sposta nella cartella di archiviazione (⌃E)',
          'Elimina il contatto selezionato (⌫)',
          'Mostra solo le schede (⌘F1)',
        ],
      );
      expect(keyLabel('Other Folder… (Ctrl+Shift+V)'), 'Other Folder… (⇧⌘V)');
      expect(keyLabel('Autre dossier… (Ctrl+Maj+V)'), 'Autre dossier… (⇧⌘V)');
      expect(keyLabel('Anderer Ordner… (Strg+Umschalt+V)'), 'Anderer Ordner… (⇧⌘V)');
      expect(keyLabel('Ctrl+Alt+2'), '⌥⌘2');
      expect(keyLabel('Supprimer (Suppr)'), 'Supprimer (⌫)');
      expect(describe(cmd(LogicalKeyboardKey.keyN)), 'Key N meta');
      expect(describe(markReadKey), 'Key T meta');
      expect(describe(archiveKey), 'Key E ctrl');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('sul Mac: ⌘T / ⇧⌘T, ⌫ elimina, ⌘A, Ctrl e ⌘Q non toccano la casella', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final messenger = tester.binding.defaultBinaryMessenger;
    final native = <String>[];
    Object? menus;
    messenger.setMockMethodCallHandler(SystemChannels.menu, (call) async {
      if (call.method == 'Menu.setMenus') menus = call.arguments;
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('com.dumm1969.postinovip/window'), (call) async {
      native.add(call.arguments == null ? call.method : '${call.method} ${call.arguments}');
      return null;
    });
    try {
      final core = await ms.start(tester);
      await ms.click(tester, 'Mail 5');
      await ms.click(tester, 'Mail 4', holding: LogicalKeyboardKey.metaLeft); // ⌘+clic aggiunge alla selezione

      await press(tester, LogicalKeyboardKey.keyQ, control: true); // Ctrl+Q non vale sul Mac
      await press(tester, LogicalKeyboardKey.keyQ, meta: true); // ⌘Q è Esci: lasciato ai menu
      expect(core.writes, isEmpty);

      await press(tester, LogicalKeyboardKey.keyT, meta: true);
      expect(core.writes.last, 'PUT /accounts/a1/messages/INBOX/seen {"uids":[4,5],"seen":true}');
      await press(tester, LogicalKeyboardKey.keyT, meta: true, shift: true);
      expect(core.writes.last, 'PUT /accounts/a1/messages/INBOX/seen {"uids":[4,5],"seen":false}');

      await press(tester, LogicalKeyboardKey.keyA, meta: true);
      expect(find.text('5 elementi selezionati'), findsOneWidget);

      await ms.click(tester, 'Mail 3');
      await press(tester, LogicalKeyboardKey.backspace);
      expect(core.writes.last, 'DELETE /accounts/a1/messages/INBOX/3 '); // in Posta eliminata, come Canc

      // Barra dei menu: voci nella lingua dell'app, titolo di Servizi passato al codice nativo prima della barra.
      expect(native.first, 'servicesTitle Servizi');
      for (final label in ['Informazioni su PostinoVip', 'Opzioni…', 'Nascondi PostinoVip', 'Esci da PostinoVip',
          'Composizione', 'Seleziona tutto', 'Finestra', 'Contrai']) {
        expect(findItem(menus, label), isNotNull, reason: label);
      }
      final quit = findItem(menus, 'Esci da PostinoVip')!;
      expect(quit['shortcutTrigger'], LogicalKeyboardKey.keyQ.keyId);

      // Scelta di una voce (come la manda il Mac): Esci → AppKit.
      Future<void> choose(String label) async {
        final id = findItem(menus, label)!['id'];
        await messenger.handlePlatformMessage(
          SystemChannels.menu.name,
          SystemChannels.menu.codec.encodeMethodCall(MethodCall('Menu.selectedCallback', id)),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      await choose('Esci da PostinoVip');
      expect(native.last, 'quit');
      await choose('Opzioni…');
      expect(find.text('Opzioni'), findsWidgets);
      await core.sse.close();
    } finally {
      messenger.setMockMethodCallHandler(SystemChannels.menu, null);
      messenger.setMockMethodCallHandler(const MethodChannel('com.dumm1969.postinovip/window'), null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('M2b: menu della finestra principale, barra multifunzione nascosta, menu della composizione', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final messenger = tester.binding.defaultBinaryMessenger;
    Object? menus;
    messenger.setMockMethodCallHandler(SystemChannels.menu, (call) async {
      if (call.method == 'Menu.setMenus') menus = call.arguments;
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('com.dumm1969.postinovip/window'), (call) async => null);
    Future<void> choose(String label) async {
      final id = findItem(menus, label)!['id'];
      await messenger.handlePlatformMessage(
        SystemChannels.menu.name,
        SystemChannels.menu.codec.encodeMethodCall(MethodCall('Menu.selectedCallback', id)),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    List<String> topLabels() => [for (final m in ((menus as Map)['0'] as List)) (m as Map)['label'] as String];
    try {
      final core = await ms.start(tester);
      expect(topLabels(), ['PostinoVip', 'File', 'Composizione', 'Visualizza', 'Messaggio', 'Cartella', 'Finestra']);
      // Senza una mail scelta: Rispondi e Stampa spenti, Nuovo messaggio acceso (come la barra).
      expect(findItem(menus, 'Rispondi')!['enabled'], false);
      expect(findItem(menus, 'Stampa…')!['enabled'], false);
      expect(findItem(menus, 'Nuovo messaggio')!['enabled'], true);
      expect(findItem(menus, '✓\u2002Posta'), isNotNull); // modulo aperto con la spunta

      await ms.click(tester, 'Mail 5');
      await ms.click(tester, 'Mail 4', holding: LogicalKeyboardKey.metaLeft);
      expect(findItem(menus, 'Rispondi')!['enabled'], false); // due mail: come la barra
      // Sottomenu gemelli di quelli della barra: categorie (con il nome scelto), Completa, Pulisci, indesiderata.
      for (final label in ['Categorizza', 'Completa', 'Pulisci', 'Posta indesiderata', 'Blocca mittente']) {
        expect(findItem(menus, label), isNotNull, reason: label);
      }
      await choose('\u2003\u2002Categoria rossa');
      expect(core.writes.last, 'PUT /accounts/a1/messages/INBOX/flags {"uids":[4,5],"addCategories":[1]}');
      await choose('Segna come letto');
      expect(core.writes.last, 'PUT /accounts/a1/messages/INBOX/seen {"uids":[4,5],"seen":true}');

      // Barra multifunzione: si nasconde dal menu Visualizza (e dalle Opzioni) e torna.
      expect(find.byType(Ribbon), findsOneWidget);
      await choose('✓\u2002Barra multifunzione');
      expect(find.byType(Ribbon), findsNothing);
      await choose('Opzioni…');
      expect(find.byKey(const Key('settings-show-ribbon')), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-show-ribbon')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Ribbon), findsOneWidget);

      // Composizione aperta: i suoi menu al posto di quelli della finestra principale; chiusa, tornano quelli.
      await press(tester, LogicalKeyboardKey.keyN, meta: true);
      expect(topLabels(), ['PostinoVip', 'File', 'Composizione', 'Messaggio', 'Formato', 'Finestra']);
      expect(findItem(menus, 'Invia'), isNotNull);
      expect(findItem(menus, 'Grassetto'), isNotNull);
      await choose('Chiudi finestra');
      expect(findItem(menus, 'Nuovo messaggio'), isNotNull);
      expect(core.writes.where((w) => w.contains('send')), isEmpty);
      await core.sse.close();
    } finally {
      messenger.setMockMethodCallHandler(SystemChannels.menu, null);
      messenger.setMockMethodCallHandler(const MethodChannel('com.dumm1969.postinovip/window'), null);
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('su Linux e Windows nessuna barra dei menu del sistema', (tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    var setMenus = 0;
    messenger.setMockMethodCallHandler(SystemChannels.menu, (call) async {
      if (call.method == 'Menu.setMenus') setMenus++;
      return null;
    });
    final core = await ms.start(tester);
    expect(setMenus, 0);
    await core.sse.close();
    messenger.setMockMethodCallHandler(SystemChannels.menu, null);
  });
}
