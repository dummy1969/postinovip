import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/state/mailbox_model.dart';
import 'package:provider/provider.dart';
import 'package:postinovip/ui/home_page.dart';

import 'multi_select_test.dart' as ms;

// Visualizza (3.9). Core finto della selezione multipla (INBOX "Mail 5"…"Mail 1" da leggere), con le
// richieste delle liste registrate per controllare ordinamento e colonna.
class ViewCore {
  final core = ms.SelectCore();
  final lists = <Uri>[];

  late final client = MockClient.streaming((request, bodyStream) async {
    if (request.url.path.endsWith('/messages') && request.method == 'GET') lists.add(request.url);
    final forward = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = await bodyStream.toBytes();
    return core.client.send(forward);
  });

  /// Ultima richiesta della lista di INBOX.
  Map<String, String> get lastList => lists.last.queryParameters;
}

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<(ViewCore, AppSettings, MemorySettingsStore)> start(
  WidgetTester tester, {
  ReadMode read = ReadMode.manual,
}) async {
  tester.view.physicalSize = const Size(1500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = ViewCore();
  final store = MemorySettingsStore();
  final settings = AppSettings(store)..readMode = read;
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: fake.client),
      settings: settings,
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return (fake, settings, store);
}

/// Visualizza → [command] → [choice].
Future<void> view(WidgetTester tester, String command, String choice) async {
  await tester.tap(find.text('Visualizza'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(command));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MenuItemButton, choice));
  await tester.pumpAndSettle();
}

final columnHeader = find.byKey(const ValueKey('column-header'));
final fullMessage = find.byKey(const ValueKey('message-window'));

void main() {
  testWidgets('riquadro In basso: colonne con le intestazioni; ricordato', (tester) async {
    final (fake, settings, store) = await start(tester);
    expect(columnHeader, findsNothing); // a destra: righe su più righe, come prima

    await view(tester, 'Riquadro di lettura', 'In basso');
    expect(settings.readingPane, ReadingPanePosition.bottom);
    expect(columnHeader, findsOneWidget);
    for (final title in ['Da', 'Oggetto', 'Ricevuto', 'Dimensione', 'Categorie']) {
      expect(find.descendant(of: columnHeader, matching: find.text(title)), findsOneWidget);
    }
    await tester.tap(find.text('Mail 5'));
    await tester.pumpAndSettle();
    expect(find.text('testo'), findsOneWidget); // riquadro di lettura sotto la lista

    final again = AppSettings(store);
    await again.load();
    expect(again.readingPane, ReadingPanePosition.bottom);
    await fake.core.sse.close();
  });

  testWidgets('intestazioni: clic ordina per la colonna, di nuovo inverte; menu "Ordina per"', (tester) async {
    final (fake, _, _) = await start(tester);
    await view(tester, 'Riquadro di lettura', 'In basso');

    await tester.tap(find.descendant(of: columnHeader, matching: find.text('Da')));
    await tester.pumpAndSettle();
    expect(fake.lastList['sort'], 'from');
    expect(fake.lastList['order'], 'asc'); // il testo parte da A → Z
    expect(find.text('Per mittente'), findsOneWidget);

    await tester.tap(find.descendant(of: columnHeader, matching: find.text('Da')));
    await tester.pumpAndSettle();
    expect(fake.lastList['sort'], 'from');
    expect(fake.lastList.containsKey('order'), isFalse); // Z → A
    expect(find.text('Anna'), findsWidgets); // gruppo per mittente

    await tester.tap(find.text('Per mittente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per dimensione: più grandi in cima').last);
    await tester.pumpAndSettle();
    expect(fake.lastList['sort'], 'size');
    expect(find.text('Minuscola (meno di 10 KB)'), findsOneWidget); // dimensione non nota: la fascia più piccola

    await tester.tap(find.descendant(of: columnHeader, matching: find.text('Ricevuto')));
    await tester.pumpAndSettle();
    expect(fake.lastList.containsKey('sort'), isFalse); // per data: predefinito
    await fake.core.sse.close();
  });

  testWidgets('riquadro Disattivato: un clic seleziona (non letta), doppio clic apre a tutta finestra; Esc torna', (
    tester,
  ) async {
    final (fake, _, _) = await start(tester, read: ReadMode.immediately);
    await view(tester, 'Riquadro di lettura', 'Disattivato');

    await tester.tap(find.text('Mail 5'));
    await tester.pumpAndSettle();
    expect(find.text('testo'), findsNothing); // nessun riquadro di lettura
    expect(ms.selected(tester, 'Mail 5'), isTrue);
    expect(fake.core.writes, isEmpty); // non segnata come letta

    await tester.tap(find.text('Mail 5'));
    await tester.tap(find.text('Mail 5'));
    await tester.pumpAndSettle();
    expect(fullMessage, findsOneWidget);
    expect(find.text('testo'), findsOneWidget);
    expect(fake.core.writes.single, 'PUT /accounts/a1/messages/INBOX/5/seen {"seen":true}'); // letta all'apertura

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(fullMessage, findsNothing);
    expect(find.text('Mail 4'), findsOneWidget);

    // Invio apre la mail selezionata.
    await tester.tap(find.text('Mail 4'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400)); // non è un doppio clic
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(fullMessage, findsOneWidget);
    await tester.tap(find.byKey(const Key('message-window-close')));
    await tester.pumpAndSettle();
    expect(fullMessage, findsNothing);
    await fake.core.sse.close();
  });

  testWidgets('finestra della mail (riquadro a destra): doppio clic, frecce, Elimina apre la successiva, File', (
    tester,
  ) async {
    final (fake, _, _) = await start(tester);
    await tester.tap(find.text('Mail 4'));
    await tester.tap(find.text('Mail 4'));
    await tester.pumpAndSettle();
    expect(fullMessage, findsOneWidget);
    expect(find.text('Messaggio'), findsWidgets); // striscia e scheda
    for (final key in ['delete', 'reply', 'replyAll', 'forward', 'zoom', 'previous', 'next', 'file']) {
      expect(find.byKey(Key('message-window-$key')), findsOneWidget, reason: key);
    }

    // ↓ (Ctrl+.) la successiva della lista, ↑ la precedente: la lista dietro segue.
    MailboxModel model() => tester.element(fullMessage).read<MailboxModel>();
    expect(model().selectedUid, 4);
    await tester.tap(find.byKey(const Key('message-window-next')));
    await tester.pumpAndSettle();
    expect(model().selectedUid, 3);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(model().selectedUid, 4);

    // Elimina: in Posta eliminata e si apre la successiva, la finestra resta.
    await tester.tap(find.byKey(const Key('message-window-delete')));
    await tester.pumpAndSettle();
    expect(fake.core.writes.last, startsWith('DELETE /accounts/a1/messages/INBOX/4'));
    expect(fullMessage, findsOneWidget);
    expect(fake.core.mail['INBOX']!.map((m) => m['uid']), isNot(contains(4)));
    expect(model().selectedUid, 3); // la successiva

    // File: Salva con nome, Stampa, Salva come PDF.
    await tester.tap(find.byKey(const Key('message-window-file')));
    await tester.pumpAndSettle();
    for (final item in ['save-eml', 'print', 'pdf']) {
      expect(find.byKey(Key('message-window-file-$item')), findsOneWidget);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // chiude il menu
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // chiude la finestra
    await tester.pumpAndSettle();
    expect(fullMessage, findsNothing);
    await fake.core.sse.close();
  });

  testWidgets('finestra della mail: eliminata l\'unica, si chiude da sola', (tester) async {
    final (fake, _, _) = await start(tester);
    final inbox = fake.core.mail['INBOX']!;
    inbox.removeWhere((m) => m['uid'] != 5);
    await tester.tap(find.text('Posta in arrivo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mail 5'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(fullMessage, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(fullMessage, findsNothing);
    await fake.core.sse.close();
  });

  testWidgets('anteprima: da 0 a 3 righe, ricordata', (tester) async {
    final (fake, settings, store) = await start(tester);
    await view(tester, 'Anteprima messaggio', '3 righe');
    expect(settings.previewLines, 3);
    await view(tester, 'Anteprima messaggio', 'Disattivata');
    expect(settings.previewLines, 0);
    final again = AppSettings(store);
    await again.load();
    expect(again.previewLines, 0);
    await fake.core.sse.close();
  });

  testWidgets('divisori trascinabili: larghezza delle cartelle e quota della lista, salvate al rilascio', (
    tester,
  ) async {
    final (fake, settings, store) = await start(tester);
    final dividers = find.byType(PaneDivider);
    expect(dividers, findsNWidgets(2)); // cartelle | lista | lettura

    final drag = await tester.startGesture(tester.getCenter(dividers.first), kind: PointerDeviceKind.mouse);
    await drag.moveBy(const Offset(60, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(settings.folderPaneWidth, closeTo(AppSettings.defaultFolderWidth + 60, 1));

    final second = await tester.startGesture(tester.getCenter(dividers.last), kind: PointerDeviceKind.mouse);
    await second.moveBy(const Offset(-30, 0));
    await second.moveBy(const Offset(-2000, 0)); // oltre il limite: fermo al minimo
    await second.up();
    await tester.pumpAndSettle();
    expect(settings.listFractionRight, AppSettings.minListFraction);

    final again = AppSettings(store);
    await again.load();
    expect(again.folderPaneWidth, closeTo(AppSettings.defaultFolderWidth + 60, 1));
    expect(again.listFractionRight, AppSettings.minListFraction);
    await fake.core.sse.close();
  });
}
