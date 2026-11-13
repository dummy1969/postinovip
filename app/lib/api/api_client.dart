import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'sse.dart';

import '../account/connection_security.dart';

import '../models/account_info.dart';
import '../models/compose_content.dart';
import '../models/compose_draft.dart';
import '../models/mail_importance.dart';
import '../models/calendar.dart';
import '../models/carddav.dart';
import '../models/contact.dart';
import '../models/conversation.dart';
import '../models/folder_change.dart';
import '../models/auto_reply.dart';
import '../models/junk_options.dart';
import '../models/mail_rule.dart';
import '../models/oauth.dart';
import '../models/mailbox_event.dart';
import '../models/mail_folder.dart';
import '../models/message_detail.dart';
import '../models/message_page.dart';
import '../models/message_tags.dart';
import '../models/orphan_cache.dart';
import '../models/search_result.dart';
import '../models/send_result.dart';

/// Errore restituito dall'Api (ProblemDetails), di connessione o di formato della risposta.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;

  /// Errori di validazione per campo (chiavi in minuscolo, es. "to", "cc"), da ValidationProblemDetails.
  final Map<String, List<String>> fieldErrors;

  @override
  String toString() => statusCode == null ? message : '$message (HTTP $statusCode)';
}

/// Esito di sposta / elimina su più mail: destinazione (null se definitiva) e UID trattati.
/// Cartella di archiviazione di un account (GET/PUT …/archive).
class ArchiveOptions {
  const ArchiveOptions(this.folder, this.suggested);

  /// Scelta dall'utente (e ancora esistente); null = non ancora scelta.
  final String? folder;

  /// Proposta per la prima volta (del server, dal nome, «Tutti i messaggi» di Gmail); null = nessuna adatta.
  final String? suggested;

  factory ArchiveOptions.fromJson(Map<String, dynamic> json) =>
      ArchiveOptions(json['folder'] as String?, json['suggested'] as String?);
}

class BatchOutcome {
  const BatchOutcome(this.movedTo, this.uids);

  final String? movedTo;
  final List<int> uids;

  factory BatchOutcome.fromJson(Map<String, dynamic> json) =>
      BatchOutcome(json['movedTo'] as String?, (json['uids'] as List).cast<int>());
}

/// Client del core PostinoVip in ascolto su 127.0.0.1.
///
/// Cartelle, messaggi e invio riguardano una casella: con [forAccount] le richieste vanno a
/// /accounts/{id}/...; dal client principale (senza account) vanno al primo account del core.
class ApiClient {
  ApiClient({this.baseUrl = 'http://127.0.0.1:5080', this.token, http.Client? httpClient})
    : _http = httpClient ?? http.Client(),
      account = null;

  ApiClient._scoped(ApiClient root, String this.account)
    : baseUrl = root.baseUrl,
      token = root.token,
      _http = root._http;

  final String baseUrl;

  /// Id dell'account di questo client (null = primo account del core).
  final String? account;

  /// Token del core (Authorization: Bearer). Null solo nei test con core finto.
  final String? token;
  final http.Client _http;

  /// Header di autenticazione, usati anche da Image.network per le anteprime degli allegati.
  Map<String, String> get authHeaders => token == null ? const {} : {'authorization': 'Bearer $token'};

  // Ogni richiesta apre una connessione IMAP/SMTP nel core: qualche secondo è normale.
  static const _timeout = Duration(seconds: 30);

  /// Client per l'account [id]: stessa connessione HTTP e stesso token, percorsi /accounts/{id}/...
  ApiClient forAccount(String id) => ApiClient._scoped(this, id);

  /// Prefisso dei percorsi di cartelle, messaggi e invio.
  String get _mail => account == null ? '' : '/accounts/${Uri.encodeComponent(account!)}';

  /// Le caselle gestite dal core, in ordine (il primo è l'account predefinito).
  Future<List<AccountInfo>> getAccounts() =>
      _get('/accounts', (json) => (json as List).map((e) => AccountInfo.fromJson(e as Map<String, dynamic>)).toList());

  Future<List<MailFolder>> getFolders() => _get(
    '$_mail/folders',
    (json) => (json as List).map((e) => MailFolder.fromJson(e as Map<String, dynamic>)).toList(),
  );

  /// [unreadOnly]: solo da leggere; [oldestFirst]: in ordine crescente (dal più vecchio, A→Z, dal più
  /// piccolo); [sort]: colonna dell'ordinamento (3.9: date, from, subject, size). Servono la cache locale nel core.
  Future<MessagePage> getMessages(
    String folder, {
    int offset = 0,
    int limit = 50,
    bool unreadOnly = false,
    bool oldestFirst = false,
    String sort = 'date',
  }) {
    // encodeComponent codifica anche "/" (-> %2F), che il core decodifica.
    final path =
        '$_mail/folders/${Uri.encodeComponent(folder)}/messages?offset=$offset&limit=$limit'
        '${unreadOnly ? '&unread=true' : ''}${oldestFirst ? '&order=asc' : ''}${sort == 'date' ? '' : '&sort=$sort'}';
    return _get(path, (json) => MessagePage.fromJson(json as Map<String, dynamic>));
  }

  /// Conversazioni di [folder] (3.6), dalla più recente; ognuna con le sue mail, anche di altre
  /// cartelle dell'account. Stessi parametri della lista (servono la cache locale nel core).
  Future<ConversationPage> getConversations(
    String folder, {
    int offset = 0,
    int limit = 50,
    bool unreadOnly = false,
    bool oldestFirst = false,
  }) {
    final path =
        '$_mail/folders/${Uri.encodeComponent(folder)}/conversations?offset=$offset&limit=$limit'
        '${unreadOnly ? '&unread=true' : ''}${oldestFirst ? '&order=asc' : ''}';
    return _get(path, (json) => ConversationPage.fromJson(json as Map<String, dynamic>));
  }

  /// Ricerca nella cache locale del core: in tutta la casella o solo in [folder].
  /// Sintassi: parole, "frasi", da: a: oggetto: allegato: allegati:sì/no.
  Future<SearchPage> search(String query, {String? folder, int offset = 0, int limit = 50}) {
    final params = Uri(
      queryParameters: {'q': query, 'folder': ?folder, 'offset': '$offset', 'limit': '$limit'},
    ).query;
    return _get('$_mail/search?$params', (json) => SearchPage.fromJson(json as Map<String, dynamic>));
  }

  /// Ricerca sul server (IMAP SEARCH) per le mail il cui corpo non è nella cache locale: più lenta,
  /// solo su richiesta dell'utente.
  Future<SearchPage> searchServer(String query, {String? folder, int limit = 200}) {
    final params = Uri(queryParameters: {'q': query, 'folder': ?folder, 'offset': '0', 'limit': '$limit'}).query;
    return _get('$_mail/search/server?$params', (json) => SearchPage.fromJson(json as Map<String, dynamic>));
  }

  // ---------------------------------------------------------------------------------------------
  // Contatti (C2): rubrica dell'account di questo client, solo sul computer. Non toccano la casella.
  // ---------------------------------------------------------------------------------------------

  Future<List<Contact>> getContacts() => _get(
    '$_mail/contacts',
    (json) => [
      for (final e in (json as Map<String, dynamic>)['items'] as List) Contact.fromJson(e as Map<String, dynamic>),
    ],
  );

  /// Stato della sincronizzazione CardDAV della rubrica (C4c); core senza CardDAV (404) = spenta.
  Future<CardDavStatus> getContactsSync() async {
    try {
      return await _get('$_mail/contacts/sync', (json) => CardDavStatus.fromJson(json as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) return CardDavStatus.off;
      rethrow;
    }
  }

  /// Sincronizza subito la rubrica con il server dei contatti.
  Future<void> syncContacts() => _send('POST', '$_mail/contacts/sync', null, (_) {});

  /// **Modifica la rubrica del server**: carica i contatti che sono solo sul computer (prima volta, 2a).
  Future<void> confirmContactsSync() => _send('POST', '$_mail/contacts/sync/confirm', null, (_) {});

  /// Calendari dell'account (K3); il primo è il predefinito.
  Future<List<CalendarInfo>> getCalendars() => _get(
    '$_mail/calendars',
    (json) => [for (final e in (json as Map<String, dynamic>)['items'] as List) CalendarInfo.fromJson(e as Map<String, dynamic>)],
  );

  /// Occorrenze di [from, to) nei calendari indicati (tutti se null), ricorrenze espanse; orari convertiti nell'ora locale.
  Future<List<CalendarOccurrence>> getCalendarEvents(DateTime from, DateTime to, {List<String>? calendars}) {
    final id = account ?? '';
    final query = Uri(queryParameters: {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      if (calendars != null) 'calendars': calendars.join(','),
    }).query;
    return _get('$_mail/calendars/events?$query', (json) => [
      for (final e in (json as Map<String, dynamic>)['items'] as List) CalendarOccurrence.fromJson(id, e as Map<String, dynamic>),
    ]);
  }

  /// La serie di un appuntamento (scheda in sola lettura).
  Future<CalendarEventDetail> getCalendarEvent(String calendarId, String eventId) => _get(
    '$_mail/calendars/${Uri.encodeComponent(calendarId)}/events/${Uri.encodeComponent(eventId)}',
    (json) => CalendarEventDetail.fromJson(json as Map<String, dynamic>),
  );

  String _eventPath(String calendarId, [String? eventId]) =>
      '$_mail/calendars/${Uri.encodeComponent(calendarId)}/events${eventId == null ? '' : '/${Uri.encodeComponent(eventId)}'}';

  String _occurrence(String recurrenceId) => '/occurrence?${Uri(queryParameters: {'recurrenceId': recurrenceId}).query}';

  /// **Modifica il calendario** (con CalDAV poi anche il server): nuovo appuntamento; [body] come EventRequest del core.
  Future<CalendarEventDetail> createCalendarEvent(String calendarId, Map<String, dynamic> body) =>
      _send('POST', _eventPath(calendarId), body, (json) => CalendarEventDetail.fromJson(json as Map<String, dynamic>));

  /// **Modifica** la serie (solo i campi indicati; con keepRecurrence la ricorrenza resta com'è).
  Future<CalendarEventDetail> updateCalendarEvent(String calendarId, String eventId, Map<String, dynamic> body) =>
      _send('PUT', _eventPath(calendarId, eventId), body, (json) => CalendarEventDetail.fromJson(json as Map<String, dynamic>));

  /// **Elimina** la serie (non si recupera).
  Future<void> deleteCalendarEvent(String calendarId, String eventId) =>
      _send('DELETE', _eventPath(calendarId, eventId), null, (_) {});

  /// Una sola occorrenza di una serie (K4a).
  Future<CalendarEventDetail> getCalendarOccurrence(String calendarId, String eventId, String recurrenceId) =>
      _get(_eventPath(calendarId, eventId) + _occurrence(recurrenceId), (json) => CalendarEventDetail.fromJson(json as Map<String, dynamic>));

  /// **Modifica** solo questa occorrenza (eccezione nella serie).
  Future<CalendarEventDetail> updateCalendarOccurrence(String calendarId, String eventId, String recurrenceId, Map<String, dynamic> body) =>
      _send('PUT', _eventPath(calendarId, eventId) + _occurrence(recurrenceId), body,
          (json) => CalendarEventDetail.fromJson(json as Map<String, dynamic>));

  /// **Elimina** solo questa occorrenza (esclusa dalla serie).
  Future<void> deleteCalendarOccurrence(String calendarId, String eventId, String recurrenceId) =>
      _send('DELETE', _eventPath(calendarId, eventId) + _occurrence(recurrenceId), null, (_) {});

  /// Stato della sincronizzazione CalDAV (stesso formato di quella dei contatti); core senza calendari = spenta.
  Future<CardDavStatus> getCalendarsSync() async {
    try {
      return await _get('$_mail/calendars/sync', (json) => CardDavStatus.fromJson(json as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) return CardDavStatus.off;
      rethrow;
    }
  }

  Future<void> syncCalendars() => _send('POST', '$_mail/calendars/sync', null, (_) {});

  /// **Modifica i calendari del server**: carica gli appuntamenti che sono solo sul computer (prima volta).
  Future<void> confirmCalendarsSync() => _send('POST', '$_mail/calendars/sync/confirm', null, (_) {});

  /// «Verifica calendario» (K3): cerca i calendari CalDAV con questi dati, in sola lettura, senza salvarli.
  /// Con la password, oppure (G3, Gmail) con fornitore e token di rinnovo.
  Future<CalDavTestResult> testCalDav({
    required String email,
    String password = '',
    required String host,
    String? url,
    String? certificateSha256,
    String? oauthProvider,
    String? refreshToken,
  }) => _send('POST', '/account/test-caldav', {
    'email': email,
    'password': password,
    'host': host,
    if ((url ?? '').trim().isNotEmpty) 'url': url!.trim(),
    'certificateSha256': ?certificateSha256,
    'oauthProvider': ?oauthProvider,
    'refreshToken': ?refreshToken,
  }, (json) => CalDavTestResult.fromJson(json as Map<String, dynamic>));

  /// «Verifica rubrica» (C4c, 1b): cerca la rubrica CardDAV con questi dati, in sola lettura, senza salvarli.
  /// «Verifica rubrica»: con la password, oppure (C4d, Gmail) con fornitore e token di rinnovo.
  Future<CardDavTestResult> testCardDav({
    required String email,
    String password = '',
    required String host,
    String? url,
    String? certificateSha256,
    String? oauthProvider,
    String? refreshToken,
  }) => _send('POST', '/account/test-carddav', {
    'email': email,
    'password': password,
    'host': host,
    if ((url ?? '').trim().isNotEmpty) 'url': url!.trim(),
    'certificateSha256': ?certificateSha256,
    'oauthProvider': ?oauthProvider,
    'refreshToken': ?refreshToken,
  }, (json) => CardDavTestResult.fromJson(json as Map<String, dynamic>));

  Future<Contact> createContact(Contact contact) =>
      _send('POST', '$_mail/contacts', contact.toJson(), (json) => Contact.fromJson(json as Map<String, dynamic>));

  Future<Contact> updateContact(Contact contact) => _send(
    'PUT',
    '$_mail/contacts/${Uri.encodeComponent(contact.id)}',
    contact.toJson(),
    (json) => Contact.fromJson(json as Map<String, dynamic>),
  );

  Future<void> deleteContact(String id) => _send('DELETE', '$_mail/contacts/${Uri.encodeComponent(id)}', null, (_) {});

  /// Importa un file .vcf o .csv ([format] "vcf"/"csv"), con i byte così come sono.
  Future<ContactImportResult> importContacts(String format, Uint8List data) => _send('POST', '$_mail/contacts/import', {
    'format': format,
    'data': base64Encode(data),
  }, (json) => ContactImportResult.fromJson(json as Map<String, dynamic>));

  /// Tutta la rubrica come file ([format] "vcf"/"csv").
  Future<Uint8List> exportContacts(String format) async {
    final http.Response response;
    try {
      response = await _http
          .get(Uri.parse('$baseUrl$_mail/contacts/export?format=$format'), headers: authHeaders)
          .timeout(_timeout);
    } on Exception catch (e) {
      throw ApiException('Core PostinoVip non raggiungibile su $baseUrl: $e');
    }
    if (response.statusCode != 200) throw _problem(utf8.decode(response.bodyBytes), response.statusCode);
    return response.bodyBytes;
  }

  /// Completamento degli indirizzi (C3): contatti e indirizzi recenti di tutti gli account.
  Future<List<AddressSuggestion>> suggestAddresses(String query, {int limit = 10}) => _get(
    '/addresses/suggest?${Uri(queryParameters: {'q': query, 'limit': '$limit'}).query}',
    (json) => [
      for (final e in (json as Map<String, dynamic>)['items'] as List)
        AddressSuggestion.fromJson(e as Map<String, dynamic>),
    ],
  );

  /// La ✕ di un indirizzo recente: non viene più suggerito.
  Future<void> removeRecentAddress(String address) =>
      _send('DELETE', '/addresses/recent?${Uri(queryParameters: {'address': address}).query}', null, (_) {});

  /// Dati locali di account non più configurati (rimossi dall'app), con lo spazio occupato.
  Future<List<OrphanCache>> getCacheOrphans() => _get(
    '/cache/orphans',
    (json) => [for (final e in json as List) OrphanCache.fromJson(e as Map<String, dynamic>)],
  );

  /// Elimina dal computer i dati locali di un account rimosso. Sul server non cambia nulla.
  Future<void> deleteCacheOrphan(String id) =>
      _send('DELETE', '/cache/orphans/${Uri.encodeComponent(id)}', null, (_) {});

  /// "Ricostruisci cache" dell'account di questo client: la copia locale viene svuotata e
  /// riscaricata dal server in background. Sul server non cambia nulla.
  Future<void> rebuildCache() {
    final id = account;
    if (id == null) throw ArgumentError('rebuildCache richiede un client per account (forAccount).');
    return _send('POST', '/accounts/${Uri.encodeComponent(id)}/cache/rebuild', null, (_) {});
  }

  /// Fornitori OAuth2 del core (con o senza client ID).
  Future<List<OAuthProviderInfo>> getOAuthProviders() => _get(
    '/oauth/providers',
    (json) => [for (final p in json as List) OAuthProviderInfo.fromJson(p as Map<String, dynamic>)],
  );

  /// Inizia un accesso: id dell'accesso e indirizzo da aprire nel browser di sistema.
  /// [contacts] (C4d): anche il permesso dei contatti (solo per un account con la sincronizzazione dei contatti).
  Future<({String id, String url})> startOAuth(String provider, {String? loginHint, bool contacts = false, bool calendar = false}) => _send(
    'POST',
    '/oauth/start',
    {'provider': provider, 'loginHint': ?loginHint, if (contacts) 'contacts': true, if (calendar) 'calendar': true},
    (json) {
      final m = json as Map<String, dynamic>;
      return (id: m['id'] as String, url: m['authorizationUrl'] as String);
    },
  );

  /// Stato dell'accesso; a fine accesso il token di rinnovo arriva una volta sola.
  Future<OAuthFlowStatus> getOAuthFlow(String id) =>
      _get('/oauth/flows/${Uri.encodeComponent(id)}', (json) => OAuthFlowStatus.fromJson(json as Map<String, dynamic>));

  Future<void> cancelOAuth(String id) => _send('DELETE', '/oauth/flows/${Uri.encodeComponent(id)}', null, (_) {});

  /// Risposte automatiche dell'account.
  Future<AutoReplySettings> getAutoReply() =>
      _get('$_mail/autoreply', (json) => AutoReplySettings.fromJson(json as Map<String, dynamic>));

  /// Salva le risposte automatiche: attivarle vuol dire che il core invierà risposte senza conferma.
  Future<AutoReplySettings> saveAutoReply(AutoReplySettings settings) => _send(
    'PUT',
    '$_mail/autoreply',
    settings.toJson(),
    (json) => AutoReplySettings.fromJson(json as Map<String, dynamic>),
  );

  /// Regole dell'account (R2), nell'ordine in cui il core le applica.
  Future<List<MailRule>> getRules() =>
      _get('$_mail/rules', (json) => [for (final r in json as List) MailRule.fromJson(r as Map<String, dynamic>)]);

  /// Sostituisce l'elenco completo; il core restituisce quello salvato (con gli id delle regole nuove).
  Future<List<MailRule>> saveRules(List<MailRule> rules) => _send(
    'PUT',
    '$_mail/rules',
    [for (final r in rules) r.toJson()],
    (json) => [for (final r in json as List) MailRule.fromJson(r as Map<String, dynamic>)],
  );

  /// "Esegui regole ora" (R3, MODIFICA la casella): avvia l'esecuzione nel core; restituisce il suo id.
  Future<String> startRulesRun({
    required List<String> ruleIds,
    required String folder,
    bool includeSubfolders = false,
    RuleRunFilter filter = RuleRunFilter.all,
  }) => _send(
    'POST',
    '$_mail/rules/run',
    {'ruleIds': ruleIds, 'folder': folder, 'includeSubfolders': includeSubfolders, 'filter': filter.coreName},
    (json) => (json as Map<String, dynamic>)['id'] as String,
  );

  Future<RuleRunStatus> getRulesRun(String id) =>
      _get('$_mail/rules/run/${Uri.encodeComponent(id)}', (json) => RuleRunStatus.fromJson(json as Map<String, dynamic>));

  /// Interrompe l'esecuzione: ciò che è già stato fatto resta.
  Future<void> cancelRulesRun(String id) => _send('DELETE', '$_mail/rules/run/${Uri.encodeComponent(id)}', null, (_) {});

  /// Opzioni posta indesiderata dell'account (J2): livello, cartella, elenchi.
  Future<JunkOptions> getJunkOptions() =>
      _get('$_mail/junk', (json) => JunkOptions.fromJson(json as Map<String, dynamic>));

  /// Salva le opzioni (non modifica la casella: valgono per le mail che arrivano da adesso). Voce o cartella non
  /// valida: ApiException con l'errore sul campo ("safesenders", "folder"...).
  Future<JunkOptions> saveJunkOptions(JunkOptions options) => _send(
    'PUT',
    '$_mail/junk',
    options.toJson(),
    (json) => JunkOptions.fromJson(json as Map<String, dynamic>),
  );

  /// «Blocca mittente», MODIFICA la casella: mittenti tra i bloccati, mail con $Junk spostate nella posta
  /// indesiderata (409 se l'account non ne ha una).
  Future<JunkCommandResult> blockSenders(String folder, List<int> uids) => _junkCommand(folder, 'block', {'uids': uids});

  /// «Non bloccare mai…»: solo gli elenchi, la casella non cambia.
  Future<JunkCommandResult> neverBlock(String folder, List<int> uids, NeverBlockKind kind) =>
      _junkCommand(folder, 'never-block', {'uids': uids, 'kind': kind.coreName});

  /// «Non è posta indesiderata», MODIFICA la casella: $NotJunk e ritorno in Posta in arrivo (solo dalla cartella
  /// della posta indesiderata); con [trustSenders] i mittenti diventano attendibili.
  Future<JunkCommandResult> notJunk(String folder, List<int> uids, {required bool trustSenders}) =>
      _junkCommand(folder, 'not-junk', {'uids': uids, 'trustSenders': trustSenders});

  /// Cartella di archiviazione (A1): la scelta (null = non ancora) e la proposta per la prima volta.
  Future<ArchiveOptions> getArchiveOptions() =>
      _get('$_mail/archive', (json) => ArchiveOptions.fromJson(json as Map<String, dynamic>));

  /// Sceglie la cartella di archiviazione (null la toglie); non modifica la casella. Cartella non valida:
  /// ApiException con l'errore sul campo "folder".
  Future<ArchiveOptions> setArchiveFolder(String? folder) => _send(
    'PUT',
    '$_mail/archive',
    {'folder': folder},
    (json) => ArchiveOptions.fromJson(json as Map<String, dynamic>),
  );

  /// «Archivia», MODIFICA la casella: sposta le mail nella cartella di archiviazione (letto/non letto invariato).
  Future<BatchOutcome> archiveMany(String folder, List<int> uids) => _send(
    'POST',
    '$_mail/messages/${Uri.encodeComponent(folder)}/archive',
    {'uids': uids},
    (json) => BatchOutcome.fromJson(json as Map<String, dynamic>),
  );

  /// La conversazione della mail è ignorata (C1)? Sola lettura.
  Future<bool> isIgnored(String folder, int uid) => _get(
    '$_mail/messages/${Uri.encodeComponent(folder)}/$uid/ignored',
    (json) => (json as Map<String, dynamic>)['ignored'] as bool? ?? false,
  );

  /// «Ignora conversazione», MODIFICA la casella: le mail delle conversazioni in [folder] vanno in Posta eliminata
  /// e le future della Posta in arrivo pure.
  Future<BatchOutcome> ignoreConversations(String folder, List<int> uids) => _send(
    'POST',
    '$_mail/messages/${Uri.encodeComponent(folder)}/ignore',
    {'uids': uids},
    (json) => BatchOutcome.fromJson(json as Map<String, dynamic>),
  );

  /// «Interrompi Ignora conversazione»; da Posta eliminata MODIFICA la casella (le mail tornano in Posta in arrivo).
  Future<BatchOutcome> stopIgnoring(String folder, List<int> uids) => _send(
    'POST',
    '$_mail/messages/${Uri.encodeComponent(folder)}/stop-ignoring',
    {'uids': uids},
    (json) => BatchOutcome.fromJson(json as Map<String, dynamic>),
  );

  /// «Pulisci conversazione», MODIFICA la casella: le mail superflue delle conversazioni in Posta eliminata.
  Future<BatchOutcome> cleanUpConversations(String folder, List<int> uids) => _send(
    'POST',
    '$_mail/messages/${Uri.encodeComponent(folder)}/clean-up',
    {'uids': uids},
    (json) => BatchOutcome.fromJson(json as Map<String, dynamic>),
  );

  /// «Pulisci cartella», MODIFICA la casella: come [cleanUpConversations] su tutta la cartella.
  Future<BatchOutcome> cleanUpFolder(String folder) => _send(
    'POST',
    '$_mail/folders/${Uri.encodeComponent(folder)}/clean-up',
    null,
    (json) => BatchOutcome.fromJson(json as Map<String, dynamic>),
  );

  Future<JunkCommandResult> _junkCommand(String folder, String command, Map<String, dynamic> body) => _send(
    'POST',
    '$_mail/messages/${Uri.encodeComponent(folder)}/$command',
    body,
    (json) => JunkCommandResult.fromJson(json as Map<String, dynamic>),
  );

  /// "Invia/ricevi" per un account POP3 (4.2c): il core controlla subito il server; le mail nuove
  /// arrivano con l'evento mailbox-changed. Per un account IMAP non fa nulla (c'è l'IDLE).
  Future<void> receive() {
    final id = account;
    if (id == null) throw ArgumentError('receive richiede un client per account (forAccount).');
    return _send('POST', '/accounts/${Uri.encodeComponent(id)}/receive', null, (_) {});
  }

  /// Lettura con BODY.PEEK nel core: il messaggio non viene segnato come letto.
  Future<MessageDetail> getMessage(String folder, int uid) {
    final path = '$_mail/messages/${Uri.encodeComponent(folder)}/$uid';
    return _get(path, (json) => MessageDetail.fromJson(json as Map<String, dynamic>));
  }

  /// URL dell'allegato, usato direttamente da Image.network per le anteprime.
  String attachmentUrl(String folder, int uid, int index) =>
      '$baseUrl$_mail/messages/${Uri.encodeComponent(folder)}/$uid/attachments/$index';

  /// Bozza di risposta / rispondi a tutti / inoltro, generata dal core. Non invia nulla.
  Future<ComposeDraft> getDraft(String folder, int uid, DraftMode mode) {
    final path = '$_mail/messages/${Uri.encodeComponent(folder)}/$uid/draft?mode=${mode.query}';
    return _get(path, (json) => ComposeDraft.fromJson(json as Map<String, dynamic>));
  }

  /// Contenuto di un allegato (per salvarlo su disco).
  Future<Uint8List> getAttachmentBytes(String folder, int uid, int index) => _bytes(attachmentUrl(folder, uid, index));

  /// Byte originali della mail (E2, «Salva con nome» .eml): dalla copia locale o con BODY.PEEK[], non diventa letta.
  Future<Uint8List> getRawMessage(String folder, int uid) =>
      _bytes('$baseUrl$_mail/messages/${Uri.encodeComponent(folder)}/$uid/raw');

  /// Risposta alla richiesta di conferma di lettura (R2): con [send] INVIA la conferma al mittente; in ogni caso
  /// MODIFICA la casella ($MDNSent). [automatic]: per l'opzione «Invia sempre». Restituisce se è stata inviata.
  Future<bool> answerReadReceipt(String folder, int uid, {required bool send, bool automatic = false}) => _send(
    'POST',
    '$_mail/messages/${Uri.encodeComponent(folder)}/$uid/receipt',
    {'send': send, if (automatic) 'automatic': true},
    (json) => (json as Map<String, dynamic>)['sent'] as bool,
  );

  /// Apre un file .eml nel core (E2): resta in memoria, in sola lettura; [closeEml] lo chiude.
  Future<({String id, MessageDetail message})> openEml(Uint8List bytes) async {
    final http.Response response;
    try {
      response = await _http
          .post(Uri.parse('$baseUrl/eml'), headers: {...authHeaders, 'content-type': 'message/rfc822'}, body: bytes)
          .timeout(_timeout);
    } on Exception catch (e) {
      throw ApiException('Core PostinoVip non raggiungibile su $baseUrl: $e');
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode != 200) throw _problem(text, response.statusCode);
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      return (id: json['id'] as String, message: MessageDetail.fromJson(json['message'] as Map<String, dynamic>));
    } on Object {
      throw ApiException('Risposta inattesa dal core (versioni diverse di app e core?)');
    }
  }

  /// URL di un allegato di un file .eml aperto (anteprime delle immagini).
  String emlAttachmentUrl(String id, int index) => '$baseUrl/eml/${Uri.encodeComponent(id)}/attachments/$index';

  Future<Uint8List> getEmlAttachmentBytes(String id, int index) => _bytes(emlAttachmentUrl(id, index));

  /// Bozza di risposta o inoltro dal file .eml aperto; il proprio indirizzo è quello di questo account.
  Future<ComposeDraft> getEmlDraft(String id, DraftMode mode) =>
      _get('$_mail/eml/${Uri.encodeComponent(id)}/draft?mode=${mode.query}', (json) => ComposeDraft.fromJson(json as Map<String, dynamic>));

  /// Chiude il file .eml nel core (finestra chiusa).
  Future<void> closeEml(String id) => _send('DELETE', '/eml/${Uri.encodeComponent(id)}', null, (_) {});

  Future<Uint8List> _bytes(String url) async {
    final http.Response response;
    try {
      response = await _http.get(Uri.parse(url), headers: authHeaders).timeout(_timeout);
    } on Exception catch (e) {
      throw ApiException('Core PostinoVip non raggiungibile su $baseUrl: $e');
    }
    if (response.statusCode != 200) throw _problem(utf8.decode(response.bodyBytes, allowMalformed: true), response.statusCode);
    return response.bodyBytes;
  }

  /// Versione del core, del runtime .NET e del sistema operativo (finestra "Informazioni").
  Future<({String version, String runtime, String os})> getVersion() => _get('/version', (json) {
    final m = json as Map<String, dynamic>;
    return (version: m['version'] as String, runtime: m['runtime'] as String, os: m['os'] as String);
  });

  /// Indirizzo del primo account del core.
  Future<String> getAccount() => _get('/account', (json) => (json as Map<String, dynamic>)['address'] as String);

  /// Il core ha i dati per collegarsi alla casella (da account salvato o, in sviluppo, user-secrets)?
  Future<({String address, bool configured})> getAccountStatus() => _get('/account', (json) {
    final m = json as Map<String, dynamic>;
    return (address: m['address'] as String, configured: m['configured'] as bool);
  });

  /// Prova login IMAP e autenticazione SMTP senza salvare né inviare nulla.
  /// Restituisce l'errore per ciascun server, null se riuscito.
  Future<AccountTestResult> testAccount({
    required String email,
    required String password,
    required String imapHost,
    required int imapPort,
    required String smtpHost,
    required int smtpPort,
    AccountType type = AccountType.imap,
    MailSecurity? imapSecurity,
    MailSecurity? smtpSecurity,
    bool smtpRequireAuth = true,
    String? imapCertificateSha256,
    String? smtpCertificateSha256,
    String? oauthProvider,
    String? refreshToken,
  }) => _send(
    'POST',
    '/account/test',
    {
      'email': email,
      'password': password,
      'imapHost': imapHost,
      'imapPort': imapPort,
      'smtpHost': smtpHost,
      'smtpPort': smtpPort,
      'type': type.coreName,
      'imapSecurity': ?imapSecurity?.coreName,
      'smtpSecurity': ?smtpSecurity?.coreName,
      'smtpRequireAuth': smtpRequireAuth,
      'imapCertificateSha256': ?imapCertificateSha256,
      'smtpCertificateSha256': ?smtpCertificateSha256,
      'oauthProvider': ?oauthProvider,
      'refreshToken': ?refreshToken,
    },
    (json) {
      final m = json as Map<String, dynamic>;
      String? error(String key) {
        final r = m[key] as Map<String, dynamic>;
        return r['ok'] == true ? null : (r['error'] as String? ?? 'errore');
      }

      CertificateInfo? certificate(String key) {
        final c = (m[key] as Map<String, dynamic>)['certificate'];
        return c is Map<String, dynamic> ? CertificateInfo.fromJson(c) : null;
      }

      return AccountTestResult(
        imapError: error('imap'),
        smtpError: error('smtp'),
        imapCertificate: certificate('imap'),
        smtpCertificate: certificate('smtp'),
      );
    },
  );

  /// Invia davvero la mail. Con [saveCopy] il core salva anche una copia in Posta inviata
  /// (MODIFICA la casella).
  Future<SendResult> send({
    required List<String> to,
    List<String> cc = const [],
    List<String> bcc = const [],
    required String subject,
    required String body,
    String? inReplyTo,
    List<String> references = const [],
    bool saveCopy = false,
    List<({String fileName, List<int> bytes})> attachments = const [],
    // Allegati da riprendere dal messaggio originale; account = casella in cui si trova
    // (null = la stessa da cui si invia).
    ({String? account, String folder, int uid, List<int> indexes})? forward,
    // Testo formattato (3.7b): con htmlBody la mail è HTML + testo (body).
    String? htmlBody,
    // Risposta o inoltro: il core aggiunge in fondo la citazione (dall'originale o già pronta).
    QuoteRef? quote,
    // "Ritarda recapito" (3.8): fino ad allora nella Posta in uscita.
    DateTime? sendAfter,
    // Bozza da eliminare una volta inviata la mail.
    DraftRef? deleteDraft,
    // Priorità alta o bassa (P1).
    MailImportance importance = MailImportance.normal,
    // «Richiedi conferma di lettura» (R2).
    bool readReceipt = false,
  }) => _send('POST', '$_mail/send', {
    ..._composeJson(
      to: to,
      cc: cc,
      bcc: bcc,
      subject: subject,
      body: body,
      inReplyTo: inReplyTo,
      references: references,
      saveCopy: saveCopy,
      attachments: attachments,
      forward: forward,
      htmlBody: htmlBody,
      quote: quote,
    ),
    'sendAfter': ?sendAfter?.toUtc().toIso8601String(),
    'deleteDraft': ?deleteDraft?.toJson(),
    if (importance != MailImportance.normal) 'importance': importance.toJson(),
    if (readReceipt) 'readReceipt': true,
  }, (json) => SendResult.fromJson(json as Map<String, dynamic>));

  /// MODIFICA la casella (3.8): salva la bozza in Bozze al posto di [replace]; senza connessione resta sul
  /// computer (pending) e va sul server al ritorno. Non invia nulla.
  Future<DraftSaveResult> saveDraft({
    required List<String> to,
    List<String> cc = const [],
    List<String> bcc = const [],
    required String subject,
    required String body,
    String? inReplyTo,
    List<String> references = const [],
    List<({String fileName, List<int> bytes})> attachments = const [],
    ({String? account, String folder, int uid, List<int> indexes})? forward,
    String? htmlBody,
    QuoteRef? quote,
    DraftRef? replace,
    MailImportance importance = MailImportance.normal,
    bool readReceipt = false,
  }) => _send('POST', '$_mail/drafts', {
    ..._composeJson(
      to: to,
      cc: cc,
      bcc: bcc,
      subject: subject,
      body: body,
      inReplyTo: inReplyTo,
      references: references,
      saveCopy: false,
      attachments: attachments,
      forward: forward,
      htmlBody: htmlBody,
      quote: quote,
    ),
    'replace': ?replace?.toJson(),
    if (importance != MailImportance.normal) 'importance': importance.toJson(),
    if (readReceipt) 'readReceipt': true,
  }, (json) => DraftSaveResult.fromJson(json as Map<String, dynamic>));

  static Map<String, dynamic> _composeJson({
    required List<String> to,
    required List<String> cc,
    required List<String> bcc,
    required String subject,
    required String body,
    required String? inReplyTo,
    required List<String> references,
    required bool saveCopy,
    required List<({String fileName, List<int> bytes})> attachments,
    required ({String? account, String folder, int uid, List<int> indexes})? forward,
    required String? htmlBody,
    required QuoteRef? quote,
  }) => {
    'to': to,
    'cc': cc,
    'bcc': bcc,
    'subject': subject,
    'body': body,
    'htmlBody': ?htmlBody,
    'quote': quote?.toJson(),
    'inReplyTo': inReplyTo,
    'references': references,
    'saveCopy': saveCopy,
    // byte in base64, come si aspetta byte[] lato C# (System.Text.Json); tipo ricavato dal core.
    'attachments': [
      for (final a in attachments) {'fileName': a.fileName, 'data': base64Encode(a.bytes)},
    ],
    'forwardAttachments': forward == null
        ? null
        : {'account': ?forward.account, 'folder': forward.folder, 'uid': forward.uid, 'indexes': forward.indexes},
  };

  /// Bozza (o mail qualsiasi) da riaprire nella composizione (3.8). Non modifica nulla.
  Future<ComposeContent> getComposeContent(String folder, int uid) => _get(
    '$_mail/messages/${Uri.encodeComponent(folder)}/$uid/compose',
    (json) => ComposeContent.fromJson(json as Map<String, dynamic>),
  );

  /// Posta in uscita dell'account (3.8); 501 se il core non ha la cache locale.
  Future<List<OutboxEntry>> getOutbox() => _get(
    '$_mail/outbox',
    (json) => [for (final e in json as List) OutboxEntry.fromJson(e as Map<String, dynamic>)],
  );

  /// La mail non verrà inviata (eliminata dal computer).
  Future<void> deleteOutbox(String id) => _send('DELETE', '$_mail/outbox/${Uri.encodeComponent(id)}', null, (_) {});

  /// "Invia ora": niente più attesa né errore; parte al prossimo passaggio del core.
  Future<void> sendOutboxNow(String id) => _send('POST', '$_mail/outbox/${Uri.encodeComponent(id)}/send', null, (_) {});

  /// MODIFICA la casella: la mail torna in Bozze (per modificarla) e non viene più inviata.
  Future<DraftSaveResult> outboxToDrafts(String id) => _send(
    'POST',
    '$_mail/outbox/${Uri.encodeComponent(id)}/to-drafts',
    null,
    (json) => DraftSaveResult.fromJson(json as Map<String, dynamic>),
  );

  /// MODIFICA la casella: imposta o toglie il flag \Seen. Restituisce lo stato confermato dal server.
  Future<bool> setSeen(String folder, int uid, bool seen) => _send(
    'PUT',
    '$_mail/messages/${Uri.encodeComponent(folder)}/$uid/seen',
    {'seen': seen},
    (json) => (json as Map<String, dynamic>)['seen'] as bool,
  );

  /// MODIFICA la casella: contrassegno ([followUp] `none` | `flagged` | `completed`, con [due] solo
  /// per `flagged`) e/o l'insieme completo delle [categories]. Restituisce lo stato dopo la modifica.
  Future<MessageTags> setTags(String folder, int uid, {String? followUp, DateTime? due, List<int>? categories}) => _send(
    'PUT',
    '$_mail/messages/${Uri.encodeComponent(folder)}/$uid/flags',
    {
      'followUp': ?followUp,
      if (due != null) 'due': MessageTags.formatDay(due),
      'categories': ?categories,
    },
    (json) => MessageTags.fromJson(json as Map<String, dynamic>),
  );

  /// MODIFICA la casella: sposta il messaggio. Restituisce la cartella di destinazione.
  Future<String> move(String folder, int uid, String destination) => _send(
    'POST',
    '$_mail/messages/${Uri.encodeComponent(folder)}/$uid/move',
    {'destination': destination},
    (json) => (json as Map<String, dynamic>)['movedTo'] as String,
  );

  /// MODIFICA la casella: sposta in Posta eliminata (restituisce la cartella) oppure, con
  /// [permanent], elimina definitivamente (solo dentro Posta eliminata; restituisce null).
  Future<String?> delete(String folder, int uid, {bool permanent = false}) => _send(
    'DELETE',
    '$_mail/messages/${Uri.encodeComponent(folder)}/$uid${permanent ? '?permanent=true' : ''}',
    null,
    (json) => (json as Map<String, dynamic>)['movedTo'] as String?,
  );

  // In blocco (3.5a): più mail della stessa cartella con una sola richiesta. Le mail che non
  // esistono più vengono ignorate: le risposte elencano quelle trattate.

  /// MODIFICA la casella: \Seen su più mail. Restituisce gli UID aggiornati.
  Future<List<int>> setSeenMany(String folder, List<int> uids, bool seen) => _send(
    'PUT',
    '$_mail/messages/${Uri.encodeComponent(folder)}/seen',
    {'uids': uids, 'seen': seen},
    (json) => ((json as Map<String, dynamic>)['uids'] as List).cast<int>(),
  );

  /// MODIFICA la casella: contrassegno e categorie su più mail; le categorie si aggiungono o tolgono.
  /// Restituisce lo stato dopo la modifica, per UID.
  Future<Map<int, MessageTags>> setTagsMany(
    String folder,
    List<int> uids, {
    String? followUp,
    DateTime? due,
    List<int>? addCategories,
    List<int>? removeCategories,
  }) => _send(
    'PUT',
    '$_mail/messages/${Uri.encodeComponent(folder)}/flags',
    {
      'uids': uids,
      'followUp': ?followUp,
      if (due != null) 'due': MessageTags.formatDay(due),
      'addCategories': ?addCategories,
      'removeCategories': ?removeCategories,
    },
    (json) => {
      for (final item in ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>())
        item['uid'] as int: MessageTags.fromJson(item),
    },
  );

  /// MODIFICA la casella: sposta più mail. Destinazione e UID spostati.
  Future<BatchOutcome> moveMany(String folder, List<int> uids, String destination) => _send(
    'POST',
    '$_mail/messages/${Uri.encodeComponent(folder)}/move',
    {'uids': uids, 'destination': destination},
    (json) => BatchOutcome.fromJson(json as Map<String, dynamic>),
  );

  /// MODIFICA la casella: copia più mail in [destination] (gli originali restano). Destinazione
  /// (in [BatchOutcome.movedTo]) e UID copiati.
  Future<BatchOutcome> copyMany(String folder, List<int> uids, String destination) => _send(
    'POST',
    '$_mail/messages/${Uri.encodeComponent(folder)}/copy',
    {'uids': uids, 'destination': destination},
    (json) {
      final map = json as Map<String, dynamic>;
      return BatchOutcome(map['copiedTo'] as String?, (map['uids'] as List).cast<int>());
    },
  );

  /// MODIFICA la casella: sposta più mail in Posta eliminata, oppure con [permanent] (solo dentro
  /// Posta eliminata) le elimina DEFINITIVAMENTE.
  Future<BatchOutcome> deleteMany(String folder, List<int> uids, {bool permanent = false}) => _send(
    'POST',
    '$_mail/messages/${Uri.encodeComponent(folder)}/delete',
    {'uids': uids, 'permanent': permanent},
    (json) => BatchOutcome.fromJson(json as Map<String, dynamic>),
  );

  /// MODIFICA la casella: crea la cartella [name] dentro [parent] (null = in cima all'account).
  /// Nome non valido o già usato: ApiException con l'errore sul campo "name".
  Future<FolderChange> createFolder(String? parent, String name) => _send('POST', '$_mail/folders', {
    'parent': ?parent,
    'name': name,
  }, (json) => FolderChange.fromJson(json as Map<String, dynamic>));

  /// MODIFICA la casella: rinomina la cartella (le sottocartelle la seguono).
  Future<FolderChange> renameFolder(String folder, String name) => _send(
    'POST',
    '$_mail/folders/${Uri.encodeComponent(folder)}/rename',
    {'name': name},
    (json) => FolderChange.fromJson(json as Map<String, dynamic>),
  );

  /// MODIFICA la casella: sposta la cartella (con le sottocartelle) dentro [parent] (null = in cima
  /// all'account). Nome già usato lì: ApiException con l'errore sul campo "parent".
  Future<FolderChange> moveFolder(String folder, String? parent) => _send(
    'POST',
    '$_mail/folders/${Uri.encodeComponent(folder)}/move',
    {'parent': parent},
    (json) => FolderChange.fromJson(json as Map<String, dynamic>),
  );

  /// MODIFICA la casella: sposta la cartella in Posta eliminata; se è già lì dentro la elimina
  /// DEFINITIVAMENTE (non reversibile).
  Future<FolderDeletion> deleteFolder(String folder) => _send(
    'DELETE',
    '$_mail/folders/${Uri.encodeComponent(folder)}',
    null,
    (json) => FolderDeletion.fromJson(json as Map<String, dynamic>),
  );

  /// MODIFICA la casella, NON reversibile: "Svuota cartella" (solo Posta eliminata, con le sottocartelle, e Posta
  /// indesiderata; le altre: 409).
  Future<FolderEmptied> emptyFolder(String folder) => _send(
    'POST',
    '$_mail/folders/${Uri.encodeComponent(folder)}/empty',
    null,
    (json) => FolderEmptied.fromJson(json as Map<String, dynamic>),
  );

  /// Eventi in tempo reale di tutti gli account (Server-Sent Events). Lo stream termina se la connessione
  /// si chiude; chi lo usa decide se e quando riconnettersi.
  Stream<MailboxEvent> events() async* {
    final request = http.Request('GET', Uri.parse('$baseUrl/events'))..headers.addAll(authHeaders);
    final http.StreamedResponse response;
    try {
      response = await _http.send(request);
    } on Exception catch (e) {
      throw ApiException('Core PostinoVip non raggiungibile su $baseUrl: $e');
    }
    if (response.statusCode != 200) {
      throw ApiException('Eventi non disponibili', statusCode: response.statusCode);
    }

    final lines = response.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final data in sseData(lines)) {
      try {
        yield MailboxEvent.fromJson(jsonDecode(data) as Map<String, dynamic>);
      } on Object {
        // Evento non riconosciuto (es. core più recente dell'app): ignorato.
      }
    }
  }

  Future<T> _get<T>(String path, T Function(Object? json) parse) => _send('GET', path, null, parse);

  /// Richiesta + conversione del JSON. Ogni errore (rete, HTTP, formato) diventa ApiException,
  /// così la UI mostra un messaggio invece di andare in errore.
  Future<T> _send<T>(String method, String path, Object? body, T Function(Object? json) parse) async {
    final http.Response response;
    try {
      final uri = Uri.parse('$baseUrl$path');
      final jsonHeaders = {...authHeaders, 'content-type': 'application/json'};
      final request = switch (method) {
        'GET' => _http.get(uri, headers: authHeaders),
        'PUT' => _http.put(uri, headers: jsonHeaders, body: jsonEncode(body)),
        'DELETE' => _http.delete(uri, headers: authHeaders),
        _ => _http.post(uri, headers: jsonHeaders, body: jsonEncode(body)),
      };
      response = await request.timeout(_timeout);
    } on Exception catch (e) {
      throw ApiException('Core PostinoVip non raggiungibile su $baseUrl: $e');
    }

    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _problem(text, response.statusCode);
    }

    try {
      // 202/204 senza contenuto (es. ricostruzione della cache avviata, dati eliminati).
      return parse(text.isEmpty ? null : jsonDecode(text));
    } on Object catch (e) {
      // Tipicamente: core e app di versioni diverse (es. core non riavviato dopo un aggiornamento).
      throw ApiException(
        'Risposta del core in formato inatteso ($path): $e. '
        'Il core è aggiornato e riavviato?',
      );
    }
  }

  /// Converte una risposta ProblemDetails / ValidationProblemDetails in ApiException.
  static ApiException _problem(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final fieldErrors = <String, List<String>>{};
      final errors = json['errors'];
      if (errors is Map<String, dynamic>) {
        for (final e in errors.entries) {
          // Chiavi del model binding: "To", "$.to"... -> "to"
          final key = e.key.replaceFirst(r'$.', '').toLowerCase();
          fieldErrors[key] = (e.value as List).cast<String>();
        }
      }
      final message = [json['title'], json['detail']].whereType<String>().join(': ');
      return ApiException(message, statusCode: statusCode, fieldErrors: fieldErrors);
    } on Object {
      return ApiException('Risposta inattesa dal core', statusCode: statusCode);
    }
  }

  void close() => _http.close();
}
