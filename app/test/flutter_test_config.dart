import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:postinovip/l10n/app_localizations.dart';
import 'package:postinovip/l10n/formats.dart';
import 'package:postinovip/state/reminder_model.dart';

/// Eseguito da `flutter test` prima di ogni file di test. I promemoria (K5) leggono i calendari di tutti gli account a
/// ogni avvio dell'app: nei test che non li riguardano sarebbero richieste in più al core finto (e le occorrenze di prova
/// suonerebbero). Li accendono i test dei promemoria (`reminder_test.dart`).
///
/// Lingua (tappa «Lingua», L1): il sistema finto dei test è in inglese (en_US), l'app segue il sistema; i test sono
/// scritti sui testi italiani, quindi il «sistema» dei test è italiano. I test della lingua cambiano lingua da sé.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ReminderModel.enabled = false;
  TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.localesTestValue = const [Locale('it', 'IT')];
  // Date (L5): nomi di giorni e mesi anche nei test senza app; ogni test riparte con i formati in italiano.
  await initializeDateFormatting();
  setUp(() => setFormatLanguage(lookupAppLocalizations(const Locale('it'))));
  await testMain();
}
