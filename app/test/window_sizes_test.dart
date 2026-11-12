import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/state/mailbox_model.dart';
import 'package:postinovip/ui/home_page.dart';
import 'package:postinovip/ui/message_window.dart';
import 'package:provider/provider.dart';

import 'message_list_test.dart' as ml;

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

/// Finestre piccole (09/11/2026): dalla minima (640x480, fissata nei programmi nativi di Linux e Windows) in su, con
/// il riquadro di lettura nelle tre posizioni, né la finestra principale né quella della mail né la composizione
/// traboccano (prima: barra di ricerca, filtri sopra la lista, date della lista, schede della barra).
void main() {
  for (final pane in ReadingPanePosition.values) {
    for (final size in const [Size(640, 480), Size(800, 500)]) {
      testWidgets('nessun trabocco: riquadro ${pane.name}, ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final core = ml.ListCore();
        final settings = AppSettings(MemorySettingsStore())
          ..readingPane = pane
          ..readMode = ReadMode.manual; // il core finto non ha «segna come letto»
        await tester.pumpWidget(
          PostinoVipApp(api: ApiClient(httpClient: core.client), settings: settings, windowPresenter: _NoWindow()),
        );
        await tester.pumpAndSettle();
        // Un trabocco arriva qui come eccezione del disegno («A RenderFlex overflowed…»).
        void noOverflow(String where) => expect(tester.takeException(), isNull, reason: where);
        noOverflow('lista');

        // Selezione e apertura dal modello: con il riquadro in basso e la finestra minima la lista è bassa e la riga
        // può essere quasi coperta (non è un trabocco).
        final home = tester.element(find.byType(HomePage));
        await home.read<MailboxModel>().selectMessage(2);
        await tester.pumpAndSettle();
        noOverflow('riquadro di lettura');
        unawaited(openMessageWindow(home));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('message-window')), findsOneWidget);
        noOverflow('finestra della mail');
        Navigator.of(tester.element(find.byKey(const ValueKey('message-window')))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nuovo messaggio').first); // composizione
        await tester.pumpAndSettle();

        noOverflow('composizione');
        await core.sse.close();
      });
    }
  }
}
