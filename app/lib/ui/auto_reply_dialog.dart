import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
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
      if (mounted) setState(() => _error = 'Impostazioni non lette: $e');
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

  static String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _ok() async {
    final editor = _editor;
    if (editor == null) return;
    final text = documentToPlainText(editor.document).trim();
    String? error;
    if (_enabled && text.isEmpty) {
      error = 'Scrivi il messaggio della risposta automatica.';
    } else if (_enabled && _period && !_end.isAfter(_start)) {
      error = 'L\'ora di fine deve venire dopo l\'ora di inizio.';
    }
    setState(() => _error = error);
    if (error != null) return;

    // Attivarle fa partire mail senza conferma: lo si dice una volta, all'attivazione.
    if (_enabled && !(_loaded?.enabled ?? false)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Attivare le risposte automatiche?'),
          content: const Text(
            'Da ora PostinoVip risponderà da solo, una volta per mittente, alle mail che arrivano nella Posta in '
            'arrivo e in cui sei in A o Cc, finché resta aperto. Le risposte partono senza chiederti conferma.',
          ),
          actions: [
            TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Attiva')),
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
          _error = 'Non salvate: ${e.fieldErrors.values.firstOrNull?.first ?? e}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final theme = Theme.of(context);
    final editor = _editor;
    return AlertDialog(
      title: const Text('Risposte automatiche'),
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
                      decoration: const InputDecoration(labelText: 'Account', isDense: true),
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
                    child: const Column(
                      children: [
                        RadioListTile(
                          key: Key('autoreply-off'),
                          dense: true,
                          value: false,
                          title: Text('Non inviare risposte automatiche'),
                        ),
                        RadioListTile(
                          key: Key('autoreply-on'),
                          dense: true,
                          value: true,
                          title: Text('Invia risposte automatiche'),
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
                          title: const Text('Invia solo durante questo intervallo di tempo'),
                        ),
                        Wrap(
                          spacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Inizio:'),
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
                            const Text('Fine:'),
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
                    'Le risposte partono da questo computer mentre PostinoVip è aperto (le mail arrivate ad app chiusa '
                    'ricevono la risposta alla riapertura): una sola per mittente, solo se sei in A o Cc, mai a mailing '
                    'list, ad altre risposte automatiche o a mittenti come «noreply». Non vengono salvate in Posta inviata.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  FormatCommands(editor, enabled: true, onEdited: () {}).toolbar(context),
                  const SizedBox(height: 6),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant)),
                      child: QuillEditor.basic(
                        key: ValueKey('autoreply-editor:$_account'),
                        controller: editor,
                        config: const QuillEditorConfig(
                          placeholder: 'es. Sono fuori sede fino a lunedì 16 novembre e risponderò al mio rientro.',
                          expands: true,
                          padding: EdgeInsets.all(8),
                          embedBuilders: [MailImageEmbedBuilder()],
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
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          key: const Key('autoreply-ok'),
          onPressed: _saving || editor == null ? null : _ok,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
