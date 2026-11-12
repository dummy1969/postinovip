import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../models/message_header.dart';
import '../settings/app_settings.dart';
import 'system_notifier.dart';

/// Cosa aprire quando si clicca la notifica: account, cartella e, se la mail nuova era una sola, il messaggio.
/// Viaggia come payload della notifica (testo JSON: solo id dell'account, cartella e UID, mai contenuti).
class NotificationTarget {
  const NotificationTarget(this.account, this.folder, [this.uid]);

  /// Null nelle notifiche di una versione precedente al multi-account (= primo account).
  final String? account;
  final String folder;
  final int? uid;

  String encode() => jsonEncode({'account': ?account, 'folder': folder, 'uid': ?uid});

  /// null se il payload manca (es. "Prova notifica") o non è nel formato atteso.
  static NotificationTarget? decode(String? payload) {
    if (payload == null) return null;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      return NotificationTarget(json['account'] as String?, json['folder'] as String, json['uid'] as int?);
    } on Object {
      return null;
    }
  }
}

/// Decide se e come notificare la nuova posta, secondo l'impostazione scelta dall'utente.
class NewMailNotifications {
  NewMailNotifications({required this.settings, required this.notifier, bool Function()? isWindowFocused})
    : _isWindowFocused = isWindowFocused ?? _focusedFromLifecycle;

  final AppSettings settings;
  final MailNotifier notifier;
  final bool Function() _isWindowFocused;

  // Sul desktop "resumed" = finestra con il focus; "inactive" = visibile ma senza focus
  // (da verificare in pratica su Linux e Windows: la documentazione non lo dice esplicitamente).
  static bool _focusedFromLifecycle() => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// Non lancia mai: un problema delle notifiche non deve interrompere l'aggiornamento della lista.
  /// [newMail] arriva sempre da INBOX di [account] (vedi MailboxModel); [accountLabel], se presente
  /// (più account), finisce nel titolo.
  Future<void> handle(List<MessageHeader> newMail, {required String account, String? accountLabel}) async {
    const folder = 'INBOX';
    if (newMail.isEmpty) return;
    final focused = _isWindowFocused();
    final mode = settings.notifyMode;
    if (mode == NotifyMode.never || (mode == NotifyMode.unfocused && focused)) {
      notifyLog(
        '$account: ${newMail.length} nuove, notifica saltata (opzione "${mode.label}", finestra in primo piano: $focused)',
      );
      return;
    }
    final suffix = accountLabel == null ? '' : ' · $accountLabel';
    notifyLog(
      '$account: ${newMail.length} nuove, notifica (opzione "${mode.label}", finestra in primo piano: $focused, '
      'stato: ${WidgetsBinding.instance.lifecycleState?.name})',
    );

    try {
      if (newMail.length == 1) {
        final m = newMail.single;
        await notifier.show(
          'Nuova mail da ${m.from}$suffix',
          m.subject,
          payload: NotificationTarget(account, folder, m.uid).encode(),
        );
      } else {
        final preview = newMail.take(3).map((m) => '${m.from}: ${m.subject}').join('\n');
        final more = newMail.length > 3 ? '\n…e altre ${newMail.length - 3}' : '';
        await notifier.show(
          '${newMail.length} nuove mail$suffix',
          '$preview$more',
          payload: NotificationTarget(account, folder).encode(),
        );
      }
    } on Object {
      // Già registrato da SystemNotifier.
    }
  }
}
