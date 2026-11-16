import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../l10n/language.dart';
import '../models/mail_folder.dart';
import '../models/mail_rule.dart';
import '../settings/app_settings.dart';
import '../state/mailbox_model.dart';
import 'categories.dart';
import 'move_dialog.dart';

/// Regole (R2), come "Regole e avvisi" di Outlook: le applica il core alle mail che arrivano nella Posta
/// in arrivo (con PostinoVip aperto; quelle arrivate ad app chiusa alla riapertura).
class RulesUi {
  RulesUi._();

  /// "Gestisci regole e avvisi": la finestra con l'elenco, sull'account indicato (o su quello aperto).
  static Future<void> manage(BuildContext context, {String? account}) {
    final model = context.read<MailboxModel>();
    final start = account ?? model.selectedAccount ?? (model.accounts.isEmpty ? null : model.accounts.first.id);
    if (start == null) return Future.value();
    // I provider dell'app (modello, client, impostazioni) stanno sopra il Navigator: valgono anche nelle finestre.
    return showDialog<void>(
      context: context,
      builder: (_) => RulesDialog(initialAccount: start),
    );
  }

  /// "Crea regola…" sulla mail aperta: editor già compilato con il mittente (attivo) e l'oggetto (da attivare).
  static Future<void> createFor(BuildContext context) async {
    final model = context.read<MailboxModel>();
    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final detail = model.detail;
    final account = model.openAccount;
    if (detail == null || account == null) return;

    final sender = detail.fromAddress ?? detail.from;
    final rule = await showDialog<MailRule>(
      context: context,
      builder: (_) => RuleEditorDialog(
        initial: MailRule(
          name: detail.subject.isEmpty ? l.ruleNameFrom(sender) : detail.subject,
          conditions: RuleConditions(from: [sender]),
        ),
        suggestedSubject: detail.subject,
        folders: model.foldersByAccount[account] ?? const [],
      ),
    );
    if (rule == null) return;
    try {
      final client = api.forAccount(account);
      await client.saveRules([...await client.getRules(), rule]);
      messenger.showSnackBar(
        SnackBar(content: Text(l.ruleCreated(rule.name))),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.ruleNotSaved('$e'))));
    }
  }

  /// Descrizione leggibile della regola, per l'elenco ("Se … → …").
  static String describe(MailRule rule, AppSettings settings) {
    final l = settings.l10n;
    String words(List<String>? w) => (w ?? const []).map(l.quoted).join(l.orSeparator);
    List<String> conditions(RuleConditions c) => [
      if ((c.from ?? const []).isNotEmpty) l.ruleDescFrom(words(c.from)),
      if ((c.toOrCc ?? const []).isNotEmpty) l.ruleDescToOrCc(words(c.toOrCc)),
      if (c.sentOnlyToMe) l.ruleDescSentOnlyToMe,
      if (c.meInTo) l.ruleDescMeInTo,
      if (c.meInCc) l.ruleDescMeInCc,
      if ((c.subjectContains ?? const []).isNotEmpty) l.ruleDescSubject(words(c.subjectContains)),
      if ((c.subjectOrBodyContains ?? const []).isNotEmpty) l.ruleDescSubjectOrBody(words(c.subjectOrBodyContains)),
      if (c.hasAttachments) l.ruleDescAttachments,
      if (c.sizeGreaterThanKb != null) l.ruleDescSize(c.sizeGreaterThanKb!),
    ];
    final a = rule.actions;
    final actions = [
      if (a.moveTo != null) l.ruleDescMove(a.moveTo!),
      if (a.copyTo != null) l.ruleDescCopy(a.copyTo!),
      if (a.delete) l.ruleDescDelete,
      if (a.markRead) l.ruleDescMarkRead,
      if (a.flag) l.ruleDescFlag,
      if (a.category != null) l.ruleDescCategory(settings.categoryName(a.category!)),
      if (a.stopProcessing) l.ruleDescStop,
    ];
    final when = conditions(rule.conditions);
    final unless = rule.exceptions == null ? const <String>[] : conditions(rule.exceptions!);
    return '${when.isEmpty ? l.ruleDescAllMail : l.ruleDescIf(when.join(l.andSeparator))}'
        '${unless.isEmpty ? '' : l.ruleDescExcept(unless.join(l.orSeparator))}'
        ' → ${actions.join(', ')}';
  }
}

/// "Regole e avvisi": elenco delle regole di un account, nell'ordine in cui si applicano. Le modifiche valgono
/// con OK (come in Outlook); "Annulla" le scarta.
class RulesDialog extends StatefulWidget {
  const RulesDialog({super.key, required this.initialAccount});

  final String initialAccount;

  @override
  State<RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends State<RulesDialog> {
  late String _account = widget.initialAccount;

  /// Regole caricate per account (modificate qui finché non si preme OK).
  final _rules = <String, List<MailRule>>{};
  final _dirty = <String>{};
  String? _error;
  int? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load(_account);
  }

  Future<void> _load(String account) async {
    if (_rules.containsKey(account)) return;
    try {
      final rules = await context.read<ApiClient>().forAccount(account).getRules();
      if (mounted) setState(() => _rules[account] = rules);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = context.l10n.rulesNotRead('$e'));
    }
  }

  List<MailRule>? get _list => _rules[_account];

  void _change(void Function(List<MailRule> rules) change) {
    setState(() {
      change(_rules[_account]!);
      _dirty.add(_account);
    });
  }

  Future<void> _edit({int? index}) async {
    final model = context.read<MailboxModel>();
    final list = _list;
    if (list == null) return;
    final rule = await showDialog<MailRule>(
      context: context,
      builder: (_) => RuleEditorDialog(
        initial: index == null ? null : list[index],
        folders: model.foldersByAccount[_account] ?? const [],
      ),
    );
    if (rule == null) return;
    _change((rules) {
      if (index == null) {
        rules.add(rule);
        _selected = rules.length - 1;
      } else {
        rules[index] = rule;
      }
    });
  }

  Future<void> _delete(int index) async {
    final name = _list![index].name;
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteRuleQuestion),
        content: Text(l.deleteRuleContent(name)),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    _change((rules) {
      rules.removeAt(index);
      _selected = rules.isEmpty ? null : index.clamp(0, rules.length - 1);
    });
  }

  void _moveBy(int index, int delta) => _change((rules) {
    final rule = rules.removeAt(index);
    rules.insert(index + delta, rule);
    _selected = index + delta;
  });

  /// "Esegui regole ora…" (R3): lavora sulle regole salvate; se ci sono modifiche, prima si salvano.
  Future<void> _runNow() async {
    final api = context.read<ApiClient>().forAccount(_account);
    final model = context.read<MailboxModel>();
    final l = context.l10n;
    if (_dirty.contains(_account)) {
      try {
        final saved = await api.saveRules(_rules[_account]!);
        setState(() {
          _rules[_account] = saved;
          _dirty.remove(_account);
        });
      } on ApiException catch (e) {
        setState(() => _error = l.rulesNotSaved('${e.fieldErrors['rules']?.first ?? e}'));
        return;
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          RunRulesDialog(api: api, rules: _rules[_account]!, folders: model.foldersByAccount[_account] ?? const []),
    );
    if (mounted) unawaited(model.refresh()); // cartelle e lista con le mail spostate
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = context.read<ApiClient>();
    try {
      for (final account in _dirty.toList()) {
        _rules[account] = await api.forAccount(account).saveRules(_rules[account]!);
        _dirty.remove(account);
      }
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.rulesNotSaved('${e.fieldErrors['rules']?.first ?? e}');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MailboxModel>();
    final settings = context.read<AppSettings>();
    final theme = Theme.of(context);
    final list = _list;
    final selected = list == null || _selected == null || _selected! >= list.length ? null : _selected;
    final l = context.l10n;

    return AlertDialog(
      title: Text(l.rulesAndAlerts),
      content: SizedBox(
        width: 680,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (model.accounts.length > 1)
              DropdownButtonFormField<String>(
                key: const Key('rules-account'),
                initialValue: _account,
                decoration: InputDecoration(labelText: l.applyChangesToFolder, isDense: true),
                items: [
                  for (final a in model.accounts)
                    DropdownMenuItem(value: a.id, child: Text('${l.folderInbox} - ${a.name}')),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _account = id;
                    _selected = null;
                  });
                  _load(id);
                },
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  onPressed: list == null ? null : () => _edit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.newRuleEllipsis),
                ),
                OutlinedButton(
                  onPressed: selected == null ? null : () => _edit(index: selected),
                  child: Text(l.editEllipsis),
                ),
                OutlinedButton(
                  onPressed: selected == null ? null : () => _delete(selected),
                  child: Text(l.delete),
                ),
                OutlinedButton.icon(
                  key: const Key('rules-run-now'),
                  onPressed: list == null || list.isEmpty || _saving ? null : _runNow,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(l.runRulesNowEllipsis),
                ),
                IconButton(
                  tooltip: l.moveUp,
                  onPressed: selected == null || selected == 0 ? null : () => _moveBy(selected, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: l.moveDown,
                  onPressed: selected == null || selected == list!.length - 1 ? null : () => _moveBy(selected, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant)),
                child: list == null
                    ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
                    : list.isEmpty
                    ? Center(child: Text(l.noRules))
                    : ListView(
                        children: [
                          for (final (i, rule) in list.indexed)
                            ListTile(
                              key: ValueKey('rule:$i'),
                              dense: true,
                              selected: i == selected,
                              leading: Checkbox(
                                value: rule.enabled,
                                onChanged: (v) => _change((rules) => rules[i] = rule.copyWith(enabled: v ?? true)),
                              ),
                              title: Text(rule.name),
                              subtitle: Text(
                                RulesUi.describe(rule, settings),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => setState(() => _selected = i),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.rulesInfo,
              style: theme.textTheme.bodySmall,
            ),
            if (_error != null && list != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('OK')),
      ],
    );
  }
}

/// Campi di un gruppo di condizioni (usato per le condizioni e per le eccezioni).
class _ConditionFields {
  _ConditionFields(RuleConditions? c, {String? suggestedSubject}) {
    final subjectWords = c?.subjectContains ?? const [];
    from = _Words(c?.from);
    toOrCc = _Words(c?.toOrCc);
    subject = _Words(
      subjectWords.isEmpty && suggestedSubject != null && suggestedSubject.isNotEmpty ? null : c?.subjectContains,
      text: subjectWords.isEmpty ? suggestedSubject : null,
    );
    subjectOrBody = _Words(c?.subjectOrBodyContains);
    sentOnlyToMe = c?.sentOnlyToMe ?? false;
    meInTo = c?.meInTo ?? false;
    meInCc = c?.meInCc ?? false;
    hasAttachments = c?.hasAttachments ?? false;
    sizeOn = c?.sizeGreaterThanKb != null;
    size = TextEditingController(text: '${c?.sizeGreaterThanKb ?? 1024}');
  }

  late final _Words from, toOrCc, subject, subjectOrBody;
  late bool sentOnlyToMe, meInTo, meInCc, hasAttachments, sizeOn;
  late final TextEditingController size;

  RuleConditions build() => RuleConditions(
    from: from.value,
    toOrCc: toOrCc.value,
    sentOnlyToMe: sentOnlyToMe,
    meInTo: meInTo,
    meInCc: meInCc,
    subjectContains: subject.value,
    subjectOrBodyContains: subjectOrBody.value,
    hasAttachments: hasAttachments,
    sizeGreaterThanKb: sizeOn ? int.tryParse(size.text.trim()) : null,
  );

  void dispose() {
    for (final w in [from, toOrCc, subject, subjectOrBody]) {
      w.text.dispose();
    }
    size.dispose();
  }
}

/// Una condizione a parole: casella "attiva" e parole separate da ";".
class _Words {
  _Words(List<String>? words, {String? text})
    : on = words != null && words.isNotEmpty,
      text = TextEditingController(text: text ?? (words ?? const []).join('; '));

  bool on;
  final TextEditingController text;

  List<String>? get value {
    if (!on) return null;
    final words = [
      for (final w in text.text.split(';'))
        if (w.trim().isNotEmpty) w.trim(),
    ];
    return words.isEmpty ? null : words;
  }
}

/// Nuova regola o modifica: nome, condizioni, azioni, eccezioni (come la procedura guidata di Outlook).
class RuleEditorDialog extends StatefulWidget {
  const RuleEditorDialog({super.key, this.initial, required this.folders, this.suggestedSubject});

  final MailRule? initial;

  /// Cartelle dell'account, per "sposta" e "copia".
  final List<MailFolder> folders;

  /// "Crea regola…": oggetto della mail già scritto nella condizione, da attivare se serve.
  final String? suggestedSubject;

  @override
  State<RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<RuleEditorDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _when = _ConditionFields(widget.initial?.conditions, suggestedSubject: widget.suggestedSubject);
  late final _unless = _ConditionFields(widget.initial?.exceptions);
  late RuleActions _a = widget.initial?.actions ?? const RuleActions();
  late bool _moveOn = _a.moveTo != null, _copyOn = _a.copyTo != null, _categoryOn = _a.category != null;
  late String? _moveTo = _a.moveTo, _copyTo = _a.copyTo;
  late int _category = _a.category ?? 1;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _when.dispose();
    _unless.dispose();
    super.dispose();
  }

  Future<String?> _chooseFolder(String title) => showDialog<String>(
    context: context,
    builder: (_) => MoveDialog(folders: widget.folders, count: 1, title: title, message: context.l10n.chooseFolderColon),
  );

  RuleActions _actions() => RuleActions(
    moveTo: _moveOn && !_a.delete ? _moveTo : null,
    copyTo: _copyOn ? _copyTo : null,
    delete: _a.delete,
    markRead: _a.markRead,
    flag: _a.flag,
    category: _categoryOn ? _category : null,
    stopProcessing: _a.stopProcessing,
  );

  Future<void> _ok() async {
    final name = _name.text.trim();
    final actions = _actions();
    final conditions = _when.build();
    final exceptions = _unless.build();
    final l = context.l10n;
    String? error;
    if (name.isEmpty) {
      error = l.ruleNameRequired;
    } else if ((_moveOn && !_a.delete && _moveTo == null) || (_copyOn && _copyTo == null)) {
      error = l.ruleFolderRequired;
    } else if (actions.isEmpty) {
      error = l.ruleActionRequired;
    } else if (_when.sizeOn && conditions.sizeGreaterThanKb == null ||
        _unless.sizeOn && exceptions.sizeGreaterThanKb == null) {
      error = l.ruleSizeRequired;
    }
    setState(() => _error = error);
    if (error != null) return;

    if (conditions.isEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.ruleForAllMail),
          content: Text(l.ruleForAllMailContent),
          actions: [
            TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: Text(l.no)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.yes)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    Navigator.pop(
      context,
      MailRule(
        id: widget.initial?.id ?? '',
        name: name,
        enabled: widget.initial?.enabled ?? true,
        conditions: conditions,
        exceptions: exceptions.isEmpty ? null : exceptions,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return DefaultTabController(
      length: 3,
      child: AlertDialog(
        title: Text(widget.initial == null || widget.initial!.id.isEmpty ? l.newRule : l.editRule),
        content: SizedBox(
          width: 620,
          height: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('rule-name'),
                controller: _name,
                autofocus: widget.initial == null,
                decoration: InputDecoration(labelText: l.ruleName, isDense: true),
              ),
              const SizedBox(height: 8),
              TabBar(
                tabs: [
                  Tab(text: l.ruleConditions),
                  Tab(text: l.ruleActions),
                  Tab(text: l.ruleExceptions),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _conditions(_when, l.ruleConditionsIntro, 'cond'),
                    _actionsTab(),
                    _conditions(_unless, l.ruleExceptionsIntro, 'exc'),
                  ],
                ),
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(key: const Key('rule-ok'), onPressed: _ok, child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _check(Key key, bool value, ValueChanged<bool> onChanged, String label, {Widget? trailing}) => Row(
    children: [
      Checkbox(key: key, value: value, onChanged: (v) => setState(() => onChanged(v ?? false))),
      Flexible(child: Text(label)),
      if (trailing != null) ...[const SizedBox(width: 8), Expanded(child: trailing)],
    ],
  );

  Widget _wordsRow(String prefix, String key, _Words w, String label, String hint) => _check(
    Key('$prefix-$key'),
    w.on,
    (v) => w.on = v,
    label,
    trailing: TextField(
      key: Key('$prefix-$key-text'),
      controller: w.text,
      decoration: InputDecoration(isDense: true, hintText: hint),
      onChanged: (t) => setState(() => w.on = t.trim().isNotEmpty),
    ),
  );

  Widget _conditions(_ConditionFields f, String intro, String p) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        Text(intro, style: Theme.of(context).textTheme.bodySmall),
        _wordsRow(p, 'from', f.from, l.ruleFrom, l.ruleFromHint),
        _wordsRow(p, 'tocc', f.toOrCc, l.ruleToOrCc, l.ruleToOrCcHint),
        _check(Key('$p-onlyme'), f.sentOnlyToMe, (v) => f.sentOnlyToMe = v, l.ruleDescSentOnlyToMe),
        _check(Key('$p-meto'), f.meInTo, (v) => f.meInTo = v, l.ruleMeInTo),
        _check(Key('$p-mecc'), f.meInCc, (v) => f.meInCc = v, l.ruleMeInCc),
        _wordsRow(p, 'subject', f.subject, l.ruleSubjectContains, l.ruleWordsHint),
        _wordsRow(p, 'body', f.subjectOrBody, l.ruleSubjectOrBodyContains, l.ruleWordsHint),
        _check(Key('$p-attach'), f.hasAttachments, (v) => f.hasAttachments = v, l.ruleDescAttachments),
        _check(
          Key('$p-size'),
          f.sizeOn,
          (v) => f.sizeOn = v,
          l.ruleLargerThan,
          trailing: Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  key: Key('$p-size-text'),
                  controller: f.size,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (_) => setState(() => f.sizeOn = true),
                ),
              ),
              const SizedBox(width: 8),
              const Text('KB'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _folderButton(String? folder, String title, ValueChanged<String> chosen, Key key) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      key: key,
      onPressed: () async {
        final f = await _chooseFolder(title);
        if (f != null) setState(() => chosen(f));
      },
      child: Text(folder ?? context.l10n.chooseFolderEllipsis, overflow: TextOverflow.ellipsis),
    ),
  );

  Widget _actionsTab() {
    final settings = context.read<AppSettings>();
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        Text(l.ruleActionsIntro, style: Theme.of(context).textTheme.bodySmall),
        _check(
          const Key('act-move'),
          _moveOn && !_a.delete,
          (v) {
            _moveOn = v;
            if (v) _a = RuleActions(markRead: _a.markRead, flag: _a.flag, stopProcessing: _a.stopProcessing);
          },
          l.ruleMoveTo,
          trailing: _folderButton(_moveTo, l.ruleMoveToTitle, (f) {
            _moveTo = f;
            _moveOn = true;
          }, const Key('act-move-folder')),
        ),
        _check(
          const Key('act-copy'),
          _copyOn,
          (v) => _copyOn = v,
          l.ruleCopyTo,
          trailing: _folderButton(_copyTo, l.ruleCopyToTitle, (f) {
            _copyTo = f;
            _copyOn = true;
          }, const Key('act-copy-folder')),
        ),
        _check(const Key('act-delete'), _a.delete, (v) {
          _a = RuleActions(delete: v, markRead: _a.markRead, flag: _a.flag, stopProcessing: _a.stopProcessing);
          if (v) _moveOn = false;
        }, l.ruleDeleteAction),
        _check(const Key('act-read'), _a.markRead, (v) => _a = _with(markRead: v), l.ruleDescMarkRead),
        _check(const Key('act-flag'), _a.flag, (v) => _a = _with(flag: v), l.ruleFlagAction),
        _check(
          const Key('act-category'),
          _categoryOn,
          (v) => _categoryOn = v,
          l.ruleCategoryAction,
          trailing: DropdownButton<int>(
            key: const Key('act-category-choice'),
            value: _category,
            isDense: true,
            isExpanded: true,
            items: [
              for (var n = 1; n <= 6; n++)
                DropdownMenuItem(
                  value: n,
                  child: Row(
                    children: [
                      CategorySwatch(n),
                      const SizedBox(width: 8),
                      Flexible(child: Text(settings.categoryName(n), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
            ],
            onChanged: (n) => setState(() {
              _category = n ?? 1;
              _categoryOn = true;
            }),
          ),
        ),
        _check(
          const Key('act-stop'),
          _a.stopProcessing,
          (v) => _a = _with(stopProcessing: v),
          l.ruleStopAction,
        ),
      ],
    );
  }

  RuleActions _with({bool? markRead, bool? flag, bool? stopProcessing}) => RuleActions(
    delete: _a.delete,
    markRead: markRead ?? _a.markRead,
    flag: flag ?? _a.flag,
    stopProcessing: stopProcessing ?? _a.stopProcessing,
  );
}

/// "Esegui regole ora" (R3, scelta 8a): regole da eseguire, cartella, sottocartelle e quali mail; poi
/// l'avanzamento nella finestra, con "Interrompi". Lavora sul computer o sul server come le regole sulle mail nuove.
class RunRulesDialog extends StatefulWidget {
  const RunRulesDialog({super.key, required this.api, required this.rules, required this.folders});

  /// Client dell'account.
  final ApiClient api;
  final List<MailRule> rules;
  final List<MailFolder> folders;

  /// Ogni quanto chiedere l'avanzamento al core.
  static const pollInterval = Duration(milliseconds: 500);

  @override
  State<RunRulesDialog> createState() => _RunRulesDialogState();
}

class _RunRulesDialogState extends State<RunRulesDialog> {
  late final _chosen = {for (final r in widget.rules) r.id};
  late String _folder = widget.folders.any((f) => f.fullName == 'INBOX')
      ? 'INBOX'
      : (widget.folders.firstOrNull?.fullName ?? 'INBOX');
  bool _subfolders = false;
  RuleRunFilter _filter = RuleRunFilter.all;

  String? _jobId;
  RuleRunStatus? _status;
  String? _error;
  bool _stopping = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _running => _jobId != null && !(_status?.done ?? false);

  Future<void> _start() async {
    final l = context.l10n;
    setState(() => _error = null);
    try {
      final id = await widget.api.startRulesRun(
        ruleIds: [
          for (final r in widget.rules)
            if (_chosen.contains(r.id)) r.id,
        ],
        folder: _folder,
        includeSubfolders: _subfolders,
        filter: _filter,
      );
      setState(() => _jobId = id);
      _timer = Timer.periodic(RunRulesDialog.pollInterval, (_) => _poll());
    } on ApiException catch (e) {
      setState(() => _error = l.rulesNotRun('${e.fieldErrors['ruleIds']?.first ?? e}'));
    }
  }

  Future<void> _poll() async {
    final id = _jobId;
    if (id == null) return;
    final l = context.l10n;
    try {
      final status = await widget.api.getRulesRun(id);
      if (!mounted) return;
      setState(() => _status = status);
      if (status.done) _timer?.cancel();
    } on ApiException catch (e) {
      _timer?.cancel();
      if (mounted) setState(() => _error = l.progressUnavailable('$e'));
    }
  }

  Future<void> _stop() async {
    final id = _jobId;
    if (id == null) return;
    setState(() => _stopping = true);
    try {
      await widget.api.cancelRulesRun(id);
    } on ApiException {
      // già finita: l'esito arriva con il prossimo avanzamento
    }
  }

  Future<void> _chooseFolder() async {
    final folder = await showDialog<String>(
      context: context,
      builder: (_) =>
          MoveDialog(folders: widget.folders, count: 1, title: context.l10n.runInFolder, message: context.l10n.chooseFolderColon),
    );
    if (folder != null) setState(() => _folder = folder);
  }

  String _outcome(AppLocalizations l, RuleRunStatus s) {
    if (s.error != null) return l.runStoppedError(s.error!);
    final head = s.cancelled ? l.runStoppedChecked(s.checked, s.total) : l.runDoneChecked(s.checked);
    return '${l.runOutcome(head, s.applied)}${s.failed > 0 ? l.runFailedActions(s.failed) : ''}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;
    final started = _jobId != null;
    final done = status?.done ?? false;
    final l = context.l10n;

    return AlertDialog(
      title: Text(l.runRulesNow),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.rulesToRun),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in widget.rules)
                    CheckboxListTile(
                      key: ValueKey('run-rule:${r.id}'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _chosen.contains(r.id),
                      onChanged: started
                          ? null
                          : (v) => setState(() => v == true ? _chosen.add(r.id) : _chosen.remove(r.id)),
                      title: Text(r.name + (r.enabled ? '' : l.ruleDisabledSuffix)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l.runInFolderLabel),
                Flexible(
                  child: TextButton(
                    key: const Key('run-folder'),
                    onPressed: started ? null : _chooseFolder,
                    child: Text(_folder == 'INBOX' ? l.folderInbox : _folder, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              key: const Key('run-subfolders'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _subfolders,
              onChanged: started ? null : (v) => setState(() => _subfolders = v ?? false),
              title: Text(l.includeSubfolders),
            ),
            DropdownButtonFormField<RuleRunFilter>(
              key: const Key('run-filter'),
              initialValue: _filter,
              decoration: InputDecoration(labelText: l.applyRulesTo, isDense: true),
              items: [for (final f in RuleRunFilter.values) DropdownMenuItem(value: f, child: Text(f.label(l)))],
              onChanged: started ? null : (f) => setState(() => _filter = f ?? RuleRunFilter.all),
            ),
            if (started) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: status == null || status.total == 0 ? (done ? 1 : null) : status.checked / status.total,
              ),
              const SizedBox(height: 4),
              Text(
                status == null
                    ? l.preparing
                    : done
                    ? _outcome(l, status)
                    : '${l.runProgress(status.checked, status.total)}${_stopping ? ' · ${l.stopping}' : ''}',
                key: const Key('run-status'),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        if (_running)
          TextButton(onPressed: _stopping ? null : _stop, child: Text(l.stop))
        else
          TextButton(onPressed: () => Navigator.pop(context), child: Text(done ? l.close : l.cancel)),
        if (!started)
          FilledButton(
            key: const Key('run-start'),
            onPressed: _chosen.isEmpty ? null : _start,
            child: Text(l.runNow),
          ),
      ],
    );
  }
}
