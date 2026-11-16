import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/language.dart';
import '../models/send_result.dart';
import '../state/mailbox_model.dart';
import 'format.dart';

/// Posta in uscita (3.8): mail sul computer in attesa di invio (senza connessione o con "Ritarda recapito").
/// Partono da sole con l'app aperta; per ognuna Invia ora, Sposta in Bozze (per modificarla), Elimina.
class OutboxView extends StatelessWidget {
  const OutboxView({super.key});

  static const listKey = ValueKey('outbox-list');

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final theme = Theme.of(context);
    final items = model.outboxItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            context.l10n.outboxHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(context.l10n.outboxEmpty))
              : ListView.separated(
                  key: listKey,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _OutboxTile(account: model.selectedAccount!, entry: items[i]),
                ),
        ),
      ],
    );
  }
}

class _OutboxTile extends StatelessWidget {
  const _OutboxTile({required this.account, required this.entry});

  final String account;
  final OutboxEntry entry;

  Future<void> _run(
    BuildContext context,
    Future<({bool ok, String message})> Function(MailboxModel model) action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await action(context.read<MailboxModel>());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteOutboxQuestion),
        content: Text(context.l10n.deleteOutboxContent(entry.subject.isEmpty ? context.l10n.noSubject : entry.subject)),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.delete)),
        ],
      ),
    );
    if (ok == true && context.mounted) await _run(context, (m) => m.outboxDelete(account, entry.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final model = context.watch<MailboxModel>();
    final online = model.isOnline(account);
    final status = entry.error != null
        ? context.l10n.outboxNotSent('${entry.error}')
        : entry.sendAfter != null && entry.sendAfter!.isAfter(DateTime.now())
        ? context.l10n.outboxSendAfter(formatSendAfter(entry.sendAfter!))
        : online
        ? context.l10n.sending
        : context.l10n.outboxWaiting;
    return ListTile(
      key: ValueKey('outbox-item:${entry.id}'),
      title: Text(entry.to.isEmpty ? context.l10n.noRecipients : entry.to.join(', '), overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.subject.isEmpty ? context.l10n.noSubject : entry.subject, overflow: TextOverflow.ellipsis),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: entry.error != null ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.l10n.sendNow,
            icon: const Icon(FluentIcons.send_20_regular),
            onPressed: () => _run(context, (m) => m.outboxSendNow(account, entry.id)),
          ),
          IconButton(
            tooltip: online ? context.l10n.moveToDrafts : context.l10n.offlineUnavailable,
            icon: const Icon(FluentIcons.document_edit_20_regular),
            onPressed: online ? () => _run(context, (m) => m.outboxToDrafts(account, entry.id)) : null,
          ),
          IconButton(
            tooltip: context.l10n.deleteOutboxTooltip,
            icon: const Icon(FluentIcons.delete_20_regular),
            onPressed: () => _delete(context),
          ),
        ],
      ),
    );
  }
}
