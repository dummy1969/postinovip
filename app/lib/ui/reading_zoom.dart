import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/language.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../settings/app_settings.dart';
import 'keys.dart';

/// Corpo della mail nel riquadro di lettura con lo zoom (P2), come Outlook classico: si ingrandisce tutto
/// (testo, immagini, tabelle), non solo il carattere. Il contenuto si dispone su una larghezza divisa per lo
/// zoom e poi si disegna in scala, così a capo e tabelle seguono la larghezza del riquadro.
/// Ctrl+rotella cambia lo zoom invece di scorrere.
class ZoomedBody extends StatelessWidget {
  const ZoomedBody({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final zoom = settings.readingZoom / 100;
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        // Il Listener sta dentro lo scorrimento: riceve la rotella per primo e, con Ctrl, la tiene per sé
        // (pointerSignalResolver dà l'evento al primo che lo chiede). Alto almeno quanto il riquadro, così
        // Ctrl+rotella funziona anche sotto una mail corta.
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (event) => _wheel(settings, event),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight.isFinite ? viewport.maxHeight : 0),
            // La colonna riempie l'altezza minima ma lascia al corpo la sua (come senza zoom nello scorrimento).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: padding,
                  child: zoom == 1
                      ? child
                      : LayoutBuilder(
                          builder: (context, c) => FittedBox(
                            key: const Key('reading-zoom'),
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topLeft,
                            child: SizedBox(width: c.maxWidth / zoom, child: child),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _wheel(AppSettings settings, PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !isCommandPressed) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) => settings.zoomBy(dy < 0 ? 1 : -1));
  }

  /// Ctrl++ / Ctrl+- / Ctrl+0 (sul Mac ⌘, keys.dart) (anche sul tastierino e Ctrl+= della tastiera americana), come nei browser.
  static Map<ShortcutActivator, VoidCallback> shortcuts(AppSettings settings) => {
    for (final key in [LogicalKeyboardKey.add, LogicalKeyboardKey.numpadAdd, LogicalKeyboardKey.equal])
      cmd(key): () => settings.zoomBy(1),
    for (final key in [LogicalKeyboardKey.minus, LogicalKeyboardKey.numpadSubtract])
      cmd(key): () => settings.zoomBy(-1),
    for (final key in [LogicalKeyboardKey.digit0, LogicalKeyboardKey.numpad0])
      cmd(key): () => settings.setReadingZoom(100),
  };
}

/// Zoom nella barra di stato, come Outlook classico: − cursore + e la percentuale (clic: torna al 100%).
class ZoomControl extends StatelessWidget {
  const ZoomControl({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    final zoom = settings.readingZoom;
    Widget button(Key key, IconData icon, String tip, int steps) => IconButton(
      key: key,
      tooltip: tip,
      onPressed: (steps < 0 ? zoom > AppSettings.minZoom : zoom < AppSettings.maxZoom)
          ? () => settings.zoomBy(steps)
          : null,
      icon: Icon(icon, size: 14),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 22, height: 22),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(const Key('zoom-out'), FluentIcons.subtract_16_regular, keyLabel(context.l10n.zoomOut), -1),
        SizedBox(
          width: 110,
          height: 22,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              tickMarkShape: SliderTickMarkShape.noTickMark,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              key: const Key('zoom-slider'),
              min: AppSettings.minZoom.toDouble(),
              max: AppSettings.maxZoom.toDouble(),
              divisions: (AppSettings.maxZoom - AppSettings.minZoom) ~/ AppSettings.zoomStep,
              value: zoom.toDouble(),
              onChanged: (v) => settings.setReadingZoom(v.round(), save: false),
              onChangeEnd: (v) => settings.setReadingZoom(v.round()),
            ),
          ),
        ),
        button(const Key('zoom-in'), FluentIcons.add_16_regular, keyLabel(context.l10n.zoomIn), 1),
        Tooltip(
          message: keyLabel(context.l10n.zoomReset),
          child: InkWell(
            key: const Key('zoom-reset'),
            onTap: () => settings.setReadingZoom(100),
            child: SizedBox(
              width: 40,
              child: Text('$zoom%', style: style, textAlign: TextAlign.right),
            ),
          ),
        ),
      ],
    );
  }
}
