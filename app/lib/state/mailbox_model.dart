import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/account_info.dart';
import '../models/auto_reply.dart';
import '../models/conversation.dart';
import '../models/favorite_folder.dart';
import '../models/folder_change.dart';
import '../models/junk_options.dart';
import '../models/mail_folder.dart';
import '../models/mailbox_event.dart';
import '../models/message_detail.dart';
import '../models/message_header.dart';
import '../models/message_tags.dart';
import '../models/search_result.dart';
import '../models/send_result.dart';
import '../settings/app_settings.dart';

/// Filtro della lista, come in Outlook classico: "Tutti" o "Da leggere".
enum ListFilter { all, unread }

/// Colonna per cui è ordinata la lista (3.9, clic sull'intestazione come Outlook).
enum ListSort {
  date('Data'),
  from('Da'),
  subject('Oggetto'),
  size('Dimensione');

  const ListSort(this.label);

  final String label;
}

/// Dove cercare: nella cartella aperta (predefinito, come Outlook), in tutte le cartelle del suo
/// account o in tutti gli account.
enum SearchScope { folder, account, allAccounts }

/// Un risultato della ricerca con l'account in cui si trova (con "Tutti gli account" sono mescolati).
class FoundMessage {
  const FoundMessage(this.account, this.hit);

  final String account;
  final SearchHit hit;

  bool isAt(String? account, String? folder, int? uid) =>
      account == this.account && folder == hit.folder && uid == hit.uid;
}

/// Chiamata con le mail nuove di un account; [accountLabel] è il nome da mostrare quando gli
/// account sono più di uno (null con un solo account).
typedef NewMailCallback = void Function(List<MessageHeader> newMail, {required String account, String? accountLabel});

/// Stato delle caselle condiviso tra i pannelli. I widget lo leggono con
/// `context.watch<MailboxModel>()` e vengono ricostruiti a ogni notifyListeners().
///
/// Più account, una sola selezione: la lista mostra la cartella [selectedFolder] dell'account
/// [selectedAccount], oppure i risultati di una ricerca ([searchActive]). La mail aperta nel
/// pannello di lettura sta in [openAccount]/[openFolder]: di solito la cartella selezionata, ma un
/// risultato della ricerca può stare in un'altra cartella o in un altro account.
class MailboxModel extends ChangeNotifier {
  /// [settings] decide quando una mail aperta diventa letta; null = subito (test).
  MailboxModel(this._api, {this._settings});

  static const pageSize = 50;

  final ApiClient _api;
  final AppSettings? _settings;

  /// Attesa prima di segnare come letta la mail aperta (modalità "dopo N secondi").
  Timer? _readTimer;

  // --- account e cartelle ---
  List<AccountInfo> accounts = const [];

  /// Cartelle di ogni account (id -> elenco); manca la voce se il caricamento non è riuscito.
  Map<String, List<MailFolder>> foldersByAccount = const {};

  /// Errore nel caricare le cartelle di un account (id -> messaggio).
  Map<String, String> folderErrors = const {};
  bool loadingFolders = false;

  /// Errore nel caricare l'elenco degli account (core non raggiungibile).
  String? foldersError;

  // --- messaggi della cartella selezionata ---
  String? selectedAccount;
  String? selectedFolder;
  List<MessageHeader> messages = const [];
  int total = 0;
  bool loadingMessages = false;
  String? messagesError;

  // --- messaggio aperto nel pannello di lettura ---
  String? _openAccount;
  String? _openFolder;

  /// Account e cartella della mail aperta (senza mail aperta: quelli selezionati).
  String? get openAccount => _openAccount ?? selectedAccount;
  String? get openFolder => _openFolder ?? selectedFolder;
  int? selectedUid;
  MessageDetail? detail;
  bool loadingDetail = false;
  String? detailError;

  bool get multipleAccounts => accounts.length > 1;

  /// Raggiungibilità del server per account (dal core: GET /accounts ed eventi "connection-status");
  /// manca la voce = raggiungibile.
  Map<String, bool> onlineStatus = const {};

  /// Il server di [account] risponde? Senza: si mostra la copia sul computer e le modifiche sono disattivate.
  bool isOnline(String? account) => onlineStatus[account ?? accounts.firstOrNull?.id] ?? true;

  /// Account il cui server non è raggiungibile, nell'ordine dell'elenco (barra "Non connesso").
  List<AccountInfo> get offlineAccounts => [
    for (final a in accounts)
      if (!isOnline(a.id)) a,
  ];

  /// OAuth2 (2a): account il cui accesso è scaduto o revocato (da GET /accounts ed eventi "login-status").
  Map<String, bool> loginStatus = const {};

  /// Il fornitore ha rifiutato il token di rinnovo di [account]: serve «Accedi di nuovo».
  bool needsLogin(String? account) => loginStatus[account ?? accounts.firstOrNull?.id] ?? false;

  /// Messaggio per le operazioni che richiedono il server (letto, sposta, elimina, invio).
  static const offlineMessage = 'Non disponibile senza connessione al server.';

  AccountInfo? get currentAccount => accounts.where((a) => a.id == selectedAccount).firstOrNull;

  /// Account della mail aperta (per il pannello di lettura: mittente delle risposte).
  AccountInfo? get openAccountInfo => accounts.where((a) => a.id == openAccount).firstOrNull;

  /// Cartelle dell'account della mail aperta (destinazioni di "Sposta").
  List<MailFolder> get openAccountFolders => foldersByAccount[openAccount] ?? const [];

  /// Client delle richieste sulla mail aperta (risposte, allegati).
  ApiClient get accountApi => openAccount == null ? _api : _api.forAccount(openAccount!);

  ApiClient _apiFor(String account) => _api.forAccount(account);

  /// La selezione è ancora questa? (risposte arrivate dopo un cambio di account o cartella vanno scartate)
  bool _isAt(String account, String folder) => account == selectedAccount && folder == selectedFolder;

  /// Collegata alle notifiche di sistema in PostinoVipApp.
  NewMailCallback? onNewMail;

  // UID più alto già visto in INBOX, per account: le mail presenti all'avvio non generano notifiche.
  final _inboxBaselines = <String, int>{};
  final _inboxChecks = <String, Timer>{};
  final _folderRefresh = <String, Timer>{};

  static bool _isInbox(String? folder) => folder?.toUpperCase() == 'INBOX';

  String? _labelFor(String account) =>
      multipleAccounts ? accounts.where((a) => a.id == account).firstOrNull?.name : null;

  /// Confronta la prima pagina di INBOX con quanto già visto; la prima volta fissa solo il punto di partenza.
  void _detectNewMail(String account, List<MessageHeader> firstPage) {
    if (firstPage.isEmpty) return;
    final maxUid = firstPage.map((m) => m.uid).reduce((a, b) => a > b ? a : b);
    final baseline = _inboxBaselines[account];
    _inboxBaselines[account] = baseline == null || maxUid > baseline ? maxUid : baseline;
    if (baseline == null) {
      debugPrint(
        '[notifiche] $account INBOX: punto di partenza UID $maxUid (le mail già presenti non vengono notificate)',
      );
      return;
    }
    final fresh = firstPage.where((m) => m.uid > baseline && !m.seen).toList();
    if (maxUid > baseline) {
      // Solo UID, mai mittente od oggetto.
      debugPrint(
        '[notifiche] $account INBOX: UID oltre $baseline: ${firstPage.where((m) => m.uid > baseline).map((m) => m.uid).toList()}, '
        'di cui non lette ${fresh.map((m) => m.uid).toList()}${onNewMail == null ? ' (notifiche non collegate)' : ''}',
      );
    }
    if (fresh.isNotEmpty) onNewMail?.call(fresh, account: account, accountLabel: _labelFor(account));
  }

  /// INBOX di [account] non è la cartella aperta: la si interroga solo per sapere se è arrivato qualcosa.
  Future<void> _checkInbox(String account) async {
    if (_disposed) return;
    try {
      final page = await _apiFor(account).getMessages('INBOX', offset: 0, limit: 10);
      if (!_disposed) _detectNewMail(account, page.items);
    } on ApiException {
      // Nessuna notifica: la lista si aggiornerà comunque aprendo INBOX.
    }
  }

  /// Aggiornamento automatico (IDLE nel core) per account: true attivo, false non attivo;
  /// manca la voce se lo stato non è (ancora) noto.
  Map<String, bool> watchStatus = const {};

  StreamSubscription<MailboxEvent>? _events;
  Timer? _reconnect;
  Timer? _debounce;
  Duration _backoff = const Duration(seconds: 2);
  bool _disposed = false;

  /// Si iscrive agli eventi del core (tutti gli account) e si riconnette da solo se la connessione cade.
  void startWatching() {
    if (_disposed || _events != null) return;
    _events = _api.events().listen(
      _onEvent,
      onError: (Object e) => _eventsEnded(retry: !(e is ApiException && e.statusCode == 404)),
      onDone: () => _eventsEnded(retry: true),
      cancelOnError: true,
    );
  }

  void _eventsEnded({required bool retry}) {
    _events = null;
    if (_disposed) return;
    // Senza eventi nessun account si aggiorna da solo; 404: core senza eventi, nessuna icona.
    watchStatus = retry ? {for (final a in accounts) a.id: false} : const {};
    notifyListeners();
    if (!retry) return;
    _reconnect = Timer(_backoff, startWatching);
    _backoff = _backoff * 2 > const Duration(seconds: 30) ? const Duration(seconds: 30) : _backoff * 2;
  }

  void _onEvent(MailboxEvent e) {
    _backoff = const Duration(seconds: 2);
    // Core precedente al multi-account: eventi senza account = primo account.
    final account = e.account ?? accounts.firstOrNull?.id;
    if (account == null) return;
    if (e.type == 'credentials-changed' && e.account != null && e.refreshToken != null) {
      onCredentialsChanged?.call(e.account!, e.refreshToken!);
      return;
    }
    if (e.type == 'contacts-changed') {
      onContactsChanged?.call(account);
      return;
    }
    if (e.type == 'calendars-changed') {
      onCalendarsChanged?.call(account);
      return;
    }
    if (e.type == 'watch-status') {
      watchStatus = {...watchStatus, account: e.connected ?? false};
      notifyListeners();
    } else if (e.type == 'login-status' && e.needsLogin != null) {
      loginStatus = {...loginStatus, account: e.needsLogin!};
      notifyListeners();
    } else if (e.type == 'connection-status' && e.online != null) {
      final wasOnline = isOnline(account);
      onlineStatus = {...onlineStatus, account: e.online!};
      notifyListeners();
      // Server di nuovo raggiungibile: cartelle e lista aperta tornano aggiornate dal server.
      if (e.online! && !wasOnline) {
        unawaited(loadAccountFolders(account));
        if (account == selectedAccount) unawaited(_refreshTop());
      }
    } else if (e.type == 'folder-synced' && e.folder != null) {
      // Prima sincronizzazione di una cartella grande completata in background (11/11/2026, 1a): la lista aperta
      // aveva solo le mail più recenti; si rilegge (totale e pagine successive).
      if (_isAt(account, e.folder!)) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), _refreshTop);
      }
    } else if (e.type == 'outbox-changed') {
      unawaited(loadOutbox(account));
      unawaited(_refreshFolderCounts(account)); // inviata: una copia in più in Posta inviata, una bozza in meno
    } else if (e.type == 'mailbox-changed' && e.folder != null) {
      final folders = foldersByAccount[account] ?? const [];
      final previous = folders.where((f) => f.fullName == e.folder).firstOrNull?.count;
      foldersByAccount = {
        ...foldersByAccount,
        account: [for (final f in folders) f.fullName == e.folder ? f.withCount(e.count) : f],
      };
      notifyListeners();
      // Il numero delle da leggere non arriva con l'evento: si rilegge l'elenco delle cartelle
      // dell'account (STATUS di tutte, pochi centesimi di secondo), una volta per gruppo di eventi.
      _folderRefresh[account]?.cancel();
      _folderRefresh[account] = Timer(const Duration(milliseconds: 300), () => _refreshFolderCounts(account));
      if (_isAt(account, e.folder!)) {
        // Più notifiche ravvicinate (es. arrivo di più mail) -> un solo aggiornamento.
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), _refreshTop);
      } else if (_isInbox(e.folder) && (previous == null || (e.count ?? 0) > previous)) {
        _inboxChecks[account]?.cancel();
        _inboxChecks[account] = Timer(const Duration(milliseconds: 300), () => _checkInbox(account));
      }
    }
  }

  /// Riscarica la prima pagina e la confronta con la lista: nuove in cima, stato letto aggiornato,
  /// rimosse (da altri client) tolte. Le pagine più vecchie già caricate restano come sono.
  Future<void> _refreshTop() async {
    final account = selectedAccount;
    final folder = selectedFolder;
    if (account == null || folder == null || _disposed || folder == outboxFolder) return;
    if (!_defaultView || conversationView) return _reloadVisible(account, folder);
    try {
      final page = await _apiFor(account).getMessages(folder, offset: 0, limit: pageSize);
      if (_disposed || !_isAt(account, folder)) return;
      if (_isInbox(folder)) _detectNewMail(account, page.items);

      final byUid = {for (final m in page.items) m.uid: m};
      final known = {for (final m in messages) m.uid};
      final oldestInPage = page.items.isEmpty ? null : page.items.last.uid;
      final fresh = page.items.where((m) => !known.contains(m.uid)).toList();
      final kept = [
        for (final m in messages)
          if (byUid[m.uid] case final updated?)
            updated
          else if (oldestInPage == null || m.uid < oldestInPage)
            m, // fuori dalla prima pagina: non verificabile, si tiene
      ];
      messages = [...fresh, ...kept];
      total = page.total;
      final openHere = openAccount == account && openFolder == folder;
      if (openHere && !searchActive && selectedUid != null && !messages.any((m) => m.uid == selectedUid)) {
        _clearDetail();
      }
      notifyListeners();
    } on ApiException {
      // Aggiornamento automatico non riuscito: resta "Aggiorna" manuale.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _events?.cancel();
    _reconnect?.cancel();
    _debounce?.cancel();
    for (final t in [..._inboxChecks.values, ..._folderRefresh.values]) {
      t.cancel();
    }
    _readTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  /// Sposta/elimina in corso: i pulsanti vengono disabilitati per evitare doppi clic.
  bool actionInProgress = false;

  /// Cartella selezionata con i suoi metadati (conteggi per la barra di stato).
  MailFolder? get selectedFolderInfo =>
      (foldersByAccount[selectedAccount] ?? const <MailFolder>[]).where((f) => f.fullName == selectedFolder).firstOrNull;

  /// Cartella della mail aperta con i suoi metadati (ruolo SPECIAL-USE).
  MailFolder? get openFolderInfo => openAccountFolders.where((f) => f.fullName == openFolder).firstOrNull;

  /// Nella cartella con ruolo \Trash "Elimina" diventa eliminazione definitiva.
  bool get inTrash => openFolderInfo?.specialUse == 'trash';

  /// Ultimo errore di un'operazione di scrittura (es. segna come letto), mostrato nel pannello di lettura.
  String? actionError;

  /// Cartelle in cui non si risponde mai a una richiesta di conferma di lettura (come il core: 409).
  static const _noReceiptRoles = {'junk', 'sent', 'drafts', 'outbox'};

  /// Risposte già date in questa sessione (account|cartella|uid): mai due volte, anche se il core non risponde.
  final Set<String> _receiptsAnswered = {};

  /// La mail aperta chiede una conferma di lettura a cui non si è ancora risposto (R2).
  bool get receiptRequested {
    final d = detail;
    return d != null &&
        d.receiptTo != null &&
        !d.receiptHandled &&
        !multiSelection &&
        !_noReceiptRoles.contains(openFolderInfo?.role) &&
        !_receiptsAnswered.contains('$openAccount|$openFolder|${d.uid}');
  }

  /// Risposta alla richiesta di conferma della mail aperta: con [send] la conferma parte (INVIO), in ogni caso la
  /// mail diventa $MDNSent sul server (MODIFICA). [automatic]: per «Invia sempre» / «Non inviare mai».
  Future<void> answerReceipt({required bool send, bool automatic = false}) async {
    final (account, folder, current) = (openAccount, openFolder, detail);
    if (folder == null || current == null) return;
    final key = '$account|$folder|${current.uid}';
    if (!_receiptsAnswered.add(key)) return;
    notifyListeners(); // la striscia sparisce subito
    void handled() {
      if (openAccount == account && openFolder == folder && detail?.uid == current.uid) {
        detail = detail!.copyWith(receiptHandled: true);
      }
    }

    try {
      await accountApi.answerReadReceipt(folder, current.uid, send: send, automatic: automatic);
      handled();
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        handled(); // già trattata (anche da un altro computer) o non più valida: niente da chiedere
      } else {
        _receiptsAnswered.remove(key);
        actionError = 'Conferma di lettura ${send ? 'non inviata' : 'non registrata'}: $e';
      }
    }
    notifyListeners();
  }

  bool get hasMore => (conversationView ? conversations.length : messages.length) < total;

  // ---------------------------------------------------------------------------------------------
  // Conversazioni (3.6). Con la vista attiva la lista è fatta di [conversations] (pagine del core,
  // [total] = numero di conversazioni) e [messages] contiene le loro mail che stanno nella cartella
  // aperta, nello stesso ordine: così letto, contrassegni, sposta ed elimina funzionano come prima.
  // ---------------------------------------------------------------------------------------------

  /// La cartella selezionata si mostra come conversazioni (deciso all'apertura dalle impostazioni).
  bool conversationView = false;
  List<Conversation> conversations = const [];

  /// Conversazioni aperte con il triangolo (si richiudono cambiando cartella).
  Set<int> expandedConversations = const {};

  /// Riga di conversazione selezionata: le mail selezionate sono quelle della conversazione nella
  /// cartella e nel riquadro di lettura c'è la più recente (scelta 3.6-4a).
  int? selectedConversation;

  /// La tastiera è sulla riga della conversazione [cursorConversation] (non su una sua mail).
  int? cursorConversation;
  int? _anchorConversation;

  bool _wantsConversations(String account, String folder) =>
      folder != outboxFolder && (_settings?.showsConversations(account, folder) ?? false);

  // ---------------------------------------------------------------------------------------------
  // Posta in uscita (3.8): sul computer, una per account, mostrata come cartella in fondo all'albero.
  // ---------------------------------------------------------------------------------------------

  /// Nome della cartella virtuale "Posta in uscita" (non può essere il nome di una cartella del server).
  static const outboxFolder = '\u0000outbox';

  bool get showingOutbox => selectedFolder == outboxFolder;

  /// Mail in attesa per account; manca la voce se il core non ha la Posta in uscita (senza cache locale).
  Map<String, List<OutboxEntry>> outboxByAccount = const {};

  List<OutboxEntry> get outboxItems => outboxByAccount[selectedAccount] ?? const [];

  Future<void> loadOutbox(String account) async {
    try {
      final list = await _apiFor(account).getOutbox();
      if (_disposed) return;
      outboxByAccount = {...outboxByAccount, account: list};
      if (showingOutbox && selectedAccount == account) total = list.length;
      notifyListeners();
    } on ApiException {
      // Core senza Posta in uscita (501) o non raggiungibile: niente cartella, o l'elenco di prima.
    }
  }

  /// Dopo la composizione (salvataggi, invio, Posta in uscita): conteggi, Posta in uscita e, se aperta,
  /// la lista di Bozze o Posta inviata dell'account, che non hanno l'aggiornamento automatico.
  Future<void> mailboxTouched(String account) async {
    await _refreshFolderCounts(account);
    await loadOutbox(account);
    final folder = selectedFolder;
    if (account != selectedAccount || folder == null || showingOutbox || searchActive) return;
    if (_roleOf(account, folder) case 'drafts' || 'sent') await _reloadVisible(account, folder);
  }

  Future<({bool ok, String message})> _outboxAction(String account, Future<void> Function(ApiClient api) action, String done) async {
    try {
      await action(_apiFor(account));
      await loadOutbox(account);
      return (ok: true, message: done);
    } on ApiException catch (e) {
      await loadOutbox(account);
      return (ok: false, message: e.statusCode == 503 ? offlineMessage : 'Operazione non riuscita: ${_refusal(e)}');
    }
  }

  /// "Invia ora": niente più attesa (né errore precedente); parte appena il server risponde.
  Future<({bool ok, String message})> outboxSendNow(String account, String id) =>
      _outboxAction(account, (api) => api.sendOutboxNow(id), 'Invio in corso: la mail parte appena il server risponde.');

  /// La mail non verrà inviata (chi chiama ha chiesto conferma).
  Future<({bool ok, String message})> outboxDelete(String account, String id) =>
      _outboxAction(account, (api) => api.deleteOutbox(id), 'Mail eliminata dalla Posta in uscita: non verrà inviata.');

  /// MODIFICA la casella: la mail torna in Bozze per modificarla.
  Future<({bool ok, String message})> outboxToDrafts(String account, String id) async {
    final outcome = await _outboxAction(account, (api) => api.outboxToDrafts(id), 'Mail spostata in Bozze: aprila da lì per modificarla.');
    await _refreshFolderCounts(account);
    return outcome;
  }

  /// "Mostra come conversazioni" (Visualizza): accende o spegne la vista nella cartella aperta o, con
  /// [allFolders], in tutte (scelta 3.6-3a); la lista si ricarica, la mail aperta resta aperta.
  Future<void> setConversationView(bool on, {required bool allFolders}) async {
    final account = selectedAccount;
    final folder = selectedFolder;
    final settings = _settings;
    if (account == null || folder == null || settings == null) return;
    await settings.setConversations(on, account: allFolders ? null : account, folder: allFolders ? null : folder);
    await _changeView(() {});
  }

  void toggleConversation(int id) {
    expandedConversations = expandedConversations.contains(id)
        ? ({...expandedConversations}..remove(id))
        : {...expandedConversations, id};
    notifyListeners();
  }

  /// Le mail della conversazione [c] che stanno nella cartella aperta.
  Set<MessageRef> conversationRefs(Conversation c) {
    final account = selectedAccount;
    final folder = selectedFolder;
    if (account == null || folder == null) return const {};
    return {for (final m in c.inFolder(folder)) MessageRef(account, folder, m.uid)};
  }

  void _deriveMessages() {
    final folder = selectedFolder;
    messages = folder == null ? const [] : [for (final c in conversations) ...c.inFolder(folder)];
  }

  /// Cambia le intestazioni [uids] di [folder] (letto, contrassegni) nella lista o nelle conversazioni.
  void _patchHeaders(String account, String folder, Set<int> uids, MessageHeader Function(MessageHeader m) change) {
    if (account != selectedAccount) return;
    if (conversationView) {
      conversations = [for (final c in conversations) c.patch(folder, uids, change)];
      _deriveMessages();
    } else if (folder == selectedFolder) {
      messages = [for (final m in messages) uids.contains(m.uid) ? change(m) : m];
    }
  }

  /// Toglie le mail [uids] di [folder] (spostate o eliminate). Una conversazione senza più mail nella
  /// cartella aperta sparisce dalla lista. Una mail spostata in un'altra cartella della stessa
  /// conversazione ricompare al prossimo aggiornamento (il nuovo UID lo sa solo il server).
  void _dropHeaders(String account, String folder, Set<int> uids) {
    final open = selectedFolder;
    if (account != selectedAccount || open == null) return;
    if (conversationView) {
      final before = conversations.length;
      conversations = [
        for (final c in conversations)
          if (c.without(folder, uids) case final rest when rest.headIn(open) != null) rest,
      ];
      total = (total - (before - conversations.length)).clamp(0, 1 << 30);
      _deriveMessages();
    } else if (folder == open) {
      final before = messages.length;
      messages = messages.where((m) => !uids.contains(m.uid)).toList();
      total = (total - (before - messages.length)).clamp(0, 1 << 30);
    }
  }

  /// Stato letto/non letto della mail [uid] della cartella aperta secondo la lista o i risultati
  /// della ricerca (null se non è tra quelli caricati).
  bool? isSeen(int uid) {
    if (searchActive) {
      return searchResults.where((r) => r.isAt(openAccount, openFolder, uid)).firstOrNull?.hit.seen;
    }
    final account = openAccount;
    final folder = openFolder;
    if (account == null || folder == null) return null;
    return _headerOf(MessageRef(account, folder, uid))?.seen;
  }

  // Incrementato a ogni cambio cartella: le risposte arrivate in ritardo
  // per una cartella non più selezionata vengono scartate.
  int _generation = 0;
  int _detailGeneration = 0;

  /// Carica l'elenco degli account e le cartelle di ognuno; la prima volta apre INBOX del primo account.
  Future<void> loadFolders() async {
    loadingFolders = true;
    foldersError = null;
    notifyListeners();

    try {
      accounts = await _api.getAccounts();
      onlineStatus = {for (final a in accounts) a.id: a.online};
      loginStatus = {for (final a in accounts) a.id: a.needsLogin};
      unawaited(loadAutoReplies());
    } on ApiException catch (e) {
      foldersError = e.toString();
      loadingFolders = false;
      notifyListeners();
      return;
    }

    // In parallelo: ogni account ha la sua connessione nel core.
    final results = await Future.wait(
      accounts.map((a) async {
        try {
          return (id: a.id, folders: await _apiFor(a.id).getFolders(), error: null);
        } on ApiException catch (e) {
          return (id: a.id, folders: null, error: e.toString());
        }
      }),
    );
    foldersByAccount = {
      for (final r in results)
        if (r.folders != null) r.id: r.folders!,
    };
    folderErrors = {
      for (final r in results)
        if (r.error != null) r.id: r.error!,
    };
    loadingFolders = false;
    notifyListeners();

    if (selectedFolder == null) {
      // INBOX del primo account le cui cartelle sono state caricate.
      for (final a in accounts) {
        final folders = foldersByAccount[a.id];
        if (folders == null || folders.isEmpty) continue;
        final inbox = folders.where((f) => _isInbox(f.fullName)).firstOrNull ?? folders.first;
        await selectFolder(inbox.fullName, account: a.id);
        break;
      }
    }

    for (final a in accounts) {
      unawaited(loadOutbox(a.id));
    }

    // Punto di partenza della posta nuova anche per gli account di cui non è aperta INBOX:
    // altrimenti la prima mail arrivata lì servirebbe solo a fissarlo e non verrebbe notificata.
    for (final a in accounts) {
      final hasInbox = (foldersByAccount[a.id] ?? const <MailFolder>[]).any((f) => _isInbox(f.fullName));
      if (hasInbox && !(a.id == selectedAccount && _isInbox(selectedFolder))) unawaited(_checkInbox(a.id));
    }
  }

  /// Riprova a caricare le cartelle di un solo account (dopo un errore).
  Future<void> loadAccountFolders(String account) async {
    folderErrors = {...folderErrors}..remove(account);
    notifyListeners();
    try {
      final folders = await _apiFor(account).getFolders();
      foldersByAccount = {...foldersByAccount, account: folders};
    } on ApiException catch (e) {
      folderErrors = {...folderErrors, account: e.toString()};
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------------------------
  // Cartelle (3.4b): nuova, rinomina, elimina. MODIFICANO la casella.
  // ---------------------------------------------------------------------------------------------

  /// Cartella in modifica nell'albero (una alla volta): rinomina oppure nuova cartella.
  FolderEdit? folderEdit;

  /// Motivo per cui l'ultima conferma non è riuscita (mostrato sotto la casella di testo).
  String? folderEditError;

  /// Avviso dopo una creazione riuscita (es. cartella confermata ma non elencata dal server); lo mostra chi l'ha chiesta.
  String? folderNotice;

  String? takeFolderNotice() {
    final notice = folderNotice;
    folderNotice = null;
    return notice;
  }
  bool folderEditBusy = false;

  /// Cartella su cui si possono usare Rinomina ed Elimina: senza ruolo e con il server raggiungibile.
  /// Il core rifiuta comunque anche quelle che contengono una cartella con ruolo.
  bool canEditFolder(String account, MailFolder folder) => folder.role == null && isOnline(account);

  /// La cartella è dentro Posta eliminata: "Elimina" diventa definitivo.
  bool isInTrash(String account, MailFolder folder) {
    final trash = (foldersByAccount[account] ?? const <MailFolder>[]).where((f) => f.role == 'trash').firstOrNull;
    final separator = folder.separator;
    return trash != null && separator != null && folder.fullName.startsWith('${trash.fullName}$separator');
  }

  /// Nuova cartella dentro [parent] (null = in cima all'account): compare una riga da scrivere (scelta 3.4-2b).
  void startNewFolder(String account, String? parent) {
    if (!isOnline(account)) {
      folderLog('nuova cartella in $account: account non raggiungibile, niente da fare');
      return;
    }
    folderLog('nuova cartella in $account dentro ${parent ?? '(cima dell\'account)'}: casella del nome aperta');
    folderEdit = FolderEdit(account, parent: parent);
    folderEditError = null;
    notifyListeners();
  }

  /// Rinomina nell'albero (scelta 3.4-3a): il nome diventa una casella di testo.
  void startRenameFolder(String account, String folder) {
    final info = (foldersByAccount[account] ?? const <MailFolder>[]).where((f) => f.fullName == folder).firstOrNull;
    if (info == null || !canEditFolder(account, info)) return;
    folderEdit = FolderEdit(account, folder: folder);
    folderEditError = null;
    notifyListeners();
  }

  void cancelFolderEdit({String reason = 'annullata'}) {
    if (folderEdit == null || folderEditBusy) return;
    folderLog('modifica della cartella annullata ($reason): nessuna richiesta al server');
    folderEdit = null;
    folderEditError = null;
    notifyListeners();
  }

  /// Conferma la modifica in corso con il nome [name]. false se il core la rifiuta (motivo in
  /// [folderEditError], la casella resta aperta per correggere).
  Future<bool> commitFolderEdit(String name) async {
    final edit = folderEdit;
    if (edit == null || folderEditBusy) return false;
    folderEditBusy = true;
    folderEditError = null;
    notifyListeners();
    try {
      final api = _apiFor(edit.account);
      String? created;
      if (edit.isNew) {
        folderLog('richiesta al core: nuova cartella «$name» dentro ${edit.parent ?? '(cima)'} in ${edit.account}');
        created = (await api.createFolder(edit.parent, name)).fullName;
        folderLog('il core ha confermato: «$created»');
      } else {
        final change = await api.renameFolder(edit.folder!, name);
        _followRename(edit.account, edit.folder!, change.fullName, change.separator);
      }
      folderEdit = null;
      await _refreshFolderCounts(edit.account);
      // Il server può confermare la creazione e poi non elencare la cartella: va detto, non taciuto.
      if (created != null && !(foldersByAccount[edit.account] ?? const <MailFolder>[]).any((f) => f.fullName == created)) {
        folderLog('«$created» non è nell\'elenco delle cartelle restituito dal server');
        folderNotice = 'Il server ha confermato la cartella «$created», ma non la mostra nell\'elenco delle cartelle.';
      }
      return true;
    } on ApiException catch (e) {
      folderLog('modifica della cartella non riuscita: HTTP ${e.statusCode}');
      folderEditError = e.statusCode == 503
          ? offlineMessage
          : (e.fieldErrors['name']?.join(' ') ?? (e.statusCode == 409 ? e.message.split(': ').last : '$e'));
      return false;
    } finally {
      folderEditBusy = false;
      notifyListeners();
    }
  }

  /// "Elimina cartella" (scelta 3.4-3a): fuori da Posta eliminata la sposta lì dentro, dentro Posta
  /// eliminata la elimina definitivamente (chi chiama deve aver chiesto conferma). Testo dell'esito.
  Future<({bool ok, String message})> deleteFolder(String account, MailFolder folder) async {
    if (actionInProgress) return (ok: false, message: 'Un\'altra operazione è in corso');
    actionInProgress = true;
    notifyListeners();
    try {
      final result = await _apiFor(account).deleteFolder(folder.fullName);
      if (result.movedTo case final movedTo?) {
        _followRename(account, folder.fullName, movedTo, result.separator);
      } else {
        _forgetFolder(account, folder.fullName, result.separator);
      }
      await _refreshFolderCounts(account);
      return result.permanent
          ? (ok: true, message: 'Cartella "${folder.name}" eliminata definitivamente')
          : (ok: true, message: 'Cartella "${folder.name}" spostata in Posta eliminata');
    } on ApiException catch (e) {
      return (ok: false, message: e.statusCode == 503 ? offlineMessage : 'Cartella non eliminata: $e');
    } finally {
      actionInProgress = false;
      notifyListeners();
    }
  }

  /// "Svuota cartella" (12/11/2026, scelta 3a) come il tasto destro di Outlook: solo Posta eliminata e Posta
  /// indesiderata, con la connessione.
  bool canEmptyFolder(String account, MailFolder folder) =>
      !actionInProgress && isOnline(account) && (folder.role == 'trash' || folder.role == 'junk');

  /// Sottocartelle di [folder] (tutti i livelli) note all'app.
  List<MailFolder> subfoldersOf(String account, MailFolder folder) {
    final separator = folder.separator ?? _separatorOf(account);
    if (separator == null) return const [];
    return [
      for (final f in foldersByAccount[account] ?? const <MailFolder>[])
        if (f.fullName.startsWith('${folder.fullName}$separator')) f,
    ];
  }

  /// MODIFICA la casella, NON reversibile: elimina definitivamente le mail di [folder] e, in Posta eliminata, le
  /// sottocartelle. Chi chiama ha già chiesto conferma.
  Future<({bool ok, String message})> emptyFolder(String account, MailFolder folder) async {
    if (actionInProgress) return (ok: false, message: 'Un\'altra operazione è in corso');
    actionInProgress = true;
    notifyListeners();
    try {
      final result = await _apiFor(account).emptyFolder(folder.fullName);
      for (final removed in result.removedFolders) {
        _forgetFolder(account, removed, result.separator);
      }
      await _refreshFolderCounts(account);
      if (selectedAccount == account && selectedFolder == folder.fullName) {
        await selectFolder(folder.fullName, account: account);
      }
      final mails = result.messages == 1 ? '1 mail eliminata' : '${result.messages} mail eliminate';
      final folders = switch (result.removedFolders.length) {
        0 => '',
        1 => ' e 1 cartella',
        final n => ' e $n cartelle',
      };
      return (ok: true, message: '"${folder.name}" svuotata: $mails$folders definitivamente');
    } on ApiException catch (e) {
      return (ok: false, message: e.statusCode == 503 ? offlineMessage : 'Cartella non svuotata: $e');
    } finally {
      actionInProgress = false;
      notifyListeners();
    }
  }

  /// Cartella madre di [folder] (null se è in cima all'account).
  static String? parentOf(MailFolder folder) {
    final separator = folder.separator;
    return separator == null ? null : folder.fullName.substring(0, folder.fullName.lastIndexOf(separator));
  }

  /// Trascinamento di una cartella (3.5c): [folder] di [fromAccount] può andare dentro [newParent] di
  /// [toAccount] (null = in cima)? Solo nello stesso account, cartelle senza ruolo, mai dentro sé stessa o
  /// una sua sottocartella, e non dove è già. Il core rifiuta comunque quelle che contengono una cartella
  /// con ruolo e i nomi già usati.
  bool canMoveFolder(String fromAccount, MailFolder folder, String toAccount, String? newParent) {
    if (fromAccount != toAccount || actionInProgress || !canEditFolder(fromAccount, folder)) return false;
    if (parentOf(folder) == newParent) return false;
    final separator = folder.separator ?? _separatorOf(fromAccount);
    return newParent == null ||
        (newParent != folder.fullName && (separator == null || !newParent.startsWith('${folder.fullName}$separator')));
  }

  /// Separatore della gerarchia dell'account (da una cartella annidata qualsiasi; null se non si vede).
  String? _separatorOf(String account) =>
      (foldersByAccount[account] ?? const <MailFolder>[]).map((f) => f.separator).nonNulls.firstOrNull;

  /// MODIFICA la casella: sposta [folder] (con mail e sottocartelle) dentro [newParent] (null = in cima).
  /// Preferiti e cartella aperta seguono il nuovo nome. Testo dell'esito.
  Future<({bool ok, String message})> moveFolder(String account, MailFolder folder, String? newParent) async {
    if (actionInProgress) return (ok: false, message: 'Un\'altra operazione è in corso');
    actionInProgress = true;
    notifyListeners();
    try {
      final change = await _apiFor(account).moveFolder(folder.fullName, newParent);
      _followRename(account, folder.fullName, change.fullName, change.separator);
      await _refreshFolderCounts(account);
      final where = newParent == null
          ? 'in cima all\'account'
          : 'in "${(foldersByAccount[account] ?? const <MailFolder>[]).where((f) => f.fullName == newParent).firstOrNull?.name ?? newParent}"';
      return (ok: true, message: 'Cartella "${folder.name}" spostata $where');
    } on ApiException catch (e) {
      final reason = e.statusCode == 503
          ? offlineMessage
          : (e.fieldErrors['parent']?.join(' ') ?? (e.statusCode == 409 ? e.message.split(': ').last : '$e'));
      return (ok: false, message: 'Cartella non spostata: $reason');
    } finally {
      actionInProgress = false;
      notifyListeners();
    }
  }

  /// Dopo una rinomina (o lo spostamento in Posta eliminata) Preferiti e cartella aperta seguono il nuovo nome.
  void _followRename(String account, String from, String to, String separator) {
    final favorites = _settings?.favorites;
    if (favorites != null) {
      final updated = [
        for (final f in favorites)
          f.account == account ? FavoriteFolder(account, renamedPath(f.folder, from, to, separator) ?? f.folder) : f,
      ];
      if (!listEquals(updated, favorites)) unawaited(_settings!.setFavorites(updated));
    }
    unawaited(_settings?.renameConversationFolders(account, (f) => renamedPath(f, from, to, separator)));
    if (selectedAccount == account && selectedFolder != null) {
      if (renamedPath(selectedFolder!, from, to, separator) case final moved?) {
        unawaited(selectFolder(moved, account: account));
      }
    }
  }

  /// Dopo un'eliminazione definitiva: via dai Preferiti; se era aperta si torna alla Posta in arrivo.
  void _forgetFolder(String account, String folder, String separator) {
    bool gone(String name) => renamedPath(name, folder, folder, separator) != null;
    final favorites = _settings?.favorites;
    if (favorites != null && favorites.any((f) => f.account == account && gone(f.folder))) {
      unawaited(
        _settings!.setFavorites([
          for (final f in favorites)
            if (f.account != account || !gone(f.folder)) f,
        ]),
      );
    }
    if (selectedAccount == account && selectedFolder != null && gone(selectedFolder!)) {
      unawaited(selectFolder('INBOX', account: account));
    }
  }

  /// Rilegge in silenzio le cartelle di [account] per aggiornare i conteggi; in caso di errore
  /// restano quelli di prima (nessun messaggio: non è un'azione dell'utente).
  Future<void> _refreshFolderCounts(String account) async {
    try {
      final folders = await _apiFor(account).getFolders();
      if (_disposed) return;
      foldersByAccount = {...foldersByAccount, account: folders};
      notifyListeners();
    } on ApiException {
      // restano i numeri precedenti
    }
  }

  /// Apre [fullName] dell'account [account] (se omesso, quello già selezionato o il primo).
  Future<void> selectFolder(String fullName, {String? account}) async {
    final target = account ?? selectedAccount ?? accounts.firstOrNull?.id;
    if (target == null) return;
    _generation++;
    _endSearch();
    listFilter = ListFilter.all; // il filtro rapido vale per la cartella aperta; l'ordine resta
    collapsedGroups = const {};
    selectedAccount = target;
    selectedFolder = fullName;
    messages = const [];
    conversations = const [];
    expandedConversations = const {};
    conversationView = _wantsConversations(target, fullName);
    total = 0;
    _clearDetail();
    await _loadPage();
  }

  /// Apre la mail [uid]; [account] e [folder] servono per i risultati della ricerca (predefiniti:
  /// quelli selezionati).
  Future<void> selectMessage(int uid, {String? account, String? folder}) async {
    _readTimer?.cancel();
    _openedWhileLoading = false;
    selectedConversation = null;
    cursorConversation = null;
    _anchorConversation = null;
    _openAccount = account;
    _openFolder = folder;
    final openIn = openFolder;
    if (openIn == null) return;
    final api = accountApi;
    final generation = ++_detailGeneration;

    selectedUid = uid;
    selection = {MessageRef(openAccount!, openIn, uid)};
    _anchor = selection.first;
    cursor = selection.first;
    detail = null;
    detailError = null;
    loadingDetail = true;
    notifyListeners();

    try {
      final result = await api.getMessage(openIn, uid);
      if (generation != _detailGeneration) return;
      detail = result;
    } on ApiException catch (e) {
      if (generation != _detailGeneration) return;
      detailError = e.statusCode == 503
          ? 'Mail non disponibile senza connessione: non è ancora stata scaricata sul computer.'
          : e.toString();
    } finally {
      if (generation == _detailGeneration) {
        loadingDetail = false;
        notifyListeners();
      }
    }

    // Riquadro di lettura disattivato (3.9): un clic seleziona soltanto; "letto" quando la si apre (anche se
    // l'apertura è arrivata mentre la mail si caricava).
    if (!readingPaneVisible && !messageWindowOpen && !_openedWhileLoading) return;
    _openedWhileLoading = false;
    // Conferma di lettura con «Invia sempre» o «Non inviare mai» (R2): risposta da sola, all'apertura.
    final mode = _settings?.receiptMode ?? ReceiptMode.ask;
    if (receiptRequested && mode != ReceiptMode.ask && generation == _detailGeneration) {
      unawaited(answerReceipt(send: mode == ReceiptMode.always, automatic: true));
    }
    await _applyReadRule(uid, generation);
  }

  bool _openedWhileLoading = false;

  /// Il riquadro di lettura si vede (3.9). Con "Disattivato" la mail selezionata non diventa letta finché non
  /// la si apre a tutta finestra ([markOpened]), come Outlook.
  bool readingPaneVisible = true;

  /// La mail è aperta nella sua finestra (MessageWindow): con ↑ ↓ le mail che si aprono valgono come aperte
  /// (regola «Segna come letto», conferma di lettura) anche con il riquadro di lettura disattivato.
  bool messageWindowOpen = false;

  /// C'è una riga prima ([delta] -1) o dopo (+1) quella aperta (frecce della finestra della mail).
  bool canMoveCursor(int delta) {
    final rows = _navRows;
    final at = _navIndex(rows, cursorConversation, cursor);
    return at >= 0 && at + delta >= 0 && at + delta < rows.length;
  }

  /// Toglie dalla cartella la mail aperta con [remove] (Elimina, Sposta) e apre quella dopo, o quella prima se era
  /// l'ultima, come la finestra di un messaggio di Outlook. Se la mail resta (annullato, errore) non cambia nulla.
  Future<void> removeAndOpenNext(Future<void> Function() remove) async {
    final rows = _navRows;
    final at = _navIndex(rows, cursorConversation, cursor);
    final next = at < 0 ? null : (at + 1 < rows.length ? rows[at + 1] : (at > 0 ? rows[at - 1] : null));
    await remove();
    if (selection.isNotEmpty || next == null) return;
    await _openRow(next);
  }

  /// La mail selezionata è stata aperta a tutta finestra: valgono le regole di "Segna come letto".
  Future<void> markOpened() async {
    final uid = selectedUid;
    if (uid == null) return;
    if (loadingDetail || detail == null) {
      _openedWhileLoading = true; // la regola si applica appena la mail è caricata
      return;
    }
    await _applyReadRule(uid, _detailGeneration);
  }

  /// "Segna come letto" (impostazione): subito, dopo N secondi o mai, solo per una mail da leggere e con la connessione.
  Future<void> _applyReadRule(int uid, int generation) async {
    if (generation != _detailGeneration || detail == null || isSeen(uid) != false) return;
    // Senza connessione la mail resta non letta (nessun errore: si potrà segnarla dopo).
    if (!isOnline(openAccount)) return;
    switch (_settings?.readMode ?? ReadMode.immediately) {
      case ReadMode.immediately:
        await setSeen(uid, true);
      case ReadMode.afterDelay:
        // Se nel frattempo si apre un'altra mail o si cambia cartella, _clearDetail annulla l'attesa.
        _readTimer = Timer(Duration(seconds: _settings!.readDelaySeconds), () {
          if (generation == _detailGeneration && isSeen(uid) == false) setSeen(uid, true);
        });
      case ReadMode.manual:
        break; // solo con il pulsante "Segna come letto"
    }
  }

  /// Clic sulla notifica: apre [folder] di [account] (se non è già quella aperta) e, se indicato e
  /// presente nella lista, il messaggio [uid], che quindi segue la regola di "segna come letto".
  /// [account] null (notifica di una versione precedente) = primo account.
  Future<void> openFromNotification(String? account, String folder, int? uid) async {
    final target = account ?? accounts.firstOrNull?.id;
    if (target == null) return;
    final name =
        (foldersByAccount[target] ?? const <MailFolder>[])
            .where((f) => f.fullName == folder || (_isInbox(folder) && _isInbox(f.fullName)))
            .firstOrNull
            ?.fullName ??
        folder;
    if (!_isAt(target, name)) await selectFolder(name, account: target);
    if (uid != null && messages.any((m) => m.uid == uid)) await selectMessage(uid);
  }

  /// MODIFICA la casella (flag \Seen). La lista si aggiorna subito e torna com'era se il server rifiuta.
  Future<void> setSeen(int uid, bool seen) async {
    final account = openAccount;
    final folder = openFolder;
    if (account == null || folder == null) return;
    final previous = isSeen(uid);
    actionError = null;
    _replaceSeen(account, folder, uid, seen);

    try {
      final confirmed = await _apiFor(account).setSeen(folder, uid, seen);
      _replaceSeen(account, folder, uid, confirmed);
      // Conteggio "da leggere" della cartella (barra di stato), finché il server non lo ridà.
      if (previous != null && previous != confirmed) _adjustUnread(account, folder, confirmed ? -1 : 1);
    } on ApiException catch (e) {
      if (previous != null) _replaceSeen(account, folder, uid, previous);
      actionError = e.statusCode == 503 ? offlineMessage : 'Stato letto/non letto non aggiornato: $e';
      notifyListeners();
    }
  }

  /// MODIFICA la casella: contrassegno e/o categorie di un messaggio (la mail aperta o una riga della
  /// lista: per questo account e cartella sono espliciti). Vedi [ApiClient.setTags].
  /// Restituisce il messaggio d'errore da mostrare, null se riuscito.
  Future<String?> updateTags({
    required String account,
    required String folder,
    required int uid,
    String? followUp,
    DateTime? due,
    List<int>? categories,
  }) async {
    try {
      final tags = await _apiFor(account).setTags(folder, uid, followUp: followUp, due: due, categories: categories);
      _patchHeaders(account, folder, {uid}, (m) => m.copyWith(tags: tags));
      if (openAccount == account && openFolder == folder && selectedUid == uid) detail = detail?.copyWith(tags: tags);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.statusCode == 503 ? offlineMessage : 'Contrassegno o categorie non aggiornati: $e';
    }
  }

  /// MODIFICA la casella: sposta il messaggio (dentro lo stesso account). Restituisce un testo di
  /// esito, null in caso di errore.
  Future<String?> moveMessage(int uid, String destination) =>
      _removeAfter(uid, (api, folder) => api.move(folder, uid, destination), (to) => 'Spostato in "$to"');

  /// MODIFICA la casella: in Posta eliminata elimina definitivamente, altrove sposta in Posta eliminata.
  Future<String?> deleteMessage(int uid) {
    final permanent = inTrash;
    return _removeAfter(
      uid,
      (api, folder) => api.delete(folder, uid, permanent: permanent),
      (to) => permanent ? 'Eliminato definitivamente' : 'Spostato in "$to"',
    );
  }

  /// Esegue l'operazione e, se riesce, toglie il messaggio dalla lista e aggiorna i conteggi.
  Future<String?> _removeAfter(
    int uid,
    Future<String?> Function(ApiClient api, String folder) action,
    String Function(String? to) describe,
  ) async {
    final account = openAccount;
    final folder = openFolder;
    if (account == null || folder == null || actionInProgress) return null;
    actionInProgress = true;
    actionError = null;
    notifyListeners();

    // Una mail da leggere spostata porta con sé il numero delle da leggere (riquadro cartelle).
    final unseen = isSeen(uid) == false ? 1 : 0;
    try {
      final to = await action(_apiFor(account), folder);
      MailFolder adjust(MailFolder f, int delta) {
        var r = f.count == null ? f : f.withCount(f.count! + delta);
        if (unseen > 0 && r.unread != null) r = r.withUnread((r.unread! + delta * unseen).clamp(0, 1 << 30));
        return r;
      }

      foldersByAccount = {
        ...foldersByAccount,
        account: [
          for (final f in foldersByAccount[account] ?? const <MailFolder>[])
            if (f.fullName == folder)
              adjust(f, -1)
            else if (f.fullName == to)
              adjust(f, 1)
            else
              f,
        ],
      };
      final wasOpen = selectedUid == uid && openAccount == account && openFolder == folder;
      if (searchResults.any((r) => r.isAt(account, folder, uid))) {
        searchResults = searchResults.where((r) => !r.isAt(account, folder, uid)).toList();
        searchTotal = searchTotal > 0 ? searchTotal - 1 : 0;
      }
      _dropHeaders(account, folder, {uid});
      if (wasOpen) _clearDetail();
      return describe(to);
    } on ApiException catch (e) {
      actionError = e.statusCode == 503 ? offlineMessage : 'Operazione non riuscita: ${_refusal(e)}';
      return null;
    } finally {
      actionInProgress = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Selezione multipla e azioni in blocco (3.5a). Una mail selezionata = quella aperta nel riquadro di
  // lettura (percorso di sempre); più mail = nessuna aperta, i comandi agiscono su tutte con le
  // richieste in blocco del core, una per account e cartella.
  // ---------------------------------------------------------------------------------------------

  /// Mail selezionate nella lista (cartella o risultati della ricerca).
  Set<MessageRef> selection = const {};

  /// Punto di partenza di Maiusc+clic e Maiusc+frecce: l'ultima mail cliccata.
  MessageRef? _anchor;

  /// Riga su cui sta la tastiera (frecce, 3.5b): la lista la tiene visibile.
  MessageRef? cursor;

  bool get multiSelection => selection.length > 1;

  bool isSelected(String? account, String? folder, int uid) =>
      account != null && folder != null && selection.contains(MessageRef(account, folder, uid));

  /// Righe della lista mostrata, nell'ordine in cui compaiono.
  List<MessageRef> get _visibleRefs {
    if (searchActive) return [for (final r in searchResults) MessageRef(r.account, r.hit.folder, r.hit.uid)];
    final account = selectedAccount;
    final folder = selectedFolder;
    if (account == null || folder == null) return const [];
    return [for (final m in messages) MessageRef(account, folder, m.uid)];
  }

  /// Righe della lista su cui si muovono clic con Maiusc e frecce: le mail, oppure in vista
  /// conversazioni le righe delle conversazioni ([_Nav.conversation]) e, se aperte, le loro mail.
  /// Una conversazione con una sola mail è una riga di mail come le altre.
  List<_Nav> get _navRows {
    final account = selectedAccount;
    final folder = selectedFolder;
    if (searchActive || !conversationView || account == null || folder == null) {
      return [for (final r in _visibleRefs) (conversation: null, ref: r)];
    }
    return [
      for (final c in conversations)
        if (c.headIn(folder) case final head?) ...[
          (conversation: c.count > 1 ? c.id : null, ref: MessageRef(account, folder, head.uid)),
          if (c.count > 1 && expandedConversations.contains(c.id))
            for (final m in c.messages) (conversation: null, ref: MessageRef(account, m.folder, m.message.uid)),
        ],
    ];
  }

  static int _navIndex(List<_Nav> rows, int? conversation, MessageRef? ref) =>
      ref == null ? -1 : rows.indexWhere((n) => n.conversation == conversation && n.ref == ref);

  /// Mail di una riga: quelle della conversazione nella cartella, oppure la mail stessa.
  Set<MessageRef> _refsOf(_Nav row) {
    if (row.conversation case final id?) {
      final c = conversations.where((c) => c.id == id).firstOrNull;
      if (c != null) return conversationRefs(c);
    }
    return {row.ref};
  }

  Set<MessageRef> _refsBetween(List<_Nav> rows, int a, int b) => {
    for (final row in rows.sublist(a < b ? a : b, (a < b ? b : a) + 1)) ..._refsOf(row),
  };

  /// Clic su una riga, come Outlook: semplice = solo quella (e si apre); [toggle] (Ctrl) = aggiunge o
  /// toglie; [range] (Maiusc) = tutte quelle tra l'ultima cliccata e questa.
  Future<void> clickMessage(MessageRef ref, {bool toggle = false, bool range = false}) =>
      _clickRow((conversation: null, ref: ref), toggle: toggle, range: range);

  /// Clic sulla riga di una conversazione (3.6): seleziona le sue mail nella cartella e apre la più
  /// recente; Ctrl e Maiusc come sulle mail.
  Future<void> clickConversation(Conversation c, {bool toggle = false, bool range = false}) async {
    final account = selectedAccount;
    final head = c.headIn(selectedFolder ?? '');
    if (account == null || head == null) return;
    await _clickRow((conversation: c.id, ref: MessageRef(account, selectedFolder!, head.uid)), toggle: toggle, range: range);
  }

  Future<void> _clickRow(_Nav row, {required bool toggle, required bool range}) async {
    final rows = _navRows;
    final a = _navIndex(rows, _anchorConversation, _anchor);
    final b = rows.indexOf(row);
    if (range && a >= 0 && b >= 0) {
      _setSelection(_refsBetween(rows, a, b), _anchor, anchorConversation: _anchorConversation, cursor: row);
      return;
    }
    if (toggle) {
      final refs = _refsOf(row);
      final next = {...selection};
      if (refs.every(next.contains)) {
        next.removeAll(refs);
      } else {
        next.addAll(refs);
      }
      _setSelection(next, row.ref, anchorConversation: row.conversation, cursor: row);
      return;
    }
    await _openRow(row);
  }

  /// Apre la riga: la mail, oppure la più recente della conversazione con tutte le sue mail della
  /// cartella selezionate (i comandi valgono per tutte, il riquadro di lettura mostra la più recente).
  Future<void> _openRow(_Nav row) async {
    final opening = selectMessage(row.ref.uid, account: row.ref.account, folder: row.ref.folder);
    if (row.conversation case final id?) {
      // selectMessage ha già scelto la sola mail (prima della richiesta al core): si allarga qui.
      selection = _refsOf(row);
      selectedConversation = id;
      cursorConversation = id;
      _anchorConversation = id;
      notifyListeners();
    }
    await opening;
  }

  /// Seleziona [refs]: una sola mail si apre, nessuna o più di una chiudono il riquadro di lettura.
  void _setSelection(Set<MessageRef> refs, MessageRef? anchor, {int? anchorConversation, _Nav? cursor}) {
    if (refs.length == 1) {
      final only = refs.single;
      unawaited(selectMessage(only.uid, account: only.account, folder: only.folder));
      _anchor = anchor ?? only;
      _anchorConversation = anchor == null ? null : anchorConversation;
      this.cursor = cursor?.ref ?? only;
      cursorConversation = cursor?.conversation;
      return;
    }
    _clearDetail();
    selection = refs;
    _anchor = anchor;
    _anchorConversation = anchorConversation;
    this.cursor = cursor?.ref;
    cursorConversation = cursor?.conversation;
    notifyListeners();
  }

  /// Ctrl+A: tutte le mail caricate della lista mostrata (come Outlook, le altre arrivano scorrendo).
  void selectAll() {
    final rows = _visibleRefs;
    if (rows.isEmpty) return;
    final nav = _navRows;
    final at = _navIndex(nav, cursorConversation, cursor);
    _setSelection(
      rows.toSet(),
      _anchor ?? rows.first,
      anchorConversation: _anchor == null ? nav.first.conversation : _anchorConversation,
      cursor: at >= 0 ? nav[at] : nav.first,
    );
  }

  /// Frecce su/giù ([delta] -1/+1): la riga precedente o successiva diventa l'unica selezionata (e si
  /// apre); con [extend] (Maiusc) la selezione va dall'ultima cliccata fino a lì. Senza selezione si
  /// parte dalla prima riga.
  void moveCursor(int delta, {bool extend = false}) {
    final rows = _navRows;
    if (rows.isEmpty) return;
    final at = _navIndex(rows, cursorConversation, cursor);
    final next = rows[at < 0 ? 0 : (at + delta).clamp(0, rows.length - 1)];
    if (at >= 0 && rows[at] == next && (selection.length == 1 || selectedConversation == next.conversation)) return;
    final a = _navIndex(rows, _anchorConversation, _anchor);
    if (extend && a >= 0) {
      _setSelection(_refsBetween(rows, a, rows.indexOf(next)), _anchor, anchorConversation: _anchorConversation, cursor: next);
    } else {
      unawaited(_openRow(next));
    }
  }

  /// Home / Fine (12/11/2026, scelta 1a): la prima o l'ultima riga diventa l'unica selezionata (e si apre); con
  /// [extend] (Maiusc) la selezione va dall'ultima cliccata (o dalla riga della tastiera) fino a lì. Fine carica prima
  /// il resto della lista dalla copia locale, come Outlook, che ha sempre tutta la cartella nella lista.
  Future<void> moveCursorToEdge({required bool end, bool extend = false}) async {
    if (end && !await _loadAll()) return;
    final rows = _navRows;
    if (rows.isEmpty) return;
    _moveCursorTo(rows, end ? rows.length - 1 : 0, extend: extend);
    onListJump?.call(end ? ListJump.end : ListJump.start);
  }

  /// Pag↑ / Pag↓ ([direction] -1/+1): la riga della tastiera si sposta di una pagina della lista ([pageRows], dalla
  /// lista mostrata); con [extend] come Maiusc+frecce. In fondo alle righe caricate carica la pagina successiva.
  Future<void> moveCursorPage(int direction, {bool extend = false}) async {
    var rows = _navRows;
    if (rows.isEmpty) return;
    final step = (pageRows?.call() ?? 10).clamp(1, 1000);
    final at = _navIndex(rows, cursorConversation, cursor);
    final more = searchActive ? searchHasMore : hasMore;
    if (direction > 0 && at + step >= rows.length && more) {
      await (searchActive ? loadMoreResults() : loadMore());
      if (_disposed) return;
      rows = _navRows;
      if (rows.isEmpty) return;
    }
    onListJump?.call(direction > 0 ? ListJump.pageDown : ListJump.pageUp);
    _moveCursorTo(rows, ((at < 0 ? 0 : at) + direction * step).clamp(0, rows.length - 1), extend: extend);
  }

  /// La lista scorre per un salto della tastiera: lo fa la lista mostrata, che conosce lo scorrimento (null senza lista).
  void Function(ListJump jump)? onListJump;

  /// Righe su cui si muove la tastiera nella lista mostrata (per stimare la pagina di Pag↑ / Pag↓).
  int get navRowCount => _navRows.length;

  /// Righe che stanno in una pagina della lista mostrata (per Pag↑ / Pag↓); null senza lista.
  int Function()? pageRows;

  /// Dopo un salto della tastiera la riga della tastiera va mostrata anche se viene costruita solo adesso (prima era
  /// fuori dalla parte disegnata della lista); la riga lo consuma.
  bool revealCursor = false;

  void _moveCursorTo(List<_Nav> rows, int index, {required bool extend}) {
    final next = rows[index];
    revealCursor = true;
    if (!extend) {
      unawaited(_openRow(next));
      return;
    }
    // Maiusc senza un punto di partenza: dalla riga della tastiera, o dalla prima.
    var a = _navIndex(rows, _anchorConversation, _anchor);
    if (a < 0) {
      final from = _navIndex(rows, cursorConversation, cursor);
      a = from < 0 ? 0 : from;
      _anchor = rows[a].ref;
      _anchorConversation = rows[a].conversation;
    }
    _setSelection(_refsBetween(rows, a, index), _anchor, anchorConversation: _anchorConversation, cursor: next);
  }

  /// Carica tutte le pagine della lista mostrata (cartella o ricerca); false se nel frattempo la lista è cambiata.
  Future<bool> _loadAll() async {
    final search = searchActive;
    final generation = search ? _searchGeneration : _generation;
    bool same() => !_disposed && searchActive == search && (search ? _searchGeneration : _generation) == generation;
    int loaded() => search ? searchResults.length : (conversationView ? conversations.length : messages.length);
    for (var guard = 0; guard < 10000 && same(); guard++) {
      if (search ? searching : loadingMessages) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        continue;
      }
      final error = search ? searchError : messagesError;
      if (!(search ? searchHasMore : hasMore) || error != null) return true;
      final before = loaded();
      await (search ? loadMoreResults() : loadMore());
      if (loaded() == before && !(search ? searching : loadingMessages)) return same();
    }
    return same();
  }

  /// Tasto destro su una riga: se fa parte di una selezione multipla la si tiene (il menu vale per
  /// tutte), altrimenti si seleziona solo quella, come Outlook.
  Future<void> selectForContextMenu(MessageRef ref) async {
    if (selection.contains(ref)) return;
    await clickMessage(ref);
  }

  /// Tasto destro sulla riga di una conversazione: come [selectForContextMenu], per tutte le sue mail.
  Future<void> selectConversationForContextMenu(Conversation c) async {
    final refs = conversationRefs(c);
    if (refs.isNotEmpty && refs.every(selection.contains)) return;
    await clickConversation(c);
  }

  /// Intestazione di una mail della lista mostrata (anche una mail di un'altra cartella dentro una
  /// conversazione); null se non è tra quelle caricate.
  MessageHeader? _headerOf(MessageRef r) {
    if (r.account != selectedAccount) return null;
    if (r.folder == selectedFolder) return messages.where((m) => m.uid == r.uid).firstOrNull;
    if (!conversationView) return null;
    for (final c in conversations) {
      for (final m in c.messages) {
        if (m.folder == r.folder && m.message.uid == r.uid) return m.message;
      }
    }
    return null;
  }

  bool? _seenOf(MessageRef r) =>
      _headerOf(r)?.seen ?? searchResults.where((f) => f.isAt(r.account, r.folder, r.uid)).firstOrNull?.hit.seen;

  String? _roleOf(String account, String folder) =>
      (foldersByAccount[account] ?? const <MailFolder>[]).where((f) => f.fullName == folder).firstOrNull?.role;

  /// Comandi che modificano la casella sulle mail selezionate: server raggiungibile per tutte.
  bool get canModifySelection =>
      selection.isNotEmpty && !actionInProgress && selection.every((r) => isOnline(r.account));

  /// L'account di tutte le mail selezionate (null se sono di account diversi: "Sposta" non vale tra account).
  String? get selectionAccount {
    final accounts = selection.map((r) => r.account).toSet();
    return accounts.length == 1 ? accounts.single : null;
  }

  /// La cartella [folder] di [account] è Posta eliminata (ruolo \\Trash).
  bool isInTrashFolder(String account, String folder) => _roleOf(account, folder) == 'trash';

  /// Tra le selezionate ce n'è almeno una in Posta eliminata: "Elimina" lì è definitivo.
  bool get selectionInTrash => selection.any((r) => _roleOf(r.account, r.folder) == 'trash');

  /// Almeno una da leggere: "Segna come letto" (altrimenti "Segna come non letto"), come Outlook.
  bool get selectionHasUnread => selection.any((r) => _seenOf(r) == false);

  /// Contrassegno e categorie comuni a tutte le selezionate (per i segni di spunta dei menu).
  MessageTags get selectionTags {
    final all = [for (final r in selection) _headerOf(r)?.tags ?? MessageTags.none];
    if (all.isEmpty) return MessageTags.none;
    return MessageTags(
      flagged: all.every((t) => t.flagged),
      completed: all.every((t) => t.completed),
      categories: [
        for (var n = 1; n <= 6; n++)
          if (all.every((t) => t.categories.contains(n))) n,
      ],
    );
  }

  /// Destinazioni di "Sposta" per le selezionate: cartelle del loro account, tranne quella da cui
  /// vengono se è una sola.
  List<MailFolder> get selectionMoveTargets {
    final account = selectionAccount;
    if (account == null) return const [];
    final from = selection.map((r) => r.folder).toSet();
    return [
      for (final f in foldersByAccount[account] ?? const <MailFolder>[])
        if (!(from.length == 1 && from.single == f.fullName)) f,
    ];
  }

  /// Selezionate raggruppate per account e cartella, in ordine di UID.
  Map<(String, String), List<int>> get _selectionGroups {
    final groups = <(String, String), List<int>>{};
    for (final r in selection) {
      (groups[(r.account, r.folder)] ??= []).add(r.uid);
    }
    for (final uids in groups.values) {
      uids.sort();
    }
    return groups;
  }

  /// MODIFICA la casella: letto/non letto su tutte le selezionate. Testo dell'esito.
  Future<({bool ok, String message})> setSeenSelected(bool seen) async {
    if (actionInProgress) return (ok: false, message: 'Un\'altra operazione è in corso');
    actionInProgress = true;
    notifyListeners();
    var done = 0;
    String? error;
    try {
      for (final MapEntry(key: (account, folder), value: uids) in _selectionGroups.entries) {
        try {
          final changed = (await _apiFor(account).setSeenMany(folder, uids, seen)).toSet();
          final flipped = changed.where((uid) => _seenOf(MessageRef(account, folder, uid)) == !seen).length;
          _replaceSeenMany(account, folder, changed, seen);
          if (flipped > 0) _adjustUnread(account, folder, seen ? -flipped : flipped);
          done += changed.length;
        } on ApiException catch (e) {
          error = e.statusCode == 503 ? offlineMessage : '$e';
        }
      }
    } finally {
      actionInProgress = false;
      notifyListeners();
    }
    final what = seen ? 'segnate come lette' : 'segnate come da leggere';
    return error == null
        ? (ok: true, message: '$done mail $what')
        : (ok: false, message: done > 0 ? '$done mail $what; le altre no: $error' : 'Stato letto non aggiornato: $error');
  }

  /// MODIFICA la casella: contrassegno e/o categorie (aggiunte o tolte) su tutte le selezionate.
  /// Restituisce il messaggio d'errore, null se riuscito.
  Future<String?> updateTagsSelected({
    String? followUp,
    DateTime? due,
    List<int>? addCategories,
    List<int>? removeCategories,
  }) async {
    String? error;
    for (final MapEntry(key: (account, folder), value: uids) in _selectionGroups.entries) {
      try {
        final tags = await _apiFor(account).setTagsMany(
          folder,
          uids,
          followUp: followUp,
          due: due,
          addCategories: addCategories,
          removeCategories: removeCategories,
        );
        _patchHeaders(account, folder, tags.keys.toSet(), (m) => m.copyWith(tags: tags[m.uid]));
      } on ApiException catch (e) {
        error = e.statusCode == 503 ? offlineMessage : 'Contrassegno o categorie non aggiornati: $e';
      }
    }
    notifyListeners();
    return error;
  }

  /// MODIFICA la casella: sposta le selezionate (stesso account) in [destination].
  Future<({bool ok, String message})> moveSelected(String destination) {
    final name = _folderName(selectionAccount, destination); // prima: la selezione poi si azzera
    return _removeSelected(
      (api, folder, uids) => api.moveMany(folder, uids, destination),
      (count, permanent) => '$count mail spostate in "$name"',
    );
  }

  /// MODIFICA la casella: quelle in Posta eliminata DEFINITIVAMENTE (chi chiama ha chiesto conferma),
  /// le altre spostate in Posta eliminata.
  Future<({bool ok, String message})> deleteSelected() => _removeSelected(
    (api, folder, uids) => api.deleteMany(folder, uids, permanent: _roleOf(api.account ?? '', folder) == 'trash'),
    (count, permanent) => permanent ? '$count mail eliminate definitivamente' : '$count mail spostate in Posta eliminata',
  );

  // ---------------------------------------------------------------------------------------------
  // Posta indesiderata (J2). I comandi valgono per la mail aperta o per tutte le selezionate (la mail aperta è
  // sempre nella selezione), con le richieste del core per account e cartella.
  // ---------------------------------------------------------------------------------------------

  /// La cartella della posta indesiderata di [account] (ruolo "junk" dato dal core), null se non ce n'è.
  String? junkFolderOf(String? account) =>
      (foldersByAccount[account] ?? const <MailFolder>[]).where((f) => f.specialUse == 'junk').firstOrNull?.fullName;

  /// La mail aperta è nella posta indesiderata: collegamenti disattivati e immagini bloccate (4a).
  bool get openInJunk => openFolderInfo?.specialUse == 'junk';

  /// Tutte le selezionate sono nella posta indesiderata del loro account («Non è posta indesiderata»).
  bool get selectionInJunk =>
      selection.isNotEmpty && selection.every((r) => _roleOf(r.account, r.folder) == 'junk');

  /// Account delle selezionate senza una cartella della posta indesiderata («Blocca mittente» non può spostare).
  List<String> get selectionAccountsWithoutJunk => [
    for (final account in selection.map((r) => r.account).toSet())
      if (junkFolderOf(account) == null) account,
  ];

  /// Cartella di archiviazione in uso per [account] (ruolo "archive", dato dal core solo a quella scelta).
  String? archiveFolderOf(String? account) =>
      (foldersByAccount[account] ?? const <MailFolder>[]).where((f) => f.specialUse == 'archive').firstOrNull?.fullName;

  /// Almeno una selezionata è già nella cartella di archiviazione: Archivia non si usa (il core la rifiuterebbe).
  bool get selectionInArchive => selection.any((r) => _roleOf(r.account, r.folder) == 'archive');

  /// Account delle selezionate senza cartella di archiviazione: prima di Archivia va scelta (1a).
  List<String> get selectionAccountsWithoutArchive => [
    for (final account in selection.map((r) => r.account).toSet())
      if (archiveFolderOf(account) == null) account,
  ];

  /// «Archivia», MODIFICA la casella: le selezionate vanno nella cartella di archiviazione del loro account, con lo
  /// stesso percorso di Sposta in blocco (lista e conteggi aggiornati subito).
  Future<({bool ok, String message})> archiveSelected() => _removeSelected(
    (api, folder, uids) => api.archiveMany(folder, uids),
    (count, _) => count == 1 ? '1 mail archiviata' : '$count mail archiviate',
  );

  // ---------------------------------------------------------------------------------------------
  // Ignora e Pulisci conversazione (C2). Valgono per la mail aperta o per tutte le selezionate, con le richieste del
  // core per account e cartella; tutto quello che si sposta va in Posta eliminata (o, con Interrompi Ignora, torna
  // in Posta in arrivo).
  // ---------------------------------------------------------------------------------------------

  /// Conversazioni ignorate già chieste al core (solo per le mail in Posta eliminata); null = in corso.
  final _ignored = <MessageRef, bool?>{};

  /// La mail aperta è in Posta eliminata e la sua conversazione è ignorata: il comando diventa «Interrompi Ignora
  /// conversazione» (come Outlook, da Posta eliminata). La prima volta lo chiede al core e poi avvisa.
  bool get openIgnoredInTrash {
    if (selection.length != 1) return false;
    final ref = selection.single;
    if (_roleOf(ref.account, ref.folder) != 'trash') return false;
    if (_ignored.containsKey(ref)) return _ignored[ref] ?? false;
    _ignored[ref] = null;
    () async {
      try {
        _ignored[ref] = await _apiFor(ref.account).isIgnored(ref.folder, ref.uid);
      } on ApiException {
        _ignored[ref] = false; // senza risposta resta «Ignora»
      }
      notifyListeners();
    }();
    return false;
  }

  /// Pulisci non vale in Posta eliminata né nella posta indesiderata (il core lo rifiuterebbe).
  bool canCleanUpIn(String account, String folder) =>
      _roleOf(account, folder) != 'trash' && _roleOf(account, folder) != 'junk';

  /// «Ignora conversazione», MODIFICA la casella: le mail delle conversazioni nella cartella (1b) vanno in Posta
  /// eliminata, come quelle che arriveranno.
  Future<({bool ok, String message})> ignoreSelected() async {
    final outcome = await _removeSelected(
      (api, folder, uids) => api.ignoreConversations(folder, uids),
      (count, _) => count == 0
          ? 'Conversazione ignorata: le mail che arriveranno andranno in Posta eliminata'
          : '$count mail spostate in Posta eliminata; anche quelle che arriveranno andranno lì',
    );
    _ignored.clear();
    return outcome;
  }

  /// «Interrompi Ignora conversazione», da Posta eliminata MODIFICA la casella: la conversazione torna in Posta in arrivo.
  Future<({bool ok, String message})> stopIgnoringSelected() async {
    final outcome = await _removeSelected(
      (api, folder, uids) => api.stopIgnoring(folder, uids),
      (count, _) => count == 0 ? 'La conversazione non è più ignorata' : '$count mail riportate in Posta in arrivo',
    );
    _ignored.clear();
    return outcome;
  }

  /// «Pulisci conversazione», MODIFICA la casella: le mail superflue delle conversazioni selezionate vanno in Posta
  /// eliminata; se le selezionate restano, restano anche selezionate.
  Future<({bool ok, String message})> cleanUpSelected() => _removeSelected(
    (api, folder, uids) => api.cleanUpConversations(folder, uids),
    _cleanUpText,
    keepSurvivors: true,
  );

  /// «Pulisci cartella», MODIFICA la casella: come [cleanUpSelected] su tutte le conversazioni di [folder].
  Future<({bool ok, String message})> cleanUpFolder(String account, String folder) async {
    if (actionInProgress) return (ok: false, message: 'Un\'altra operazione è in corso');
    actionInProgress = true;
    notifyListeners();
    try {
      final gone = _applyRemoval(account, folder, await _apiFor(account).cleanUpFolder(folder));
      if (selection.any((r) => r.account == account && r.folder == folder && gone.contains(r.uid))) _clearDetail();
      return (ok: true, message: _cleanUpText(gone.length, false));
    } on ApiException catch (e) {
      return (ok: false, message: 'Operazione non riuscita: ${e.statusCode == 503 ? offlineMessage : _refusal(e)}');
    } finally {
      actionInProgress = false;
      notifyListeners();
    }
  }

  static String _cleanUpText(int count, bool _) => switch (count) {
    0 => 'Nessuna mail superflua da spostare',
    1 => '1 mail superflua spostata in Posta eliminata',
    _ => '$count mail superflue spostate in Posta eliminata',
  };

  /// Rilegge le cartelle di [account] (dopo le Opzioni posta indesiderata il ruolo "junk" può cambiare cartella).
  Future<void> reloadFolders(String account) => _refreshFolderCounts(account);

  /// «Blocca mittente», MODIFICA la casella: mittenti tra i bloccati e mail spostate nella posta indesiderata.
  Future<({bool ok, String message})> blockSelected() async {
    final entries = <String>{};
    final outcome = await _removeSelected(
      (api, folder, uids) async {
        final r = await api.blockSenders(folder, uids);
        entries.addAll(r.entries);
        return BatchOutcome(r.folder, r.moved);
      },
      (count, _) => count == 0 ? 'Nessuna mail spostata' : '$count mail spostate nella posta indesiderata',
    );
    if (entries.isEmpty) return outcome;
    return (ok: outcome.ok, message: '${_entriesText('bloccato', 'bloccati', entries)}. ${outcome.message}');
  }

  /// «Non è posta indesiderata», MODIFICA la casella: le selezionate tornano in Posta in arrivo; con
  /// [trustSenders] i mittenti diventano attendibili.
  Future<({bool ok, String message})> notJunkSelected({required bool trustSenders}) async {
    final entries = <String>{};
    final outcome = await _removeSelected(
      (api, folder, uids) async {
        final r = await api.notJunk(folder, uids, trustSenders: trustSenders);
        entries.addAll(r.entries);
        return BatchOutcome(r.folder, r.moved);
      },
      (count, _) => '$count mail riportate in Posta in arrivo',
    );
    if (entries.isEmpty) return outcome;
    return (ok: outcome.ok, message: '${outcome.message}. ${_entriesText('attendibile', 'attendibili', entries)}');
  }

  /// «Non bloccare mai…»: solo gli elenchi, la casella non cambia (vale anche senza connessione: il core legge la
  /// copia locale).
  Future<({bool ok, String message})> neverBlockSelected(NeverBlockKind kind) async {
    if (actionInProgress) return (ok: false, message: 'Un\'altra operazione è in corso');
    final entries = <String>{};
    String? error;
    for (final MapEntry(key: (account, folder), value: uids) in _selectionGroups.entries) {
      try {
        entries.addAll((await _apiFor(account).neverBlock(folder, uids, kind)).entries);
      } on ApiException catch (e) {
        error = _refusal(e);
      }
    }
    final list = kind == NeverBlockKind.group ? 'tra i destinatari attendibili' : 'tra i mittenti attendibili';
    final text = entries.isEmpty ? '' : '${entries.join(', ')} aggiunt${entries.length == 1 ? 'o' : 'i'} $list';
    if (error == null) return (ok: true, message: text);
    return (ok: false, message: text.isEmpty ? 'Elenchi non aggiornati: $error' : '$text; le altre no: $error');
  }

  /// Testo di un errore del core per l'utente: un rifiuto (409) dice già il motivo, senza «Operazione non
  /// consentita» né il codice HTTP (prima: «Operazione non riuscita: Operazione non consentita: … (HTTP 409)»).
  static String _refusal(ApiException e) =>
      e.statusCode == 409 ? e.message.replaceFirst('Operazione non consentita: ', '') : '$e';

  static String _entriesText(String one, String many, Set<String> entries) =>
      entries.length == 1 ? '${entries.single} $one' : '${entries.length} mittenti $many (${entries.join(', ')})';

  /// Trascinamento di mail (3.5c): [refs] possono andare nella cartella [folder] di [account]? Solo
  /// mail di quell'account (scelta 3.5c-1a), server raggiungibile e almeno una che non sia già lì.
  bool canDropMessages(Set<MessageRef> refs, String account, String folder) =>
      refs.isNotEmpty &&
      !actionInProgress &&
      isOnline(account) &&
      refs.every((r) => r.account == account) &&
      refs.any((r) => r.folder != folder);

  /// MODIFICA la casella: le mail trascinate [refs] vanno in [destination], spostate oppure, con [copy]
  /// (Ctrl, scelta 3.5c-2a), copiate. Quelle già in [destination] restano dove sono. Testo dell'esito.
  Future<({bool ok, String message})> dropMessages(Set<MessageRef> refs, String destination, {required bool copy}) {
    selection = refs.where((r) => r.folder != destination).toSet();
    return copy ? copySelected(destination) : moveSelected(destination);
  }

  /// MODIFICA la casella: copia le selezionate (stesso account) in [destination]; gli originali restano
  /// e la selezione non cambia. I conteggi delle cartelle vengono riletti dal server.
  Future<({bool ok, String message})> copySelected(String destination) async {
    if (actionInProgress) return (ok: false, message: 'Un\'altra operazione è in corso');
    actionInProgress = true;
    notifyListeners();
    var done = 0;
    String? error;
    final accounts = <String>{};
    try {
      for (final MapEntry(key: (account, folder), value: uids) in _selectionGroups.entries) {
        try {
          done += (await _apiFor(account).copyMany(folder, uids, destination)).uids.length;
          accounts.add(account);
        } on ApiException catch (e) {
          error = e.statusCode == 503 ? offlineMessage : '$e';
        }
      }
    } finally {
      actionInProgress = false;
      notifyListeners();
    }
    for (final account in accounts) {
      await _refreshFolderCounts(account);
    }
    final text = '$done mail copiate in "${_folderName(accounts.firstOrNull, destination)}"';
    return error == null
        ? (ok: true, message: text)
        : (ok: false, message: done > 0 ? '$text; le altre no: $error' : 'Mail non copiate: $error');
  }

  String _folderName(String? account, String folder) =>
      (foldersByAccount[account] ?? const <MailFolder>[]).where((f) => f.fullName == folder).firstOrNull?.name ?? folder;

  /// Esegue [action] per ogni gruppo; le mail trattate spariscono dalla lista e dai risultati e i conteggi
  /// delle cartelle seguono (da leggere comprese). La selezione si azzera.
  Future<({bool ok, String message})> _removeSelected(
    Future<BatchOutcome> Function(ApiClient api, String folder, List<int> uids) action,
    String Function(int count, bool permanent) describe, {
    bool keepSurvivors = false,
  }) async {
    if (actionInProgress) return (ok: false, message: 'Un\'altra operazione è in corso');
    actionInProgress = true;
    notifyListeners();
    var done = 0;
    var allPermanent = true;
    final goneRefs = <MessageRef>{};
    String? error;
    try {
      for (final MapEntry(key: (account, folder), value: uids) in _selectionGroups.entries) {
        try {
          final outcome = await action(_apiFor(account), folder, uids);
          final gone = _applyRemoval(account, folder, outcome);
          goneRefs.addAll(gone.map((uid) => MessageRef(account, folder, uid)));
          done += gone.length;
          if (outcome.movedTo != null) allPermanent = false;
        } on ApiException catch (e) {
          error = e.statusCode == 503 ? offlineMessage : _refusal(e);
        }
      }
      // Pulisci conversazione: se le selezionate restano tutte, la mail aperta resta aperta.
      if (!keepSurvivors || selection.any(goneRefs.contains)) _clearDetail();
    } finally {
      actionInProgress = false;
      notifyListeners();
    }
    final text = describe(done, allPermanent && done > 0);
    return error == null
        ? (ok: true, message: text)
        : (ok: false, message: done > 0 ? '$text; le altre no: $error' : 'Operazione non riuscita: $error');
  }

  /// Le mail [outcome].uids sono uscite da [folder] di [account] (in [outcome].movedTo, o eliminate): via dalla lista e
  /// dai risultati, conteggi delle cartelle aggiornati (da leggere comprese). Restituisce le mail tolte.
  Set<int> _applyRemoval(String account, String folder, BatchOutcome outcome) {
    final gone = outcome.uids.toSet();
    final unseen = gone.where((uid) => _seenOf(MessageRef(account, folder, uid)) == false).length;
    MailFolder adjust(MailFolder f, int sign) {
      var r = f.count == null ? f : f.withCount((f.count! + sign * gone.length).clamp(0, 1 << 30));
      if (unseen > 0 && r.unread != null) r = r.withUnread((r.unread! + sign * unseen).clamp(0, 1 << 30));
      return r;
    }

    foldersByAccount = {
      ...foldersByAccount,
      account: [
        for (final f in foldersByAccount[account] ?? const <MailFolder>[])
          if (f.fullName == folder)
            adjust(f, -1)
          else if (f.fullName == outcome.movedTo)
            adjust(f, 1)
          else
            f,
      ],
    };
    final removedResults = searchResults.where((r) => r.account == account && r.hit.folder == folder && gone.contains(r.hit.uid)).length;
    if (removedResults > 0) {
      searchResults = searchResults.where((r) => !(r.account == account && r.hit.folder == folder && gone.contains(r.hit.uid))).toList();
      searchTotal = (searchTotal - removedResults).clamp(0, 1 << 30);
    }
    _dropHeaders(account, folder, gone);
    return gone;
  }

  /// Come [_replaceSeen] per più mail della stessa cartella, con una sola notifica.
  void _replaceSeenMany(String account, String folder, Set<int> uids, bool seen) {
    _patchHeaders(account, folder, uids, (m) => m.copyWith(seen: seen));
    searchResults = [
      for (final r in searchResults)
        r.account == account && r.hit.folder == folder && uids.contains(r.hit.uid)
            ? FoundMessage(r.account, r.hit.copyWith(seen: seen))
            : r,
    ];
    notifyListeners();
  }

  void clearActionError() {
    actionError = null;
    notifyListeners();
  }

  void _adjustUnread(String account, String folder, int delta) {
    foldersByAccount = {
      ...foldersByAccount,
      account: [
        for (final f in foldersByAccount[account] ?? const <MailFolder>[])
          if (f.fullName == folder && f.unread != null) f.withUnread((f.unread! + delta).clamp(0, 1 << 30)) else f,
      ],
    };
    notifyListeners();
  }

  /// Aggiorna lo stato letto nella lista della cartella e nei risultati della ricerca.
  void _replaceSeen(String account, String folder, int uid, bool seen) {
    _patchHeaders(account, folder, {uid}, (m) => m.copyWith(seen: seen));
    searchResults = [
      for (final r in searchResults) r.isAt(account, folder, uid) ? FoundMessage(r.account, r.hit.copyWith(seen: seen)) : r,
    ];
    notifyListeners();
  }

  /// URL di un allegato del messaggio aperto.
  String attachmentUrl(int index) => accountApi.attachmentUrl(openFolder!, selectedUid!, index);

  /// Header da usare con [attachmentUrl] (token del core).
  Map<String, String> get attachmentHeaders => _api.authHeaders;

  void _clearDetail() {
    _readTimer?.cancel();
    _detailGeneration++;
    actionError = null;
    _openAccount = null;
    _openFolder = null;
    selectedUid = null;
    selection = const {};
    _anchor = null;
    cursor = null;
    selectedConversation = null;
    cursorConversation = null;
    _anchorConversation = null;
    detail = null;
    detailError = null;
    loadingDetail = false;
  }

  Future<void> loadMore() async {
    if (loadingMessages || !hasMore) return;
    await _loadPage();
  }

  /// OAuth2: il fornitore ha rinnovato il token di rinnovo di un account (va salvato nel portachiavi).
  void Function(String account, String refreshToken)? onCredentialsChanged;

  /// Rubrica di un account cambiata dalla sincronizzazione CardDAV (evento contacts-changed): la vista Persone la rilegge.
  void Function(String account)? onContactsChanged;

  /// Calendari di un account cambiati dalla sincronizzazione CalDAV (evento calendars-changed): la vista Calendario li rilegge.
  void Function(String account)? onCalendarsChanged;

  /// Risposte automatiche per account (barra gialla "Le risposte automatiche sono attive").
  Map<String, AutoReplySettings> autoReplies = const {};

  /// Account per cui le risposte automatiche partono adesso.
  List<AccountInfo> get autoReplyAccounts {
    final now = DateTime.now();
    return [for (final a in accounts) if (autoReplies[a.id]?.activeAt(now) ?? false) a];
  }

  Future<void> loadAutoReplies() async {
    final result = <String, AutoReplySettings>{};
    for (final a in accounts) {
      try {
        result[a.id] = await _apiFor(a.id).getAutoReply();
      } on ApiException {
        // core senza copia locale (501) o non raggiungibile: niente barra
      }
    }
    if (_disposed) return;
    autoReplies = result;
    notifyListeners();
  }

  /// Salva e aggiorna la barra; gli errori (es. messaggio vuoto) arrivano al chiamante.
  Future<AutoReplySettings> saveAutoReply(String account, AutoReplySettings settings) async {
    final saved = await _apiFor(account).saveAutoReply(settings);
    if (!_disposed) {
      autoReplies = {...autoReplies, account: saved};
      notifyListeners();
    }
    return saved;
  }

  /// Account POP3 (4.2): mail solo sul computer.
  bool isPop3(String? account) => accounts.any((a) => a.id == account && a.isPop3);

  /// Ricarica account, cartelle e prima pagina della cartella corrente. Per gli account POP3 chiede anche
  /// al core di controllare subito il server (le mail nuove arrivano poi con l'evento mailbox-changed); per
  /// quelli con CardDAV (C4c) di sincronizzare la rubrica.
  Future<void> refresh() async {
    final account = selectedAccount;
    final folder = selectedFolder;
    for (final a in accounts.where((a) => a.isPop3 || a.cardDav || a.calDav)) {
      unawaited(_apiFor(a.id).receive().catchError((Object e) => debugPrint('[pop3] invia/ricevi non riuscito: $e')));
    }
    await loadFolders();
    if (folder != null) await selectFolder(folder, account: account);
  }

  // ---------------------------------------------------------------------------------------------
  // Ricerca (cache locale del core)
  // ---------------------------------------------------------------------------------------------

  /// Testo nella casella di ricerca (la casella lo legge da qui: cambiando cartella si svuota).
  String searchText = '';
  SearchScope searchScope = SearchScope.folder;

  /// Ricerca mostrata nella lista; null = lista della cartella.
  String? _activeQuery;
  bool get searchActive => _activeQuery != null;

  List<FoundMessage> searchResults = const [];
  int searchTotal = 0;
  bool searching = false;
  String? searchError;

  // Per account: totale e risultati già ricevuti (con "Tutti gli account" si pagina ogni account).
  Map<String, int> _searchTotals = const {};
  Map<String, int> _searchOffsets = const {};
  int _searchGeneration = 0;
  Timer? _searchDebounce;

  /// Attesa dopo l'ultima lettera digitata prima di cercare.
  static const searchDelay = Duration(milliseconds: 400);

  bool get searchHasMore => _searchTotals.entries.any((e) => (_searchOffsets[e.key] ?? 0) < e.value);

  // --- ricerca sul server ("Cerca anche sul server"), una volta per ricerca ---
  static const serverSearchLimit = 200;
  bool serverSearching = false;
  bool serverSearchDone = false;

  /// Mail aggiunte dalla ricerca sul server (non già tra i risultati locali).
  int serverAdded = 0;

  /// Il server ha trovato più di [serverSearchLimit] mail in almeno un account: mostrate le più recenti.
  bool serverTruncated = false;
  String? serverSearchError;

  /// Testo cambiato nella casella: cerca dopo [searchDelay]; casella vuota = torna alla cartella.
  void setSearchText(String text) {
    searchText = text;
    _searchDebounce?.cancel();
    if (text.trim().isEmpty) {
      clearSearch();
      return;
    }
    _searchDebounce = Timer(searchDelay, () => search());
  }

  void setSearchScope(SearchScope scope) {
    if (scope == searchScope) return;
    searchScope = scope;
    notifyListeners();
    if (searchText.trim().isNotEmpty) search();
  }

  /// Cerca subito [searchText] (Invio nella casella).
  Future<void> search() async {
    _searchDebounce?.cancel();
    final query = searchText.trim();
    final account = selectedAccount;
    if (query.isEmpty || account == null) return;
    final targets = searchScope == SearchScope.allAccounts ? [for (final a in accounts) a.id] : [account];
    final folder = searchScope == SearchScope.folder ? selectedFolder : null;
    final generation = ++_searchGeneration;

    _activeQuery = query;
    _searchFolder = folder;
    _resetServerSearch();
    searchResults = const [];
    searchTotal = 0;
    _searchTotals = {for (final t in targets) t: 1}; // "c'è altro" finché non arriva la risposta
    _searchOffsets = const {};
    await _loadSearchPage(generation);
  }

  String? _searchFolder;

  Future<void> loadMoreResults() async {
    if (searching || !searchHasMore) return;
    await _loadSearchPage(_searchGeneration);
  }

  /// Chiude la ricerca e torna alla lista della cartella (pulsante X o casella svuotata).
  void clearSearch() {
    _searchDebounce?.cancel();
    final wasActive = searchActive || searchText.isNotEmpty;
    searchText = '';
    _endSearch();
    if (wasActive) notifyListeners();
  }

  void _endSearch() {
    _searchGeneration++;
    _searchDebounce?.cancel();
    final openFromSearch = searchActive && (openAccount != selectedAccount || openFolder != selectedFolder);
    _activeQuery = null;
    searchText = '';
    _resetServerSearch();
    searchResults = const [];
    searchTotal = 0;
    searching = false;
    searchError = null;
    _searchTotals = const {};
    _searchOffsets = const {};
    // Una mail aperta dai risultati ma di un'altra cartella non è più nella lista: si chiude.
    if (openFromSearch) _clearDetail();
  }

  /// Pagina successiva di ogni account che ha ancora risultati, unita alle precedenti dal più recente.
  Future<void> _loadSearchPage(int generation) async {
    final query = _activeQuery;
    if (query == null) return;
    searching = true;
    searchError = null;
    notifyListeners();

    final pending = [
      for (final e in _searchTotals.entries)
        if ((_searchOffsets[e.key] ?? 0) < e.value) e.key,
    ];
    final pages = await Future.wait(
      pending.map((account) async {
        try {
          final page = await _apiFor(
            account,
          ).search(query, folder: _searchFolder, offset: _searchOffsets[account] ?? 0, limit: pageSize);
          return (account: account, page: page, error: null);
        } on ApiException catch (e) {
          return (account: account, page: null, error: e.toString());
        }
      }),
    );
    if (generation != _searchGeneration || _disposed) return;

    final totals = {..._searchTotals};
    final offsets = {..._searchOffsets};
    var found = [...searchResults];
    String? error;
    for (final r in pages) {
      if (r.page case final page?) {
        totals[r.account] = page.total;
        offsets[r.account] = (offsets[r.account] ?? 0) + page.items.length;
        // Un risultato locale prende il posto dello stesso trovato prima sul server (ha l'estratto).
        final local = [for (final h in page.items) FoundMessage(r.account, h)];
        found = [
          for (final f in found)
            if (!local.any((l) => l.isAt(f.account, f.hit.folder, f.hit.uid))) f,
          ...local,
        ];
      } else {
        totals[r.account] = 0; // non si riprova da solo: resta l'errore
        error ??= r.error;
      }
    }
    _sortByDate(found);
    _searchTotals = totals;
    _searchOffsets = offsets;
    searchResults = found;
    searchTotal = totals.values.fold(0, (a, b) => a + b);
    searchError = error;
    searching = false;
    notifyListeners();
  }

  /// Più account o risultati dal server: si mescolano per data (senza data in fondo), come la lista
  /// di una cartella. L'ordinamento è stabile: a parità di data resta l'ordine del core.
  static void _sortByDate(List<FoundMessage> list) {
    // List.sort non garantisce la stabilità: a parità si confronta la posizione di partenza.
    final position = {for (final (i, f) in list.indexed) f: i};
    list.sort((a, b) {
      final da = a.hit.date, db = b.hit.date;
      final byDate = da == null || db == null ? (da == null ? (db == null ? 0 : 1) : -1) : db.compareTo(da);
      return byDate != 0 ? byDate : position[a]!.compareTo(position[b]!);
    });
  }

  void _resetServerSearch() {
    serverSearching = false;
    serverSearchDone = false;
    serverAdded = 0;
    serverTruncated = false;
    serverSearchError = null;
  }

  /// "Cerca anche sul server": stessa ricerca e stesso ambito, sul server, per le mail il cui corpo
  /// non è nella cache locale. Le mail già tra i risultati non vengono ripetute.
  /// "Cerca anche sul server" ha senso solo se tra gli account cercati ce n'è uno IMAP: per i POP3 tutte le
  /// mail sono già nell'indice locale.
  bool get canSearchServer => _searchTotals.keys.any((a) => !isPop3(a));

  Future<void> searchServer() async {
    final query = _activeQuery;
    if (query == null || serverSearching) return;
    final generation = _searchGeneration;
    serverSearching = true;
    serverSearchError = null;
    notifyListeners();

    final pages = await Future.wait(
      _searchTotals.keys.where((a) => !isPop3(a)).map((account) async {
        try {
          final page = await _apiFor(account).searchServer(query, folder: _searchFolder, limit: serverSearchLimit);
          return (account: account, page: page, error: null);
        } on ApiException catch (e) {
          return (account: account, page: null, error: e.toString());
        }
      }),
    );
    if (generation != _searchGeneration || _disposed) return;

    final found = [...searchResults];
    var added = 0;
    for (final r in pages) {
      final page = r.page;
      if (page == null) {
        serverSearchError ??= r.error;
        continue;
      }
      if (page.total > page.items.length) serverTruncated = true;
      for (final h in page.items) {
        if (found.any((f) => f.isAt(r.account, h.folder, h.uid))) continue;
        found.add(FoundMessage(r.account, h));
        added++;
      }
    }
    _sortByDate(found);
    searchResults = found;
    serverAdded = added;
    serverSearching = false;
    serverSearchDone = serverSearchError == null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------------------------
  // Filtro e ordine della lista (3.2)
  // ---------------------------------------------------------------------------------------------

  ListFilter listFilter = ListFilter.all;

  /// Gruppi per data chiusi nella lista (per etichetta, es. "Settimana scorsa"); si riaprono cambiando cartella.
  Set<String> collapsedGroups = const {};

  void toggleGroup(String label) {
    collapsedGroups = collapsedGroups.contains(label) ? ({...collapsedGroups}..remove(label)) : {...collapsedGroups, label};
    notifyListeners();
  }

  /// Dal più vecchio invece che dal più recente (ordinamento per data, scelta 3.2-3a).
  bool oldestFirst = false;

  /// Colonna dell'ordinamento; con [oldestFirst] in ordine crescente (dal più vecchio, A→Z, dal più piccolo).
  /// In vista conversazioni solo per data.
  ListSort sort = ListSort.date;

  /// Clic sull'intestazione di una colonna: ordina per quella; di nuovo, ordine inverso. Il testo parte da A→Z,
  /// data e dimensione dal più recente / più grande, come Outlook.
  /// Menu "Ordina per": colonna e verso scelti insieme.
  Future<void> setSort(ListSort column, {required bool ascending}) => _changeView(() {
    sort = column;
    oldestFirst = ascending;
  });

  Future<void> sortBy(ListSort column) => _changeView(() {
    if (sort == column) {
      oldestFirst = !oldestFirst;
    } else {
      sort = column;
      oldestFirst = column == ListSort.from || column == ListSort.subject;
    }
  });

  /// Vista predefinita: tutti, dal più recente (l'aggiornamento automatico confronta la prima pagina).
  bool get _defaultView => listFilter == ListFilter.all && !oldestFirst && sort == ListSort.date;

  /// Ordinamento chiesto al core: per data in vista conversazioni.
  String get _sortQuery => conversationView ? 'date' : sort.name;

  Future<void> setListFilter(ListFilter filter) => _changeView(() => listFilter = filter);

  Future<void> setOldestFirst(bool value) => _changeView(() {
    sort = ListSort.date;
    oldestFirst = value;
  });

  /// Ricarica la lista con la nuova vista; la mail aperta resta aperta.
  Future<void> _changeView(void Function() change) async {
    change();
    collapsedGroups = const {};
    _generation++;
    messages = const [];
    conversations = const [];
    expandedConversations = const {};
    selectedConversation = null;
    cursorConversation = null;
    _anchorConversation = null;
    if (selectedAccount case final account?) conversationView = _wantsConversations(account, selectedFolder ?? '');
    total = 0;
    await _loadPage();
  }

  /// Aggiornamento automatico con filtro o ordine diversi dal predefinito: le nuove non sono per
  /// forza in cima, quindi si ricaricano le righe già visibili (al massimo 200). La posta nuova in
  /// INBOX si controlla a parte, come per una cartella non aperta.
  Future<void> _reloadVisible(String account, String folder) async {
    final generation = _generation;
    try {
      if (conversationView) {
        final page = await _apiFor(account).getConversations(
          folder,
          offset: 0,
          limit: conversations.length.clamp(pageSize, 200),
          unreadOnly: listFilter == ListFilter.unread,
          oldestFirst: oldestFirst,
        );
        if (_disposed || generation != _generation || !_isAt(account, folder)) return;
        conversations = page.items;
        total = page.total;
        _deriveMessages();
        notifyListeners();
        if (_isInbox(folder)) unawaited(_checkInbox(account));
        return;
      }
      final limit = messages.length.clamp(pageSize, 200);
      final page = await _apiFor(
        account,
      ).getMessages(
        folder,
        offset: 0,
        limit: limit,
        unreadOnly: listFilter == ListFilter.unread,
        oldestFirst: oldestFirst,
        sort: _sortQuery,
      );
      if (_disposed || generation != _generation || !_isAt(account, folder)) return;
      messages = page.items;
      total = page.total;
      notifyListeners();
      if (_isInbox(folder)) unawaited(_checkInbox(account));
    } on ApiException {
      // Aggiornamento automatico non riuscito: resta "Invia/ricevi".
    }
  }

  Future<void> _loadPage() async {
    final account = selectedAccount;
    final folder = selectedFolder;
    if (account == null || folder == null) return;
    final generation = _generation;

    if (folder == outboxFolder) {
      await loadOutbox(account);
      total = outboxItems.length;
      notifyListeners();
      return;
    }

    loadingMessages = true;
    messagesError = null;
    notifyListeners();

    try {
      if (conversationView) {
        final firstPage = conversations.isEmpty;
        final page = await _apiFor(account).getConversations(
          folder,
          offset: conversations.length,
          limit: pageSize,
          unreadOnly: listFilter == ListFilter.unread,
          oldestFirst: oldestFirst,
        );
        if (generation != _generation) return;
        final known = {for (final c in conversations) c.id};
        conversations = [...conversations, ...page.items.where((c) => !known.contains(c.id))];
        total = page.total;
        _deriveMessages();
        // Posta nuova: il punto di partenza si fissa con la lista semplice di INBOX (le notifiche non
        // dipendono dalla vista).
        if (firstPage && _isInbox(folder)) unawaited(_checkInbox(account));
        return;
      }
      final firstPage = messages.isEmpty;
      final page = await _apiFor(account).getMessages(
        folder,
        offset: messages.length,
        limit: pageSize,
        unreadOnly: listFilter == ListFilter.unread,
        oldestFirst: oldestFirst,
        sort: _sortQuery,
      );
      if (generation != _generation) return;
      // Posta nuova: solo dalla prima pagina della vista predefinita (le più recenti, tutte).
      if (firstPage && _isInbox(folder) && _defaultView) _detectNewMail(account, page.items);
      messages = [...messages, ...page.items];
      total = page.total;
    } on ApiException catch (e) {
      if (generation != _generation) return;
      messagesError = e.toString();
    } finally {
      if (generation == _generation) {
        loadingMessages = false;
        notifyListeners();
      }
    }
  }
}

/// Cartella in modifica nell'albero: rinomina di [folder], oppure (se [folder] è null) nuova
/// cartella dentro [parent] (null = in cima all'account).
/// Diagnostica di Nuova cartella / Rinomina nel terminale: solo nomi di account e cartelle.
void folderLog(String message) => debugPrint('[cartelle] $message');

class FolderEdit {
  const FolderEdit(this.account, {this.folder, this.parent});

  final String account;
  final String? folder;
  final String? parent;

  bool get isNew => folder == null;
}

/// Riga della lista per la navigazione: una mail ([conversation] null) o la riga di una conversazione.
typedef _Nav = ({int? conversation, MessageRef ref});

/// Una mail della lista: account, cartella e UID (selezione multipla, 3.5a).
class MessageRef {
  const MessageRef(this.account, this.folder, this.uid);

  final String account;
  final String folder;
  final int uid;

  @override
  bool operator ==(Object other) =>
      other is MessageRef && other.account == account && other.folder == folder && other.uid == uid;

  @override
  int get hashCode => Object.hash(account, folder, uid);
}

/// Salti della tastiera nella lista (Home, Fine, Pag↑, Pag↓): la lista mostrata scorre di conseguenza.
enum ListJump { start, end, pageUp, pageDown }
