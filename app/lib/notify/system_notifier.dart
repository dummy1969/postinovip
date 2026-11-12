import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Mostra una notifica di sistema (popup del desktop) e segnala i clic su di essa.
abstract interface class MailNotifier {
  /// [payload] torna indietro su [clicks] quando l'utente clicca la notifica.
  Future<void> show(String title, String body, {String? payload});

  /// Un evento per ogni clic su una notifica, con il suo payload (null se non indicato).
  Stream<String?> get clicks;
}

/// Riga diagnostica nel terminale ("[notifiche] ..."). Mai mittente, oggetto o testo delle mail.
void notifyLog(String message) => debugPrint('[notifiche] $message');

/// Notifiche tramite flutter_local_notifications (Linux: specifica Desktop Notifications via D-Bus;
/// Windows: toast, che richiedono nome app, AppUserModelId e GUID).
class SystemNotifier implements MailNotifier {
  SystemNotifier._(this._plugin, this._clicks);

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String?> _clicks;
  int _nextId = 1;

  @override
  Stream<String?> get clicks => _clicks.stream;

  /// null se la piattaforma non è supportata o l'inizializzazione fallisce: l'app funziona lo stesso,
  /// ma il motivo viene scritto nel terminale.
  static Future<SystemNotifier?> create() async {
    if (!(Platform.isLinux || Platform.isWindows)) {
      notifyLog('non disponibili su ${Platform.operatingSystem}');
      return null;
    }
    final plugin = FlutterLocalNotificationsPlugin();
    // Broadcast: dopo un riavvio del core l'app si iscrive di nuovo allo stesso notifier.
    final clicks = StreamController<String?>.broadcast();
    try {
      final ok = await plugin.initialize(
        settings: const InitializationSettings(
          // Azione predefinita: per la specifica freedesktop è il clic sul corpo della notifica; su Xfce
          // invece è il pulsante "Apri mail" (il clic sul corpo chiude soltanto: verificato con dbus-monitor).
          linux: LinuxInitializationSettings(defaultActionName: 'Apri mail'),
          windows: WindowsInitializationSettings(
            appName: 'PostinoVip',
            appUserModelId: 'Dumm1969.PostinoVip',
            guid: '37423cc0-f2cf-4175-a8bf-7870e7cd5491', // fisso: identifica l'app nelle notifiche di Windows
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          notifyLog('clic sulla notifica ${response.id}');
          clicks.add(response.payload);
        },
      );
      if (ok == false) {
        notifyLog('inizializzazione rifiutata dal plugin: notifiche disattivate');
        return null;
      }
      notifyLog('pronte (initialize = $ok)');
      return SystemNotifier._(plugin, clicks);
    } on Object catch (e) {
      notifyLog('inizializzazione fallita: notifiche disattivate ($e)');
      return null;
    }
  }

  @override
  Future<void> show(String title, String body, {String? payload}) async {
    final id = _nextId++;
    try {
      await _plugin.show(id: id, title: title, body: body, payload: payload);
      notifyLog('mostrata (id $id)');
    } on Object catch (e) {
      notifyLog('errore nel mostrare la notifica $id: $e');
      rethrow;
    }
  }
}
