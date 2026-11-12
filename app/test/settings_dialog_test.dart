import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'view_test.dart' show start;

/// File → Opzioni (10/11/2026, scelte 1a 2a 3a 4a): categorie a sinistra come le Opzioni di Outlook, una pagina per
/// volta, finestra di grandezza fissa.
void main() {
  Future<void> openOptions(WidgetTester tester) async {
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
  }

  Future<void> page(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(Key('settings-tab-$name')));
    await tester.pumpAndSettle();
  }

  testWidgets('una pagina per categoria, sempre della stessa grandezza', (tester) async {
    final (fake, _, _) = await start(tester);
    await openOptions(tester);
    final dialog = find.byKey(const Key('settings-dialog'));
    final size = tester.getSize(dialog);
    expect(
      find.byType(ListTile).evaluate().where((e) => e.widget.key.toString().contains('settings-tab-')),
      hasLength(4),
    );

    // Generale: tema; non le notifiche né il calendario.
    expect(find.byKey(const ValueKey('theme-choice')), findsOneWidget);
    expect(find.text('Notifiche di nuova posta'), findsNothing);

    await page(tester, 'mail');
    expect(
      find.descendant(of: find.byKey(const Key('settings-dialog')), matching: find.text('Segna come letto')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('theme-choice')), findsNothing);
    expect(tester.getSize(dialog), size);

    await page(tester, 'notifications');
    expect(find.text('Notifiche di nuova posta'), findsOneWidget);
    expect(tester.getSize(dialog), size);

    await page(tester, 'calendar');
    expect(find.byKey(const ValueKey('calendar-first-day')), findsOneWidget);
    expect(tester.getSize(dialog), size);
    await fake.core.sse.close();
  });

  testWidgets('Posta: le conferme di Ignora conversazione si riattivano', (tester) async {
    final (fake, settings, store) = await start(tester);
    await settings.setConfirmIgnore(false); // «Non visualizzare più questo messaggio»
    await openOptions(tester);
    await page(tester, 'mail');
    final ignore = find.byKey(const Key('settings-confirm-ignore'));
    await tester.ensureVisible(ignore);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(ignore).value, isFalse);
    await tester.tap(ignore);
    await tester.pumpAndSettle();
    expect(settings.confirmIgnore, isTrue);
    expect(await store.read('confirmIgnore'), 'true');
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('settings-confirm-stop-ignoring'))).value, isTrue);
    await fake.core.sse.close();
  });

  testWidgets('finestra minima 640×480: le categorie restano a sinistra, nessun trabocco', (tester) async {
    final (fake, _, _) = await start(tester);
    tester.view.physicalSize = const Size(640, 480);
    await tester.pumpAndSettle();
    await openOptions(tester);
    for (final name in ['general', 'mail', 'notifications', 'calendar']) {
      await page(tester, name);
      expect(tester.takeException(), isNull);
    }
    await fake.core.sse.close();
  });
}
