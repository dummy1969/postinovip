import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:provider/provider.dart';

import '../attachments/file_picker.dart';
import '../compose/rich_text.dart';
import '../models/account_info.dart';
import '../models/signature.dart';
import '../settings/app_settings.dart';
import 'format_commands.dart';

/// Limite di una firma, immagini comprese (scelta 3.7c-9a): un logo tipico è di pochi KB.
const maxSignatureBytes = 1024 * 1024;

/// Apre la finestra delle firme; [select]: firma da mostrare all'apertura.
Future<void> showSignaturesDialog(BuildContext context, {required List<AccountInfo> accounts, String? account}) =>
    showDialog<void>(
      context: context,
      builder: (_) => SignaturesDialog(accounts: accounts, initialAccount: account),
    );

/// "Firme e elementi decorativi" come Outlook (scelta 3.7c-7a): elenco delle firme (Nuova, Elimina,
/// Rinomina), editor formattato e, a destra, le firme predefinite di ogni account per i nuovi messaggi e
/// per risposte e inoltri. Le modifiche valgono solo con OK; tutto resta su questo computer.
class SignaturesDialog extends StatefulWidget {
  const SignaturesDialog({super.key, required this.accounts, this.initialAccount});

  final List<AccountInfo> accounts;
  final String? initialAccount;

  @override
  State<SignaturesDialog> createState() => _SignaturesDialogState();
}

class _SignaturesDialogState extends State<SignaturesDialog> {
  late final AppSettings _settings = context.read<AppSettings>();
  late List<Signature> _signatures = [..._settings.signatures];
  late final Map<String, SignatureDefaults> _defaults = {..._settings.signatureDefaults};
  late String? _account = widget.initialAccount ?? widget.accounts.firstOrNull?.id;

  String? _selected;
  QuillController? _editor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _select(_signatures.firstOrNull?.id);
  }

  @override
  void dispose() {
    _editor?.dispose();
    super.dispose();
  }

  /// Salva nell'elenco il testo della firma che si stava modificando e apre [id].
  void _select(String? id) {
    _keepEditing();
    // Chiuso dopo il ridisegno: fino ad allora l'editor lo sta ancora mostrando.
    final old = _editor;
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    _selected = id;
    final s = _signatures.where((s) => s.id == id).firstOrNull;
    _editor = s == null ? null : _controllerFor(s);
    _checkSize();
  }

  QuillController _controllerFor(Signature s) => QuillController(
    document: Document.fromDelta(Delta.fromJson(s.delta)),
    selection: const TextSelection.collapsed(offset: 0),
    // Come nella composizione: immagini incollate come "data:" (onImagePaste è sperimentale).
    // ignore: experimental_member_use
    config: QuillControllerConfig(
      // ignore: experimental_member_use
      clipboardConfig: QuillClipboardConfig(onImagePaste: (bytes) async => pastedImageUrl(bytes)),
    ),
  )..addListener(_checkSize);

  void _keepEditing() {
    final editor = _editor;
    final id = _selected;
    if (editor == null || id == null) return;
    final delta = [for (final op in editor.document.toDelta().toJson()) Map<String, dynamic>.from(op as Map)];
    _signatures = [for (final s in _signatures) s.id == id ? s.copyWith(delta: delta) : s];
  }

  void _checkSize() {
    final bytes = _editor == null ? 0 : embeddedImageBytes(_editor!.document);
    final error = bytes > maxSignatureBytes
        ? 'Firma troppo grande: ${formatSize(bytes)} di immagini, massimo ${formatSize(maxSignatureBytes)}.'
        : null;
    if (error != _error && mounted) setState(() => _error = error);
  }

  static String _newId() {
    final r = Random.secure();
    return List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<void> _new() async {
    final name = await _askName(title: 'Nuova firma');
    if (name == null) return;
    final s = Signature(
      id: _newId(),
      name: name,
      delta: const [
        {'insert': '\n'},
      ],
    );
    setState(() {
      _signatures = [..._signatures, s];
      _select(s.id);
    });
  }

  Future<void> _rename() async {
    final current = _signatures.where((s) => s.id == _selected).firstOrNull;
    if (current == null) return;
    final name = await _askName(title: 'Rinomina firma', initial: current.name, except: current.id);
    if (name == null) return;
    setState(() => _signatures = [for (final s in _signatures) s.id == current.id ? s.copyWith(name: name) : s]);
  }

  Future<void> _delete() async {
    final current = _signatures.where((s) => s.id == _selected).firstOrNull;
    if (current == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare la firma?'),
        content: Text('"${current.name}" verrà eliminata da questo computer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _selected = null; // niente da salvare: la firma è eliminata
      _signatures = [
        for (final s in _signatures)
          if (s.id != current.id) s,
      ];
      _select(_signatures.firstOrNull?.id);
    });
  }

  /// Nome della firma: non vuoto e diverso da quelli delle altre (senza distinzione di maiuscole).
  Future<String?> _askName({required String title, String initial = '', String? except}) => showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: title,
      initial: initial,
      taken: {
        for (final s in _signatures)
          if (s.id != except) s.name.toLowerCase(),
      },
    ),
  );

  Future<void> _insertImage() async {
    final editor = _editor;
    if (editor == null) return;
    final files = await context.read<FilePickerService>().pickFiles();
    if (files.isEmpty || !mounted) return;
    final url = pastedImageUrl(files.first.bytes);
    if (url == null) {
      setState(() => _error = 'Il file scelto non è un\'immagine (PNG, JPEG, GIF, BMP o WebP).');
      return;
    }
    final at = editor.selection.start.clamp(0, editor.document.length - 1);
    editor.replaceText(at, 0, BlockEmbed.image(url), TextSelection.collapsed(offset: at + 1));
  }

  Future<void> _ok() async {
    _keepEditing();
    final navigator = Navigator.of(context);
    await _settings.setSignatures(_signatures, _defaults);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editor = _editor;
    return AlertDialog(
      title: const Text('Firme e elementi decorativi'),
      content: SizedBox(
        width: 960,
        height: 520,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 210,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Seleziona la firma da modificare', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant)),
                      child: ListView(
                        key: const ValueKey('signature-list'),
                        children: [
                          for (final s in _signatures)
                            ListTile(
                              dense: true,
                              selected: s.id == _selected,
                              title: Text(s.name, overflow: TextOverflow.ellipsis),
                              onTap: () => setState(() => _select(s.id)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: _new,
                        icon: const Icon(FluentIcons.add_20_regular),
                        label: const Text('Nuova'),
                      ),
                      TextButton.icon(
                        onPressed: _selected == null ? null : _delete,
                        icon: const Icon(FluentIcons.delete_20_regular),
                        label: const Text('Elimina'),
                      ),
                      TextButton.icon(
                        onPressed: _selected == null ? null : _rename,
                        icon: const Icon(FluentIcons.rename_20_regular),
                        label: const Text('Rinomina'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Modifica firma', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  if (editor == null)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Nessuna firma: crea la prima con "Nuova".',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else ...[
                    FormatCommands(
                      editor,
                      enabled: true,
                      onEdited: () {},
                    ).toolbar(context, onInsertImage: _insertImage),
                    const SizedBox(height: 6),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant)),
                        child: QuillEditor.basic(
                          key: ValueKey('signature-editor:$_selected'),
                          controller: editor,
                          config: const QuillEditorConfig(
                            placeholder: 'Testo della firma',
                            expands: true,
                            padding: EdgeInsets.all(8),
                            embedBuilders: [MailImageEmbedBuilder()],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 24),
            SizedBox(width: 230, child: _defaultsPanel(theme)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(onPressed: _error == null ? _ok : null, child: const Text('OK')),
      ],
    );
  }

  /// "Scegli firma predefinita": account, nuovi messaggi, risposte e inoltri.
  Widget _defaultsPanel(ThemeData theme) {
    final account = _account;
    final d = _defaults[account] ?? SignatureDefaults.none;
    DropdownMenuItem<String?> none() => const DropdownMenuItem(value: null, child: Text('(nessuna)'));
    List<DropdownMenuItem<String?>> items() => [
      none(),
      for (final s in _signatures)
        DropdownMenuItem(
          value: s.id,
          child: Text(s.name, overflow: TextOverflow.ellipsis),
        ),
    ];
    void update(SignatureDefaults value) => setState(() => _defaults[account!] = value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Scegli firma predefinita', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: const ValueKey('signature-account'),
          initialValue: account,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Account'),
          items: [
            for (final a in widget.accounts)
              DropdownMenuItem(
                value: a.id,
                child: Text(
                  a.name == a.address ? a.address : '${a.name} <${a.address}>',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (id) => setState(() => _account = id),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: ValueKey('signature-new:$account'),
          initialValue: _signatures.any((s) => s.id == d.newMessage) ? d.newMessage : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Nuovi messaggi'),
          items: items(),
          onChanged: account == null ? null : (id) => update(SignatureDefaults(newMessage: id, reply: d.reply)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: ValueKey('signature-reply:$account'),
          initialValue: _signatures.any((s) => s.id == d.reply) ? d.reply : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Risposte/inoltri'),
          items: items(),
          onChanged: account == null ? null : (id) => update(SignatureDefaults(newMessage: d.newMessage, reply: id)),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial, required this.taken});

  final String title;
  final String initial;
  final Set<String> taken;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _ok() {
    final name = _text.text.trim();
    final error = name.isEmpty
        ? 'Scrivi un nome.'
        : widget.taken.contains(name.toLowerCase())
        ? 'C\'è già una firma con questo nome.'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 360,
      child: TextField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(labelText: 'Nome della firma', errorText: _error),
        onSubmitted: (_) => _ok(),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
      FilledButton(onPressed: _ok, child: const Text('OK')),
    ],
  );
}
