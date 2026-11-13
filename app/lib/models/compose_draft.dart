import 'attachment_info.dart';
import 'mail_importance.dart';
import 'send_result.dart';

/// Modalità delle bozze generate dal core (valori del parametro ?mode=).
enum DraftMode {
  reply('reply', 'Rispondi'),
  replyAll('replyAll', 'Rispondi a tutti'),
  forward('forward', 'Inoltra');

  const DraftMode(this.query, this.label);

  final String query;
  final String label;
}

/// Citazione da aggiungere in fondo all'invio: dall'originale ([folder], [uid], [mode]) oppure già pronta in
/// [html] (bozza riaperta, 3.8: l'originale può non esserci più).
class QuoteRef {
  const QuoteRef.original({this.account, required String this.folder, required int this.uid, required DraftMode this.mode})
    : html = null;
  const QuoteRef.inline(String this.html) : account = null, folder = null, uid = null, mode = null;

  final String? account;
  final String? folder;
  final int? uid;
  final DraftMode? mode;
  final String? html;

  Map<String, dynamic> toJson() => html != null
      ? {'html': html}
      : {'account': ?account, 'folder': folder, 'uid': uid, 'mode': mode!.query};
}

/// Contenuto iniziale della composizione: vuoto per un nuovo messaggio, dal core per risposte e inoltri.
class ComposeDraft {
  const ComposeDraft({
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.subject = '',
    this.body = '',
    this.inReplyTo,
    this.references = const [],
    this.forwardAttachments = const [],
    this.forwardFolder,
    this.forwardUid,
    this.forwardAccount,
    this.quoteHtml,
    this.mode,
    this.htmlBody,
    this.quoteInline = false,
    this.draftRef,
    this.importance = MailImportance.normal,
    this.readReceipt,
    this.plainText,
  });

  final List<String> to;
  final List<String> cc;

  /// Ccn: destinatari nascosti (bozza riaperta).
  final List<String> bcc;
  final String subject;
  final String body;

  /// Collegamento al thread originale (solo risposte).
  final String? inReplyTo;
  final List<String> references;

  /// Inoltro: allegati dell'originale (inclusi di default, rimovibili) e messaggio da cui riprenderli.
  final List<AttachmentInfo> forwardAttachments;
  final String? forwardFolder;
  final int? forwardUid;

  /// Account del messaggio originale: gli allegati si riprendono da lì anche se il mittente cambia.
  final String? forwardAccount;

  /// Anteprima formattata della citazione (3.7b, scelta 6a): mostrata sotto l'editor, non modificabile;
  /// all'invio il core la ricostruisce dall'originale. null = nessuna (nuovo messaggio, core precedente).
  final String? quoteHtml;

  /// Risposta, rispondi a tutti o inoltro (per la citazione); null per un nuovo messaggio.
  final DraftMode? mode;

  /// Bozza riaperta (3.8): il testo scritto, formattato; la citazione [quoteHtml] si invia così com'è
  /// ([quoteInline]); salvando o inviando si sostituisce o si elimina la bozza [draftRef].
  final String? htmlBody;
  final bool quoteInline;
  final DraftRef? draftRef;

  /// Priorità alta o bassa (P1): di una bozza riaperta; normale per i messaggi nuovi, le risposte e gli inoltri.
  final MailImportance importance;

  /// «Richiedi conferma di lettura» (R2): null = la scelta di File → Opzioni («Chiedi sempre…»).
  final bool? readReceipt;

  /// Testo normale (13/11/2026): true per le risposte e gli inoltri di una mail di solo testo (dal core, scelta
  /// 3a) e per le bozze riaperte senza HTML; null = la scelta di File → Opzioni → Posta (messaggi nuovi).
  final bool? plainText;

  /// Collega la bozza al messaggio originale (il core non lo ripete nella bozza).
  ComposeDraft withForwardSource(String folder, int uid, {String? account, DraftMode? mode}) => ComposeDraft(
    to: to,
    cc: cc,
    subject: subject,
    body: body,
    inReplyTo: inReplyTo,
    references: references,
    forwardAttachments: forwardAttachments,
    forwardFolder: folder,
    forwardUid: uid,
    forwardAccount: account,
    quoteHtml: quoteHtml,
    mode: mode,
    plainText: plainText,
  );

  factory ComposeDraft.fromJson(Map<String, dynamic> json) => ComposeDraft(
    to: (json['to'] as List).cast<String>(),
    cc: (json['cc'] as List).cast<String>(),
    subject: json['subject'] as String,
    body: json['body'] as String,
    inReplyTo: json['inReplyTo'] as String?,
    references: (json['references'] as List).cast<String>(),
    quoteHtml: json['quoteHtml'] as String?,
    plainText: json['plainText'] as bool? ?? false, // core precedente: HTML, come prima
    forwardAttachments: [
      for (final a in (json['forwardAttachments'] as List?) ?? const [])
        AttachmentInfo.fromJson(a as Map<String, dynamic>),
    ],
  );
}
