import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/favorite_folder.dart';
import '../models/mail_folder.dart';
import '../state/mailbox_model.dart';

// Trascinamento (3.5c), come Outlook: mail su una cartella = Sposta (con Ctrl = Copia), cartella su
// cartella = sposta la cartella, cartella o Preferito sui Preferiti = aggiunge / riordina i Preferiti.

/// Mail trascinate: la selezione, se la riga trascinata ne fa parte, altrimenti solo quella riga.
class MessagesDrag {
  const MessagesDrag(this.refs);

  final Set<MessageRef> refs;
}

/// Cartella dell'albero trascinata.
class FolderDrag {
  const FolderDrag(this.account, this.folder);

  final String account;
  final MailFolder folder;
}

/// Preferito trascinato (per riordinare i Preferiti).
class FavoriteDrag {
  const FavoriteDrag(this.favorite);

  final FavoriteFolder favorite;
}

/// Spostamento minimo del mouse (pixel logici) perché un clic diventi un trascinamento. Il
/// riconoscitore predefinito di Flutter parte già a 1 pixel con il mouse (kPrecisePointerHitSlop):
/// un clic con la mano poco ferma diventerebbe un trascinamento. 4 è il valore predefinito di Windows.
const double dragThreshold = 4;

/// [Draggable] solo con il mouse e con la soglia [dragThreshold], trascinato dal punto in cui si è preso.
class MailDraggable<T extends Object> extends Draggable<T> {
  const MailDraggable({super.key, required super.child, required super.feedback, super.data, super.childWhenDragging, super.onDragStarted})
    : super(dragAnchorStrategy: pointerDragAnchorStrategy);

  @override
  MultiDragGestureRecognizer createRecognizer(GestureMultiDragStartCallback onStart) =>
      _ThresholdDragRecognizer()..onStart = onStart;
}

/// Solo il mouse (anche il clic-e-trascina del touchpad arriva come mouse): con il dito o la penna
/// trascinare sulla lista deve continuare a farla scorrere.
class _ThresholdDragRecognizer extends MultiDragGestureRecognizer {
  _ThresholdDragRecognizer() : super(debugOwner: null, supportedDevices: const {PointerDeviceKind.mouse});

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _ThresholdPointerState(event.position, event.kind, gestureSettings);

  @override
  String get debugDescription => 'trascinamento con soglia';
}

class _ThresholdPointerState extends MultiDragPointerState {
  _ThresholdPointerState(super.initialPosition, super.kind, super.gestureSettings);

  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > dragThreshold) resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) => starter(initialPosition);
}

/// Riga di mail trascinabile. [refs]: le mail che partono (la selezione o solo questa riga); se la riga
/// non era selezionata diventa l'unica selezionata, come Outlook.
class MessageDragSource extends StatelessWidget {
  const MessageDragSource({
    super.key,
    required this.row,
    required this.refs,
    required this.label,
    required this.child,
    this.onSelect,
  });

  final MessageRef row;
  final Set<MessageRef> refs;

  /// Seleziona la riga quando parte il trascinamento, se le sue mail non sono già selezionate
  /// (predefinito: solo [row]; la riga di una conversazione seleziona tutta la conversazione).
  final VoidCallback? onSelect;

  /// Testo dell'etichetta che segue il mouse con una sola mail (di solito l'oggetto).
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => MailDraggable<MessagesDrag>(
    data: MessagesDrag(refs),
    feedback: DragFeedback(
      icon: FluentIcons.mail_20_regular,
      text: refs.length == 1 ? (label.trim().isEmpty ? '(senza oggetto)' : label) : '${refs.length} mail',
      copyable: true,
    ),
    onDragStarted: () {
      final model = context.read<MailboxModel>();
      if (refs.every(model.selection.contains)) return;
      (onSelect ?? () => model.selectForContextMenu(row))();
    },
    child: child,
  );
}

/// Etichetta che segue il mouse. Con [copyable], tenendo premuto Ctrl, diventa "Copia: …"
/// (rilasciando con Ctrl le mail vengono copiate).
class DragFeedback extends StatefulWidget {
  const DragFeedback({super.key, required this.icon, required this.text, this.copyable = false});

  final IconData icon;
  final String text;
  final bool copyable;

  @override
  State<DragFeedback> createState() => _DragFeedbackState();
}

class _DragFeedbackState extends State<DragFeedback> {
  @override
  void initState() {
    super.initState();
    if (widget.copyable) HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    if (widget.copyable) HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (mounted) setState(() {});
    return false; // il tasto resta disponibile al resto dell'app
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final copy = widget.copyable && isCopyDrop;
    return Transform.translate(
      offset: const Offset(14, 10), // accanto al puntatore, non sotto
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        color: scheme.surfaceContainerHighest,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(copy ? FluentIcons.copy_add_20_regular : widget.icon, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    copy ? 'Copia: ${widget.text}' : widget.text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: scheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ctrl premuto al rilascio: le mail vengono copiate invece che spostate (scelta 3.5c-2a).
bool get isCopyDrop => HardwareKeyboard.instance.isControlPressed;

/// Zona che accetta un rilascio: evidenziata mentre ci passa sopra qualcosa che [accepts] accetta.
class DropZone extends StatelessWidget {
  const DropZone({super.key, required this.accepts, required this.onDrop, required this.child});

  final bool Function(Object data) accepts;
  final void Function(Object data) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => accepts(details.data),
      onAcceptWithDetails: (details) => onDrop(details.data),
      // Evidenziazione in un livello sopra la riga (non un riquadro colorato attorno: nasconderebbe
      // sfondo e selezione della ListTile); lo Stack c'è sempre, così la riga non viene ricreata.
      builder: (context, candidates, _) => Stack(
        children: [
          child,
          if (candidates.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    border: Border.all(color: scheme.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Esiti del rilascio, condivisi da albero delle cartelle e Preferiti.
class DropActions {
  DropActions._();

  /// Mail rilasciate sulla cartella [folder]: spostate, o copiate con Ctrl.
  static Future<void> messages(BuildContext context, MessagesDrag drag, String folder) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await model.dropMessages(drag.refs, folder, copy: isCopyDrop);
    messenger
      ..hideCurrentSnackBar() // con azioni in fila l'esito nuovo prende il posto del precedente
      ..showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  /// Cartella rilasciata dentro [newParent] (null = sul nome dell'account: in cima).
  static Future<void> folder(BuildContext context, FolderDrag drag, String? newParent) async {
    final model = context.read<MailboxModel>();
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await model.moveFolder(drag.account, drag.folder, newParent);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(outcome.message)));
  }
}
