import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/l10n/app_localizations.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/attachments/file_saver.dart';
import 'package:postinovip/ui/eml_view.dart';
import 'package:postinovip/l10n/core_errors.dart';
import 'package:postinovip/l10n/formats.dart';
import 'package:postinovip/models/calendar.dart';
import 'package:postinovip/l10n/language.dart';
import 'package:postinovip/print/message_pdf.dart';
import 'package:postinovip/ui/format.dart';
import 'package:postinovip/settings/app_settings.dart';

import 'view_test.dart' show start;

// Tappa «Lingua», L1: traduzioni (lib/l10n/*.arb), scelta della lingua in File → Opzioni → Generale (scelta 1a).

Map<String, dynamic> _arb(String name) => jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

/// Lingue tradotte dall'italiano (il modello).
const _translations = ['en', 'es', 'fr', 'de'];

Iterable<String> _messages(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@'));

/// Nomi tra graffe di un testo ICU, senza i casi dei plurali (`=1{...}`, `other{...}`).
Set<String> _placeholders(String text) =>
    RegExp(r'(?<!=\d)(?<!other)(?<!one)(?<!few)(?<!many)(?<!zero)(?<!two)\{(\w+)[,}]').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  for (final lang in _translations) {
  test('app_$lang.arb ha tutti i testi di app_it.arb (e niente in più), con gli stessi segnaposto', () {
    final it = _arb('app_it.arb');
    final en = _arb('app_$lang.arb');
    expect(_messages(en).toSet(), _messages(it).toSet());
    for (final key in _messages(it)) {
      expect((en[key] as String).trim(), isNotEmpty, reason: key);
      expect(_placeholders(en[key] as String), _placeholders(it[key] as String), reason: key);
      // Caselle dentro le frasi (fillTemplate, finestra della ricorrenza): stessi nomi tra parentesi quadre.
      Set<String> boxes(String text) => RegExp(r'\[(\w+)\]').allMatches(text).map((m) => m.group(1)!).toSet();
      expect(boxes(en[key] as String), boxes(it[key] as String), reason: key);
      expect(it.containsKey('@$key'), isTrue, reason: 'descrizione «@$key» mancante in app_it.arb');
    }
  });
  }

  test('codice generato aggiornato: dopo una modifica ai file .arb serve «flutter gen-l10n»', () {
    final generated = {
      'it': File('lib/l10n/app_localizations_it.dart').readAsStringSync(),
      for (final lang in _translations) lang: File('lib/l10n/app_localizations_$lang.dart').readAsStringSync(),
    };
    for (final MapEntry(key: lang, value: code) in generated.entries) {
      final arb = _arb('app_$lang.arb');
      final plain = code.replaceAll(r'\', ''); // senza le «\» del generatore (\' \" \n \$)
      for (final key in _messages(arb)) {
        expect(code, contains(' $key'), reason: '$lang: $key');
        final text = arb[key] as String;
        // I testi senza segnaposto finiscono interi nel codice, a meno delle «\» (un a capo diventa «n»).
        if (!text.contains('{')) {
          expect(plain, contains(text.replaceAll('\n', 'n').replaceAll(r'\', '')), reason: '$lang: $key');
        }
      }
    }
  });

  test('avvisi del modello (L4e): plurali nelle due lingue', () {
    final it = lookupAppLocalizations(const Locale('it'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(it.mailsArchived(1), '1 mail archiviata');
    expect(it.mailsArchived(3), '3 mail archiviate');
    expect(en.mailsArchived(1), '1 message archived');
    expect(en.mailsMovedToTrash(2), '2 messages moved to Deleted Items');
    expect(it.folderEmptied('Posta eliminata', it.emptiedMails(1), it.emptiedFolders(2)),
        '"Posta eliminata" svuotata: 1 mail eliminata e 2 cartelle definitivamente');
    expect(en.folderEmptied('Deleted Items', en.emptiedMails(4), ''), '"Deleted Items" emptied: 4 messages permanently deleted');
    expect(it.cleanUpDone(0), 'Nessuna mail superflua da spostare');
    expect(en.addedToSafeSenders(2, 'a@x.it, b@y.it'), 'a@x.it, b@y.it added to Safe Senders');
    expect(it.addedToSafeSenders(1, 'a@x.it'), 'a@x.it aggiunto tra i mittenti attendibili');
  });

  test('date e dimensioni (L5a) nelle due lingue', () {
    final now = DateTime(2026, 10, 29, 12); // giovedì
    expect(formatListDate(DateTime(2026, 10, 26, 8, 30), now: now), 'lun 08:30');
    expect(formatSendAfter(DateTime(2026, 11, 5, 8, 30)), 'gio 05/11/2026 08:30');
    expect(listGroupLabel(DateTime(2026, 10, 27), now: now), 'Martedì');
    expect(formatMailSize((1.4 * 1024 * 1024).round()), '1,4 MB');
    setFormatLanguage(lookupAppLocalizations(const Locale('en')));
    expect(formatListDate(DateTime(2026, 10, 29, 14, 5), now: now), '2:05 PM');
    expect(formatListDate(DateTime(2026, 10, 26, 8, 30), now: now), 'Mon 8:30 AM');
    expect(formatListDate(DateTime(2026, 3, 1), now: now), '3/1');
    expect(formatListDate(DateTime(2025, 12, 31), now: now), '12/31/2025');
    expect(formatSendAfter(DateTime(2026, 11, 5, 8, 30)), 'Thu 11/5/2026 8:30 AM');
    expect(listGroupLabel(DateTime(2026, 10, 27), now: now), 'Tuesday');
    expect(listGroupLabel(DateTime(2026, 10, 28), now: now), 'Yesterday');
    expect(formatMailSize((1.4 * 1024 * 1024).round()), '1.4 MB');
    expect(MessagePdf.formatPrintDate(DateTime(2026, 11, 9, 10, 5)), 'Monday, November 9, 2026 10:05 AM');
  });

  test('date del calendario (L5b) nelle due lingue', () {
    expect(formatDayRange(DateTime(2026, 11, 30), DateTime(2026, 12, 4)), '30 novembre – 4 dicembre 2026');
    expect(const CalendarRecurrence(frequency: 'yearly', week: 2, days: ['TU'], month: 11).describe(),
        'Ogni anno il secondo martedì di novembre');
    setFormatLanguage(lookupAppLocalizations(const Locale('en')));
    expect(formatDayRange(DateTime(2026, 11, 9), DateTime(2026, 11, 13)), 'November 9 – 13, 2026');
    expect(formatDayRange(DateTime(2026, 11, 30), DateTime(2026, 12, 4)), 'November 30 – December 4, 2026');
    expect(formatDayRange(DateTime(2026, 12, 28), DateTime(2027, 1, 1)), 'December 28, 2026 – January 1, 2027');
    expect(formatFullDate(DateTime(2026, 11, 11)), 'Wednesday, November 11, 2026');
    expect(formatMonthYear(DateTime(2026, 11)), 'November 2026');
    expect(formatHour(8), '8 AM');
    expect(formatMinutes(17 * 60 + 30), '5:30 PM');
    expect(const CalendarRecurrence(frequency: 'daily', interval: 2, until: '2026-12-31').describe(), 'Every 2 days, until 12/31/2026');
    expect(const CalendarRecurrence(frequency: 'monthly', week: 2, days: ['TU']).describe(), 'Every month on the second Tuesday');
    expect(const CalendarRecurrence(frequency: 'monthly', monthDay: 15, count: 6).describe(), 'Every month on day 15, 6 times');
    expect(const CalendarRecurrence(frequency: 'yearly', monthDay: 25, month: 12).describe(), 'Every year on December 25');
    expect(const CalendarRecurrence(frequency: 'weekly', interval: 2, days: ['MO', 'WE']).describe(), 'Every 2 weeks on Monday, Wednesday');
    expect(const CalendarRecurrence(frequency: 'yearly', week: -1, days: ['FR'], month: 3).describe(), 'Every year on the last Friday of March');
  });

  test('errori del core (L6a): tipo e codice tradotti, testo del core se il codice non è noto', () {
    const offline = ApiException('Non connesso: Server non raggiungibile (x).', statusCode: 503, kind: 'offline',
        code: 'serverUnreachable', args: {'reason': 'x'}, title: 'Non connesso', detail: 'Server non raggiungibile (x).');
    const unknown = ApiException('Non trovato: Cartella sparita.', statusCode: 404, kind: 'notFound', code: 'boh',
        title: 'Non trovato', detail: 'Cartella sparita.');
    expect(offline.message, 'Non connesso: Server non raggiungibile (x).');
    expect(certificateProblemsText('nameMismatch,untrustedRoot', 'mail.example.com'),
        "intestato a un nome diverso da mail.example.com, non firmato da un'autorità riconosciuta (es. autofirmato)");
    setFormatLanguage(lookupAppLocalizations(const Locale('en')));
    expect(offline.message, 'Not connected: Server not reachable (x).');
    expect(unknown.message, 'Not found: Cartella sparita.');
    expect(coreErrorText('testNoAnswer', {'address': 'mail.example.com:993', 'seconds': '20'}, null),
        'No answer from mail.example.com:993 within 20 s: wrong server, port or encryption?');
    expect(const ApiException('vecchio formato').message, 'vecchio formato');
  });

  test('errori del core convertiti in L6c: testo tradotto, nomi dei server DAV compresi', () {
    final code = 'nessunaDelleMailIndicateIn';
    final it = coreErrorText(code, {'folder': 'Fatture'}, null)!;
    expect(it, contains('Fatture'));
    setFormatLanguage(lookupAppLocalizations(const Locale('en')));
    expect(coreErrorText(code, {'folder': 'Fatture'}, null), isNot(it));
    expect(coreErrorText('troppiReindirizzamentiDal', {'serverLabel': 'server dei contatti'}, null),
        'Too many redirects from the contacts server.');
  });

  test('contorno (L7): nomi proposti per i file e intestazioni della stampa', () {
    expect(safeFileName(''), 'allegato');
    expect(EmlActions.fileName(' '), 'messaggio.eml');
    setFormatLanguage(lookupAppLocalizations(const Locale('en')));
    expect(safeFileName(''), 'attachment');
    expect(EmlActions.fileName(' '), 'message.eml');
  });

  test('lingua del sistema: la prima che l\'app ha, altrimenti inglese', () {
    expect(resolveLocale(const [Locale('it', 'CH')]), const Locale('it'));
    expect(resolveLocale(const [Locale('en', 'GB')]), const Locale('en'));
    expect(resolveLocale(const [Locale('nl'), Locale('it')]), const Locale('it'));
    expect(resolveLocale(const [Locale('de'), Locale('fr')]), const Locale('de'));
    expect(resolveLocale(const [Locale('es', 'MX')]), const Locale('es'));
    expect(resolveLocale(const [Locale('fr', 'CA')]), const Locale('fr'));
    expect(resolveLocale(const [Locale('pt'), Locale('ja')]), const Locale('en'));
    expect(resolveLocale(null), const Locale('en'));
  });

  testWidgets('Opzioni → Generale → Lingua: English cambia subito i testi, si salva e torna in italiano', (tester) async {
    final (fake, settings, store) = await start(tester);
    expect(settings.language, AppLanguage.system);
    expect(find.text('Connesso'), findsOneWidget); // sistema dei test: italiano

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('language-choice')));
    await tester.tap(find.byKey(const ValueKey('language-choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(settings.language, AppLanguage.english);
    expect(await store.read('language'), 'english');
    expect(find.text('Options'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Display language'), findsOneWidget);
    // Categorie su una riga e intere, anche quelle più lunghe dell'italiano («Notifications» andava a capo).
    for (final label in ['General', 'Mail', 'Notifications', 'Calendar']) {
      final text = tester.renderObject<RenderParagraph>(find.text(label));
      expect(text.size.width, greaterThanOrEqualTo(text.getMaxIntrinsicWidth(double.infinity) - 0.5), reason: label);
    }
    expect(tester.getSize(find.byKey(const Key('settings-tabs'))).width, greaterThanOrEqualTo(170));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    expect(find.textContaining('Items: '), findsOneWidget);
    // Lista (L2b): filtri e ordinamento sopra la lista.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('By Date'), findsOneWidget);
    // Cartelle (L2c): Preferiti e Posta in arrivo.
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Inbox'), findsWidgets);
    expect(find.text('Posta in arrivo'), findsNothing);

    // Ricaricata dalle impostazioni salvate.
    final reloaded = AppSettings(store);
    await reloaded.load();
    expect(reloaded.language, AppLanguage.english);

    await settings.setLanguage(AppLanguage.italian);
    await tester.pumpAndSettle();
    expect(find.text('Connesso'), findsOneWidget);
    expect(find.textContaining('Elementi: '), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('«Come il sistema» con il sistema in una lingua che l\'app non ha: inglese', (tester) async {
    addTearDown(() => tester.platformDispatcher.localesTestValue = const [Locale('it', 'IT')]);
    tester.platformDispatcher.localesTestValue = const [Locale('pt', 'BR')];
    final (fake, settings, _) = await start(tester);
    expect(settings.language, AppLanguage.system);
    expect(find.text('Connected'), findsOneWidget);
    // Fissata l'italiana, vince sul sistema.
    await settings.setLanguage(AppLanguage.italian);
    await tester.pumpAndSettle();
    expect(find.text('Connesso'), findsOneWidget);
    await fake.core.sse.close();
  });

  // Spagnolo, francese e tedesco (17/11/2026): il sistema in tedesco dà il tedesco, e ogni lingua ha i suoi formati.
  testWidgets('«Come il sistema» con il sistema in tedesco: tedesco', (tester) async {
    addTearDown(() => tester.platformDispatcher.localesTestValue = const [Locale('it', 'IT')]);
    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    final (fake, settings, _) = await start(tester);
    expect(find.text('Verbunden'), findsOneWidget);
    await settings.setLanguage(AppLanguage.french);
    await tester.pumpAndSettle();
    expect(find.text('Connecté'), findsOneWidget);
    await settings.setLanguage(AppLanguage.spanish);
    await tester.pumpAndSettle();
    expect(find.text('Conectado'), findsOneWidget);
    await fake.core.sse.close();
  });

  test('date, plurali ed errori del core in spagnolo, francese e tedesco', () {
    addTearDown(() => setFormatLanguage(lookupAppLocalizations(const Locale('it'))));
    final d = DateTime(2026, 11, 5, 14, 30);
    final es = lookupAppLocalizations(const Locale('es'));
    setFormatLanguage(es);
    expect(formatDate(d), '05/11/2026');
    expect(formatTime(d), '14:30');
    expect(formatFullDate(d), 'jueves, 5 de noviembre de 2026');
    expect(es.mailsArchived(2), '2 mensajes archivados');
    expect(coreErrorText('testUnreachable', const {'address': 'mail.example.com:993'}, null), 'Servidor mail.example.com:993 no accesible.');

    final fr = lookupAppLocalizations(const Locale('fr'));
    setFormatLanguage(fr);
    expect(formatDate(d), '05/11/2026');
    expect(formatFullDate(d), 'jeudi 5 novembre 2026');
    expect(formatMegabytes(1468006), '1,4 MB');
    expect(fr.mailsArchived(1), '1 message archivé');

    final de = lookupAppLocalizations(const Locale('de'));
    setFormatLanguage(de);
    expect(formatDate(d), '05.11.2026');
    expect(formatTime(d), '14:30');
    expect(formatFullDate(d), 'Donnerstag, 5. November 2026');
    expect(formatDayRange(DateTime(2026, 11, 9), DateTime(2026, 11, 13)), '9. – 13. November 2026');
    expect(de.mailsArchived(3), '3 Nachrichten archiviert');
    expect(coreKindText('offline'), 'Keine Verbindung');
  });
}
