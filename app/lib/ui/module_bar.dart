import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/app_settings.dart';
import '../state/calendar_model.dart';
import '../state/contacts_model.dart';
import '../state/mailbox_model.dart';
import 'theme.dart';

/// Barra dei moduli: Posta (Ctrl+1), Calendario (Ctrl+2), Persone (Ctrl+3). Dove sta lo sceglie l'utente in
/// File → Opzioni → Generale (scelta 1c del 12/11/2026):
/// - a sinistra (predefinita), verticale sotto la barra multifunzione, come l'Outlook classico di oggi (tappa
///   «Aspetto», V2): il modulo aperto ha l'icona piena in blu, una barretta blu a sinistra e un fondo leggero;
/// - in basso, orizzontale in fondo al riquadro di sinistra di ogni modulo, come Outlook 2016/2019 (prima del V2):
///   il modulo aperto ha l'icona piena in blu e una riga blu sotto.
class ModuleBar extends StatelessWidget {
  const ModuleBar({super.key, this.bottom = false});

  /// Barra orizzontale in fondo al riquadro di sinistra invece di quella verticale.
  final bool bottom;

  /// Larghezza della barra verticale.
  static const width = 48.0;

  /// Altezza della barra in basso.
  static const bottomHeight = 40.0;

  /// La barra in basso, da mettere in fondo alla colonna del riquadro di sinistra di un modulo; vuota se la barra
  /// è a sinistra.
  static List<Widget> bottomOf(BuildContext context) =>
      context.watch<AppSettings>().moduleBar == ModuleBarPosition.bottom ? const [ModuleBar(bottom: true)] : const [];

  /// Passa a [module]; entrando in Persone la prima volta si apre la rubrica dell'account della posta.
  static void show(BuildContext context, AppModule module) {
    final mail = context.read<MailboxModel>();
    final calendar = context.read<CalendarModel>();
    if (module == AppModule.calendar) {
      calendar.activate(mail.accounts);
    } else {
      calendar.deactivate();
    }
    context.read<ContactsModel>().showModule(
      module,
      defaultBook: mail.selectedAccount ?? mail.accounts.firstOrNull?.id,
      cardDavAccounts: [for (final a in mail.accounts) if (a.cardDav) a.id],
    );
  }

  /// Suggerimento a destra dell'icona, centrato in altezza (nella barra verticale sopra o sotto coprirebbe le
  /// icone vicine); a sinistra se a destra non c'è spazio.
  static Offset _beside(TooltipPositionContext c) {
    const gap = 8.0;
    var x = c.target.dx + c.targetSize.width / 2 + gap;
    if (x + c.tooltipSize.width > c.overlaySize.width) x = c.target.dx - c.targetSize.width / 2 - gap - c.tooltipSize.width;
    final y = (c.target.dy - c.tooltipSize.height / 2).clamp(0.0, c.overlaySize.height - c.tooltipSize.height);
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = context.watch<ContactsModel>().module;
    Widget item(AppModule module, String label, IconData regular, IconData filled) {
      final active = current == module;
      final icon = Icon(active ? filled : regular, size: bottom ? 22 : 24, color: active ? scheme.primary : scheme.onSurfaceVariant);
      if (bottom) {
        return Tooltip(
          message: label,
          child: InkWell(
            key: Key('module-${module.name}'),
            onTap: () => show(context, module),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: active ? scheme.primary : Colors.transparent, width: 2)),
              ),
              child: icon,
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Tooltip(
          message: label,
          positionDelegate: _beside,
          child: Material(
            color: active ? scheme.onSurface.withValues(alpha: 0.06) : Colors.transparent,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(OfficeTheme.radius))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('module-${module.name}'),
              onTap: () => show(context, module),
              child: SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    icon,
                    if (active)
                      Positioned(
                        left: 0,
                        top: 10,
                        bottom: 10,
                        child: Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: const BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final items = [
      item(AppModule.mail, 'Posta (Ctrl+1)', FluentIcons.mail_24_regular, FluentIcons.mail_24_filled),
      item(AppModule.calendar, 'Calendario (Ctrl+2)', FluentIcons.calendar_ltr_24_regular, FluentIcons.calendar_ltr_24_filled),
      item(AppModule.people, 'Persone (Ctrl+3)', FluentIcons.people_24_regular, FluentIcons.people_24_filled),
    ];

    if (bottom) {
      return Container(
        key: const Key('module-bar'),
        height: bottomHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
        child: Row(children: [for (final (i, w) in items.indexed) ...[if (i > 0) const SizedBox(width: 4), w]]),
      );
    }

    return Container(
      key: const Key('module-bar'),
      width: width,
      padding: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      // Scorre se la finestra è più bassa delle icone (non succede da 640×480 in su, ma non deve traboccare).
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
      ),
    );
  }
}
