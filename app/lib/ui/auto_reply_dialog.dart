import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/formats.dart';
import '../l10n/language.dart';
import '../compose/rich_text.dart';
import '../models/auto_reply.dart';
import '../state/mailbox_model.dart';
import 'format_commands.dart';

/// "Risposte automatiche" (scelte 2a, 3a, 4a, 5a): come la finestra di Outlook, per account. Le risposte le invia
/// il core alle mail nuove della Posta in arrivo, con PostinoVip aperto; una per mittente a ogni attivazione,
/// senza copia in Posta inviata, mai a mailing list, altre risposte automatiche o mittenti di sistema.
class AutoReplyDialog extends StatefulWidget {
  const AutoReplyDialog({super.key, required this.initialAccount});

  final String initialAccount;

  static Future<void> show(BuildContext context, {String? account}) {
    final model = context.read<MailboxModel>();
    final start = account ?? model.selectedAccount ?? (model.accounts.isEmpty ? null : model.accounts.first.id);
    if (start == null) return Future.value();
    return showDialog<void>(
      context: context,
      builder: (_) => AutoReplyDialog(initialAccount: start),
    );
  }

  @override
  State<AutoReplyDialog> createState() => _AutoReplyDialogState();
}

class _AutoReplyDialogState extends State<AutoReplyDialog> {
  late String _account = widget.initialAccount;
  AutoReplySettings? _loaded;
  QuillController? _editor;
  bool _enabled = false;
  bool _period = false;
  late DateTime _start, _end;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _editor?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final model = context.read<MailboxModel>();
    AutoReplySettings settings;
    try {
      settings = await context.read<ApiClient>().forAccount(_account).getAutoReply();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = context.l10n.settingsNotRead('$e'));
      return;
    }
    if (!mounted) return;
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final old = _editor;
    setState(() {
      _loaded = settings;
      _enabled = settings.enabled;
      _period = settings.start != null || settings.end != null;
      _start = settings.start ?? nextHour;
      _end = settings.end ?? nextHour.add(const Duration(days: 1));
      _editor = QuillController(document: _documentOf(settings), selection: const TextSelection.collapsed(offset: 0));
      _error = null;
    });
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    model.autoReplies = {...model.autoReplies, _account: settings};
  }

  static Document _documentOf(AutoReplySettings s) {
    if (s.document case final json? when json.isNotEmpty) {
      try {
        return Document.fromDelta(Delta.fromJson(jsonDecode(json) as List));
      } on Object {
        // documento rovinato: si riparte dall'HTML
      }
    }
    return s.html.isEmpty ? Document() : htmlToDocument(s.html);
  }

  Future<DateTime?> _pick(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3 * 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static String _format(DateTime d) => '${formatDate(d)} ${formatTime(d)}';

  Future<void> _ok() async {
    final editor = _editor;
    if (editor == null) return;
    final text = documentToPlainText(editor.document).trim();
    final l = context.l10n;
    String? error;
    if (_enabled && text.isEmpty) {
      error = l.autoReplyTextRequired;
    } else if (_enabled && _period && !_end.isAfter(_start)) {
      error = l.endAfterStart;
    }
    setState(() => _error = error);
    if (error != null) return;

    // Attivarle fa partire mail senza conferma: lo si dice una volta, all'attivazione.
    if (_enabled && !(_loaded?.enabled ?? false)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.turnOnAutoRepliesQuestion),
          content: Text(l.turnOnAutoRepliesContent),
          actions: [
            TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.turnOn)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _saving = true);
    final delta = editor.document.toDelta().toJson();
    try {
      await context.read<MailboxModel>().saveAutoReply(
        _account,
        AutoReplySettings(
          enabled: _enabled,
          start: _period ? _start : null,
          end: _period ? _end : null,
          html: text.isEmpty ? '' : documentToHtml(editor.document),
          text: text,
          document: jsonEncode(delta),
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.notSavedPlural('${e.fieldErrors.values.firstOrNull?.first ?? e}');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final theme = Theme.of(context);
    final editor = _editor;
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.automaticReplies),
      content: SizedBox(
        width: 640,
        height: 520,
        child: editor == null
            ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (model.accounts.length > 1)
                    DropdownButtonFormField<String>(
                      key: const Key('autoreply-account'),
                      initialValue: _account,
                      decoration: InputDecoration(labelText: l.account, isDense: true),
                      items: [for (final a in model.accounts) DropdownMenuItem(value: a.id, child: Text(a.name))],
                      onChanged: _saving
                          ? null
                          : (id) {
                              if (id == null || id == _account) return;
                              setState(() {
                                _account = id;
                                _editor = null;
                              });
                              _load();
                            },
                    ),
                  RadioGroup<bool>(
                    groupValue: _enabled,
                    onChanged: (v) => setState(() => _enabled = v ?? false),
                    child: Column(
                      children: [
                        RadioListTile(
                          key: const Key('autoreply-off'),
                          dense: true,
                          value: false,
                          title: Text(l.dontSendAutoReplies),
                        ),
                        RadioListTile(
                          key: const Key('autoreply-on'),
                          dense: true,
                          value: true,
                          title: Text(l.sendAutoReplies),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          key: const Key('autoreply-period'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _period,
                          onChanged: _enabled ? (v) => setState(() => _period = v ?? false) : null,
                          title: Text(l.onlyDuringRange),
                        ),
                        Wrap(
                          spacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(l.startTimeColon),
                            TextButton(
                              key: const Key('autoreply-start'),
                              onPressed: _enabled && _period
                                  ? () async {
                                      final d = await _pick(_start);
                                      if (d != null) setState(() => _start = d);
                                    }
                                  : null,
                              child: Text(_format(_start)),
                            ),
                            Text(l.endTimeColon),
                            TextButton(
                              key: const Key('autoreply-end'),
                              onPressed: _enabled && _period
                                  ? () async {
                                      final d = await _pick(_end);
                                      if (d != null) setState(() => _end = d);
                                    }
                                  : null,
                              child: Text(_format(_end)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.autoRepliesInfo,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  FormatCommands(editor, l10n: context.l10n, enabled: true, onEdited: () {}).toolbar(context),
                  const SizedBox(height: 6),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant)),
                      child: QuillEditor.basic(
                        key: ValueKey('autoreply-editor:$_account'),
                        controller: editor,
                        config: QuillEditorConfig(
                          placeholder: l.autoReplyPlaceholder,
                          expands: true,
                          padding: const EdgeInsets.all(8),
                          embedBuilders: const [MailImageEmbedBuilder()],
                        ),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          key: const Key('autoreply-ok'),
          onPressed: _saving || editor == null ? null : _ok,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
