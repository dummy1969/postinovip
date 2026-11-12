import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/models/favorite_folder.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/folder_pane.dart';
import 'package:provider/provider.dart';

// Stesso core finto della selezione multipla: INBOX con "Mail 5"…"Mail 1" (UID 5–1, da leggere),
// Archivio, Posta eliminata con "Vecchia 9" e "Vecchia 8"; qui anche le cartelle passate a start.
import 'multi_select_test.dart' as ms;

Finder folderRow(String folder) => find.byKey(ValueKey('folder:a1:$folder'));
Finder favoriteRow(String folder) => find.byKey(ValueKey('favorite:a1:$folder'));
Finder accountRow() => find.descendant(of: find.byType(FolderPane), matching: find.text('io@example.com'));

/// Trascina con il mouse da [from] a [to]; con [control] Ctrl resta premuto durante il rilascio.
Future<void> drag(WidgetTester tester, Finder from, Finder to, {bool control = false}) async {
  final gesture = await tester.startGesture(tester.getCenter(from), kind: PointerDeviceKind.mouse);
  await tester.pump();
  await gesture.moveBy(const Offset(12, 0)); // oltre la soglia: parte il trascinamento
  await tester.pump();
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump();
  await gesture.up();
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

List<FavoriteFolder>? favorites(WidgetTester tester) =>
    tester.element(find.byType(FolderPane)).read<AppSettings>().favorites;

void main() {
  testWidgets('mail trascinata su una cartella: spostata (anche se non era selezionata)', (tester) async {
    final core = await ms.start(tester);

    await drag(tester, find.text('Mail 5'), folderRow('Archivio'));

    expect(core.writes, ['POST /accounts/a1/messages/INBOX/move {"uids":[5],"destination":"Archivio"}']);
    expect(find.text('Mail 5'), findsNothing);
    expect(find.text('1 mail spostate in "Archivio"'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('selezione trascinata con Ctrl: copiate, restano nella lista', (tester) async {
    final core = await ms.start(tester);
    await ms.click(tester, 'Mail 4');
    await ms.click(tester, 'Mail 2', holding: LogicalKeyboardKey.controlLeft);

    await drag(tester, find.text('Mail 2'), favoriteRow('Posta eliminata'), control: true);

    expect(core.writes, ['POST /accounts/a1/messages/INBOX/copy {"uids":[2,4],"destination":"Posta eliminata"}']);
    expect(find.text('Mail 4'), findsOneWidget);
    expect(find.text('Mail 2'), findsOneWidget);
    expect(find.text('2 mail copiate in "Posta eliminata"'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('mail rilasciata sulla sua cartella o sul nome dell\'account: niente', (tester) async {
    final core = await ms.start(tester);

    await drag(tester, find.text('Mail 3'), folderRow('INBOX'));
    await drag(tester, find.text('Mail 3'), accountRow());

    expect(core.writes, isEmpty);
    expect(find.text('Mail 3'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('cartella trascinata dentro un\'altra e poi sul nome dell\'account (in cima)', (tester) async {
    final core = await ms.start(tester, folders: ['Clienti']);

    await drag(tester, folderRow('Clienti'), folderRow('Archivio'));
    expect(core.writes, ['POST /accounts/a1/folders/Clienti/move {"parent":"Archivio"}']);
    expect(folderRow('Archivio/Clienti'), findsOneWidget);
    expect(find.text('Cartella "Clienti" spostata in "Archivio"'), findsOneWidget);

    await drag(tester, folderRow('Archivio/Clienti'), accountRow());
    expect(core.writes.last, 'POST /accounts/a1/folders/Archivio/Clienti/move {"parent":null}');
    expect(folderRow('Clienti'), findsOneWidget);
    await core.sse.close();
  });

  testWidgets('cartelle con ruolo, dentro sé stessa o dove sono già: nessuno spostamento', (tester) async {
    final core = await ms.start(tester, folders: ['Clienti', 'Clienti/Rossi']);

    await drag(tester, folderRow('INBOX'), folderRow('Archivio')); // ruolo
    await drag(tester, folderRow('Clienti'), folderRow('Clienti/Rossi')); // dentro una sua sottocartella
    await drag(tester, folderRow('Clienti/Rossi'), folderRow('Clienti')); // è già lì
    await drag(tester, folderRow('Archivio'), accountRow()); // è già in cima

    expect(core.writes, isEmpty);
    await core.sse.close();
  });

  testWidgets('Preferiti: cartella aggiunta trascinandola, Preferiti riordinati trascinandoli', (tester) async {
    final core = await ms.start(tester);
    expect(favoriteRow('Archivio'), findsNothing);

    await drag(tester, folderRow('Archivio'), find.text('Preferiti'));
    expect(favorites(tester), const [
      FavoriteFolder('a1', 'INBOX'),
      FavoriteFolder('a1', 'Posta eliminata'),
      FavoriteFolder('a1', 'Archivio'),
    ]);
    expect(favoriteRow('Archivio'), findsOneWidget);

    await drag(tester, favoriteRow('Archivio'), favoriteRow('INBOX')); // prende il posto di INBOX
    expect(favorites(tester), const [
      FavoriteFolder('a1', 'Archivio'),
      FavoriteFolder('a1', 'INBOX'),
      FavoriteFolder('a1', 'Posta eliminata'),
    ]);
    await drag(tester, favoriteRow('Archivio'), favoriteRow('Posta eliminata')); // verso il basso: dopo
    expect(favorites(tester), const [
      FavoriteFolder('a1', 'INBOX'),
      FavoriteFolder('a1', 'Posta eliminata'),
      FavoriteFolder('a1', 'Archivio'),
    ]);

    // Nessuna modifica sul server: i Preferiti stanno solo su questo computer.
    expect(core.writes, isEmpty);
    await core.sse.close();
  });

  testWidgets('con il dito la lista non si trascina (scorre)', (tester) async {
    final core = await ms.start(tester);

    await tester.dragFrom(tester.getCenter(find.text('Mail 5')), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(core.writes, isEmpty);
    await core.sse.close();
  });
}
