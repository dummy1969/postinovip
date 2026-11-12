import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../api/api_client.dart';
import '../models/carddav.dart';
import '../models/contact.dart';

/// Parte dell'app mostrata, scelta con la barra di navigazione in basso (come Outlook classico).
enum AppModule { mail, calendar, people }

/// Vista Persone (C2): rubrica scelta a sinistra (una per account, 6a), elenco filtrato dalla casella
/// «Cerca contatti», contatto selezionato. I contatti stanno nel core, solo sul computer.
class ContactsModel extends ChangeNotifier {
  ContactsModel(this.api);

  final ApiClient api;

  AppModule module = AppModule.mail;

  /// Casella «Cerca contatti» (Ctrl+E nella vista Persone).
  final searchFocus = FocusNode(debugLabel: 'Cerca contatti');

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    searchFocus.dispose();
    super.dispose();
  }

  bool _disposed = false;

  /// Stato della sincronizzazione CardDAV per account (C4c, 2a); assente = spenta o non ancora letta.
  final Map<String, CardDavStatus> syncStatus = {};

  /// Account con CardDAV attivo (da GET /accounts), per leggerne lo stato.
  List<String> syncAccounts = const [];

  Timer? _poll;

  CardDavStatus statusOf(String? account) => syncStatus[account] ?? CardDavStatus.off;

  /// Rilegge lo stato; se nel frattempo c'è stata una sincronizzazione della rubrica aperta, anche i contatti
  /// (l'evento contacts-changed arriva solo se la rubrica è cambiata).
  Future<void> loadSyncStatus(String account) async {
    final CardDavStatus status;
    try {
      status = await api.forAccount(account).getContactsSync();
    } on ApiException {
      return;
    }
    if (_disposed) return;
    final before = syncStatus[account];
    syncStatus[account] = status;
    notifyListeners();
    if (account == book && before != null && before.lastSync != status.lastSync && status.state == 'ok') {
      await reload();
    }
  }

  Future<void> loadSyncStatuses() => Future.wait([for (final a in syncAccounts) loadSyncStatus(a)]);

  /// Segue la sincronizzazione appena chiesta (o partita dopo una modifica): stato ogni secondo finché il core
  /// non ha finito un giro nuovo, al massimo 30 volte.
  void _follow(String account) {
    if (!syncAccounts.contains(account)) return;
    final since = statusOf(account).lastSync;
    var left = 30;
    unawaited(() async {
      while (left-- > 0 && !_disposed) {
        await Future<void>.delayed(followInterval);
        if (_disposed) return;
        await loadSyncStatus(account);
        final s = statusOf(account);
        if (!s.busy && s.lastSync != since) return;
        if (s.state == 'error' || s.state == 'offline' || s.state == 'unavailable') return;
      }
    }());
  }

  /// Intervallo con cui si segue una sincronizzazione (più corto nei test).
  static Duration followInterval = const Duration(seconds: 1);

  /// Evento contacts-changed: la sincronizzazione ha cambiato la rubrica (o serve la conferma).
  Future<void> contactsChanged(String account) async {
    await loadSyncStatus(account);
    if (account == book) await reload();
  }

  /// «Sincronizza» (o F9 nella vista Persone).
  Future<void> syncNow() async {
    final account = book;
    if (account == null || !statusOf(account).enabled) return;
    try {
      await api.forAccount(account).syncContacts();
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return;
    }
    syncStatus[account] = CardDavStatus(
      enabled: true,
      state: 'syncing',
      lastSync: statusOf(account).lastSync,
      addressBook: statusOf(account).addressBook,
      needsConfirmation: statusOf(account).needsConfirmation,
      pendingUpload: statusOf(account).pendingUpload,
    );
    notifyListeners();
    _follow(account);
  }

  /// Conferma della prima volta (3a): **modifica la rubrica del server** caricando i contatti solo sul computer.
  Future<void> confirmUpload() async {
    final account = book;
    if (account == null) return;
    await api.forAccount(account).confirmContactsSync();
    syncStatus[account] = CardDavStatus(
      enabled: true,
      state: 'syncing',
      lastSync: statusOf(account).lastSync,
      addressBook: statusOf(account).addressBook,
    );
    notifyListeners();
    _follow(account);
  }

  /// Account della rubrica aperta (null finché non si entra in Persone).
  String? book;

  /// Contatti per account, come li ha restituiti il core (in ordine di nome).
  final Map<String, List<Contact>> contacts = {};
  bool loading = false;
  String? error;
  String query = '';
  String? selectedId;

  /// [cardDavAccounts]: account con CardDAV attivo, di cui mostrare lo stato.
  void showModule(AppModule value, {String? defaultBook, List<String> cardDavAccounts = const []}) {
    if (value == AppModule.people) syncAccounts = cardDavAccounts;
    if (module == value) return;
    module = value;
    notifyListeners();
    _poll?.cancel();
    if (value != AppModule.people) return;
    unawaited(loadSyncStatuses());
    // Ogni minuto, finché si resta in Persone: «Sincronizzata alle …» resta aggiornato.
    if (syncAccounts.isNotEmpty) _poll = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(loadSyncStatuses()));
    if (book == null && defaultBook != null) openBook(defaultBook);
  }

  List<Contact> get _all => contacts[book] ?? const [];

  /// I contatti della rubrica aperta che corrispondono alla ricerca (nome, indirizzi, società, telefoni).
  List<Contact> get visible {
    final words = foldText(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return _all;
    return [
      for (final c in _all)
        if (words.every(
          (w) => foldText(
            [c.name, c.company ?? '', ...c.emails.map((e) => e.address), ...c.phones.map((p) => p.number)].join(' '),
          ).contains(w),
        ))
          c,
    ];
  }

  Contact? get selected => _all.where((c) => c.id == selectedId).firstOrNull;

  int get count => _all.length;

  Future<void> openBook(String account) async {
    book = account;
    selectedId = null;
    query = '';
    await reload();
  }

  Future<void> reload() async {
    final account = book;
    if (account == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      contacts[account] = await api.forAccount(account).getContacts();
      if (selected == null) selectedId = visible.firstOrNull?.id;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    query = value;
    if (!visible.any((c) => c.id == selectedId)) selectedId = visible.firstOrNull?.id;
    notifyListeners();
  }

  void select(String id) {
    selectedId = id;
    notifyListeners();
  }

  /// Crea (id vuoto) o modifica il contatto nella rubrica di [account]; errori del core come ApiException.
  Future<Contact> save(Contact contact, {required String account}) async {
    final client = api.forAccount(account);
    final saved = contact.id.isEmpty ? await client.createContact(contact) : await client.updateContact(contact);
    _follow(account); // con CardDAV il core la manda subito al server
    if (book == account) {
      contacts[account] = await client.getContacts();
      selectedId = saved.id;
      notifyListeners();
    }
    return saved;
  }

  Future<void> delete(String id) async {
    final account = book;
    if (account == null) return;
    final list = visible;
    final index = list.indexWhere((c) => c.id == id);
    await api.forAccount(account).deleteContact(id);
    _follow(account);
    contacts[account] = _all.where((c) => c.id != id).toList();
    if (selectedId == id) {
      final rest = visible;
      selectedId = rest.isEmpty ? null : rest[index.clamp(0, rest.length - 1)].id;
    }
    notifyListeners();
  }

  Future<ContactImportResult> import(String format, Uint8List data) async {
    final account = book!;
    final result = await api.forAccount(account).importContacts(format, data);
    _follow(account);
    await reload();
    return result;
  }

  Future<Uint8List> export(String format) => api.forAccount(book!).exportContacts(format);
}
