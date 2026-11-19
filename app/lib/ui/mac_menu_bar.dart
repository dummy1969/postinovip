import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../about/about_dialog.dart';
import '../l10n/language.dart';
import '../settings/app_settings.dart';
import '../state/calendar_model.dart';
import '../state/contacts_model.dart';
import '../state/mailbox_model.dart';
import 'keys.dart';
import 'settings_dialog.dart';

/// Barra dei menu del Mac (tappa «Mac», M2, scelta 1a): come Outlook per Mac la barra multifunzione resta nella
/// finestra (o si nasconde: File → Opzioni → Generale, M2b) e in alto c'è la barra dei menu del sistema.
///
/// Voci fisse (M2a): menu dell'app (Informazioni, Opzioni ⌘,, Servizi, Nascondi, Esci), Composizione e Finestra.
/// In mezzo (M2b) i menu della finestra in primo piano: ogni finestra li dichiara con [MacMenuScope] (principale,
/// mail, composizione, appuntamento) e vale l'ultima aperta. Il primo menu di una finestra va prima di
/// Composizione (è File), gli altri dopo.
///
/// Su Linux e Windows (e nei test, che girano come Android) [MacMenuBar] e [MacMenuScope] restituiscono il figlio.
///
/// I tasti arrivano prima all'app e solo se l'app non li usa ai menu (FlutterViewController.performKeyEquivalent):
/// le scorciatoie della finestra valgono come prima, e nessuna deve prendere ⌘Q, ⌘H, ⌘M o ⌘, (keys.dart). Per lo
/// stesso motivo le voci non mostrano tasti che servono anche a scrivere (⌫, ⌃E, Invio, frecce): con il fuoco in
/// una casella vuota il tasto passerebbe al menu ed eseguirebbe il comando.
///
/// Le voci «fornite dal sistema» di Flutter (Nascondi, Esci…) prendono il titolo dal MainMenu.xib, in inglese: qui
/// sono voci normali, nella lingua dell'app, che chiamano AppKit con il canale della finestra
/// (macos/Runner/MainFlutterWindow.swift). Solo Servizi resta del sistema (il suo sottomenu lo riempie macOS), con il
/// titolo cambiato dal canale.
///
/// Limite di Flutter 3.47: le voci del menu non hanno il segno di spunta; le scelte attive hanno «✓» davanti
/// ([macChecked]).
class MacMenuBar extends StatefulWidget {
  const MacMenuBar({super.key, required this.child});

  final Widget child;

  @override
  State<MacMenuBar> createState() => _MacMenuBarState();
}

/// Menu delle finestre aperte, in ordine di apertura; sta sopra il Navigator (main.dart) perché le finestre sono
/// pagine diverse dello stesso Navigator.
class MacMenus extends ChangeNotifier {
  final _scopes = <_MacMenuScopeState>[];
  bool _scheduled = false;
  bool _disposed = false;

  _MacMenuScopeState? get _top => _scopes.isEmpty ? null : _scopes.last;

  void _add(_MacMenuScopeState scope) {
    _scopes.add(scope);
    _changed();
  }

  void _remove(_MacMenuScopeState scope) {
    _scopes.remove(scope);
    _changed();
  }

  /// Dopo il fotogramma: chi chiama sta costruendo o togliendo dei widget, e lì non si può ridisegnare la barra.
  void _changed() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// I menu di una finestra ([menus], ricostruiti a ogni cambiamento della finestra o della posta). Le voci sono
/// spente mentre sopra la finestra c'è un'altra pagina o una finestra di dialogo.
class MacMenuScope extends StatefulWidget {
  const MacMenuScope({super.key, required this.menus, this.editExtras, required this.child});

  final List<PlatformMenu> Function(BuildContext context) menus;

  /// Voci in fondo a Composizione (Cerca ⌘E nella finestra principale).
  final List<PlatformMenuItem> Function(BuildContext context)? editExtras;
  final Widget child;

  @override
  State<MacMenuScope> createState() => _MacMenuScopeState();
}

class _MacMenuScopeState extends State<MacMenuScope> {
  MacMenus? _registry;

  @override
  void initState() {
    super.initState();
    if (usesCommandKey) _registry = context.read<MacMenus?>()?.._add(this);
  }

  @override
  void dispose() {
    _registry?._remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _registry?._changed(); // lo stato della finestra può essere cambiato: la barra rilegge i menu
    return widget.child;
  }
}

/// Voce con «✓» davanti se [on] (vedi [MacMenuBar]); le altre con uno spazio della stessa larghezza circa.
String macChecked(String label, bool on) => on ? '✓ $label' : '  $label';

final _shortcutText = RegExp(r'\s*\([^()]*\)$');

/// Testo di una voce senza la scorciatoia scritta tra parentesi («Stampa… (Ctrl+P)» → «Stampa…»): sul Mac la
/// scorciatoia la mostra il menu.
String macLabel(String text) => text.replaceFirst(_shortcutText, '');

PlatformMenuItem macItem(String label, VoidCallback? onSelected, [MenuSerializableShortcut? shortcut]) =>
    PlatformMenuItem(label: label, onSelected: onSelected, shortcut: shortcut);

/// ⌘[key] per le voci dei menu.
SingleActivator macKey(LogicalKeyboardKey key, {bool shift = false, bool alt = false, bool control = false}) =>
    SingleActivator(key, meta: true, shift: shift, alt: alt, control: control);

class _MacMenuBarState extends State<MacMenuBar> {
  static const _channel = MethodChannel('com.dumm1969.postinovip/window');

  /// Ultimo titolo dato a Servizi: il canale si chiama solo quando cambia la lingua.
  static String? _servicesTitle;

  /// Opzioni già aperte (⌘, di nuovo non ne apre una seconda sopra).
  bool _optionsOpen = false;

  /// Ultima barra mandata al Mac e la sua descrizione: la posta cambia spesso (sincronizzazione), la barra solo
  /// quando cambiano le voci; mandarla ogni volta chiuderebbe un menu aperto.
  String? _lastSignature;
  List<PlatformMenuItem>? _lastMenus;

  static void _native(String method, [Object? arguments]) {
    _channel.invokeMethod<void>(method, arguments).catchError((Object e) {
      debugPrint('[menu] $method non riuscito: $e');
    });
  }

  /// Comando di Composizione: va al campo che ha il fuoco (casella di testo o editor della mail). Restituisce
  /// false se lì nessuno lo gestisce.
  static bool _toFocused(Intent intent) {
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus == null) return false;
    final action = Actions.maybeFind<Intent>(focus, intent: intent);
    if (action == null || !action.isEnabled(intent)) return false;
    Actions.invoke(focus, intent);
    return true;
  }

  Future<void> _options() async {
    if (_optionsOpen) return;
    _optionsOpen = true;
    try {
      await showDialog<void>(context: context, builder: (_) => const SettingsDialog());
    } finally {
      _optionsOpen = false;
    }
  }

  /// ⌘A dal menu: il testo del campo con il fuoco, altrimenti (nella posta, con la finestra principale davanti)
  /// tutte le mail della lista, come Ctrl+A.
  void _selectAll() {
    if (_toFocused(const SelectAllTextIntent(SelectionChangedCause.keyboard))) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    if (context.read<ContactsModel>().module == AppModule.mail) context.read<MailboxModel>().selectAll();
  }

  /// Voci della finestra: eseguite solo se la finestra è davanti (niente comandi dietro una finestra di dialogo).
  static PlatformMenuItem _guarded(PlatformMenuItem item, BuildContext scope) => switch (item) {
    PlatformMenu(:final label, :final menus) => PlatformMenu(label: label, menus: [for (final m in menus) _guarded(m, scope)]),
    PlatformMenuItemGroup(:final members) => PlatformMenuItemGroup(members: [for (final m in members) _guarded(m, scope)]),
    PlatformProvidedMenuItem() => item,
    _ => PlatformMenuItem(
      label: item.label,
      shortcut: item.shortcut,
      onSelected: item.onSelected == null
          ? null
          : () {
              if (scope.mounted && ModalRoute.of(scope)?.isCurrent != false) item.onSelected!();
            },
    ),
  };

  static String _signature(PlatformMenuItem item) => switch (item) {
    PlatformMenu(:final label, :final menus) => 'M($label:${menus.map(_signature).join(',')})',
    PlatformMenuItemGroup(:final members) => 'G(${members.map(_signature).join(',')})',
    PlatformProvidedMenuItem(:final type) => 'P($type)',
    _ => 'I(${item.label}|${item.onSelected != null}|${item.shortcut?.serializeForMenu().toChannelRepresentation()})',
  };

  @override
  Widget build(BuildContext context) {
    if (!usesCommandKey) return widget.child;
    // La barra dipende dalla finestra davanti e dallo stato della posta, del calendario e delle impostazioni.
    final registry = context.watch<MacMenus?>();
    context.watch<MailboxModel>();
    context.watch<ContactsModel>();
    context.watch<CalendarModel>();
    context.watch<AppSettings>();
    final l = context.l10n;
    // Prima della barra: i messaggi del canale arrivano ad AppKit nell'ordine in cui partono, quindi il titolo
    // c'è già quando Flutter copia la voce Servizi nel menu nuovo.
    if (_servicesTitle != l.macMenuServices) {
      _servicesTitle = l.macMenuServices;
      _native('servicesTitle', l.macMenuServices);
    }

    final scope = registry?._top;
    final scopeContext = scope?.context;
    final windowMenus = scope == null || scopeContext == null
        ? const <PlatformMenu>[]
        : [for (final m in scope.widget.menus(scopeContext)) _guarded(m, scopeContext) as PlatformMenu];
    final editExtras = scope == null || scopeContext == null
        ? const <PlatformMenuItem>[]
        : [for (final m in scope.widget.editExtras?.call(scopeContext) ?? const <PlatformMenuItem>[]) _guarded(m, scopeContext)];

    final menus = <PlatformMenuItem>[
      PlatformMenu(
        label: 'PostinoVip', // il Mac mostra comunque il nome dell'app
        menus: [
          PlatformMenuItemGroup(members: [macItem(l.macMenuAbout, () => showPostinoVipAbout(context))]),
          PlatformMenuItemGroup(members: [macItem(l.macMenuOptions, _options, macKey(LogicalKeyboardKey.comma))]),
          const PlatformMenuItemGroup(
            members: [PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.servicesSubmenu)],
          ),
          PlatformMenuItemGroup(
            members: [
              macItem(l.macMenuHide, () => _native('hide'), macKey(LogicalKeyboardKey.keyH)),
              macItem(l.macMenuHideOthers, () => _native('hideOthers'), macKey(LogicalKeyboardKey.keyH, alt: true)),
              macItem(l.macMenuShowAll, () => _native('showAll')),
            ],
          ),
          PlatformMenuItemGroup(members: [macItem(l.macMenuQuit, () => _native('quit'), macKey(LogicalKeyboardKey.keyQ))]),
        ],
      ),
      if (windowMenus.isNotEmpty) windowMenus.first,
      PlatformMenu(
        label: l.macMenuEdit,
        menus: [
          PlatformMenuItemGroup(
            members: [
              macItem(
                l.macMenuUndo,
                () => _toFocused(const UndoTextIntent(SelectionChangedCause.keyboard)),
                macKey(LogicalKeyboardKey.keyZ),
              ),
              macItem(
                l.macMenuRedo,
                () => _toFocused(const RedoTextIntent(SelectionChangedCause.keyboard)),
                macKey(LogicalKeyboardKey.keyZ, shift: true),
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              macItem(
                l.macMenuCut,
                () => _toFocused(const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard)),
                macKey(LogicalKeyboardKey.keyX),
              ),
              macItem(l.macMenuCopy, () => _toFocused(CopySelectionTextIntent.copy), macKey(LogicalKeyboardKey.keyC)),
              macItem(
                l.macMenuPaste,
                () => _toFocused(const PasteTextIntent(SelectionChangedCause.keyboard)),
                macKey(LogicalKeyboardKey.keyV),
              ),
              macItem(l.macMenuSelectAll, _selectAll, macKey(LogicalKeyboardKey.keyA)),
            ],
          ),
          if (editExtras.isNotEmpty) PlatformMenuItemGroup(members: editExtras),
        ],
      ),
      ...windowMenus.skip(1),
      PlatformMenu(
        label: l.macMenuWindow,
        menus: [
          PlatformMenuItemGroup(
            members: [
              macItem(l.macMenuMinimize, () => _native('minimize'), macKey(LogicalKeyboardKey.keyM)),
              macItem(l.macMenuZoom, () => _native('zoom')),
              macItem(l.macMenuFullScreen, () => _native('fullScreen'), macKey(LogicalKeyboardKey.keyF, control: true)),
            ],
          ),
          PlatformMenuItemGroup(members: [macItem(l.macMenuBringAllToFront, () => _native('bringAllToFront'))]),
        ],
      ),
    ];
    final signature = menus.map(_signature).join(';');
    if (signature != _lastSignature) {
      _lastSignature = signature;
      _lastMenus = menus;
    }
    return PlatformMenuBar(menus: _lastMenus!, child: widget.child);
  }
}
