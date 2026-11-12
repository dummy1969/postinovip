import 'dart:io';

import 'package:flutter/services.dart';

import 'system_notifier.dart';

/// Porta la finestra dell'app in primo piano (clic sulla notifica di nuova posta).
abstract interface class WindowPresenter {
  Future<void> present();
}

/// Chiede al codice nativo del runner di mostrare la finestra (Linux: linux/runner/my_application.cc;
/// Windows: windows/runner/flutter_window.cpp). Dart da solo non può farlo: serve il sistema di
/// finestre (GTK, Win32, Cocoa).
class NativeWindowPresenter implements WindowPresenter {
  static const _channel = MethodChannel('com.dumm1969.postinovip/window');

  /// Non lancia mai: se non riesce, la mail viene comunque aperta nella finestra.
  @override
  Future<void> present() async {
    try {
      // Linux non restituisce nulla; Windows "foreground" oppure "flash" se il sistema ha negato il
      // primo piano e l'icona lampeggia nella barra delle applicazioni.
      final how = await _channel.invokeMethod<String>('present');
      notifyLog(
        how == 'flash'
            ? 'primo piano negato da Windows: l\'icona lampeggia nella barra delle applicazioni'
            : 'finestra portata in primo piano',
      );
    } on MissingPluginException {
      // Runner senza il canale (per ora macOS).
      notifyLog('primo piano non disponibile su ${Platform.operatingSystem}');
    } on PlatformException catch (e) {
      notifyLog('primo piano non riuscito: ${e.message}');
    }
  }
}
