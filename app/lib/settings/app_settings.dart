import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar.dart';
import '../models/favorite_folder.dart';
import '../models/signature.dart';

/// Quando mostrare la notifica di sistema per la nuova posta.
enum NotifyMode {
  always('Sempre'),
  unfocused('Solo con la finestra non in primo piano'),
  never('Mai');

  const NotifyMode(this.label);

  final String label;
}

/// Quando una mail aperta nel pannello di lettura viene segnata come letta (come in Outlook).
enum ReadMode {
  immediately('Subito all\'apertura'),
  afterDelay('Dopo alcuni secondi di visualizzazione'),
  manual('Mai automaticamente (solo con il pulsante)');

  const ReadMode(this.label);

  final String label;
}

/// Risposta alle richieste di conferma di lettura (R2, scelta 4a), come Outlook classico.
enum ReceiptMode {
  ask('Chiedi ogni volta'),
  always('Invia sempre una conferma di lettura'),
  never('Non inviare mai una conferma di lettura');

  const ReceiptMode(this.label);

  final String label;
}

/// Posizione del riquadro di lettura (3.9, Visualizza → Riquadro di lettura, come Outlook).
enum ReadingPanePosition {
  right('A destra'),
  bottom('In basso'),
  off('Disattivato');

  const ReadingPanePosition(this.label);

  final String label;
}

/// Barra multifunzione classica (gruppi con l'etichetta, comandi grandi e piccoli su tre righe) o semplificata (una
/// riga sola), come le «Opzioni di visualizzazione della barra multifunzione» di Outlook (tappa «Aspetto», V3b,
/// scelta 1b del 12/11/2026). Predefinita la classica.
enum RibbonLayout {
  classic('Barra multifunzione classica'),
  simplified('Barra multifunzione semplificata');

  const RibbonLayout(this.label);

  final String label;
}

/// Posizione della barra dei moduli (Posta, Calendario, Persone), File → Opzioni → Generale (scelta 1c del
/// 12/11/2026): a sinistra come l'Outlook di oggi (predefinita) o in fondo al riquadro di sinistra come Outlook 2016/2019.
enum ModuleBarPosition {
  left('A sinistra'),
  bottom('In basso nel riquadro di sinistra');

  const ModuleBarPosition(this.label);

  final String label;
}

/// Tema di Office (File → Opzioni → Aspetto, Visualizza → Tema), come in Outlook classico.
/// «Usa impostazione di sistema» = Colorato con il sistema chiaro, Nero con quello scuro.
enum AppTheme {
  system('Usa impostazione di sistema'),
  colorful('Colorato'),
  white('Bianco'),
  darkGray('Grigio scuro'),
  black('Nero');

  const AppTheme(this.label);

  final String label;
}

/// Dove leggere/scrivere le impostazioni: SharedPreferences nell'app, memoria nei test.
abstract interface class SettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPreferencesStore implements SettingsStore {
  // API consigliata dal pacchetto (la classe SharedPreferences "classica" verrà deprecata).
  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}

class MemorySettingsStore implements SettingsStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

/// Impostazioni dell'app. Valori predefiniti finché non vengono caricate.
class AppSettings extends ChangeNotifier {
  AppSettings(this._store);

  static const _notifyKey = 'notifyMode';
  static const _readModeKey = 'readMode';
  static const _readDelayKey = 'readDelaySeconds';
  static const _collapsedKey = 'collapsedAccounts';
  static const _ribbonKey = 'ribbonCollapsed';
  static const _ribbonLayoutKey = 'ribbonLayout';
  static const _categoriesKey = 'categoryNames';
  static const _favoritesKey = 'favoriteFolders';
  static const _favoritesCollapsedKey = 'favoritesCollapsed';
  static const _conversationsKey = 'conversationView';
  static const _signaturesKey = 'signatures';
  static const _readingPaneKey = 'readingPane';
  static const _layoutKey = 'paneLayout';
  static const _previewLinesKey = 'previewLines';
  static const _themeKey = 'theme';
  static const _moduleBarKey = 'moduleBar';
  static const _showBccKey = 'showBcc';
  static const _calendarKey = 'calendar';
  static const _remindersKey = 'reminders';
  static const _zoomKey = 'readingZoom';
  static const _requestReceiptKey = 'requestReadReceipt';
  static const _receiptModeKey = 'receiptMode';
  static const _confirmIgnoreKey = 'confirmIgnore';
  static const _confirmStopIgnoringKey = 'confirmStopIgnoring';

  /// Zoom del riquadro di lettura (P2, scelta 4a): percentuale, a passi di [zoomStep]; uguale per tutte le mail.
  static const minZoom = 50;
  static const maxZoom = 200;
  static const zoomStep = 10;

  /// Limiti dei divisori trascinabili (3.9): larghezza del riquadro cartelle in pixel, quota della lista.
  static const minFolderWidth = 160.0;
  static const maxFolderWidth = 480.0;
  static const defaultFolderWidth = 250.0;
  static const minListFraction = 0.2;
  static const maxListFraction = 0.8;

  /// Nomi predefiniti delle sei categorie, nell'ordine dei colori (ui/categories.dart).
  static const defaultCategoryNames = [
    'Categoria rossa',
    'Categoria arancione',
    'Categoria gialla',
    'Categoria verde',
    'Categoria blu',
    'Categoria viola',
  ];

  /// Limiti e valore predefinito di "dopo N secondi" (scelta dell'utente, 30/10/2026).
  static const minReadDelay = 1;
  static const maxReadDelay = 60;
  static const defaultReadDelay = 5;

  final SettingsStore _store;

  NotifyMode notifyMode = NotifyMode.always; // scelta predefinita dell'utente
  ReadMode readMode = ReadMode.immediately; // comportamento precedente all'opzione
  int readDelaySeconds = defaultReadDelay;

  /// Account chiusi nell'albero delle cartelle (id). Predefinito: tutti aperti.
  Set<String> collapsedAccounts = {};

  /// Barra multifunzione compressa (solo i nomi delle schede). Predefinito: completa (scelta 3.1-1a).
  bool ribbonCollapsed = false;

  /// Nomi delle categorie 1–6, rinominabili (scelta 3.3-3a); valgono solo su questo computer: sul
  /// server ogni categoria è una parola chiave fissa per colore.
  List<String> categoryNames = defaultCategoryNames;

  /// Preferiti scelti dall'utente, in ordine; null finché non li cambia: allora valgono quelli
  /// predefiniti (FavoriteFolder.defaults), calcolati dalle cartelle del primo account.
  List<FavoriteFolder>? favorites;

  /// Sezione Preferiti chiusa nel riquadro cartelle.
  bool favoritesCollapsed = false;

  /// "Mostra come conversazioni" (scelta 3.6-3a): vale per tutte le cartelle senza una scelta propria.
  /// Predefinito: spento.
  bool conversationsEverywhere = false;

  /// Scelta fatta per una sola cartella ("Questa cartella"), che prevale su [conversationsEverywhere].
  /// Chiave: [FavoriteFolder] (account + nome completo); valgono solo su questo computer.
  Map<FavoriteFolder, bool> conversationFolders = const {};

  /// La cartella [folder] di [account] si mostra come conversazioni?
  bool showsConversations(String account, String folder) =>
      conversationFolders[FavoriteFolder(account, folder)] ?? conversationsEverywhere;

  /// Accende o spegne le conversazioni nella sola cartella indicata, oppure ([folder] null) in tutte:
  /// allora le scelte fatte per le singole cartelle si cancellano, come "Tutte le cartelle" di Outlook.
  Future<void> setConversations(bool on, {String? account, String? folder}) async {
    if (account == null || folder == null) {
      conversationsEverywhere = on;
      conversationFolders = const {};
    } else {
      conversationFolders = {...conversationFolders, FavoriteFolder(account, folder): on};
    }
    notifyListeners();
    await _saveConversations();
  }

  /// Dopo una rinomina o uno spostamento di cartelle: le scelte seguono il nuovo nome ([rename]
  /// restituisce il nome nuovo, null se la cartella non è toccata).
  Future<void> renameConversationFolders(String account, String? Function(String folder) rename) async {
    var changed = false;
    final updated = <FavoriteFolder, bool>{};
    for (final MapEntry(:key, :value) in conversationFolders.entries) {
      final to = key.account == account ? rename(key.folder) : null;
      changed |= to != null && to != key.folder;
      updated[to == null ? key : FavoriteFolder(account, to)] = value;
    }
    if (!changed) return;
    conversationFolders = updated;
    notifyListeners();
    await _saveConversations();
  }

  Future<void> _saveConversations() => _store.write(
    _conversationsKey,
    jsonEncode({
      'all': conversationsEverywhere,
      'folders': [
        for (final MapEntry(:key, :value) in conversationFolders.entries) {...key.toJson(), 'on': value},
      ],
    }),
  );

  /// JSON {all, folders: [{account, folder, on}]}; mancante o illeggibile: spento ovunque.
  void _parseConversations(String? saved) {
    conversationsEverywhere = false;
    conversationFolders = const {};
    try {
      final json = jsonDecode(saved ?? '') as Map<String, dynamic>;
      conversationsEverywhere = json['all'] == true;
      conversationFolders = {
        for (final f in json['folders'] as List)
          if ((FavoriteFolder.fromJson(f), (f as Map)['on']) case (final FavoriteFolder key?, final bool on)) key: on,
      };
    } on Object {
      // file modificato a mano: si tiene quanto letto fin lì
    }
  }

  /// Riquadro di lettura: a destra (predefinito, com'era), in basso o disattivato (si apre a tutta finestra).
  ReadingPanePosition readingPane = ReadingPanePosition.right;

  /// Larghezza del riquadro cartelle e quota della lista nello spazio con il riquadro di lettura
  /// (larghezza se a destra, altezza se in basso), ricordate a parte per le due posizioni.
  double folderPaneWidth = defaultFolderWidth;
  double listFractionRight = 0.4;
  double listFractionBottom = 0.45;

  /// Righe di anteprima del testo nella lista: 0 (disattivata) – 3; predefinita 1, com'era.
  int previewLines = 1;

  /// Campo Ccn visibile nella composizione (Opzioni → Ccn, come Outlook); ricordato. Predefinito nascosto.
  bool showBcc = false;

  /// Calendario (K3): vista, settimana, orario lavorativo, colori e calendari nascosti; solo su questo computer.
  CalendarPrefs calendar = CalendarPrefs.defaults;

  /// Promemoria ignorati e rimandati (K5).
  ReminderState reminders = const ReminderState();

  Future<void> setReminders(ReminderState value) async {
    reminders = value;
    await _store.write(_remindersKey, jsonEncode(value.toJson()));
  }

  Future<void> setCalendar(CalendarPrefs value) async {
    calendar = value;
    notifyListeners();
    await _store.write(_calendarKey, jsonEncode(value.toJson()));
  }

  Future<void> setShowBcc(bool value) async {
    showBcc = value;
    notifyListeners();
    await _store.write(_showBccKey, '$value');
  }

  /// «Chiedi sempre la conferma di lettura» (R2): «Richiedi conferma di lettura» acceso nei nuovi messaggi.
  bool requestReadReceipt = false;

  /// Come rispondere alle richieste di conferma di lettura; predefinito «Chiedi ogni volta».
  ReceiptMode receiptMode = ReceiptMode.ask;

  /// Ignora conversazione (C2, 4a): chiedere conferma, finché non si spunta «Non visualizzare più questo messaggio».
  bool confirmIgnore = true;

  /// Come [confirmIgnore] per «Interrompi Ignora conversazione».
  bool confirmStopIgnoring = true;

  Future<void> setConfirmIgnore(bool value) async {
    confirmIgnore = value;
    notifyListeners();
    await _store.write(_confirmIgnoreKey, '$value');
  }

  Future<void> setConfirmStopIgnoring(bool value) async {
    confirmStopIgnoring = value;
    notifyListeners();
    await _store.write(_confirmStopIgnoringKey, '$value');
  }

  Future<void> setRequestReadReceipt(bool value) async {
    requestReadReceipt = value;
    notifyListeners();
    await _store.write(_requestReceiptKey, '$value');
  }

  Future<void> setReceiptMode(ReceiptMode mode) async {
    receiptMode = mode;
    notifyListeners();
    await _store.write(_receiptModeKey, mode.name);
  }

  /// Zoom del corpo delle mail nel riquadro di lettura, in percentuale (100 = normale), ricordato.
  int readingZoom = 100;

  /// [save] falso mentre si trascina il cursore: si salva solo al rilascio.
  Future<void> setReadingZoom(int percent, {bool save = true}) async {
    final value = percent.clamp(minZoom, maxZoom);
    if (value == readingZoom && !save) return;
    readingZoom = value;
    notifyListeners();
    if (save) await _store.write(_zoomKey, '$value');
  }

  /// Un passo in su ([steps] positivo) o in giù, sui multipli di [zoomStep] (da 105 si va a 110 o a 100).
  Future<void> zoomBy(int steps) {
    final base = steps > 0
        ? (readingZoom ~/ zoomStep) * zoomStep
        : ((readingZoom + zoomStep - 1) ~/ zoomStep) * zoomStep;
    return setReadingZoom(base + steps * zoomStep);
  }

  /// Tema scelto; predefinito quello del sistema.
  AppTheme theme = AppTheme.system;

  Future<void> setTheme(AppTheme value) async {
    if (value == theme) return;
    theme = value;
    notifyListeners();
    await _store.write(_themeKey, value.name);
  }

  /// Dove sta la barra dei moduli; predefinita a sinistra.
  ModuleBarPosition moduleBar = ModuleBarPosition.left;

  Future<void> setModuleBar(ModuleBarPosition value) async {
    if (value == moduleBar) return;
    moduleBar = value;
    notifyListeners();
    await _store.write(_moduleBarKey, value.name);
  }

  Future<void> setReadingPane(ReadingPanePosition position) async {
    readingPane = position;
    notifyListeners();
    await _store.write(_readingPaneKey, position.name);
  }

  Future<void> setPreviewLines(int lines) async {
    previewLines = lines.clamp(0, 3);
    notifyListeners();
    await _store.write(_previewLinesKey, '$previewLines');
  }

  /// Mentre si trascina un divisore ([save] falso) si ridisegna soltanto; al rilascio si salva.
  Future<void> setPaneLayout({double? folderWidth, double? listRight, double? listBottom, bool save = true}) async {
    if (folderWidth != null) folderPaneWidth = folderWidth.clamp(minFolderWidth, maxFolderWidth);
    if (listRight != null) listFractionRight = listRight.clamp(minListFraction, maxListFraction);
    if (listBottom != null) listFractionBottom = listBottom.clamp(minListFraction, maxListFraction);
    notifyListeners();
    if (save) {
      await _store.write(
        _layoutKey,
        jsonEncode({'folders': folderPaneWidth, 'listRight': listFractionRight, 'listBottom': listFractionBottom}),
      );
    }
  }

  void _parseLayout(String? saved) {
    try {
      final json = jsonDecode(saved ?? '') as Map<String, dynamic>;
      double? number(String key) => (json[key] as num?)?.toDouble();
      folderPaneWidth = (number('folders') ?? defaultFolderWidth).clamp(minFolderWidth, maxFolderWidth);
      listFractionRight = (number('listRight') ?? 0.4).clamp(minListFraction, maxListFraction);
      listFractionBottom = (number('listBottom') ?? 0.45).clamp(minListFraction, maxListFraction);
    } on Object {
      // mancante o modificato a mano: predefiniti
    }
  }

  /// Firme (3.7c), nell'ordine dell'elenco, e predefinite per account (id -> nuovi / risposte).
  List<Signature> signatures = const [];
  Map<String, SignatureDefaults> signatureDefaults = const {};

  Signature? signature(String? id) => id == null ? null : signatures.where((s) => s.id == id).firstOrNull;

  /// Firma da inserire per [account]: nuovi messaggi o ([reply]) risposte e inoltri; null = nessuna.
  Signature? defaultSignature(String? account, {required bool reply}) {
    final d = signatureDefaults[account] ?? SignatureDefaults.none;
    return signature(reply ? d.reply : d.newMessage);
  }

  /// Salva firme e predefinite insieme (finestra Firme, pulsante OK). Le predefinite che puntano a firme
  /// eliminate diventano "nessuna".
  Future<void> setSignatures(List<Signature> list, Map<String, SignatureDefaults> defaults) async {
    final ids = {for (final s in list) s.id};
    String? keep(String? id) => ids.contains(id) ? id : null;
    signatures = List.unmodifiable(list);
    signatureDefaults = {
      for (final MapEntry(:key, :value) in defaults.entries)
        if (SignatureDefaults(newMessage: keep(value.newMessage), reply: keep(value.reply)) case final d
            when d != SignatureDefaults.none)
          key: d,
    };
    notifyListeners();
    await _store.write(
      _signaturesKey,
      jsonEncode({
        'signatures': [for (final s in signatures) s.toJson()],
        'defaults': {for (final MapEntry(:key, :value) in signatureDefaults.entries) key: value.toJson()},
      }),
    );
  }

  /// JSON {signatures: [...], defaults: {account: {new, reply}}}; mancante o illeggibile: nessuna firma.
  void _parseSignatures(String? saved) {
    signatures = const [];
    signatureDefaults = const {};
    try {
      final json = jsonDecode(saved ?? '') as Map<String, dynamic>;
      signatures = [for (final s in json['signatures'] as List) ?Signature.fromJson(s)];
      signatureDefaults = {
        for (final MapEntry(:key, :value) in (json['defaults'] as Map<String, dynamic>).entries)
          key: SignatureDefaults.fromJson(value),
      };
    } on Object {
      // file modificato a mano: si tiene quanto letto fin lì
    }
  }

  /// Nome della categoria [number] (1–6).
  String categoryName(int number) => categoryNames[number - 1];

  Future<void> load() async {
    final saved = await _store.read(_notifyKey);
    notifyMode = NotifyMode.values.where((m) => m.name == saved).firstOrNull ?? NotifyMode.always;
    final savedRead = await _store.read(_readModeKey);
    readMode = ReadMode.values.where((m) => m.name == savedRead).firstOrNull ?? ReadMode.immediately;
    // Valore mancante, non numerico o fuori dai limiti (file modificato a mano): predefinito.
    final delay = int.tryParse(await _store.read(_readDelayKey) ?? '');
    readDelaySeconds = delay != null && delay >= minReadDelay && delay <= maxReadDelay ? delay : defaultReadDelay;
    // Id separati da virgola: contengono solo lettere, cifre, '-' e '_'.
    final collapsed = await _store.read(_collapsedKey) ?? '';
    collapsedAccounts = collapsed.split(',').where((id) => id.isNotEmpty).toSet();
    ribbonCollapsed = await _store.read(_ribbonKey) == 'true';
    final savedLayout = await _store.read(_ribbonLayoutKey);
    ribbonLayout = RibbonLayout.values.where((l) => l.name == savedLayout).firstOrNull ?? RibbonLayout.classic;
    categoryNames = _parseCategoryNames(await _store.read(_categoriesKey));
    favorites = _parseFavorites(await _store.read(_favoritesKey));
    favoritesCollapsed = await _store.read(_favoritesCollapsedKey) == 'true';
    _parseConversations(await _store.read(_conversationsKey));
    _parseSignatures(await _store.read(_signaturesKey));
    final pane = await _store.read(_readingPaneKey);
    readingPane = ReadingPanePosition.values.where((p) => p.name == pane).firstOrNull ?? ReadingPanePosition.right;
    _parseLayout(await _store.read(_layoutKey));
    previewLines = (int.tryParse(await _store.read(_previewLinesKey) ?? '') ?? 1).clamp(0, 3);
    showBcc = await _store.read(_showBccKey) == 'true';
    try {
      calendar = CalendarPrefs.fromJson(jsonDecode(await _store.read(_calendarKey) ?? '') as Map<String, dynamic>);
    } on Object {
      calendar = CalendarPrefs.defaults; // mancante o non valido
    }
    try {
      reminders = ReminderState.fromJson(jsonDecode(await _store.read(_remindersKey) ?? '') as Map<String, dynamic>);
    } on Object {
      reminders = const ReminderState();
    }
    requestReadReceipt = await _store.read(_requestReceiptKey) == 'true';
    confirmIgnore = await _store.read(_confirmIgnoreKey) != 'false';
    confirmStopIgnoring = await _store.read(_confirmStopIgnoringKey) != 'false';
    final savedReceipt = await _store.read(_receiptModeKey);
    receiptMode = ReceiptMode.values.where((m) => m.name == savedReceipt).firstOrNull ?? ReceiptMode.ask;
    readingZoom = (int.tryParse(await _store.read(_zoomKey) ?? '') ?? 100).clamp(minZoom, maxZoom);
    final savedTheme = await _store.read(_themeKey);
    theme = AppTheme.values.where((t) => t.name == savedTheme).firstOrNull ?? AppTheme.system;
    final savedBar = await _store.read(_moduleBarKey);
    moduleBar = ModuleBarPosition.values.where((p) => p.name == savedBar).firstOrNull ?? ModuleBarPosition.left;
    notifyListeners();
  }

  /// Elenco JSON di sei nomi; mancante o non valido (file modificato a mano): predefiniti, anche per i nomi vuoti.
  static List<String> _parseCategoryNames(String? saved) {
    try {
      final list = (jsonDecode(saved ?? '') as List).cast<String>();
      if (list.length != defaultCategoryNames.length) return defaultCategoryNames;
      return [for (final (i, name) in list.indexed) name.trim().isEmpty ? defaultCategoryNames[i] : name.trim()];
    } on Object {
      return defaultCategoryNames;
    }
  }

  /// Elenco JSON di {account, folder}; mancante -> null (predefiniti); voci non valide o doppie
  /// (file modificato a mano) ignorate; elenco illeggibile -> predefiniti.
  static List<FavoriteFolder>? _parseFavorites(String? saved) {
    if (saved == null) return null;
    try {
      final list = jsonDecode(saved) as List;
      return list.map(FavoriteFolder.fromJson).nonNulls.toSet().toList();
    } on Object {
      return null;
    }
  }

  /// Salva i Preferiti (da qui in poi niente più predefiniti, anche se l'elenco è vuoto).
  Future<void> setFavorites(List<FavoriteFolder> list) async {
    favorites = list.toSet().toList();
    notifyListeners();
    await _store.write(_favoritesKey, jsonEncode([for (final f in favorites!) f.toJson()]));
  }

  Future<void> setFavoritesCollapsed(bool collapsed) async {
    favoritesCollapsed = collapsed;
    notifyListeners();
    await _store.write(_favoritesCollapsedKey, '$collapsed');
  }

  Future<void> setCategoryNames(List<String> names) async {
    categoryNames = _parseCategoryNames(jsonEncode(names));
    notifyListeners();
    await _store.write(_categoriesKey, jsonEncode(categoryNames));
  }

  /// Classica o semplificata, per tutte le barre multifunzione (finestra principale, composizione, Appuntamento,
  /// finestra della mail).
  RibbonLayout ribbonLayout = RibbonLayout.classic;

  Future<void> setRibbonLayout(RibbonLayout value) async {
    if (value == ribbonLayout) return;
    ribbonLayout = value;
    notifyListeners();
    await _store.write(_ribbonLayoutKey, value.name);
  }

  Future<void> setRibbonCollapsed(bool collapsed) async {
    ribbonCollapsed = collapsed;
    notifyListeners();
    await _store.write(_ribbonKey, '$collapsed');
  }

  Future<void> setAccountExpanded(String id, bool expanded) async {
    final changed = expanded ? collapsedAccounts.remove(id) : collapsedAccounts.add(id);
    if (!changed) return;
    notifyListeners();
    await _store.write(_collapsedKey, collapsedAccounts.join(','));
  }

  Future<void> setReadMode(ReadMode mode) async {
    readMode = mode;
    notifyListeners();
    await _store.write(_readModeKey, mode.name);
  }

  /// [save] falso mentre si trascina il cursore: si salva solo al rilascio.
  Future<void> setReadDelay(int seconds, {bool save = true}) async {
    readDelaySeconds = seconds.clamp(minReadDelay, maxReadDelay);
    notifyListeners();
    if (save) await _store.write(_readDelayKey, '$readDelaySeconds');
  }

  Future<void> setNotifyMode(NotifyMode mode) async {
    notifyMode = mode;
    notifyListeners();
    await _store.write(_notifyKey, mode.name);
  }
}
