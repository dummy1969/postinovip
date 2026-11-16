import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../l10n/language.dart';
import 'package:provider/provider.dart';

import '../state/calendar_model.dart';
import '../state/contacts_model.dart';
import '../state/mailbox_model.dart';
import 'search_box.dart';
import 'theme.dart';

/// Barra in alto della finestra principale, sopra la barra multifunzione, come quella del titolo dell'Outlook
/// classico di oggi (tappa «Aspetto», V2): a sinistra «Invia/ricevi tutte le cartelle» (la barra di accesso rapido),
/// al centro la ricerca della posta. Blu nel tema Colorato, chiara in Bianco, scura nei temi scuri.
/// Nel Calendario e in Persone il centro resta vuoto (Persone ha la sua ricerca sopra l'elenco).
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  static const height = 40.0;

  /// Larghezza massima della casella di ricerca, come in Outlook.
  static const searchWidth = 560.0;

  /// Invia/ricevi: la posta di tutti gli account e, nel Calendario, anche i calendari (come F9).
  static void sendReceive(BuildContext context) {
    context.read<MailboxModel>().refresh();
    if (context.read<ContactsModel>().module == AppModule.calendar) context.read<CalendarModel>().syncNow();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = OfficeChrome.of(context);
    final module = context.watch<ContactsModel>().module;
    final quick = IconButton(
      key: const Key('top-send-receive'),
      tooltip: context.l10n.sendReceiveAllF9,
      iconSize: 20,
      color: chrome.onTitleBar,
      style: IconButton.styleFrom(
        hoverColor: chrome.onTitleBar.withValues(alpha: 0.12),
        highlightColor: chrome.onTitleBar.withValues(alpha: 0.2),
      ),
      icon: const Icon(FluentIcons.arrow_sync_20_regular),
      onPressed: () => sendReceive(context),
    );
    return Container(
      key: const Key('top-bar'),
      height: height,
      color: chrome.titleBar,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          // Stessa larghezza a sinistra e a destra: la ricerca resta al centro della finestra.
          SizedBox(width: 48, child: Align(alignment: Alignment.centerLeft, child: quick)),
          Expanded(
            child: Center(
              child: module == AppModule.mail
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: searchWidth),
                      // La casella ha i colori del tema chiaro o scuro, anche sulla barra blu.
                      child: const MailSearchBox(),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
