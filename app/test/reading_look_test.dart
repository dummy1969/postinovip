import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/models/attachment_info.dart';
import 'package:postinovip/models/message_detail.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/attachment_previews.dart';
import 'package:postinovip/ui/reading_pane.dart';
import 'package:postinovip/ui/sender_avatar.dart';
import 'package:postinovip/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:postinovip/main.dart' show appLocalizationsDelegates;
import 'package:postinovip/l10n/app_localizations.dart';

// Tappa «Aspetto», V5: riquadro di lettura come l'Outlook classico di oggi.

void main() {
  test('mittente diviso in nome e indirizzo', () {
    expect(splitSender('Marta Conti <marta@x.it>'), (name: 'Marta Conti', address: 'marta@x.it'));
    expect(splitSender('"Conti, Marta" <marta@x.it>'), (name: 'Conti, Marta', address: 'marta@x.it'));
    expect(splitSender('marta@x.it'), (name: 'marta@x.it', address: 'marta@x.it'));
    expect(splitSender('<marta@x.it>'), (name: 'marta@x.it', address: 'marta@x.it'));
  });

  test('iniziali come Outlook', () {
    expect(senderInitials('Marta Conti'), 'MC');
    expect(senderInitials('marta conti rossi'), 'MC');
    expect(senderInitials('Conti, Marta'), 'CM');
    expect(senderInitials('Niccolò'), 'N');
    expect(senderInitials('laura.bianchi@studiolumen.example'), 'L');
    expect(senderInitials('Élodie Ünal'), 'ÉÜ');
    expect(senderInitials('— !'), '');
  });

  test('colore: stesso indirizzo, stesso colore (senza distinguere maiuscole)', () {
    expect(SenderAvatar.colorIndex('Marta@X.it'), SenderAvatar.colorIndex('marta@x.it'));
    final all = {
      for (final a in ['a@x.it', 'b@x.it', 'c@x.it', 'd@x.it', 'e@x.it', 'f@x.it']) SenderAvatar.colorIndex(a),
    };
    expect(all.length, greaterThan(1));
  });

  test('tipo dell\'allegato sotto il nome', () {
    AttachmentInfo a(String name, String type) => AttachmentInfo(index: 0, fileName: name, contentType: type);
    expect(AttachmentCard.kindOf(a('note.txt', 'text/plain')), 'TXT');
    expect(AttachmentCard.kindOf(a('Fattura.Nov.PDF', 'application/pdf')), 'PDF');
    expect(AttachmentCard.kindOf(a('senza-estensione', 'application/octet-stream')), 'File');
    expect(AttachmentCard.kindOf(a('inoltro.eml', 'message/rfc822')), 'Mail');
    expect(AttachmentCard.kindOf(a('.bashrc', 'text/plain')), 'File');
  });

  testWidgets('intestazione: cerchio con le iniziali, nome senza «Da:», data a destra, allegati come schede', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = <int>[];
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettings(MemorySettingsStore()),
        child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
          theme: OfficeTheme.light(),
          home: Scaffold(
            body: MessageView(
              MessageDetail(
                uid: 1,
                subject: 'Bozze',
                from: 'Marta Conti <marta@x.it>',
                to: const ['Laura <laura@x.it>'],
                cc: const [],
                date: DateTime(2026, 11, 12, 9, 42),
                textBody: 'ciao',
                htmlBody: null,
                hasRemoteImages: false,
                attachments: const [AttachmentInfo(index: 3, fileName: 'note.txt', contentType: 'text/plain')],
              ),
              attachmentBytes: (i) async {
                saved.add(i);
                return Uint8List(0);
              },
              attachmentUrl: (_) => '',
              attachmentHeaders: const {},
              onReply: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('sender-avatar')), matching: find.text('MC')), findsOneWidget);
    final from = tester.widget<SelectableText>(find.byKey(const Key('reading-from')));
    expect(from.textSpan!.toPlainText(), 'Marta Conti  <marta@x.it>');
    final date = tester.getRect(find.byKey(const Key('reading-date')));
    expect(date.right, greaterThan(800)); // a destra
    expect(tester.widget<Text>(find.byKey(const Key('reading-date'))).data, 'gio 12/11/2026 09:42');
    final card = find.byKey(const Key('attachment-save-3'));
    expect(find.descendant(of: card, matching: find.text('note.txt')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('TXT')), findsOneWidget);
  });
}
