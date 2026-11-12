import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/app_settings.dart';
import 'theme.dart';

// Pezzi della barra multifunzione in stile Office, comuni alla finestra principale (ribbon.dart) e
// alla composizione (compose_page.dart).

/// Barra multifunzione: [leading] (il menu File), le schede con i comandi raggruppati, a destra le «Opzioni di
/// visualizzazione della barra multifunzione» (classica o semplificata, sempre visibile o solo le schede; comprimere
/// anche con Ctrl+F1). Le scelte stanno in AppSettings e valgono per tutte le barre. Compressa mostra solo i nomi
/// delle schede: un clic su una scheda la riapre.
///
/// Aspetto dell'Outlook classico di oggi (tappa «Aspetto», V3): le schede stanno sul fondo della cornice (grigio
/// chiaro nel tema Colorato), «File» è una scheda come le altre, la scheda aperta ha una barretta blu arrotondata
/// sotto il nome; i comandi stanno in un riquadro chiaro con gli angoli arrotondati, staccato dai bordi.
///
/// Semplificata (V3b): lo stesso riquadro alto una riga; i pezzi qui sotto ([RibbonGroup], [RibbonLargeButton],
/// [RibbonSmallColumn], [RibbonSmallButton]) si dispongono da soli in riga leggendo [RibbonStyle].
class RibbonFrame extends StatelessWidget {
  const RibbonFrame({
    super.key,
    this.leading,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.groups,
  });

  final Widget? leading;
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  final List<Widget> groups;

  /// Altezza del riquadro dei comandi (bordo compreso), classica e semplificata.
  static const panelHeight = 94.0;
  static const simplifiedHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final collapsed = settings.ribbonCollapsed;
    final simplified = settings.ribbonLayout == RibbonLayout.simplified;
    final chrome = OfficeChrome.of(context);

    return Material(
      color: chrome.tabBar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('ribbon-tabs'),
            height: 34,
            color: chrome.tabBar,
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                ?leading,
                // Finestra stretta: le schede scorrono invece di uscire dalla banda.
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (i, tab) in tabs.indexed)
                          RibbonTabButton(
                            label: tab,
                            selected: i == selected && !collapsed,
                            onPressed: () {
                              onSelect(i);
                              if (collapsed) settings.setRibbonCollapsed(false);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const _DisplayOptions(),
                const SizedBox(width: 4),
              ],
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Container(
                key: const ValueKey('ribbon-panel'),
                height: simplified ? simplifiedHeight : panelHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.all(Radius.circular(OfficeTheme.dialogRadius)),
                  border: Border.all(color: scheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1)),
                  ],
                ),
                child: RibbonStyle(
                  simplified: simplified,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      crossAxisAlignment: simplified ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
                      children: groups,
                    ),
                  ),
                ),
              ),
            ),
          Divider(height: 1, color: scheme.outlineVariant),
        ],
      ),
    );
  }
}

/// Classica o semplificata, per i pezzi della barra sotto [RibbonFrame]. Fuori da una barra vale la classica.
class RibbonStyle extends InheritedWidget {
  const RibbonStyle({super.key, required this.simplified, required super.child});

  final bool simplified;

  static bool simplifiedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RibbonStyle>()?.simplified ?? false;

  @override
  bool updateShouldNotify(RibbonStyle oldWidget) => oldWidget.simplified != simplified;
}

/// «Opzioni di visualizzazione della barra multifunzione», come in Outlook: classica o semplificata, sempre visibile o
/// solo le schede (Ctrl+F1).
class _DisplayOptions extends StatelessWidget {
  const _DisplayOptions();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final chrome = OfficeChrome.of(context);
    Widget item(String text, bool checked, VoidCallback onPressed, {Key? key}) => MenuItemButton(
      key: key,
      leadingIcon: Icon(checked ? Icons.check : null, size: 16),
      onPressed: onPressed,
      child: Text(text),
    );
    return MenuAnchor(
      alignmentOffset: const Offset(-240, 0),
      menuChildren: [
        for (final l in RibbonLayout.values)
          item(
            l.label,
            settings.ribbonLayout == l,
            () => settings.setRibbonLayout(l),
            key: Key('ribbon-layout-${l.name}'),
          ),
        const Divider(height: 8),
        item(
          'Mostra sempre la barra multifunzione',
          !settings.ribbonCollapsed,
          () => settings.setRibbonCollapsed(false),
          key: const Key('ribbon-show-always'),
        ),
        item(
          'Mostra solo le schede (Ctrl+F1)',
          settings.ribbonCollapsed,
          () => settings.setRibbonCollapsed(true),
          key: const Key('ribbon-tabs-only'),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        key: const Key('ribbon-display-options'),
        color: chrome.onTabBar,
        tooltip: 'Opzioni di visualizzazione della barra multifunzione',
        iconSize: 16,
        icon: Icon(settings.ribbonCollapsed ? FluentIcons.chevron_down_20_regular : FluentIcons.chevron_up_20_regular),
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// Nome di una scheda della barra multifunzione: aperta, testo blu in grassetto e barretta blu arrotondata sotto,
/// larga quanto il nome. Usato dalle schede e da «File» (che apre un menu invece di una scheda).
class RibbonTabLabel extends StatelessWidget {
  const RibbonTabLabel({super.key, required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final chrome = OfficeChrome.of(context);
    final text = Theme.of(context).textTheme.bodyMedium!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: text.copyWith(
                    color: selected ? chrome.selectedTab : chrome.onTabBar,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: selected ? chrome.selectedTab : Colors.transparent,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
            const SizedBox(height: 3),
          ],
        ),
      ),
    );
  }
}

class RibbonTabButton extends StatelessWidget {
  const RibbonTabButton({super.key, required this.label, required this.selected, required this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: InkWell(
      onTap: onPressed,
      borderRadius: const BorderRadius.all(Radius.circular(OfficeTheme.radius)),
      child: RibbonTabLabel(label: label, selected: selected),
    ),
  );
}

/// Aspetto di «File» nella banda delle schede (V3: una scheda come le altre, non più un blocco blu); il clic lo
/// gestisce il menu che lo contiene.
class RibbonFileTab extends StatelessWidget {
  const RibbonFileTab({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 3),
    child: RibbonTabLabel(label: 'File'),
  );
}

/// Gruppo di comandi con l'etichetta sotto e un separatore corto a destra, come in Office. Nella barra semplificata
/// i comandi stanno in riga, senza etichetta.
class RibbonGroup extends StatelessWidget {
  const RibbonGroup({super.key, required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final separator = Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 10),
      color: theme.colorScheme.outlineVariant,
    );
    if (RibbonStyle.simplifiedOf(context)) {
      return Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
          SizedBox(height: 32, child: separator),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 3),
          child: Column(
            children: [
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: children),
              ),
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        separator,
      ],
    );
  }
}

/// Comando grande: icona sopra, etichetta sotto (al massimo due righe). Nella barra semplificata icona e etichetta
/// sulla stessa riga.
class RibbonLargeButton extends StatelessWidget {
  const RibbonLargeButton({
    super.key,
    required this.icon,
    required this.label,
    this.tooltip,
    this.onPressed,
    this.enabled,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String? tooltip;

  /// null: disattivato (salvo [enabled], per i pulsanti che fanno da aspetto a un menu).
  final VoidCallback? onPressed;
  final bool? enabled;

  /// Comando a interruttore acceso: fondo e bordo colorati.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final simplified = RibbonStyle.simplifiedOf(context);
    final active = enabled ?? onPressed != null;
    final color = active ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38);
    // Icone grigie a linea sottile (V3), alla loro misura nativa di 24 px (20 nella barra semplificata).
    final iconColor = active ? scheme.onSurfaceVariant : color;
    final decoration = selected
        ? BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(OfficeTheme.radius),
          )
        : null;
    final body = simplified
        ? Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: decoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 6),
                Text(label, maxLines: 1, style: theme.textTheme.bodyMedium!.copyWith(fontSize: 13, color: color)),
              ],
            ),
          )
        : Container(
            // Larghezza secondo l'etichetta, tra 60 e 100 (V6: a 76 fissi «Nuovo appuntamento» andava a capo a metà
            // parola, «appu-ntamento»).
            constraints: const BoxConstraints(minWidth: 60, maxWidth: 100),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: decoration,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: iconColor),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall!.copyWith(fontSize: 12, height: 1.15, color: color),
                ),
              ],
            ),
          );
    final button = onPressed == null && enabled != null
        ? body // il clic lo gestisce il menu che lo contiene
        : InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(OfficeTheme.radius), child: body);
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Comandi piccoli uno sopra l'altro; nella barra semplificata uno accanto all'altro.
class RibbonSmallColumn extends StatelessWidget {
  const RibbonSmallColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => RibbonStyle.simplifiedOf(context)
      ? Row(mainAxisSize: MainAxisSize.min, children: children)
      : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
}

/// Comando piccolo che apre un menu (Categorizza, Completa).
class RibbonMenuButton extends StatelessWidget {
  const RibbonMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.menuChildren,
    required this.enabled,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final List<Widget> menuChildren;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: menuChildren,
    builder: (context, controller, _) => RibbonSmallButton(
      icon: icon,
      label: label,
      tooltip: tooltip,
      onPressed: enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
    ),
  );
}

/// Comando piccolo: icona e etichetta sulla stessa riga. Nella barra semplificata solo l'icona, con il nome nel
/// suggerimento (come i comandi secondari della barra semplificata di Outlook).
class RibbonSmallButton extends StatelessWidget {
  const RibbonSmallButton({super.key, required this.icon, required this.label, this.tooltip, this.onPressed});

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final simplified = RibbonStyle.simplifiedOf(context);
    final color = onPressed != null ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38);
    final iconWidget = Icon(icon, size: 20, color: onPressed != null ? scheme.onSurfaceVariant : color);
    final button = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(OfficeTheme.radius),
      child: simplified
          ? SizedBox(
              width: 32,
              height: 32,
              child: Semantics(
                label: label,
                child: Center(child: iconWidget),
              ),
            )
          : Padding(
              // Tre comandi piccoli uno sopra l'altro devono stare nell'altezza di un gruppo.
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(width: 6),
                  Text(label, style: theme.textTheme.bodyMedium!.copyWith(fontSize: 13, height: 1.2, color: color)),
                ],
              ),
            ),
    );
    final message = simplified ? (tooltip == null ? label : '$label\n$tooltip') : tooltip;
    return message == null ? button : Tooltip(message: message, child: button);
  }
}
