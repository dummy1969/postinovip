import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language.dart';
import '../attachments/file_picker.dart';
import '../compose/address_field.dart';
import '../compose/address_list.dart';
import '../compose/rich_text.dart';
import '../compose/signature_text.dart';
import '../models/mail_importance.dart';
import '../models/signature.dart';
import '../models/account_info.dart';
import '../models/attachment_info.dart';
import '../models/compose_draft.dart';
import '../models/send_result.dart';
import '../settings/app_settings.dart';
import 'address_book_dialog.dart';
import 'theme.dart';
import '../state/mailbox_model.dart';
import 'keys.dart';
import 'mac_menu_bar.dart';
import 'format.dart';
import 'format_commands.dart';
import 'html_body_view.dart';
import 'ribbon_parts.dart';
import 'signatures_dialog.dart';

/// Apre la composizione (nuovo messaggio, risposta o inoltro) e, se il messaggio
/// viene inviato, mostra l'esito nella pagina chiamante. [account]: casella proposta come mittente
/// (null = primo account del core); [accounts]: tutte, per il menu "Da:" (con più di una).
Future<void> openCompose(
  BuildContext context, {
  ComposeDraft draft = const ComposeDraft(),
  String? title,
  AccountInfo? account,
  List<AccountInfo> accounts = const [],
  List<PickedFile> files = const [],
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final model = context.read<MailboxModel>();
  final l = context.l10n;
  final result = await Navigator.of(context).push<SendResult>(
    MaterialPageRoute(
      builder: (_) => ComposePage(
        draft: draft,
        title: title,
        account: account,
        accounts: accounts,
        files: files,
      ),
    ),
  );
  // Bozze, Posta inviata e Posta in uscita possono essere cambiate (salvataggi, invio): conteggi e lista.
  final touched = account?.id ?? model.accounts.firstOrNull?.id;
  if (touched != null) unawaited(model.mailboxTouched(touched));
  if (result == null || !context.mounted) return;

  if (result.queued) {
    final when = result.sendAfter;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          when != null
              ? l.queuedSendAfter(formatSendAfter(when))
              : l.queuedOffline,
        ),
      ),
    );
    return;
  }

  if (result.saveError != null) {
    // Ben visibile (non una SnackBar che sparisce): la mail è partita ma non c'è la copia.
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber),
        title: Text(l.sentCopyNotSavedTitle),
        content: Text(l.sentCopyNotSaved('${result.saveError}')),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    return;
  }

  final where = result.savedTo == null ? '' : l.sentSavedIn(result.savedTo!);
  messenger.showSnackBar(SnackBar(content: Text(l.messageSent(where, '${result.serverResponse}'))));
}

/// Composizione con testo formattato (3.7b) e l'aspetto della finestra del messaggio di Outlook (3.7a). Chiusa con successo restituisce l'esito dell'invio;
/// chiusa senza inviare restituisce null.
class ComposePage extends StatefulWidget {
  const ComposePage({
    super.key,
    this.draft = const ComposeDraft(),
    this.title,
    this.account,
    this.accounts = const [],
    this.files = const [],
  });

  final ComposeDraft draft;

  /// Allegati già presenti all'apertura (bozza riaperta: quelli della bozza, ripresi dal server).
  final List<PickedFile> files;

  /// null = «Nuovo messaggio» nella lingua dell'app.
  final String? title;

  /// Salvataggio automatico della bozza come Outlook (3.8): ogni 3 minuti, se ci sono modifiche.
  static const autosaveInterval = Duration(minutes: 3);

  /// Barra del titolo, editor e citazione della composizione (per i test).
  static const titleKey = ValueKey('compose-title');
  static const editorKey = ValueKey('compose-editor');
  static const quoteKey = ValueKey('compose-quote');

  /// Casella proposta come mittente (e in cui salvare la copia); null = primo account del core.
  final AccountInfo? account;

  /// Tutti gli account: con più di uno "Da:" diventa un menu per scegliere il mittente.
  final List<AccountInfo> accounts;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _formKey = GlobalKey<FormState>();
  late final _to = TextEditingController(text: widget.draft.to.join(', '));
  late final _cc = TextEditingController(text: widget.draft.cc.join(', '));
  late final _bcc = TextEditingController(text: widget.draft.bcc.join(', '));

  /// Ccn visibile: scelta ricordata (Opzioni → Ccn) o bozza che ne ha già.
  bool _showBcc(BuildContext context) => context.watch<AppSettings>().showBcc || widget.draft.bcc.isNotEmpty;
  late final _subject = TextEditingController(text: widget.draft.subject);
  // Testo formattato (3.7b). Con un core che manda l'anteprima della citazione l'editor parte vuoto e la
  // citazione sta sotto (scelta 6a); altrimenti, come prima, il testo della bozza entra nell'editor.
  // Firma predefinita dell'account (3.7c, scelta 8a): nel testo, modificabile, dopo una riga vuota.
  late final _editor = QuillController(
    document: widget.draft.htmlBody != null
        ? htmlToDocument(widget.draft.htmlBody!) // bozza riaperta: la firma c'è già
        : composeDocument(body: _quoteHtml == null ? widget.draft.body : '', signature: _startSignature),
    // Cursore all'inizio: in risposta si scrive sopra il testo citato.
    selection: const TextSelection.collapsed(offset: 0),
    // Incolla di testo formattato da altri programmi: attivo di serie in flutter_quill 11.6.0
    // (enableExternalRichPasteDefault). Le immagini incollate servono invece onImagePaste, che il pacchetto
    // segna come sperimentale: da ricontrollare quando si aggiorna flutter_quill (scelta 3.7-5b).
    // ignore: experimental_member_use
    config: QuillControllerConfig(
      // ignore: experimental_member_use
      clipboardConfig: QuillClipboardConfig(onImagePaste: (bytes) async => _plain ? null : pastedImageUrl(bytes)),
    ),
  );
  final _editorFocus = FocusNode(debugLabel: 'Testo del messaggio');
  final _editorScroll = ScrollController();

  /// Citazione dell'originale (risposta o inoltro), finché non la si toglie con "Rimuovi citazione".
  late String? _quoteHtml = widget.draft.quoteHtml;

  /// Testo normale (13/11/2026, scelte 1a 2a 3a): dalla bozza (risposta a una mail di solo testo, bozza senza
  /// HTML), altrimenti da File → Opzioni → Posta. Si cambia da Formato testo → Formato.
  late bool _plain = widget.draft.plainText ?? context.read<AppSettings>().composePlainText;
  bool _stripping = false;

  /// In testo normale la formattazione arrivata dopo (incolla, firma, scorciatoie) si toglie subito.
  void _keepPlain() {
    if (!_plain || _stripping || !hasFormatting(_editor.document)) return;
    _stripping = true;
    try {
      stripFormatting(_editor);
    } finally {
      _stripping = false;
    }
  }

  /// Citazione da mostrare in testo normale: quella in testo che il core aggiunge all'invio (risposte e
  /// inoltri); null se non c'è (bozza riaperta: allora si vede quella HTML).
  String? get _plainQuote {
    final text = widget.draft.body.trim();
    return widget.draft.mode != null && widget.draft.quoteHtml != null && text.isNotEmpty ? text : null;
  }

  /// Formato testo → HTML / Testo normale. Verso il testo normale, se c'è qualcosa da perdere, chiede conferma.
  Future<void> _setPlain(bool plain) async {
    if (plain == _plain) return;
    if (plain && (hasFormatting(_editor.document) || _quoteHtml != null)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('plain-text-confirm'),
          title: Text(context.l10n.toPlainTextQuestion),
          content: Text(context.l10n.toPlainTextContent),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.continueButton)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _plain = plain);
    _keepPlain();
    _editorFocus.requestFocus();
  }

  String get _bodyText => documentToPlainText(_editor.document);

  /// Firma inserita all'apertura: quella predefinita del mittente per i nuovi messaggi o per le risposte.
  late final Signature? _startSignature = widget.draft.htmlBody != null || widget.draft.draftRef != null
      ? null
      : context.read<AppSettings>().defaultSignature(_account?.id, reply: widget.draft.mode != null);

  /// Testo della firma presente nel messaggio (per ritrovarla e sostituirla); null = nessuna.
  late String? _signaturePlain = _startSignature == null ? null : signaturePlainText(_startSignature);

  /// Menu "Firma": la firma scelta prende il posto di quella inserita (o va dove sta il cursore).
  void _applySignature(Signature s) {
    setState(() => _signaturePlain = replaceSignature(_editor, _signaturePlain, s));
    _editorFocus.requestFocus();
  }

  /// Cambio di "Da:": come Outlook, se la firma non è stata toccata passa a quella del nuovo account.
  void _signatureForAccount() {
    final next = context.read<AppSettings>().defaultSignature(_account?.id, reply: widget.draft.mode != null);
    final plain = _signaturePlain;
    if (plain == null) {
      if (next != null) _signaturePlain = appendSignature(_editor, next);
      return;
    }
    if (findSignature(_editor.document, plain) == null) return; // modificata a mano: resta com'è
    _signaturePlain = replaceSignature(_editor, plain, next);
  }

  /// Mittente scelto: all'inizio quello proposto, poi dal menu "Da:". Invio e copia in Posta
  /// inviata avvengono su questa casella.
  late AccountInfo? _account = widget.account ?? widget.accounts.firstOrNull;

  ApiClient get _api {
    final root = context.read<ApiClient>();
    return _account == null ? root : root.forAccount(_account!.id);
  }

  bool get _chooseFrom => widget.accounts.length > 1;

  /// Mittente da mostrare con un solo account (senza menu).
  late final Future<String> _from = _account == null
      ? context.read<ApiClient>().getAccount()
      : Future.value(_account!.address);

  static String _fromLabel(AccountInfo a) => a.name == a.address ? a.address : '${a.name} <${a.address}>';

  // Valori all'ultimo salvataggio (all'inizio quelli di apertura): senza modifiche da allora si chiude senza
  // domanda; con modifiche "Salvare le modifiche?" come Outlook (3.8).
  late List<String> _saved = _values();

  bool _sending = false;
  bool _sent = false;

  /// Copia in Posta inviata (APPEND): attiva di default, scelta dell'utente.
  bool _saveCopy = true;

  /// Limite sul totale degli allegati, uguale a quello del core (MimeMessageBuilder.MaxAttachmentBytes).
  static const maxAttachmentBytes = 25 * 1024 * 1024;

  /// File scelti dal disco (o della bozza riaperta).
  late final List<PickedFile> _files = [...widget.files];

  /// Inoltro: allegati dell'originale ancora inclusi (all'inizio tutti, scelta dell'utente).
  late final List<AttachmentInfo> _forwarded = [...widget.draft.forwardAttachments];

  /// File dal disco più immagini incollate nel testo: contano tutti nel limite di 25 MB.
  int get _filesBytes => _files.fold(0, (sum, f) => sum + f.bytes.length) + embeddedImageBytes(_editor.document);
  Map<String, List<String>> _serverFieldErrors = const {};
  String? _error;

  List<String> _values() => [
    _to.text,
    _cc.text,
    _bcc.text,
    _subject.text,
    _bodyText,
    documentToHtml(_editor.document), // anche la sola formattazione è una modifica
    '${_quoteHtml != null}',
    [for (final f in _files) '${f.name}:${f.bytes.length}'].join('|'),
    [for (final a in _forwarded) a.index].join(','),
    '${_sendAfter?.millisecondsSinceEpoch}',
    _importance.name,
    '$_readReceipt',
    '$_plain',
  ];

  /// «Priorità alta» / «Priorità bassa» (P1), come nella scheda Messaggio di Outlook.
  late MailImportance _importance = widget.draft.importance;

  /// «Richiedi conferma di lettura» (R2, Opzioni → Rilevamento): dalla bozza riaperta, altrimenti da File → Opzioni.
  late bool _readReceipt = widget.draft.readReceipt ?? context.read<AppSettings>().requestReadReceipt;

  bool get _dirty {
    final now = _values();
    return List.generate(now.length, (i) => now[i] != _saved[i]).any((changed) => changed);
  }

  // --- bozze (3.8) ---

  /// Bozza che si sta scrivendo: sostituita a ogni salvataggio, eliminata all'invio.
  late DraftRef? _draftRef = widget.draft.draftRef;
  bool _savingDraft = false;

  /// Esito dell'ultimo salvataggio, nella barra del titolo ("Bozza salvata alle 10:32").
  String? _draftInfo;
  Timer? _autosave;

  /// "Ritarda recapito": prima di allora la mail resta nella Posta in uscita.
  DateTime? _sendAfter;

  // Con destinatari già presenti (risposta) il fuoco va sul testo, altrimenti su "A".
  bool get _focusBody => widget.draft.to.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _keepPlain(); // testo normale: la firma entra senza formattazione
    _saved; // fissa i valori iniziali prima di qualunque modifica
    _autosave = Timer.periodic(ComposePage.autosaveInterval, (_) {
      if (_dirty && !_sending && !_savingDraft) _saveDraft(auto: true);
    });
    // Testo cambiato: "Scartare il messaggio?" e il limite degli allegati dipendono da lì.
    _editorChanges = _editor.document.changes.listen((_) {
      if (!mounted) return;
      // Dopo la modifica, non durante: il documento sta ancora notificando.
      if (_plain && !_stripping) scheduleMicrotask(() => mounted ? _keepPlain() : null);
      setState(() {});
    });
  }

  late final StreamSubscription<DocChange> _editorChanges;

  @override
  void dispose() {
    for (final c in [_to, _cc, _bcc, _subject]) {
      c.dispose();
    }
    _editorChanges.cancel();
    _autosave?.cancel();
    _editor.dispose();
    _editorFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  /// Scheda aperta della barra multifunzione (0 = Messaggio).
  int _tab = 0;

  /// Larghezza delle etichette a sinistra dei campi (Da, A, Cc, Oggetto), come in Outlook.
  static const _labelWidth = 76.0;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<AppSettings>();
    return PopScope(
      // Con modifiche non inviate si chiede conferma prima di scartarle.
      canPop: _sent || !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _sending || _savingDraft) return;
        final save = await _confirmSave();
        if (save == null || !context.mounted) return; // Annulla: si continua a scrivere
        if (save && !await _saveDraft()) return; // non salvata: resta aperta con il motivo
        if (!context.mounted) return;
        setState(() => _sent = true); // consente il pop
        WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).pop());
      },
      // Scorciatoie essenziali di Outlook (scelta 3.5b-3a): Ctrl+Invio e Alt+S inviano (sempre con il
      // riepilogo di conferma), Esc chiude (con la domanda se c'è qualcosa di scritto); Ctrl+F1 come
      // nella finestra principale.
      child: CallbackShortcuts(
        bindings: {
          cmd(LogicalKeyboardKey.enter): _sendShortcut,
          cmd(LogicalKeyboardKey.numpadEnter): _sendShortcut,
          const SingleActivator(LogicalKeyboardKey.keyS, alt: true): _sendShortcut,
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
          cmd(LogicalKeyboardKey.f1): () =>
              settings.setRibbonCollapsed(!settings.ribbonCollapsed),
          cmd(LogicalKeyboardKey.keyS): () {
            if (!_sending && !_savingDraft) _saveDraft();
          },
          cmd(LogicalKeyboardKey.keyK): () {
            if (!_sending && !_plain) FormatCommands.insertLink(context, _editor);
          },
        },
        // Sul Mac i comandi anche nella barra dei menu in alto (M2b).
        child: MacMenuScope(
          menus: _macMenus,
          child: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ComposeTitleBar(
                  key: ComposePage.titleKey,
                  title: widget.title ?? context.l10n.newMessageTitle,
                  subject: _subject.text.trim(),
                  info: _savingDraft ? context.l10n.savingDraft : _draftInfo,
                  onClose: _sending ? null : () => Navigator.maybePop(context),
                ),
                RibbonFrame(
                  tabs: [context.l10n.messageTab, context.l10n.tabInsert, context.l10n.tabFormatText, context.l10n.groupOptions],
                  selected: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                  groups: _ribbonGroups(),
                ),
                Expanded(child: _form(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Menu del Mac (M2b): File, Messaggio e Formato della composizione, con le stesse condizioni della barra.
  List<PlatformMenu> _macMenus(BuildContext context) {
    final l = context.l10n;
    final format = FormatCommands(_editor, l10n: l, enabled: !_sending && !_plain, onEdited: _editorFocus.requestFocus);
    final idle = !_sending;
    final settings = context.read<AppSettings>();
    final bccShown = settings.showBcc || widget.draft.bcc.isNotEmpty;
    PlatformMenuItem toggle(String label, bool on, VoidCallback? action, [MenuSerializableShortcut? key]) =>
        macItem(macChecked(label, on), action, key);
    PlatformMenuItem importance(MailImportance value, String label) => toggle(
      label,
      _importance == value,
      idle ? () => setState(() => _importance = _importance == value ? MailImportance.normal : value) : null,
    );
    PlatformMenuItem style(String label, Attribute attribute, [MenuSerializableShortcut? key]) =>
        macItem(macLabel(label), idle && !_plain ? () => format.toggle(attribute) : null, key);
    return [
      PlatformMenu(
        label: l.fileTab,
        menus: [
          PlatformMenuItemGroup(
            members: [
              macItem(l.receiptSend, idle ? _send : null, macKey(LogicalKeyboardKey.enter)),
              macItem(
                l.saveDraft,
                idle && !_savingDraft ? () => _saveDraft() : null,
                macKey(LogicalKeyboardKey.keyS),
              ),
              macItem('${l.attachFile}…', idle ? _pickFiles : null),
            ],
          ),
          PlatformMenuItemGroup(
            members: [macItem(l.macMenuCloseWindow, idle ? () => Navigator.maybePop(context) : null, macKey(LogicalKeyboardKey.keyW))],
          ),
        ],
      ),
      PlatformMenu(
        label: l.messageTab,
        menus: [
          PlatformMenuItemGroup(
            members: [importance(MailImportance.high, l.importanceHigh), importance(MailImportance.low, l.importanceLow)],
          ),
          PlatformMenuItemGroup(
            members: [
              toggle(l.requestReadReceipt, _readReceipt, idle ? () => setState(() => _readReceipt = !_readReceipt) : null),
              toggle(
                l.bcc,
                bccShown,
                // Con dei Ccn già scritti il campo resta (come il pulsante della barra).
                !idle || (_bcc.text.trim().isNotEmpty && bccShown) ? null : () => settings.setShowBcc(!settings.showBcc),
              ),
              toggle(l.saveSentCopy, _saveCopy, idle ? () => setState(() => _saveCopy = !_saveCopy) : null),
              macItem('${l.delayDelivery}…', idle ? _pickSendAfter : null),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: l.groupFormat,
        menus: [
          PlatformMenuItemGroup(
            members: [
              toggle('HTML', !_plain, idle ? () => _setPlain(false) : null),
              toggle(l.plainText, _plain, idle ? () => _setPlain(true) : null),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              style(l.bold, Attribute.bold, macKey(LogicalKeyboardKey.keyB)),
              style(l.italic, Attribute.italic, macKey(LogicalKeyboardKey.keyI)),
              style(l.underline, Attribute.underline, macKey(LogicalKeyboardKey.keyU)),
              style(l.strikethrough, Attribute.strikeThrough),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              macItem(
                '${l.insertLink}…',
                idle && !_plain ? () => FormatCommands.insertLink(context, _editor) : null,
                macKey(LogicalKeyboardKey.keyK),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  /// Comandi della barra multifunzione (le firme arrivano con la 3.7c).
  List<Widget> _ribbonGroups() {
    final format = FormatCommands(_editor, l10n: context.l10n, enabled: !_sending && !_plain, onEdited: _editorFocus.requestFocus);
    final attach = RibbonLargeButton(
      icon: FluentIcons.attach_24_regular,
      label: context.l10n.attachFile,
      tooltip: context.l10n.attachFileTooltip,
      onPressed: _sending ? null : _pickFiles,
    );
    final saveCopy = RibbonLargeButton(
      icon: _saveCopy ? FluentIcons.save_24_filled : FluentIcons.save_24_regular,
      label: context.l10n.saveSentCopy,
      selected: _saveCopy,
      tooltip: _saveCopy ? context.l10n.saveSentCopyOnTooltip : context.l10n.saveSentCopyOffTooltip,
      onPressed: _sending ? null : () => setState(() => _saveCopy = !_saveCopy),
    );
    final saveDraft = RibbonLargeButton(
      icon: FluentIcons.document_save_24_regular,
      label: context.l10n.saveDraft,
      tooltip: keyLabel(context.l10n.saveDraftTooltip),
      onPressed: _sending || _savingDraft ? null : () => _saveDraft(),
    );
    final delay = RibbonLargeButton(
      icon: FluentIcons.calendar_clock_24_regular,
      label: context.l10n.delayDelivery,
      selected: _sendAfter != null,
      tooltip: _sendAfter == null
          ? context.l10n.delayDeliveryTooltip
          : context.l10n.delayDeliveryActiveTooltip(formatSendAfter(_sendAfter!)),
      onPressed: _sending ? null : _pickSendAfter,
    );
    RibbonLargeButton importance(MailImportance value) => RibbonLargeButton(
      key: Key('compose-importance-${value.name}'),
      icon: value == MailImportance.high ? FluentIcons.important_24_regular : FluentIcons.arrow_down_24_regular,
      label: value == MailImportance.high ? context.l10n.importanceHigh : context.l10n.importanceLow,
      selected: _importance == value,
      tooltip: value == MailImportance.high ? context.l10n.importanceHighTooltip : context.l10n.importanceLowTooltip,
      onPressed: _sending ? null : () => setState(() => _importance = _importance == value ? MailImportance.normal : value),
    );
    return switch (_tab) {
      0 => [
        format.basicText(),
        RibbonGroup(label: context.l10n.groupInclude, children: [attach, _signatureMenu()]),
        RibbonGroup(label: context.l10n.groupTags, children: [importance(MailImportance.high), importance(MailImportance.low)]),
        RibbonGroup(label: context.l10n.groupSave, children: [saveDraft, saveCopy]),
      ],
      1 => [
        RibbonGroup(
          label: context.l10n.groupInclude,
          children: [
            attach,
            FormatCommands.linkButton(context, _editor, enabled: !_sending && !_plain),
            _signatureMenu(),
          ],
        ),
      ],
      2 => [_formatGroup(), ...format.formatTab()],
      _ => [
        RibbonGroup(
          label: context.l10n.groupShowFields,
          children: [
            RibbonLargeButton(
              icon: FluentIcons.eye_off_24_regular,
              label: context.l10n.bcc,
              selected: _showBcc(context),
              tooltip: context.l10n.bccTooltip,
              // Con dei Ccn già scritti il campo resta (nasconderlo li lascerebbe nella mail senza vederli).
              onPressed: _sending || (_bcc.text.trim().isNotEmpty && _showBcc(context))
                  ? null
                  : () => context.read<AppSettings>().setShowBcc(!context.read<AppSettings>().showBcc),
            ),
          ],
        ),
        RibbonGroup(
          label: context.l10n.groupTracking,
          children: [
            RibbonLargeButton(
              key: const Key('compose-read-receipt'),
              icon: FluentIcons.mail_read_24_regular,
              label: context.l10n.requestReadReceipt,
              selected: _readReceipt,
              tooltip: _readReceipt ? context.l10n.requestReadReceiptOnTooltip : context.l10n.requestReadReceiptOffTooltip,
              onPressed: _sending ? null : () => setState(() => _readReceipt = !_readReceipt),
            ),
          ],
        ),
        RibbonGroup(label: context.l10n.groupMoreOptions, children: [delay]),
        RibbonGroup(label: context.l10n.groupSave, children: [saveCopy]),
      ],
    };
  }

  /// Gruppo «Formato» della scheda Formato testo, come Outlook (senza Rich Text, scelta 4a).
  Widget _formatGroup() => RibbonGroup(
    label: context.l10n.groupFormat,
    children: [
      RibbonLargeButton(
        key: const Key('compose-format-html'),
        icon: FluentIcons.code_24_regular,
        label: 'HTML',
        selected: !_plain,
        tooltip: context.l10n.formatHtmlTooltip,
        onPressed: _sending ? null : () => _setPlain(false),
      ),
      RibbonLargeButton(
        key: const Key('compose-format-plain'),
        icon: FluentIcons.text_t_24_regular,
        label: context.l10n.plainText,
        selected: _plain,
        tooltip: context.l10n.plainTextTooltip,
        onPressed: _sending ? null : () => _setPlain(true),
      ),
    ],
  );

  /// "Firma" come Outlook: le firme salvate e, in fondo, "Firme…" per crearle e modificarle.
  Widget _signatureMenu() {
    final signatures = context.watch<AppSettings>().signatures;
    return MenuAnchor(
      menuChildren: [
        for (final s in signatures) MenuItemButton(onPressed: () => _applySignature(s), child: Text(s.name)),
        if (signatures.isNotEmpty) const Divider(height: 8),
        MenuItemButton(
          onPressed: () => showSignaturesDialog(
            context,
            accounts: widget.accounts.isNotEmpty ? widget.accounts : [?_account],
            account: _account?.id,
          ),
          child: Text(context.l10n.signaturesEllipsis),
        ),
      ],
      builder: (context, controller, _) => RibbonLargeButton(
        icon: FluentIcons.signature_24_regular,
        label: context.l10n.signature,
        tooltip: context.l10n.signatureTooltip,
        onPressed: _sending ? null : () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  /// Intestazione come Outlook: "Invia" grande a sinistra, a destra Da, A, Cc, Oggetto con
  /// l'etichetta davanti, sotto gli allegati e poi il testo.
  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SendButton(sending: _sending, onPressed: _sending ? null : _send),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _fromRow(context),
                      // A obbligatorio solo se Cc e Ccn sono vuoti (come Outlook).
                      _addressField(_to, context.l10n.headerTo, 'to', required: true, autofocus: !_focusBody),
                      _addressField(_cc, context.l10n.headerCc, 'cc', required: false),
                      if (_showBcc(context)) _addressField(_bcc, context.l10n.bcc, 'bcc', required: false),
                      TextFormField(
                        controller: _subject,
                        enabled: !_sending,
                        decoration: _decoration(context.l10n.columnSubject),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_forwarded.isNotEmpty || _files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _SendButton.width + 12 + _labelWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(context.l10n.attachments, textAlign: TextAlign.right, style: theme.textTheme.bodySmall),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final a in _forwarded)
                            InputChip(
                              avatar: const Icon(Icons.forward, size: 16),
                              label: Text(a.fileName),
                              tooltip: context.l10n.originalAttachment,
                              deleteButtonTooltipMessage: context.l10n.remove,
                              onDeleted: _sending ? null : () => setState(() => _forwarded.remove(a)),
                            ),
                          for (final f in _files)
                            InputChip(
                              avatar: const Icon(Icons.attach_file, size: 16),
                              label: Text('${f.name} (${formatSize(f.bytes.length)})'),
                              deleteButtonTooltipMessage: context.l10n.remove,
                              onDeleted: _sending ? null : () => setState(() => _files.remove(f)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_filesBytes > maxAttachmentBytes)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.l10n.attachmentsTooLarge(formatSize(_filesBytes), formatSize(maxAttachmentBytes)),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              flex: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                ),
                child: QuillEditor(
                  key: ComposePage.editorKey,
                  controller: _editor,
                  focusNode: _editorFocus,
                  scrollController: _editorScroll,
                  config: QuillEditorConfig(
                    placeholder: context.l10n.messageBody,
                    autoFocus: _focusBody,
                    expands: true,
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
                    embedBuilders: const [MailImageEmbedBuilder()],
                    // L'editor usa Esc per nascondere la barra di selezione e il tasto non arriverebbe alla
                    // composizione: qui Esc chiude, come negli altri campi (scelta 3.5b-3a). onKeyPressed
                    // riceve il tasto prima delle scorciatoie del pacchetto. Sperimentale in flutter_quill 11.6.0:
                    // lo controlla shortcuts_test (Esc con il cursore nel testo).
                    // ignore: experimental_member_use
                    onKeyPressed: (event, _) {
                      if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return null;
                      Navigator.maybePop(context);
                      return KeyEventResult.handled;
                    },
                    // Calibri 11 pt come Outlook, se c'è; altrimenti il carattere del sistema.
                    customStyles: DefaultStyles(
                      paragraph: DefaultTextBlockStyle(
                        theme.textTheme.bodyMedium!.copyWith(fontFamily: 'Calibri', fontSize: 14.5, height: 1.3),
                        HorizontalSpacing.zero,
                        VerticalSpacing.zero,
                        VerticalSpacing.zero,
                        null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_quoteHtml case final quote?) Expanded(flex: 2, child: _quotePreview(context, quote, text: _plain ? _plainQuote : null)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }

  /// Etichetta a sinistra del campo, sempre visibile (non sparisce scrivendo), come in Outlook.
  /// [onLabel]: l'etichetta diventa un pulsante (A… e Cc… aprono la Rubrica, come in Outlook).
  InputDecoration _decoration(String label, {String? hint, String? errorText, VoidCallback? onLabel, String? keyName}) => InputDecoration(
    isDense: true,
    hintText: hint,
    errorText: errorText,
    prefixIcon: SizedBox(
      width: _labelWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: onLabel == null
            ? Text(label, style: const TextStyle(fontSize: 14))
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                child: OutlinedButton(
                  // Chiave dal nome del campo (prima dall'etichetta, che ora cambia con la lingua): «A» = to, «Cc» = cc.
                  key: Key('book-open-${keyName ?? label}'),
                  onPressed: _sending ? null : onLabel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('$label…', style: const TextStyle(fontSize: 14)),
                ),
              ),
      ),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: _labelWidth, minHeight: 36),
  );

  Widget _fromRow(BuildContext context) {
    if (_chooseFrom) {
      return DropdownButtonFormField<String>(
        initialValue: _account?.id,
        decoration: _decoration(context.l10n.columnFrom),
        items: [for (final a in widget.accounts) DropdownMenuItem(value: a.id, child: Text(_fromLabel(a)))],
        onChanged: _sending
            ? null
            : (id) => setState(() {
                _account = widget.accounts.firstWhere((a) => a.id == id);
                _signatureForAccount();
              }),
      );
    }
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(context.l10n.columnFrom, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: FutureBuilder(
              future: _from,
              builder: (context, snap) => Text(
                snap.data ?? (snap.hasError ? context.l10n.accountUnavailable : '…'),
                key: const ValueKey('compose-from'),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Citazione dell'originale sotto l'editor (scelta 6a): com'era, non modificabile, rimovibile.
  Widget _quotePreview(BuildContext context, String html, {String? text}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: ComposePage.quoteKey,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(FluentIcons.arrow_reply_20_regular, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.originalMessageQuote,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: _sending ? null : () => setState(() => _quoteHtml = null),
                child: Text(context.l10n.removeQuote),
              ),
            ],
          ),
          Expanded(
            child: MessageSurface(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: text != null
                    ? SelectableText(text, key: const Key('compose-quote-text'))
                    : HtmlBodyView(html: html, allowRemoteImages: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressField(
    TextEditingController c,
    String label,
    String field, {
    required bool required,
    bool autofocus = false,
  }) {
    final api = context.read<ApiClient>();
    // Completamento dai contatti e dagli indirizzi recenti (C3); «A…»/«Cc…» aprono la Rubrica.
    return AddressField(
      fieldKey: Key('address-$field'),
      controller: c,
      enabled: !_sending,
      autofocus: autofocus,
      suggest: (q) => api.suggestAddresses(q),
      removeRecent: api.removeRecentAddress,
      decoration: _decoration(
        label,
        hint: context.l10n.addressesHint,
        // Errore restituito dal core per questo campo (validazione rigorosa).
        errorText: _serverFieldErrors[field]?.join('\n'),
        onLabel: () => _openAddressBook(target: field),
        keyName: switch (field) { 'to' => 'A', 'cc' => 'Cc', _ => 'Ccn' },
      ),
      validator: (text) => validateAddressField(
        context.l10n,
        text ?? '',
        required: required && splitAddresses(_cc.text).isEmpty && splitAddresses(_bcc.text).isEmpty,
      ),
      onChanged: (_) => setState(() => _serverFieldErrors = const {}),
    );
  }

  /// Rubrica (C3): i destinatari scelti si aggiungono in fondo ad A, Cc e Ccn, senza doppioni. Scegliendo
  /// dei Ccn il campo compare (e resta visibile, come Opzioni → Ccn).
  Future<void> _openAddressBook({required String target}) async {
    final settings = context.read<AppSettings>();
    final choice = await AddressBookDialog.show(
      context,
      api: context.read<ApiClient>(),
      accounts: widget.accounts.isNotEmpty ? widget.accounts : [?_account],
      target: target,
    );
    if (choice == null || !mounted) return;
    void append(TextEditingController c, List<String> add) {
      final present = addressesIn(c.text);
      final fresh = add.where((m) => !present.contains((RegExp(r'<([^>]+)>').firstMatch(m)?.group(1) ?? m).toLowerCase()));
      if (fresh.isEmpty) return;
      final current = c.text.trim().replaceAll(RegExp(r'[,;]\s*$'), '');
      c.text = [if (current.isNotEmpty) current, ...fresh].join(', ');
    }

    setState(() {
      append(_to, choice.to);
      append(_cc, choice.cc);
      append(_bcc, choice.bcc);
      _serverFieldErrors = const {};
    });
    if (choice.bcc.isNotEmpty && !settings.showBcc) await settings.setShowBcc(true);
  }

  // Senza connessione la mail va nella Posta in uscita; 503 arriva solo se serve l'originale (citazione,
  // allegati inoltrati) e non è sul computer.

  void _sendShortcut() {
    if (!_sending) _send();
  }

  Future<void> _send() async {
    setState(() {
      _error = null;
      _serverFieldErrors = const {};
    });
    if (!_formKey.currentState!.validate()) return;

    if (_filesBytes > maxAttachmentBytes) return; // messaggio già visibile sotto gli allegati
    // Senza connessione (3.8): il core la mette nella Posta in uscita e la invia da solo al ritorno.

    final to = splitAddresses(_to.text);
    final cc = splitAddresses(_cc.text);
    final bcc = splitAddresses(_bcc.text);
    if (!await _confirmSend(to, cc, bcc)) return;

    setState(() => _sending = true);
    try {
      final result = await _api.send(
        to: to,
        cc: cc,
        bcc: bcc,
        subject: _subject.text,
        body: _bodyText,
        htmlBody: _plain ? null : documentToHtml(_editor.document),
        quote: _quote,
        inReplyTo: widget.draft.inReplyTo,
        references: widget.draft.references,
        saveCopy: _saveCopy,
        attachments: _attachments,
        forward: _forward,
        sendAfter: _sendAfter,
        deleteDraft: _draftRef,
        importance: _importance,
        readReceipt: _readReceipt,
      );
      _autosave?.cancel();
      if (!mounted) return;
      setState(() => _sent = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).pop(result));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _serverFieldErrors = e.fieldErrors;
        // "attachments" non ha un campo di testo: il messaggio va nella riga d'errore generale.
        final attachmentErrors = e.fieldErrors['attachments'];
        _error = attachmentErrors != null
            ? attachmentErrors.join('\n')
            : e.statusCode == 503
            ? context.l10n.offlineSendMessage
            : (e.fieldErrors.isEmpty ? context.l10n.sendFailed('$e') : null);
      });
    }
  }

  /// Citazione da aggiungere: dall'originale, oppure (bozza riaperta) così come stava nella bozza.
  QuoteRef? get _quote {
    final html = _quoteHtml;
    if (html == null) return null;
    if (widget.draft.quoteInline) return QuoteRef.inline(html);
    if (widget.draft.forwardFolder == null || widget.draft.mode == null) return null;
    return QuoteRef.original(
      account: widget.draft.forwardAccount,
      folder: widget.draft.forwardFolder!,
      uid: widget.draft.forwardUid!,
      mode: widget.draft.mode!,
    );
  }

  List<({String fileName, List<int> bytes})> get _attachments => [
    for (final f in _files) (fileName: f.name, bytes: f.bytes),
  ];

  // Gli allegati restano nella casella del messaggio originale, anche se il mittente è cambiato.
  ({String? account, String folder, int uid, List<int> indexes})? get _forward =>
      _forwarded.isEmpty || widget.draft.forwardFolder == null
      ? null
      : (
          account: widget.draft.forwardAccount,
          folder: widget.draft.forwardFolder!,
          uid: widget.draft.forwardUid!,
          indexes: [for (final a in _forwarded) a.index],
        );

  /// MODIFICA la casella (3.8): salva in Bozze al posto della bozza precedente; senza connessione sul
  /// computer (andrà in Bozze al ritorno). true se salvata. Nessuna validazione degli indirizzi: una bozza
  /// può essere incompleta.
  Future<bool> _saveDraft({bool auto = false}) async {
    if (_filesBytes > maxAttachmentBytes) {
      if (!auto) setState(() => _error = context.l10n.draftTooLarge(formatSize(maxAttachmentBytes)));
      return false;
    }
    final values = _values();
    setState(() => _savingDraft = true);
    try {
      final result = await _api.saveDraft(
        to: splitAddresses(_to.text),
        cc: splitAddresses(_cc.text),
        bcc: splitAddresses(_bcc.text),
        subject: _subject.text,
        body: _bodyText,
        htmlBody: _plain ? null : documentToHtml(_editor.document),
        quote: _quote,
        inReplyTo: widget.draft.inReplyTo,
        references: widget.draft.references,
        attachments: _attachments,
        forward: _forward,
        replace: _draftRef,
        importance: _importance,
        readReceipt: _readReceipt,
      );
      if (!mounted) return true;
      final at = TimeOfDay.now().format(context);
      setState(() {
        _draftRef = result.ref;
        _saved = values;
        _error = null;
        _draftInfo = result.pending ? context.l10n.draftSavedLocally(at) : context.l10n.draftSavedAt(at);
      });
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _draftInfo = context.l10n.draftNotSaved;
          _error = context.l10n.draftNotSavedError('$e');
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  /// "Ritarda recapito" (scheda Opzioni): data e ora prima delle quali la mail non parte.
  Future<void> _pickSendAfter() async {
    final now = DateTime.now();
    final start = _sendAfter ?? now.add(const Duration(hours: 1));
    final choice = await showDialog<_DelayChoice>(
      context: context,
      builder: (_) => _SendAfterDialog(initial: start, active: _sendAfter != null),
    );
    if (choice == null || !mounted) return;
    setState(() => _sendAfter = choice.when);
  }

  /// L'invio ha effetti esterni: riepilogo e conferma esplicita, come nella Cli.
  Future<bool> _confirmSend(List<String> to, List<String> cc, List<String> bcc) async {
    final subject = _subject.text.trim();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.sendQuestion),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_chooseFrom && _account != null) Text('${context.l10n.columnFrom}: ${_fromLabel(_account!)}'),
            if (to.isNotEmpty) Text('${context.l10n.headerTo}: ${to.join(', ')}'),
            if (cc.isNotEmpty) Text('${context.l10n.headerCc}: ${cc.join(', ')}'),
            if (bcc.isNotEmpty) Text('${context.l10n.bcc}: ${bcc.join(', ')}'),
            Text('${context.l10n.columnSubject}: ${subject.isEmpty ? context.l10n.noSubject : subject}'),
            Text('${context.l10n.attachments}: ${_attachmentSummary(context.l10n)}'),
            Text(context.l10n.sendSummaryCopy(_saveCopy ? context.l10n.yesValue : context.l10n.noValue)),
            if (_sendAfter case final after?) Text(context.l10n.sendSummaryDelivery(formatSendAfter(after))),
            if (subject.isEmpty) ...[
              const SizedBox(height: 8),
              Text(context.l10n.emptySubjectWarning, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.receiptSend)),
        ],
      ),
    );
    return result ?? false;
  }

  String _attachmentSummary(AppLocalizations l) {
    final count = _files.length + _forwarded.length;
    if (count == 0) return l.attachmentsNone;
    final size = _files.isEmpty ? '' : l.attachmentsFromDisk(formatSize(_filesBytes));
    return '$count$size';
  }

  Future<void> _pickFiles() async {
    final picked = await context.read<FilePickerService>().pickFiles();
    if (picked.isNotEmpty && mounted) setState(() => _files.addAll(picked));
  }

  /// Chiusura con modifiche non salvate, come Outlook: Sì salva in Bozze, No chiude senza salvare (resta
  /// l'ultima bozza salvata, se c'era), Annulla (o Esc) torna al messaggio. null = Annulla.
  Future<bool?> _confirmSave() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.saveChangesQuestion),
      content: Text(_draftRef == null ? context.l10n.composeSaveNew : context.l10n.composeSaveExisting),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.no)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.yes)),
      ],
    ),
  );
}

/// Barra in cima alla composizione: tipo di messaggio, oggetto e chiusura (come il titolo della
/// finestra del messaggio in Outlook: "Oggetto - Messaggio").
class _ComposeTitleBar extends StatelessWidget {
  const _ComposeTitleBar({super.key, required this.title, required this.subject, required this.onClose, this.info});

  final String title;
  final String subject;

  /// Esito dell'ultimo salvataggio della bozza, a destra.
  final String? info;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: 36,
      color: scheme.primary,
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Icon(FluentIcons.mail_edit_20_regular, size: 18, color: scheme.onPrimary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600),
          ),
          if (subject.isNotEmpty) ...[
            Text('  –  ', style: TextStyle(color: scheme.onPrimary)),
            Expanded(
              child: Text(
                subject,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onPrimary),
              ),
            ),
          ] else
            const Spacer(),
          if (info case final text?)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(text, style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85), fontSize: 12)),
            ),
          IconButton(
            tooltip: context.l10n.closeEsc,
            onPressed: onClose,
            icon: Icon(FluentIcons.dismiss_20_regular, size: 18, color: scheme.onPrimary),
          ),
        ],
      ),
    );
  }
}

/// "Invia" grande a sinistra dei campi, come in Outlook classico.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onPressed});

  static const width = 72.0;

  final bool sending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 92,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          sending
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(FluentIcons.send_24_regular, size: 26),
          const SizedBox(height: 4),
          Text(sending ? context.l10n.sending : context.l10n.receiptSend),
        ],
      ),
    ),
  );
}

/// Scelta della finestra "Ritarda recapito": null = nessun ritardo.
class _DelayChoice {
  const _DelayChoice(this.when);

  final DateTime? when;
}

/// "Ritarda recapito" come Outlook: "Non recapitare prima del" giorno e ora.
class _SendAfterDialog extends StatefulWidget {
  const _SendAfterDialog({required this.initial, required this.active});

  final DateTime initial;
  final bool active;

  @override
  State<_SendAfterDialog> createState() => _SendAfterDialogState();
}

class _SendAfterDialogState extends State<_SendAfterDialog> {
  late DateTime _when = widget.initial;

  bool get _inFuture => _when.isAfter(DateTime.now());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day != null) setState(() => _when = DateTime(day.year, day.month, day.day, _when.hour, _when.minute));
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (time != null) setState(() => _when = DateTime(_when.year, _when.month, _when.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.delayDelivery),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.doNotDeliverBefore),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                key: const ValueKey('send-after-date'),
                onPressed: _pickDate,
                icon: const Icon(FluentIcons.calendar_20_regular, size: 18),
                label: Text(MaterialLocalizations.of(context).formatMediumDate(_when)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const ValueKey('send-after-time'),
                onPressed: _pickTime,
                icon: const Icon(FluentIcons.clock_20_regular, size: 18),
                label: Text(TimeOfDay.fromDateTime(_when).format(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _inFuture
                ? context.l10n.delayDeliveryHint
                : context.l10n.chooseFutureTime,
            style: TextStyle(
              fontSize: 12,
              color: _inFuture ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    ),
    actions: [
      if (widget.active)
        TextButton(
          onPressed: () => Navigator.pop(context, const _DelayChoice(null)),
          child: Text(context.l10n.noDelay),
        ),
      TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
      FilledButton(
        onPressed: _inFuture ? () => Navigator.pop(context, _DelayChoice(_when)) : null,
        child: const Text('OK'),
      ),
    ],
  );
}
