import 'dart:async';

import 'package:postinovip/state/reminder_model.dart';

/// Eseguito da `flutter test` prima di ogni file di test. I promemoria (K5) leggono i calendari di tutti gli account a
/// ogni avvio dell'app: nei test che non li riguardano sarebbero richieste in più al core finto (e le occorrenze di prova
/// suonerebbero). Li accendono i test dei promemoria (`reminder_test.dart`).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ReminderModel.enabled = false;
  await testMain();
}
