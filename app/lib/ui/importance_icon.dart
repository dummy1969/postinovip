import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../models/mail_importance.dart';

/// «!» rosso per la priorità alta, freccia blu in giù per la bassa (P1), come in Outlook; niente per la normale.
class ImportanceIcon extends StatelessWidget {
  const ImportanceIcon(this.importance, {super.key});

  final MailImportance importance;

  static Widget? of(MailImportance importance) =>
      importance == MailImportance.normal ? null : ImportanceIcon(importance, key: Key('importance-${importance.name}'));

  @override
  Widget build(BuildContext context) {
    final high = importance == MailImportance.high;
    return Tooltip(
      message: high ? 'Priorità alta' : 'Priorità bassa',
      child: Icon(
        high ? FluentIcons.important_16_filled : FluentIcons.arrow_down_16_filled,
        size: 14,
        color: high ? const Color(0xFFC50F1F) : const Color(0xFF0F6CBD),
      ),
    );
  }
}
