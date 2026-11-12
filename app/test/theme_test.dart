import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/theme.dart';

import 'view_test.dart' show start, view;

// Temi di Office: Visualizza → Tema e File → Opzioni → Aspetto; testo delle mail sempre su fondo bianco.

MaterialApp app(WidgetTester tester) => tester.widget<MaterialApp>(find.byType(MaterialApp));

/// Colore della banda delle schede della barra multifunzione.
Color? tabBand(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(const ValueKey('ribbon-tabs')).first).color;

/// Colore della barra in alto (V2: nel tema Colorato il blu sta qui).
Color? topBar(WidgetTester tester) => tester.widget<Container>(find.byKey(const Key('top-bar'))).color;

Brightness brightness(WidgetTester tester) => Theme.of(tester.element(find.text('Visualizza'))).brightness;

void main() {
  test('temi: sistema = Colorato/Nero; chiari e scuri; costruiti una volta', () {
    final system = OfficeTheme.forApp(AppTheme.system);
    expect(system.mode, ThemeMode.system);
    expect(identical(system.theme, OfficeTheme.of(AppTheme.colorful)), isTrue);
    expect(identical(system.darkTheme, OfficeTheme.of(AppTheme.black)), isTrue);
    for (final t in [AppTheme.colorful, AppTheme.white]) {
      expect(OfficeTheme.forApp(t).mode, ThemeMode.light);
      expect(OfficeTheme.of(t).brightness, Brightness.light);
    }
    for (final t in [AppTheme.darkGray, AppTheme.black]) {
      expect(OfficeTheme.forApp(t).mode, ThemeMode.dark);
      expect(OfficeTheme.of(t).brightness, Brightness.dark);
    }
    expect(OfficeTheme.of(AppTheme.colorful).extension<OfficeChrome>()!.titleBar, OfficeTheme.brand);
    expect(OfficeTheme.of(AppTheme.colorful).extension<OfficeChrome>()!.tabBar, isNot(OfficeTheme.brand));
    expect(OfficeTheme.of(AppTheme.white).extension<OfficeChrome>()!.titleBar, Colors.white);
    expect(OfficeTheme.of(AppTheme.white).extension<OfficeChrome>()!.tabBar, Colors.white);
    expect(
      OfficeTheme.of(AppTheme.darkGray).colorScheme.surface,
      isNot(OfficeTheme.of(AppTheme.black).colorScheme.surface),
    );
  });

  test('tema salvato e riletto; valore sconosciuto = sistema', () async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store);
    await settings.load();
    expect(settings.theme, AppTheme.system);
    await settings.setTheme(AppTheme.darkGray);
    expect(await store.read('theme'), 'darkGray');
    final again = AppSettings(store);
    await again.load();
    expect(again.theme, AppTheme.darkGray);
    await store.write('theme', 'arcobaleno');
    await again.load();
    expect(again.theme, AppTheme.system);
  });

  testWidgets('Visualizza → Tema: Nero e Colorato; mail su fondo bianco col tema scuro', (tester) async {
    final (fake, settings, store) = await start(tester);
    expect(app(tester).themeMode, ThemeMode.system);
    expect(brightness(tester), Brightness.light); // il sistema dei test è chiaro: Colorato
    expect(topBar(tester), OfficeTheme.brand); // il blu nella barra in alto, le schede su fondo chiaro
    expect(tabBand(tester), const Color(0xFFF3F3F3));

    await view(tester, 'Tema', 'Nero');
    expect(settings.theme, AppTheme.black);
    expect(await store.read('theme'), 'black');
    expect(app(tester).themeMode, ThemeMode.dark);
    expect(brightness(tester), Brightness.dark);
    expect(tabBand(tester), OfficeTheme.of(AppTheme.black).colorScheme.surfaceContainer);
    expect(topBar(tester), OfficeTheme.of(AppTheme.black).colorScheme.surfaceContainerLowest);

    await tester.tap(find.text('Mail 5'));
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('message-surface'));
    expect(tester.widget<Material>(surface).color, Colors.white);
    final body = tester.element(find.descendant(of: surface, matching: find.text('testo')));
    expect(Theme.of(body).brightness, Brightness.light);
    expect(DefaultTextStyle.of(body).style.color!.computeLuminance(), lessThan(0.2)); // testo scuro

    await view(tester, 'Tema', 'Colorato');
    expect(app(tester).themeMode, ThemeMode.light);
    expect(topBar(tester), OfficeTheme.brand);
    await fake.core.sse.close();
  });

  testWidgets('File → Opzioni → Aspetto: Bianco', (tester) async {
    final (fake, settings, _) = await start(tester);
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    expect(find.text('Aspetto'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bianco').last);
    await tester.pumpAndSettle();
    expect(settings.theme, AppTheme.white);
    expect(tabBand(tester), Colors.white);
    expect(topBar(tester), Colors.white);
    await fake.core.sse.close();
  });

  test('V6: testo normale a 14 come Office (anche caselle e menu a tendina), caselle basse', () {
    for (final t in AppTheme.values) {
      final theme = OfficeTheme.of(t);
      expect(theme.textTheme.bodyLarge!.fontSize, 14, reason: t.name);
      expect(theme.textTheme.titleMedium!.fontSize, 14, reason: t.name);
      expect(theme.textTheme.titleMedium!.fontWeight, FontWeight.w400, reason: t.name);
      expect(theme.textTheme.bodyLarge!.fontFamily, OfficeTheme.fontFamily, reason: t.name);
      expect(theme.inputDecorationTheme.isDense, isTrue, reason: t.name);
      // Il bordo lo sceglie ogni casella (le righe sottolineate della composizione restano tali).
      expect(theme.inputDecorationTheme.border, isNull, reason: t.name);
    }
  });
}
