import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/l10n/app_localizations.dart';
import 'package:postinovip/models/mail_folder.dart';

import 'view_test.dart' show start;

// Tappa «Aspetto», V4: riquadro delle cartelle e lista come l'Outlook classico di oggi.

void main() {
  test('«INBOX» si mostra come «Posta in arrivo» («Inbox» in inglese); le altre cartelle tengono il nome del server', () {
    final it = lookupAppLocalizations(const Locale('it'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(const MailFolder(fullName: 'INBOX', name: 'INBOX').displayName(it), 'Posta in arrivo');
    expect(const MailFolder(fullName: 'Inbox', name: 'Inbox').displayName(it), 'Posta in arrivo');
    expect(const MailFolder(fullName: 'INBOX', name: 'INBOX').displayName(en), 'Inbox');
    expect(const MailFolder(fullName: 'INBOX/Clienti', name: 'Clienti').displayName(it), 'Clienti');
    expect(const MailFolder(fullName: 'Deleted Messages', name: 'Deleted Messages').displayName(it), 'Deleted Messages');
    expect(const MailFolder(fullName: 'Posta inviata', name: 'Posta inviata').displayName(en), 'Posta inviata');
  });

  testWidgets('righe delle cartelle alte 32 e staccate dai bordi; «Tutti» e «Da leggere» vicine', (tester) async {
    final (fake, _, _) = await start(tester);
    final row = find.ancestor(of: find.text('Posta in arrivo').last, matching: find.byType(ListTile));
    final rect = tester.getRect(row);
    expect(rect.height, 32);
    final pane = tester.getRect(find.byKey(const Key('module-bar')));
    expect(rect.left, greaterThan(pane.right + 4)); // staccata dal bordo sinistro del riquadro
    expect(tester.widget<ListTile>(row).selected, isTrue);

    final all = tester.getRect(find.text('Tutti'));
    final unread = tester.getRect(find.text('Da leggere'));
    expect(unread.left - all.right, 16); // solo i margini delle due schede (prima si allontanavano)
    await fake.core.sse.close();
  });
}
