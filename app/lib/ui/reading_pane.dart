import 'dart:io';
import 'dart:typed_data';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../l10n/language.dart';
import 'package:provider/provider.dart';

import '../models/mail_importance.dart';
import '../models/message_detail.dart';
import '../state/mailbox_model.dart';
import '../api/api_client.dart';
import '../attachments/file_saver.dart';
import '../models/attachment_info.dart';
import '../models/compose_draft.dart';
import '../models/message_tags.dart';
import '../settings/app_settings.dart';
import 'theme.dart';
import 'attachment_previews.dart';
import 'categories.dart';
import 'follow_up.dart';
import 'message_actions.dart';
import 'eml_view.dart';
import 'error_view.dart';
import 'html_body_view.dart';
import 'html_to_text.dart';
import 'importance_icon.dart';
import 'junk_ui.dart';
import 'reading_zoom.dart';
import 'format.dart';
import 'sender_avatar.dart';

/// Pannello destro: messaggio selezionato, in HTML (se presente) o testo semplice.
/// «Non è posta indesiderata» dalla striscia; nella finestra della mail poi si apre la successiva, come gli altri spostamenti.
void _notJunk(BuildContext context, MailboxModel model) {
  if (model.messageWindowOpen) {
    model.removeAndOpenNext(() => JunkActions.notJunk(context));
  } else {
    JunkActions.notJunk(context);
  }
}

class ReadingPane extends StatelessWidget {
  const ReadingPane({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final outline = Theme.of(context).colorScheme.outline;

    // Più mail selezionate (3.5a): nessuna aperta, i comandi valgono per tutte (come Outlook).
    // Riga di una conversazione selezionata: si legge la più recente, i comandi valgono per tutte (3.6).
    if (model.multiSelection && model.selectedConversation == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.mail_multiple_24_regular, size: 40, color: outline),
            const SizedBox(height: 8),
            Text(
              context.l10n.selectedItems(model.selection.length),
              style: Theme.of(context).textTheme.titleSmall!.copyWith(fontSize: 16),
            ),
            if (model.actionInProgress) ...[const SizedBox(height: 12), const CircularProgressIndicator()],
          ],
        ),
      );
    }
    if (model.selectedUid == null) {
      return Center(
        child: Text(context.l10n.selectMessage, style: TextStyle(color: outline)),
      );
    }
    if (model.loadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }
    if (model.detailError != null) {
      return ErrorView(message: model.detailError!, onRetry: () => model.selectMessage(model.selectedUid!));
    }
    final detail = model.detail;
    if (detail == null) {
      return Center(
        child: Text(context.l10n.messageUnavailable, style: TextStyle(color: outline)),
      );
    }
    // La chiave azzera le scelte (HTML/testo, immagini) quando cambia messaggio.
    // Account e cartella della mail aperta: un risultato della ricerca può stare altrove.
    final api = model.accountApi;
    final folder = model.openFolder!;
    final view = MessageView(
      detail,
      attachmentBytes: (index) => api.getAttachmentBytes(folder, detail.uid, index),
      attachmentUrl: (a) => model.attachmentUrl(a.index),
      attachmentHeaders: model.attachmentHeaders,
      onReply: (mode) => MessageActions.reply(context, mode),
      junk: model.openInJunk,
      onNotJunk: MessageActions.canModify(model) && model.selectionInJunk ? () => _notJunk(context, model) : null,
      key: ValueKey((model.openAccount, model.openFolder, detail.uid)),
    );
    // Una bozza (3.8): come Outlook si riapre per finirla e inviarla.
    final draft = model.openFolderInfo?.role == 'drafts';
    // Conferma di lettura (R2) con «Chiedi ogni volta», come la striscia di Outlook.
    final receipt = model.receiptRequested && context.watch<AppSettings>().receiptMode == ReceiptMode.ask;
    if (model.actionError == null && !draft && !receipt) return view;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.actionError != null)
          MaterialBanner(
            content: Text(model.actionError!),
            actions: [TextButton(onPressed: model.clearActionError, child: Text(context.l10n.close))],
          ),
        if (receipt)
          MaterialBanner(
            key: const Key('receipt-banner'),
            leading: const Icon(FluentIcons.mail_read_20_regular),
            content: Text(context.l10n.receiptRequested(detail.from)),
            actions: [
              TextButton(
                key: const Key('receipt-decline'),
                onPressed: () => model.answerReceipt(send: false),
                child: Text(context.l10n.receiptDecline),
              ),
              FilledButton.tonal(
                key: const Key('receipt-send'),
                onPressed: () => model.answerReceipt(send: true),
                child: Text(context.l10n.receiptSend),
              ),
            ],
          ),
        if (draft)
          MaterialBanner(
            leading: const Icon(FluentIcons.drafts_20_regular),
            content: Text(context.l10n.draftBanner),
            actions: [
              FilledButton.tonal(
                onPressed: () => MessageActions.editDraft(context),
                child: Text(context.l10n.editDraft),
              ),
            ],
          ),
        Expanded(child: view),
      ],
    );
  }
}

enum _BodyMode { html, text }

/// Una mail con intestazioni, allegati, avvisi e corpo: nel riquadro di lettura e nella finestra di un file .eml
/// (E2). Da dove vengono allegati e risposte lo decide chi la usa.
class MessageView extends StatefulWidget {
  const MessageView(
    this.message, {
    required this.attachmentBytes,
    required this.attachmentUrl,
    required this.attachmentHeaders,
    required this.onReply,
    this.junk = false,
    this.onNotJunk,
    super.key,
  });

  /// La mail è nella posta indesiderata (J2, 4a): striscia, collegamenti disattivati, immagini sempre bloccate.
  final bool junk;

  /// «Non è posta indesiderata» dalla striscia (null: comando non disponibile).
  final VoidCallback? onNotJunk;

  final MessageDetail message;

  /// Byte dell'allegato numero index (per salvarlo o, se è una mail, aprirlo).
  final Future<Uint8List> Function(int index) attachmentBytes;

  /// URL delle anteprime delle immagini allegate, con [attachmentHeaders].
  final String Function(AttachmentInfo) attachmentUrl;
  final Map<String, String> attachmentHeaders;

  /// Rispondi, Rispondi a tutti, Inoltra.
  final Future<void> Function(DraftMode mode) onReply;

  @override
  State<MessageView> createState() => _MessageViewState();
}

class _MessageViewState extends State<MessageView> {
  late _BodyMode _mode = widget.message.htmlBody != null ? _BodyMode.html : _BodyMode.text;
  bool _showRemoteImages = false;
  DraftMode? _loadingDraft;

  MessageDetail get _m => widget.message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHtml = _m.htmlBody != null;
    final hasText = _m.textBody != null && _m.textBody!.trim().isNotEmpty;
    final images = _m.attachments.where((a) => a.isPreviewableImage).toList();

    // Intestazioni, anteprime delle immagini e avvisi: al massimo il 60% dell'altezza, poi scorrono. Con il
    // riquadro di lettura basso e una mail con allegati il corpo restava senza spazio e la colonna traboccava.
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            key: const Key('reading-header'),
            constraints: BoxConstraints(maxHeight: box.maxHeight.isFinite ? box.maxHeight * 0.6 : double.infinity),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          _m.subject,
                          style: theme.textTheme.titleLarge!.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        // Come l'Outlook di oggi (tappa «Aspetto», V5): cerchio con le iniziali del mittente, nome in
                        // grassetto con l'indirizzo accanto (niente «Da:»), destinatari sotto, data a destra.
                        // Rispondi, Rispondi a tutti e Inoltra a destra del mittente (scelta 4a del 09/11/2026);
                        // stretto: sopra il mittente, e la data sotto i destinatari.
                        LayoutBuilder(
                          builder: (context, box) {
                            // 640 (prima 560): con il cerchio delle iniziali i tre pulsanti accanto al mittente non stavano.
                            final wide = box.maxWidth >= 640;
                            final date = _m.date == null
                                ? null
                                : Text(
                                    formatSendAfter(_m.date!),
                                    key: const Key('reading-date'),
                                    style: theme.textTheme.bodySmall!.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  );
                            final recipients = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_m.to.isNotEmpty) _headerLine(context.l10n.headerTo, _m.to.join(', ')),
                                if (_m.cc.isNotEmpty) _headerLine(context.l10n.headerCc, _m.cc.join(', ')),
                              ],
                            );
                            final person = Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SenderAvatar(from: _m.from, size: wide ? 40 : 32),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _withRight(
                                        _senderLine(theme),
                                        wide ? Wrap(spacing: 6, children: _replyButtons()) : null,
                                      ),
                                      const SizedBox(height: 2),
                                      if (wide)
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: recipients),
                                            if (date != null) ...[const SizedBox(width: 12), date],
                                          ],
                                        )
                                      else ...[
                                        recipients,
                                        ?date,
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                            if (wide) return person;
                            // Stretto: i pulsanti sopra, a tutta larghezza (accanto al cerchio andavano a capo).
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(spacing: 6, runSpacing: 4, children: _replyButtons()),
                                const SizedBox(height: 8),
                                person,
                              ],
                            );
                          },
                        ),
                        // Categorie e contrassegno a sinistra, HTML/Testo a destra.
                        if (_m.tags.categories.isNotEmpty || _m.tags.flagged || _m.tags.completed || hasHtml) ...[
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            // Stretto (finestra piccola): HTML/Testo sotto le categorie invece che accanto.
                            builder: (context, box) {
                              final tags = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_m.tags.categories.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        for (final c in _m.tags.categories)
                                          CategoryChip(number: c, name: context.watch<AppSettings>().categoryName(c)),
                                      ],
                                    ),
                                  if (_m.tags.flagged || _m.tags.completed) ...[
                                    if (_m.tags.categories.isNotEmpty) const SizedBox(height: 6),
                                    _FollowUpLine(_m.tags),
                                  ],
                                ],
                              );
                              if (!hasHtml) return Align(alignment: Alignment.centerLeft, child: tags);
                              if (box.maxWidth < 400) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [tags, const SizedBox(height: 6), _bodyModeToggle()],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: tags),
                                  const SizedBox(width: 8),
                                  _bodyModeToggle(),
                                ],
                              );
                            },
                          ),
                        ],
                        // Allegati come schede (V5), come l'Outlook di oggi: icona del tipo, nome e tipo sotto.
                        if (_m.attachments.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final a in _m.attachments)
                                // Una mail allegata si apre (E2), come in Outlook; da lì «Salva con nome».
                                a.contentType == 'message/rfc822'
                                    ? AttachmentCard(
                                        key: Key('attachment-open-${a.index}'),
                                        attachment: a,
                                        tooltip: context.l10n.openAttachment(a.fileName),
                                        onPressed: () => _openAttachedMail(a),
                                      )
                                    : AttachmentCard(
                                        key: Key('attachment-save-${a.index}'),
                                        attachment: a,
                                        tooltip: context.l10n.saveAttachment(a.fileName),
                                        onPressed: () => _saveAttachment(a),
                                      ),
                            ],
                          ),
                        ],
                        if (images.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          AttachmentPreviews(
                            images: images,
                            urlFor: widget.attachmentUrl,
                            headers: widget.attachmentHeaders,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_m.importance != MailImportance.normal)
                    _Banner(
                      key: const Key('importance-banner'),
                      text: _m.importance == MailImportance.high
                          ? context.l10n.importanceHighBanner
                          : context.l10n.importanceLowBanner,
                      leading: ImportanceIcon(_m.importance),
                    ),
                  if (widget.junk)
                    _Banner(
                      key: const Key('junk-banner'),
                      leading: const Icon(FluentIcons.folder_prohibited_20_regular, size: 16),
                      text: context.l10n.junkBanner,
                      action: widget.onNotJunk == null
                          ? null
                          : TextButton(
                              key: const Key('junk-banner-not-junk'),
                              onPressed: widget.onNotJunk,
                              child: Text(context.l10n.notJunk),
                            ),
                    ),
                  if (!widget.junk && _mode == _BodyMode.html && _m.hasRemoteImages && !_showRemoteImages)
                    _Banner(
                      text: context.l10n.remoteImagesBlocked,
                      action: TextButton(
                        onPressed: () => setState(() => _showRemoteImages = true),
                        child: Text(context.l10n.showImages),
                      ),
                    ),
                  if (_mode == _BodyMode.text && hasHtml && !hasText)
                    _Banner(text: context.l10n.htmlOnlyAsText),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            // Testo della mail sempre su fondo bianco, anche con un tema scuro (scelta 2b).
            child: MessageSurface(
              // Zoom (P2): solo il corpo, come Outlook; le intestazioni restano come sono.
              child: ZoomedBody(
                child: _mode == _BodyMode.html
                    ? HtmlBodyView(
                        // Chiave diversa per forzare la ricostruzione quando si sbloccano le immagini.
                        key: ValueKey(_showRemoteImages),
                        html: _m.htmlBody!,
                        allowRemoteImages: _showRemoteImages && !widget.junk,
                        linksEnabled: !widget.junk,
                      )
                    : SelectableText(_plainText(hasText), style: const TextStyle(height: 1.4)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rispondi, Rispondi a tutti, Inoltra in piccolo, con l'indicatore sul pulsante premuto.
  List<Widget> _replyButtons() => [
    for (final (mode, icon) in [
      (DraftMode.reply, FluentIcons.arrow_reply_20_regular),
      (DraftMode.replyAll, FluentIcons.arrow_reply_all_20_regular),
      (DraftMode.forward, FluentIcons.arrow_forward_20_regular),
    ])
      OutlinedButton.icon(
        key: Key('header-${mode.name}'),
        style: _compact,
        onPressed: _loadingDraft == null ? () => _openDraft(mode) : null,
        icon: _loadingDraft == mode
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 16),
        label: Text(mode.label(context.l10n)),
      ),
  ];

  /// HTML / Testo in piccolo.
  Widget _bodyModeToggle() => SegmentedButton<_BodyMode>(
    key: const Key('body-mode'),
    style: _compact,
    showSelectedIcon: false,
    segments: [
      const ButtonSegment(value: _BodyMode.html, label: Text('HTML'), icon: Icon(Icons.web, size: 16)),
      ButtonSegment(value: _BodyMode.text, label: Text(context.l10n.bodyText), icon: const Icon(Icons.notes, size: 16)),
    ],
    selected: {_mode},
    onSelectionChanged: (s) => setState(() => _mode = s.first),
  );

  // Il testo parte da quello del tema: un TextStyle senza carattere prenderebbe quello predefinito del motore.
  ButtonStyle get _compact => ButtonStyle(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
    textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 13)),
  );

  /// Una riga di intestazione con [right] allineato a destra (pulsanti piccoli).
  static Widget _withRight(Widget left, Widget? right) => right == null
      ? left
      : Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: left),
            const SizedBox(width: 8),
            right,
          ],
        );

  /// Chiede dove salvare, scarica l'allegato dal core e lo scrive su disco.
  Future<void> _saveAttachment(AttachmentInfo a) async {
    final saver = context.read<FileSaver>();
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;

    final path = await saver.pickSaveLocation(safeFileName(a.fileName));
    if (path == null) return; // annullato
    try {
      final bytes = await widget.attachmentBytes(a.index);
      await saver.write(path, bytes);
      messenger.showSnackBar(SnackBar(content: Text(l.savedTo(path))));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.attachmentNotDownloaded('$e'))));
    } on FileSystemException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.fileNotWritten(e.message, '${e.path}'))));
    }
  }

  /// Mail allegata (message/rfc822): si apre nella finestra dei file .eml (E2).
  Future<void> _openAttachedMail(AttachmentInfo a) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      final bytes = await widget.attachmentBytes(a.index);
      if (mounted) await EmlActions.open(context, bytes, name: a.fileName);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.attachedMailNotOpened('$e'))));
    }
  }

  /// Bozza di risposta o inoltro, con l'indicatore sul pulsante premuto.
  Future<void> _openDraft(DraftMode mode) async {
    setState(() => _loadingDraft = mode);
    try {
      await widget.onReply(mode);
    } finally {
      if (mounted) setState(() => _loadingDraft = null);
    }
  }

  String _plainText(bool hasText) {
    if (hasText) return _m.textBody!;
    if (_m.htmlBody != null) return htmlToText(_m.htmlBody!);
    return context.l10n.messageWithoutText;
  }

  static Widget _headerLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );

  /// Mittente: nome in grassetto e, se c'è, l'indirizzo accanto in grigio.
  Widget _senderLine(ThemeData theme) {
    final sender = splitSender(_m.from);
    return SelectableText.rich(
      key: const Key('reading-from'),
      TextSpan(
        children: [
          TextSpan(
            text: sender.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (sender.address != sender.name)
            TextSpan(
              text: '  <${sender.address}>',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// Stato del contrassegno sotto le intestazioni, come la riga informativa di Outlook.
class _FollowUpLine extends StatelessWidget {
  const _FollowUpLine(this.tags);

  final MessageTags tags;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final due = tags.due;
    final overdue = tags.flagged && due != null && due.isBefore(DateTime(now.year, now.month, now.day));
    final (icon, color, text) = tags.completed
        ? (FluentIcons.checkmark_16_regular, scheme.onSurfaceVariant, context.l10n.completed)
        : (
            FluentIcons.flag_16_filled,
            scheme.error,
            due == null
                ? context.l10n.flaggedForFollowUp
                : context.l10n.dueBy(formatDueDate(due)) + (overdue ? context.l10n.overdueSuffix : ''),
          );
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 13, color: overdue ? scheme.error : null)),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, this.action, this.leading});

  final String text;
  final Widget? action;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
          ?action,
        ],
      ),
    );
  }
}
