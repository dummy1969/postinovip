/// Esito di POST /send. Inviata: [serverResponse], [savedTo] è la cartella della copia, [saveError] il motivo
/// se la copia era richiesta ma non è stata salvata. Messa nella Posta in uscita (3.8): [queued], con
/// [sendAfter] (invio differito) oppure [offlineQueued] (server non raggiungibile).
class SendResult {
  const SendResult({
    this.serverResponse,
    this.savedTo,
    this.saveError,
    this.queued = false,
    this.offlineQueued = false,
    this.sendAfter,
  });

  final String? serverResponse;
  final String? savedTo;
  final String? saveError;
  final bool queued;
  final bool offlineQueued;
  final DateTime? sendAfter;

  factory SendResult.fromJson(Map<String, dynamic> json) => SendResult(
    serverResponse: json['serverResponse'] as String?,
    savedTo: json['savedTo'] as String?,
    saveError: json['saveError'] as String?,
    queued: json['queued'] as bool? ?? false,
    offlineQueued: json['offlineQueued'] as bool? ?? false,
    sendAfter: json['sendAfter'] == null ? null : DateTime.parse(json['sendAfter'] as String).toLocal(),
  );
}

/// Bozza (3.8): in Bozze sul server ([uid]) o ancora sul computer in attesa di connessione ([localId]).
class DraftRef {
  const DraftRef({this.uid, this.localId});

  final int? uid;
  final String? localId;

  Map<String, dynamic> toJson() => {'uid': ?uid, 'localId': ?localId};
}

/// Esito di POST /drafts.
class DraftSaveResult {
  const DraftSaveResult({required this.ref, required this.pending});

  final DraftRef ref;

  /// Salvata sul computer: il server non risponde, andrà in Bozze al ritorno della connessione.
  final bool pending;

  factory DraftSaveResult.fromJson(Map<String, dynamic> json) => DraftSaveResult(
    ref: DraftRef(uid: json['uid'] as int?, localId: json['localId'] as String?),
    pending: json['pending'] as bool? ?? false,
  );
}

/// Una mail della Posta in uscita (GET .../outbox).
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.subject,
    required this.to,
    required this.created,
    this.sendAfter,
    this.error,
  });

  final String id;
  final String subject;
  final List<String> to;
  final DateTime created;

  /// Non prima di questo momento ("Ritarda recapito"); null = appena il server risponde.
  final DateTime? sendAfter;

  /// L'ultimo invio non è riuscito (niente nuovi tentativi da soli: "Invia ora").
  final String? error;

  factory OutboxEntry.fromJson(Map<String, dynamic> json) => OutboxEntry(
    id: json['id'] as String,
    subject: json['subject'] as String,
    to: (json['to'] as List).cast<String>(),
    created: DateTime.parse(json['created'] as String).toLocal(),
    sendAfter: json['sendAfter'] == null ? null : DateTime.parse(json['sendAfter'] as String).toLocal(),
    error: json['error'] as String?,
  );
}
