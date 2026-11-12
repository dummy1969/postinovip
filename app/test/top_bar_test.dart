import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/settings/app_settings.dart';

import 'view_test.dart' show start;

// Tappa «Aspetto», V2: barra in alto (Invia/ricevi e ricerca) e barra dei moduli verticale a sinistra.

void main() {
  testWidgets('barra in alto sopra la barra multifunzione; moduli a sinistra sotto di essa', (tester) async {
    final (fake, _, _) = await start(tester);
    final top = tester.getRect(find.byKey(const Key('top-bar')));
    final tabs = tester.getRect(find.byKey(const ValueKey('ribbon-tabs')).first);
    final modules = tester.getRect(find.byKey(const Key('module-bar')));
    final inbox = tester.getRect(find.text('Posta in arrivo').first);
    expect(top.top, 0);
    expect(top.bottom, lessThanOrEqualTo(tabs.top));
    expect(modules.left, 0);
    expect(modules.top, greaterThan(tabs.bottom)); // sotto la barra multifunzione
    expect(modules.right, lessThanOrEqualTo(inbox.left)); // a sinistra del riquadro cartelle
    // Le tre icone una sotto l'altra.
    final mail = tester.getCenter(find.byKey(const Key('module-mail')));
    final calendar = tester.getCenter(find.byKey(const Key('module-calendar')));
    final people = tester.getCenter(find.byKey(const Key('module-people')));
    expect(mail.dx, calendar.dx);
    expect(calendar.dx, people.dx);
    expect(mail.dy < calendar.dy && calendar.dy < people.dy, isTrue);
    await fake.core.sse.close();
  });

  testWidgets('Invia/ricevi nella barra in alto ricarica la cartella; ricerca solo nella Posta', (tester) async {
    final (fake, _, _) = await start(tester);
    final before = fake.lists.length;
    await tester.tap(find.byKey(const Key('top-send-receive')));
    await tester.pumpAndSettle();
    expect(fake.lists.length, greaterThan(before));

    expect(find.byKey(const Key('search-box')), findsOneWidget);
    await tester.tap(find.byKey(const Key('module-people')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-box')), findsNothing);
    await tester.tap(find.byKey(const Key('module-mail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-box')), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('suggerimento della barra verticale a destra dell\'icona, senza coprire le altre', (tester) async {
    final (fake, _, _) = await start(tester);
    await tester.longPress(find.byKey(const Key('module-people')));
    await tester.pump(const Duration(milliseconds: 500));
    final tip = tester.getRect(find.text('Persone (Ctrl+3)'));
    final bar = tester.getRect(find.byKey(const Key('module-bar')));
    final people = tester.getCenter(find.byKey(const Key('module-people')));
    expect(tip.left, greaterThan(bar.right - 8)); // a destra della barra
    expect((tip.center.dy - people.dy).abs(), lessThan(4)); // alla stessa altezza
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await fake.core.sse.close();
  });

  testWidgets('File → Opzioni → Generale: barra dei moduli in basso nel riquadro di sinistra, e ritorno (1c)', (tester) async {
    final (fake, settings, store) = await start(tester);
    expect(settings.moduleBar, ModuleBarPosition.left);
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('module-bar-choice')));
    await tester.tap(find.byKey(const ValueKey('module-bar-choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ModuleBarPosition.bottom.label).last);
    await tester.pumpAndSettle();
    expect(settings.moduleBar, ModuleBarPosition.bottom);
    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();

    // Orizzontale, in fondo al riquadro delle cartelle, sotto le cartelle.
    final bar = tester.getRect(find.byKey(const Key('module-bar')));
    final inbox = tester.getRect(find.text('Posta in arrivo').first);
    final mail = tester.getCenter(find.byKey(const Key('module-mail')));
    final people = tester.getCenter(find.byKey(const Key('module-people')));
    expect(mail.dy, people.dy);
    expect(mail.dx, lessThan(people.dx));
    expect(bar.top, greaterThan(inbox.bottom));
    expect(bar.left, lessThan(inbox.left));
    expect(bar.right, lessThan(tester.getRect(find.byKey(const Key('top-bar'))).width / 2));

    // Anche nel Calendario e in Persone, e la scelta resta dopo il riavvio.
    for (final m in ['calendar', 'people', 'mail']) {
      await tester.tap(find.byKey(Key('module-$m')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('module-bar')), findsOneWidget, reason: m);
    }
    final again = AppSettings(store);
    await again.load();
    expect(again.moduleBar, ModuleBarPosition.bottom);

    await settings.setModuleBar(ModuleBarPosition.left);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('module-bar'))).left, 0);
    await fake.core.sse.close();
  });
}
