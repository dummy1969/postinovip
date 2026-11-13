import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/state/mailbox_model.dart';
import 'package:postinovip/ui/ribbon_parts.dart';
import 'package:provider/provider.dart';

// Core finto della selezione multipla (a pagine di 50 come il core vero).
import 'multi_select_test.dart' as ms;
import 'shortcuts_test.dart' show key;

/// UID selezionati (la lista mostra solo le righe in vista).
List<int> selectedUids(WidgetTester tester) =>
    [for (final r in tester.element(find.byKey(const ValueKey('message-list'))).read<MailboxModel>().selection) r.uid]..sort();

/// Tasti della lista e Svuota cartella (12/11/2026, scelte 1a 2a 3a).
void main() {
  testWidgets('Home, Fine e Maiusc+Fine arrivano in fondo alla lista a pagine; Pag↓ e Pag↑', (tester) async {
    final core = await ms.start(tester);
    core.mail['INBOX'] = [for (var uid = 120; uid >= 1; uid--) ms.SelectCore.header(uid, 'Mail $uid', seen: false)];
    await tester.tap(find.byKey(const ValueKey('folder:a1:INBOX')));
    await tester.pumpAndSettle();
    expect(find.text('Mail 1'), findsNothing); // caricate le prime 50, e solo quelle in vista

    await key(tester, LogicalKeyboardKey.end);
    expect(find.text('Mail 1'), findsOneWidget); // tutta la lista caricata e mostrata in fondo
    expect(ms.selected(tester, 'Mail 1'), isTrue);

    await key(tester, LogicalKeyboardKey.home);
    expect(ms.selected(tester, 'Mail 120'), isTrue);

    await key(tester, LogicalKeyboardKey.end, shift: true);
    expect(find.text('120 elementi selezionati'), findsOneWidget);
    expect(ms.selected(tester, 'Mail 1'), isTrue);

    // Pag↓ dall'inizio: una sola mail, più in basso di una riga; Pag↑ torna alla prima.
    await key(tester, LogicalKeyboardKey.home);
    await key(tester, LogicalKeyboardKey.pageDown);
    final page = selectedUids(tester);
    expect(page, hasLength(1));
    expect(page.single, lessThan(119)); // più di una riga sotto la prima
    expect(find.text('Mail ${page.single}'), findsOneWidget); // e la lista l'ha portata in vista
    expect(find.text('testo'), findsOneWidget); // una sola: aperta
    await key(tester, LogicalKeyboardKey.pageUp);
    expect(selectedUids(tester), [120]);
    expect(ms.selected(tester, 'Mail 120'), isTrue);

    // Maiusc+Pag↓: la selezione si allarga dalla prima fino a dove arrivava Pag↓.
    await key(tester, LogicalKeyboardKey.pageDown, shift: true);
    expect(selectedUids(tester), [for (var uid = page.single; uid <= 120; uid++) uid]);
    expect(core.writes, isEmpty);
    await core.sse.close();
  });

  testWidgets('Svuota cartella: solo Posta eliminata e indesiderata, dopo la conferma con il numero', (tester) async {
    final core = await ms.start(tester, folders: ['Posta indesiderata', 'Posta eliminata/Vecchia']);
    Finder row(String f) => find.byKey(ValueKey('folder:a1:$f'));
    Future<void> rightClick(String f) async {
      await tester.tap(row(f), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
    }

    await rightClick('Posta eliminata');
    await tester.tap(find.text('Svuota cartella'));
    await tester.pumpAndSettle();
    expect(find.text('Svuotare "Posta eliminata"?'), findsOneWidget);
    expect(
      find.textContaining('Tutte le 2 mail di "Posta eliminata" e la sottocartella, con le sue mail, verranno cancellate'),
      findsOneWidget,
    );
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(core.writes, isEmpty);

    await rightClick('Posta eliminata');
    await tester.tap(find.text('Svuota cartella'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('empty-folder-confirm')));
    await tester.pumpAndSettle();
    expect(core.writes.single, 'POST /accounts/a1/folders/Posta eliminata/empty null');
    expect(find.text('"Posta eliminata" svuotata: 2 mail eliminate e 1 cartella definitivamente'), findsOneWidget);
    expect(row('Posta eliminata/Vecchia'), findsNothing);

    // Posta indesiderata: senza sottocartelle; dalla scheda Cartella.
    await tester.tap(row('Posta indesiderata'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cartella').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ribbon-empty-folder')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tutte le mail di "Posta indesiderata" verranno cancellate'), findsNothing); // count 0
    await tester.tap(find.byKey(const Key('empty-folder-confirm')));
    await tester.pumpAndSettle();
    expect(core.writes.last, 'POST /accounts/a1/folders/Posta indesiderata/empty null');

    // Nelle altre cartelle il comando non c'è (menu) o è spento (scheda Cartella).
    await tester.tap(row('INBOX'));
    await tester.pumpAndSettle();
    expect(tester.widget<RibbonSmallButton>(find.byKey(const Key('ribbon-empty-folder'))).onPressed, isNull);
    await rightClick('INBOX');
    expect(find.widgetWithText(MenuItemButton, 'Elimina cartella'), findsOneWidget); // il menu è aperto
    expect(find.widgetWithText(MenuItemButton, 'Svuota cartella'), findsNothing);
    await core.sse.close();
  });
}
