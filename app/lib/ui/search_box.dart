import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/mailbox_model.dart';
import 'ribbon.dart' show SearchFocus;
import 'theme.dart';

/// Casella di ricerca della posta nella barra in alto (tappa «Aspetto», V2), come l'Outlook classico di oggi:
/// lente, testo, aiuto o «Chiudi la ricerca», e a destra dentro la casella la scelta di dove cercare. Il testo sta
/// nel modello: cambiando cartella la ricerca si chiude e la casella si svuota. Senza una cartella aperta (o nella
/// Posta in uscita) è disattivata.
class MailSearchBox extends StatefulWidget {
  const MailSearchBox({super.key});

  /// Altezza della casella nella barra in alto.
  static const height = 30.0;

  @override
  State<MailSearchBox> createState() => _MailSearchBoxState();
}

class _MailSearchBoxState extends State<MailSearchBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_controller.text != model.searchText) _controller.text = model.searchText;
    final enabled = model.selectedFolder != null && !model.showingOutbox;

    // "Tutti gli account" ha senso solo con più account.
    final scope = model.searchScope == SearchScope.allAccounts && !model.multipleAccounts
        ? SearchScope.account
        : model.searchScope;
    final textStyle = theme.textTheme.bodyMedium;
    final field = TextField(
      controller: _controller,
      focusNode: context.read<SearchFocus?>()?.node,
      enabled: enabled,
      onChanged: model.setSearchText,
      onSubmitted: (_) => model.search(),
      textInputAction: TextInputAction.search,
      style: textStyle,
      decoration: InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.zero, // niente margini del tema (V6): il testo resta allineato alla lente
        border: InputBorder.none,
        hintText: 'Cerca',
        hintStyle: textStyle?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    final trailing = model.searchText.isEmpty
        ? Tooltip(
            message:
                'Parole (anche iniziali: "fatt" trova "fattura"), "frase esatta"\n'
                'da:anna   a:mario   oggetto:riunione\n'
                'allegato:pdf   allegati:sì   allegati:no',
            child: Icon(FluentIcons.question_circle_20_regular, size: 18, color: scheme.onSurfaceVariant),
          )
        : IconButton(
            tooltip: 'Chiudi la ricerca',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            iconSize: 16,
            icon: const Icon(FluentIcons.dismiss_20_regular),
            onPressed: model.clearSearch,
          );
    Text item(String text) => Text(text, overflow: TextOverflow.ellipsis, maxLines: 1, style: textStyle);
    final scopeMenu = DropdownButtonHideUnderline(
      child: DropdownButton<SearchScope>(
        key: const Key('search-scope'),
        value: scope,
        isDense: true,
        isExpanded: true, // si adatta allo spazio, testo con «…»
        focusColor: Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(OfficeTheme.radius)),
        icon: Icon(FluentIcons.chevron_down_16_regular, size: 14, color: scheme.onSurfaceVariant),
        onChanged: enabled ? (s) => model.setSearchScope(s!) : null,
        items: [
          DropdownMenuItem(value: SearchScope.folder, child: item('Cartella attuale')),
          DropdownMenuItem(value: SearchScope.account, child: item('Tutte le cartelle')),
          if (model.multipleAccounts) DropdownMenuItem(value: SearchScope.allAccounts, child: item('Tutti gli account')),
        ],
      ),
    );

    return Container(
      key: const Key('search-box'),
      height: MailSearchBox.height,
      decoration: BoxDecoration(
        color: enabled ? scheme.surface : scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(OfficeTheme.radius)),
        border: Border.all(color: scheme.outline),
      ),
      child: LayoutBuilder(
        // Casella stretta (finestra piccola): la scelta di dove cercare resta nel menu, più corta.
        builder: (context, box) => Row(
          children: [
            const SizedBox(width: 8),
            Icon(FluentIcons.search_20_regular, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: field),
            trailing,
            const SizedBox(width: 6),
            Container(width: 1, height: 18, color: scheme.outlineVariant),
            SizedBox(width: box.maxWidth < 360 ? 96 : 150, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: scopeMenu,
            )),
          ],
        ),
      ),
    );
  }
}
