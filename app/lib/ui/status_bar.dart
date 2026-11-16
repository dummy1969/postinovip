import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/calendar_model.dart';
import '../state/contacts_model.dart';
import '../state/mailbox_model.dart';
import 'people_view.dart';
import 'reading_zoom.dart';

/// Barra di stato in basso, come in Outlook classico: a sinistra elementi e da leggere della
/// cartella (o i risultati della ricerca), a destra lo stato della connessione ("Disconnesso"
/// quando il server di un account non risponde) e, nella Posta, lo zoom del riquadro di lettura.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    final l = AppLocalizations.of(context);
    final offline = model.offlineAccounts;
    final unread = model.selectedFolderInfo?.unread;

    final people = context.watch<ContactsModel>();
    final calendar = context.watch<CalendarModel>();
    final left = people.module == AppModule.calendar
        ? l.statusItems(calendar.visibleOccurrences.length)
        : people.module == AppModule.people
        ? [
            l.statusContacts(people.count),
            if (people.query.isNotEmpty) l.statusFound(people.visible.length),
            ?PeopleActions.syncLabel(l, people.statusOf(people.book))?.text,
          ].join('      ')
        : model.searchActive
        ? l.statusResults(model.searchTotal)
        : model.selectedFolder == null
        ? ''
        : [
            // Il numero della cartella, anche con il filtro "Da leggere" attivo.
            l.statusItems(model.selectedFolderInfo?.count ?? model.total),
            if (unread != null) l.statusUnread(unread),
          ].join('      ');

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(left, style: style, overflow: TextOverflow.ellipsis)),
          // Zoom del riquadro di lettura (P2), solo nella Posta, come Outlook.
          if (people.module == AppModule.mail) ...[const ZoomControl(), const SizedBox(width: 16)],
          if (offline.isEmpty) ...[
            Icon(FluentIcons.plug_connected_16_regular, size: 14, color: style?.color),
            const SizedBox(width: 4),
            Text(l.statusConnected, style: style),
          ] else ...[
            Icon(FluentIcons.plug_disconnected_16_regular, size: 14, color: theme.colorScheme.error),
            const SizedBox(width: 4),
            Text(
              model.multipleAccounts
                  ? l.statusDisconnectedAccounts(offline.map((a) => a.name).join(', '))
                  : l.statusDisconnected,
              style: style?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
