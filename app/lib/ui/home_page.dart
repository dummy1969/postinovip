import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/compose_draft.dart';
import '../print/print_actions.dart';
import '../settings/app_settings.dart';
import '../models/calendar.dart';
import '../state/calendar_model.dart';
import '../state/contacts_model.dart';
import '../state/mailbox_model.dart';
import 'calendar_view.dart';
import 'eml_view.dart';
import 'folder_actions.dart';
import 'folder_pane.dart';
import 'archive_ui.dart';
import 'message_actions.dart';
import 'message_list_pane.dart';
import 'message_window.dart';
import 'module_bar.dart';
import 'top_bar.dart';
import 'people_view.dart';
import 'reading_pane.dart';
import 'reading_zoom.dart';
import 'ribbon.dart';
import 'status_bar.dart';

/// Il fuoco della tastiera nella finestra principale fuori dai campi di testo: un clic sulla lista
/// lo riporta qui, così le scorciatoie (Canc, frecce, Ctrl+A...) agiscono sulla posta.
class MainFocus {
  final node = FocusNode(debugLabel: 'Finestra principale');
}

/// Apre la mail selezionata nella sua finestra (MessageWindow): doppio clic sulla riga della lista.
class MessageOpener {
  const MessageOpener(this.open);

  final VoidCallback open;
}

/// Finestra principale in stile Outlook classico: barra multifunzione in alto, poi cartelle |
/// lista | lettura, barra di stato in basso. Scorciatoie di Outlook classico (scelta 3.5-4a), vedi
/// [_HomePageState._bindings].
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchFocus = SearchFocus();
  final _mainFocus = MainFocus();

  /// Doppio clic o Invio: la mail nella sua finestra (MessageWindow), con qualsiasi posizione del riquadro di lettura;
  /// chiusa, la tastiera torna alla lista.
  Future<void> _openMessage() async {
    await openMessageWindow(context);
    if (mounted) _mainFocus.node.requestFocus();
  }

  @override
  void dispose() {
    _searchFocus.node.dispose();
    _mainFocus.node.dispose();
    super.dispose();
  }

  /// Si sta scrivendo in un campo (ricerca, nome della cartella): i tasti della posta non valgono,
  /// così Canc, Ctrl+A, le frecce o Ctrl+D restano al testo.
  static bool _typing() {
    final focus = FocusManager.instance.primaryFocus?.context;
    return focus != null &&
        (focus.widget is EditableText || focus.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  /// Scorciatoie da non usare mentre si scrive: il tasto va lasciato alla casella di testo (Invio, Canc, frecce,
  /// Ctrl+A…). CallbackShortcuts lo considererebbe comunque gestito anche con l'azione che non fa niente, e la
  /// casella non riceverebbe mai l'Invio (trovato con Nuova cartella il 10/11/2026).
  final _whenNotTyping = Set<VoidCallback>.identity();

  VoidCallback _notTyping(VoidCallback action) {
    _whenNotTyping.add(action);
    return action;
  }

  /// Scorciatoia che agisce sulla posta: ignorata mentre si scrive.
  VoidCallback _mail(void Function(BuildContext context, MailboxModel model) action) =>
      _notTyping(() => action(context, context.read<MailboxModel>()));

  /// Come CallbackShortcuts, ma le scorciatoie di [_whenNotTyping] mentre si scrive lasciano passare il tasto.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final bindings = _bindings;
    for (final MapEntry(key: activator, value: action) in bindings.entries) {
      if (!activator.accepts(event, HardwareKeyboard.instance)) continue;
      if (_whenNotTyping.contains(action) && _typing()) return KeyEventResult.ignored;
      action();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Scorciatoie di Outlook classico (3.5b). F9 invia/ricevi, Ctrl+F1 comprime la barra, F2 rinomina
  /// la cartella selezionata; Ctrl+F è Inoltra (come Outlook), la ricerca è Ctrl+E.
  Map<ShortcutActivator, VoidCallback> get _bindings {
    _whenNotTyping.clear();
    final modules = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => ModuleBar.show(context, AppModule.mail),
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => ModuleBar.show(context, AppModule.calendar),
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => ModuleBar.show(context, AppModule.people),
      const SingleActivator(LogicalKeyboardKey.f1, control: true): () {
        final settings = context.read<AppSettings>();
        settings.setRibbonCollapsed(!settings.ribbonCollapsed);
      },
    };
    // Calendario (K3): Ctrl+Alt+1..4 le viste come Outlook, F9 sincronizza anche i calendari.
    if (context.read<ContactsModel>().module == AppModule.calendar) {
      final calendar = context.read<CalendarModel>();
      return {
        ...modules,
        const SingleActivator(LogicalKeyboardKey.f9): () {
          context.read<MailboxModel>().refresh();
          calendar.syncNow();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => CalendarActions.newAppointment(context),
        const SingleActivator(LogicalKeyboardKey.delete): _notTyping(() => CalendarActions.deleteSelected(context)),
        for (final (i, kind) in CalendarViewKind.values.indexed)
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true, alt: true): () => calendar.setView(kind),
      };
    }
    // Vista Persone (C2): Ctrl+N nuovo contatto, Ctrl+E cerca, Canc elimina, Invio apre.
    if (context.read<ContactsModel>().module == AppModule.people) {
      VoidCallback people(Future<void> Function(BuildContext context) action) => _notTyping(() => action(context));
      return {
        ...modules,
        const SingleActivator(LogicalKeyboardKey.f9): () {
          context.read<MailboxModel>().refresh();
          context.read<ContactsModel>().syncNow(); // C4c: anche la rubrica aperta, seguendone lo stato
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => PeopleActions.newContact(context),
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
            context.read<ContactsModel>().searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.delete): people(PeopleActions.delete),
        const SingleActivator(LogicalKeyboardKey.enter): people(PeopleActions.edit),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): people(PeopleActions.edit),
      };
    }

    void reply(BuildContext context, MailboxModel model, DraftMode mode) {
      if (MessageActions.hasMessage(model)) MessageActions.reply(context, mode);
    }

    void delete(BuildContext context, MailboxModel model) {
      // Maiusc+Canc come Canc (scelta 3.5b-1a): definitiva solo dentro Posta eliminata, con conferma.
      if (MessageActions.canModify(model)) MessageActions.delete(context);
    }

    void seen(BuildContext context, MailboxModel model, bool value) {
      if (MessageActions.canModify(model)) MessageActions.setSeen(context, value);
    }

    return {
      ...modules,
      ...ZoomedBody.shortcuts(context.read<AppSettings>()), // P2: Ctrl++, Ctrl+-, Ctrl+0
      const SingleActivator(LogicalKeyboardKey.f9): () => context.read<MailboxModel>().refresh(),
      const SingleActivator(LogicalKeyboardKey.f2): _mail((context, _) => FolderActions.renameSelected(context)),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => MessageActions.compose(context),
      const SingleActivator(LogicalKeyboardKey.f12): _mail((c, m) {
        if (EmlActions.canSave(m)) EmlActions.saveAs(c);
      }),
      const SingleActivator(LogicalKeyboardKey.keyP, control: true): _mail((c, m) {
        if (PrintActions.canPrint(m)) PrintActions.printMessage(c);
      }),
      const SingleActivator(LogicalKeyboardKey.keyE, control: true): () => _searchFocus.node.requestFocus(),
      const SingleActivator(LogicalKeyboardKey.keyR, control: true): _mail((c, m) => reply(c, m, DraftMode.reply)),
      const SingleActivator(LogicalKeyboardKey.keyR, control: true, shift: true): _mail(
        (c, m) => reply(c, m, DraftMode.replyAll),
      ),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): _mail((c, m) => reply(c, m, DraftMode.forward)),
      const SingleActivator(LogicalKeyboardKey.delete): _mail(delete),
      const SingleActivator(LogicalKeyboardKey.delete, shift: true): _mail(delete),
      const SingleActivator(LogicalKeyboardKey.keyD, control: true): _mail(delete),
      // Archivia (A2): Backspace come Outlook; non nella finestra della mail, che ha le sue scorciatoie.
      const SingleActivator(LogicalKeyboardKey.backspace): _mail((c, _) => ArchiveActions.archive(c)),
      const SingleActivator(LogicalKeyboardKey.keyQ, control: true): _mail((c, m) => seen(c, m, true)),
      const SingleActivator(LogicalKeyboardKey.keyU, control: true): _mail((c, m) => seen(c, m, false)),
      const SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true): _mail((c, m) {
        if (MessageActions.canModify(m)) MessageActions.moveToFolder(c);
      }),
      const SingleActivator(LogicalKeyboardKey.keyA, control: true): _mail((_, m) => m.selectAll()),
      const SingleActivator(LogicalKeyboardKey.arrowDown): _mail((_, m) => m.moveCursor(1)),
      const SingleActivator(LogicalKeyboardKey.arrowUp): _mail((_, m) => m.moveCursor(-1)),
      const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): _mail((_, m) => m.moveCursor(1, extend: true)),
      const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): _mail((_, m) => m.moveCursor(-1, extend: true)),
      // Home, Fine, Pag↑, Pag↓ (12/11/2026, scelta 1a): con Maiusc la selezione si allarga; Fine carica tutta la lista.
      const SingleActivator(LogicalKeyboardKey.home): _mail((_, m) => m.moveCursorToEdge(end: false)),
      const SingleActivator(LogicalKeyboardKey.end): _mail((_, m) => m.moveCursorToEdge(end: true)),
      const SingleActivator(LogicalKeyboardKey.home, shift: true): _mail((_, m) => m.moveCursorToEdge(end: false, extend: true)),
      const SingleActivator(LogicalKeyboardKey.end, shift: true): _mail((_, m) => m.moveCursorToEdge(end: true, extend: true)),
      const SingleActivator(LogicalKeyboardKey.pageUp): _mail((_, m) => m.moveCursorPage(-1)),
      const SingleActivator(LogicalKeyboardKey.pageDown): _mail((_, m) => m.moveCursorPage(1)),
      const SingleActivator(LogicalKeyboardKey.pageUp, shift: true): _mail((_, m) => m.moveCursorPage(-1, extend: true)),
      const SingleActivator(LogicalKeyboardKey.pageDown, shift: true): _mail((_, m) => m.moveCursorPage(1, extend: true)),
      // Invio apre la mail selezionata nella sua finestra, come Outlook (con qualsiasi riquadro di lettura).
      const SingleActivator(LogicalKeyboardKey.enter): _mail((_, _) => _openMessage()),
      const SingleActivator(LogicalKeyboardKey.numpadEnter): _mail((_, _) => _openMessage()),
    };
  }

  /// Cartelle | lista | lettura con i divisori trascinabili (3.9-1a): lettura a destra, in basso o disattivata
  /// (allora la mail si apre a tutta finestra al posto della lista).
  Widget _panes(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final model = context.watch<MailboxModel>();
    final position = settings.readingPane;
    model.readingPaneVisible = position != ReadingPanePosition.off;
    final work = switch (position) {
      ReadingPanePosition.right => PaneSplit(
        key: const ValueKey('split-right'),
        axis: Axis.horizontal,
        fraction: settings.listFractionRight,
        onChanged: (d, {required save}) =>
            settings.setPaneLayout(listRight: settings.listFractionRight + d, save: save),
        first: const MessageListPane(),
        second: const ReadingPane(),
      ),
      ReadingPanePosition.bottom => PaneSplit(
        key: const ValueKey('split-bottom'),
        axis: Axis.vertical,
        fraction: settings.listFractionBottom,
        onChanged: (d, {required save}) =>
            settings.setPaneLayout(listBottom: settings.listFractionBottom + d, save: save),
        first: const MessageListPane(),
        second: const ReadingPane(),
      ),
      ReadingPanePosition.off => const MessageListPane(),
    };
    return LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: settings.folderPaneWidth, child: const FolderPane()),
          PaneDivider(
            axis: Axis.horizontal,
            onDrag: (delta, {required save}) =>
                settings.setPaneLayout(folderWidth: settings.folderPaneWidth + delta, save: save),
          ),
          Expanded(child: work),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _searchFocus),
        Provider.value(value: _mainFocus),
        Provider<MessageOpener?>.value(value: MessageOpener(_openMessage)),
      ],
      child: Scaffold(
        body: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: Focus(
            focusNode: _mainFocus.node,
            autofocus: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TopBar(),
                const Ribbon(),
                Expanded(
                  // Barra dei moduli a sinistra, sotto la barra multifunzione (V2), poi il modulo aperto. Con la barra «in basso»
                  // (File → Opzioni → Generale) la mettono i riquadri di sinistra dei moduli (`ModuleBar.bottomOf`).
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (context.watch<AppSettings>().moduleBar == ModuleBarPosition.left) const ModuleBar(),
                      Expanded(
                        child: switch (context.watch<ContactsModel>().module) {
                          AppModule.people => const PeopleView(),
                          AppModule.calendar => const CalendarView(),
                          AppModule.mail => _panes(context),
                        },
                      ),
                    ],
                  ),
                ),
                const StatusBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Due riquadri con un divisore trascinabile in mezzo; [fraction] è la quota del primo.
class PaneSplit extends StatelessWidget {
  const PaneSplit({
    super.key,
    required this.axis,
    required this.fraction,
    required this.onChanged,
    required this.first,
    required this.second,
  });

  /// Misure minime di ciascun riquadro (in pixel), qualunque sia la quota salvata.
  static const minPaneWidth = 360.0;
  static const minPaneHeight = 160.0;

  final Axis axis;
  final double fraction;

  /// Spostamento del divisore come quota dello spazio: chi lo riceve lo somma al valore attuale (non a
  /// [fraction], che durante il trascinamento sarebbe quello di inizio gesto).
  final void Function(double delta, {required bool save}) onChanged;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final total = axis == Axis.horizontal ? box.maxWidth : box.maxHeight;
      // Ogni riquadro resta usabile (casella di ricerca, barra della lista) anche al limite della quota.
      final min = axis == Axis.horizontal ? minPaneWidth : minPaneHeight;
      final room = total - PaneDivider.thickness;
      final firstSize = room < 2 * min ? room * fraction : (room * fraction).clamp(min, room - min);
      final divider = PaneDivider(
        axis: axis,
        onDrag: (delta, {required save}) => onChanged(delta / total, save: save),
      );
      return Flex(
        direction: axis,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: axis == Axis.horizontal ? firstSize : null,
            height: axis == Axis.vertical ? firstSize : null,
            child: first,
          ),
          divider,
          Expanded(child: second),
        ],
      );
    },
  );
}

/// Divisore tra due riquadri: una linea sottile con un'area di presa più larga; trascinandolo cambia la
/// misura, al rilascio la si salva (come Outlook, ricordata su questo computer).
class PaneDivider extends StatelessWidget {
  const PaneDivider({super.key, required this.axis, required this.onDrag});

  static const thickness = 5.0;

  /// Direzione dei riquadri: orizzontale = divisore verticale tra colonne.
  final Axis axis;
  final void Function(double delta, {required bool save}) onDrag;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    final horizontal = axis == Axis.horizontal;
    return MouseRegion(
      cursor: horizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: horizontal ? (d) => onDrag(d.delta.dx, save: false) : null,
        onHorizontalDragEnd: horizontal ? (_) => onDrag(0, save: true) : null,
        onVerticalDragUpdate: horizontal ? null : (d) => onDrag(d.delta.dy, save: false),
        onVerticalDragEnd: horizontal ? null : (_) => onDrag(0, save: true),
        child: SizedBox(
          width: horizontal ? thickness : null,
          height: horizontal ? null : thickness,
          child: Center(
            child: Container(width: horizontal ? 1 : null, height: horizontal ? null : 1, color: color),
          ),
        ),
      ),
    );
  }
}
