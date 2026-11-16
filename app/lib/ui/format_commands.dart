import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../compose/rich_text.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language.dart';
import 'ribbon_parts.dart';

/// Comandi di formato della composizione (3.7b), come in Outlook: gruppo "Testo base" nella scheda
/// Messaggio e gruppi "Carattere" e "Paragrafo" nella scheda Formato testo. Agiscono sul testo
/// selezionato (o su quello che si scrive dopo) e si aggiornano con la posizione del cursore.
class FormatCommands {
  FormatCommands(this.controller, {required this.l10n, required this.enabled, required this.onEdited});

  final QuillController controller;

  /// Testi nella lingua dell'app (la classe non è un widget).
  final AppLocalizations l10n;
  final bool enabled;

  /// Dopo un comando la tastiera torna al testo.
  final VoidCallback onEdited;

  Style get _style => controller.getSelectionStyle();

  bool _has(Attribute attribute) {
    final current = _style.attributes[attribute.key];
    return current != null && (attribute.value == null || current.value == attribute.value);
  }

  void _toggle(Attribute attribute) {
    controller.formatSelection(_has(attribute) ? Attribute.clone(attribute, null) : attribute);
    onEdited();
  }

  void _set(Attribute attribute) {
    controller.formatSelection(attribute);
    onEdited();
  }

  void _clearFormatting() {
    for (final a in _style.attributes.values) {
      if (a.scope == AttributeScope.inline) controller.formatSelection(Attribute.clone(a, null));
    }
    onEdited();
  }

  /// Gruppo "Testo base" della scheda Messaggio.
  Widget basicText() => RibbonGroup(
    label: l10n.groupBasicText,
    children: [
      _rows([_fontRow(), _styleRow(withExtras: false)]),
      const SizedBox(width: 4),
      _rows([_listRow(), _alignRow()]),
    ],
  );

  /// Gruppi della scheda Formato testo.
  List<Widget> formatTab() => [
    RibbonGroup(
      label: l10n.groupFont,
      children: [
        _rows([_fontRow(), _styleRow(withExtras: true)]),
      ],
    ),
    RibbonGroup(
      label: l10n.groupParagraph,
      children: [
        _rows([_listRow(), _alignRow()]),
      ],
    ),
  ];

  /// Barra compatta per un editor fuori dalla barra multifunzione (finestra Firme): carattere, stili,
  /// elenchi e allineamenti, collegamento e, con [onInsertImage], immagine da file.
  Widget toolbar(BuildContext context, {VoidCallback? onInsertImage}) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _fontRow(),
        _styleRow(withExtras: true),
        _listRow(),
        _alignRow(),
        _IconToggle(
          icon: FluentIcons.link_20_regular,
          tooltip: l10n.linkTooltip,
          onPressed: enabled ? () => insertLink(context, controller) : null,
        ),
        if (onInsertImage != null)
          _IconToggle(
            icon: FluentIcons.image_add_20_regular,
            tooltip: l10n.imageFromFile,
            onPressed: enabled ? onInsertImage : null,
          ),
      ],
    ),
  );

  /// Righe di comandi una sopra l'altra; nella barra semplificata (V3b) una accanto all'altra.
  Widget _rows(List<Widget> rows) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => RibbonStyle.simplifiedOf(context)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final r in rows) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: r)],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: r)],
          ),
  );

  Widget _fontRow() {
    final font = _style.attributes[Attribute.font.key]?.value as String?;
    final size = _style.attributes[Attribute.size.key]?.value?.toString();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Picker(
          tooltip: l10n.groupFont,
          width: 130,
          label: font ?? l10n.defaultFont,
          enabled: enabled,
          items: [
            (l10n.defaultFont, () => _set(Attribute.clone(Attribute.font, null))),
            for (final name in mailFonts.keys) (name, () => _set(FontAttribute(name))),
          ],
        ),
        const SizedBox(width: 4),
        _Picker(
          tooltip: l10n.fontSize,
          width: 52,
          label: size ?? '11',
          enabled: enabled,
          items: [
            for (final pt in mailFontSizes)
              ('$pt', () => _set(pt == 11 ? Attribute.clone(Attribute.size, null) : SizeAttribute('$pt'))),
          ],
        ),
      ],
    );
  }

  Widget _styleRow({required bool withExtras}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _toggleButton(FluentIcons.text_bold_20_regular, l10n.bold, Attribute.bold),
      _toggleButton(FluentIcons.text_italic_20_regular, l10n.italic, Attribute.italic),
      _toggleButton(FluentIcons.text_underline_20_regular, l10n.underline, Attribute.underline),
      if (withExtras) _toggleButton(FluentIcons.text_strikethrough_20_regular, l10n.strikethrough, Attribute.strikeThrough),
      _ColorPicker(
        icon: FluentIcons.text_color_20_regular,
        tooltip: l10n.fontColor,
        enabled: enabled,
        current: _style.attributes[Attribute.color.key]?.value as String?,
        onPick: (rgb) => _set(rgb == null ? Attribute.clone(Attribute.color, null) : ColorAttribute(cssColor(rgb))),
      ),
      if (withExtras) ...[
        _ColorPicker(
          icon: FluentIcons.highlight_20_regular,
          tooltip: l10n.highlightColor,
          enabled: enabled,
          noneLabel: l10n.noColor,
          current: _style.attributes[Attribute.background.key]?.value as String?,
          onPick: (rgb) =>
              _set(rgb == null ? Attribute.clone(Attribute.background, null) : BackgroundAttribute(cssColor(rgb))),
        ),
        _IconToggle(
          icon: FluentIcons.text_clear_formatting_20_regular,
          tooltip: l10n.clearFormatting,
          onPressed: enabled ? _clearFormatting : null,
        ),
      ],
    ],
  );

  Widget _listRow() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _toggleButton(FluentIcons.text_bullet_list_ltr_20_regular, l10n.bullets, Attribute.ul),
      _toggleButton(FluentIcons.text_number_list_ltr_20_regular, l10n.numbering, Attribute.ol),
      _IconToggle(
        icon: FluentIcons.text_indent_decrease_ltr_20_regular,
        tooltip: l10n.decreaseIndent,
        onPressed: enabled
            ? () {
                controller.indentSelection(false);
                onEdited();
              }
            : null,
      ),
      _IconToggle(
        icon: FluentIcons.text_indent_increase_ltr_20_regular,
        tooltip: l10n.increaseIndent,
        onPressed: enabled
            ? () {
                controller.indentSelection(true);
                onEdited();
              }
            : null,
      ),
    ],
  );

  Widget _alignRow() {
    final align = _style.attributes[Attribute.align.key]?.value as String?;
    Widget button(IconData icon, String tooltip, Attribute<String?> attribute) => _IconToggle(
      icon: icon,
      tooltip: tooltip,
      selected: (align ?? 'left') == attribute.value,
      // "A sinistra" è il predefinito: si toglie l'attributo invece di scriverlo.
      onPressed: enabled
          ? () => _set(attribute.value == 'left' ? Attribute.clone(Attribute.align, null) : attribute)
          : null,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(FluentIcons.text_align_left_20_regular, l10n.alignLeft, Attribute.leftAlignment),
        button(FluentIcons.text_align_center_20_regular, l10n.center, Attribute.centerAlignment),
        button(FluentIcons.text_align_right_20_regular, l10n.alignRight, Attribute.rightAlignment),
        button(FluentIcons.text_align_justify_20_regular, l10n.justify, Attribute.justifyAlignment),
      ],
    );
  }

  Widget _toggleButton(IconData icon, String tooltip, Attribute attribute) => _IconToggle(
    icon: icon,
    tooltip: tooltip,
    selected: _has(attribute),
    onPressed: enabled ? () => _toggle(attribute) : null,
  );

  /// "Collegamento" (scheda Inserisci, Ctrl+K come Outlook): sul testo selezionato, o inserisce
  /// l'indirizzo stesso come testo. Solo http, https e mailto.
  static Future<void> insertLink(BuildContext context, QuillController controller) async {
    final selection = controller.selection;
    final current = controller.getSelectionStyle().attributes[Attribute.link.key]?.value as String?;
    final url = await showDialog<String>(
      context: context,
      builder: (context) => _LinkDialog(initial: current ?? ''),
    );
    if (url == null) return;
    if (url.isEmpty) {
      controller.formatText(selection.start, selection.end - selection.start, Attribute.clone(Attribute.link, null));
    } else if (selection.isCollapsed) {
      controller.replaceText(selection.start, 0, url, TextSelection.collapsed(offset: selection.start + url.length));
      controller.formatText(selection.start, url.length, LinkAttribute(url));
    } else {
      controller.formatText(selection.start, selection.end - selection.start, LinkAttribute(url));
    }
  }

  static RibbonLargeButton linkButton(BuildContext context, QuillController controller, {required bool enabled}) =>
      RibbonLargeButton(
        icon: FluentIcons.link_24_regular,
        label: context.l10n.link,
        tooltip: context.l10n.linkButtonTooltip,
        onPressed: enabled ? () => insertLink(context, controller) : null,
      );
}

/// Indirizzo accettato per un collegamento: http(s) o mailto; senza schema si aggiunge https://.
String? normalizeLink(String text) {
  final t = text.trim();
  if (t.isEmpty) return '';
  final withScheme = RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(t)
      ? t
      : (t.contains('@') && !t.contains('/') ? 'mailto:$t' : 'https://$t');
  final uri = Uri.tryParse(withScheme);
  if (uri == null || !{'http', 'https', 'mailto'}.contains(uri.scheme.toLowerCase())) return null;
  if (uri.scheme != 'mailto' && uri.host.isEmpty) return null;
  return withScheme;
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.initial});

  final String initial;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _ok() {
    final url = normalizeLink(_text.text);
    if (url == null) {
      setState(() => _error = context.l10n.linkInvalid);
      return;
    }
    Navigator.pop(context, url);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.insertLink),
    content: SizedBox(
      width: 420,
      child: TextField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(
          labelText: context.l10n.linkAddress,
          hintText: context.l10n.linkAddressHint,
          errorText: _error,
        ),
        onSubmitted: (_) => _ok(),
      ),
    ),
    actions: [
      if (widget.initial.isNotEmpty)
        TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(context.l10n.removeLink)),
      TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
      FilledButton(onPressed: _ok, child: const Text('OK')),
    ],
  );
}

/// Pulsante a icona della barra multifunzione, con stato acceso (grassetto attivo...).
class _IconToggle extends StatelessWidget {
  const _IconToggle({required this.icon, required this.tooltip, required this.onPressed, this.selected = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          width: 26,
          height: 24,
          decoration: selected
              ? BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(3),
                )
              : null,
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null ? scheme.onSurface.withValues(alpha: 0.38) : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Menu a tendina compatto (carattere, dimensione).
class _Picker extends StatelessWidget {
  const _Picker({
    required this.tooltip,
    required this.width,
    required this.label,
    required this.items,
    required this.enabled,
  });

  final String tooltip;
  final double width;
  final String label;
  final List<(String, VoidCallback)> items;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      menuChildren: [for (final (text, action) in items) MenuItemButton(onPressed: action, child: Text(text))],
      builder: (context, controller, _) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
          child: Container(
            width: width,
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Colore del carattere o evidenziatore: un quadratino sotto l'icona mostra il colore attuale.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.current,
    required this.onPick,
    this.noneLabel,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final String? current;
  final ValueChanged<int?> onPick;
  /// null = «Automatico».
  final String? noneLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = current == null ? null : int.tryParse(current!.replaceFirst('#', ''), radix: 16);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(onPressed: () => onPick(null), child: Text(noneLabel ?? context.l10n.fontColorAutomatic)),
        for (final (i, rgb) in fontColors.indexed.skip(1))
          MenuItemButton(
            leadingIcon: Container(width: 14, height: 14, color: Color(0xFF000000 | rgb)),
            onPressed: () => onPick(rgb),
            child: Text(fontColorNames(context.l10n)[i]),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
          child: SizedBox(
            width: 28,
            height: 24,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38)),
                Container(width: 16, height: 3, color: shown == null ? Colors.transparent : Color(0xFF000000 | shown)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
