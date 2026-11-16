/// Regole (R1/R2): stesse strutture del core (`Rules/MailRule.cs`), JSON con gli stessi nomi.
library;

import '../l10n/app_localizations.dart';

List<String>? _words(Object? json) => json is List ? [for (final w in json) w as String] : null;

/// Condizioni: tutte quelle indicate devono valere (AND); dentro una condizione basta una parola (OR).
class RuleConditions {
  const RuleConditions({
    this.from,
    this.toOrCc,
    this.sentOnlyToMe = false,
    this.meInTo = false,
    this.meInCc = false,
    this.subjectContains,
    this.subjectOrBodyContains,
    this.hasAttachments = false,
    this.sizeGreaterThanKb,
  });

  final List<String>? from;
  final List<String>? toOrCc;
  final bool sentOnlyToMe;
  final bool meInTo;
  final bool meInCc;
  final List<String>? subjectContains;
  final List<String>? subjectOrBodyContains;
  final bool hasAttachments;
  final int? sizeGreaterThanKb;

  static bool _empty(List<String>? words) => words == null || words.every((w) => w.trim().isEmpty);

  bool get isEmpty =>
      _empty(from) &&
      _empty(toOrCc) &&
      !sentOnlyToMe &&
      !meInTo &&
      !meInCc &&
      _empty(subjectContains) &&
      _empty(subjectOrBodyContains) &&
      !hasAttachments &&
      sizeGreaterThanKb == null;

  factory RuleConditions.fromJson(Map<String, dynamic> json) => RuleConditions(
    from: _words(json['from']),
    toOrCc: _words(json['toOrCc']),
    sentOnlyToMe: json['sentOnlyToMe'] as bool? ?? false,
    meInTo: json['meInTo'] as bool? ?? false,
    meInCc: json['meInCc'] as bool? ?? false,
    subjectContains: _words(json['subjectContains']),
    subjectOrBodyContains: _words(json['subjectOrBodyContains']),
    hasAttachments: json['hasAttachments'] as bool? ?? false,
    sizeGreaterThanKb: json['sizeGreaterThanKb'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'from': ?from,
    'toOrCc': ?toOrCc,
    'sentOnlyToMe': sentOnlyToMe,
    'meInTo': meInTo,
    'meInCc': meInCc,
    'subjectContains': ?subjectContains,
    'subjectOrBodyContains': ?subjectOrBodyContains,
    'hasAttachments': hasAttachments,
    'sizeGreaterThanKb': ?sizeGreaterThanKb,
  };
}

/// Azioni (niente "inoltra"; "elimina" = in Posta eliminata).
class RuleActions {
  const RuleActions({
    this.moveTo,
    this.copyTo,
    this.delete = false,
    this.markRead = false,
    this.flag = false,
    this.category,
    this.stopProcessing = false,
  });

  final String? moveTo;
  final String? copyTo;
  final bool delete;
  final bool markRead;
  final bool flag;
  final int? category;
  final bool stopProcessing;

  bool get isEmpty => moveTo == null && copyTo == null && !delete && !markRead && !flag && category == null;

  factory RuleActions.fromJson(Map<String, dynamic> json) => RuleActions(
    moveTo: json['moveTo'] as String?,
    copyTo: json['copyTo'] as String?,
    delete: json['delete'] as bool? ?? false,
    markRead: json['markRead'] as bool? ?? false,
    flag: json['flag'] as bool? ?? false,
    category: json['category'] as int?,
    stopProcessing: json['stopProcessing'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'moveTo': ?moveTo,
    'copyTo': ?copyTo,
    'delete': delete,
    'markRead': markRead,
    'flag': flag,
    'category': ?category,
    'stopProcessing': stopProcessing,
  };
}

/// "Esegui regole ora" (R3): su quali mail della cartella.
enum RuleRunFilter {
  all('All'),
  read('Read'),
  unread('Unread');

  const RuleRunFilter(this.coreName);

  final String coreName;

  String label(AppLocalizations l) => switch (this) {
    all => l.runFilterAll,
    read => l.runFilterRead,
    unread => l.runFilterUnread,
  };
}

/// Avanzamento di "Esegui regole ora" (GET …/rules/run/{id}).
class RuleRunStatus {
  const RuleRunStatus({
    required this.checked,
    required this.total,
    required this.applied,
    required this.failed,
    required this.done,
    required this.cancelled,
    this.error,
  });

  final int checked;
  final int total;
  final int applied;
  final int failed;
  final bool done;
  final bool cancelled;
  final String? error;

  factory RuleRunStatus.fromJson(Map<String, dynamic> json) => RuleRunStatus(
    checked: json['checked'] as int? ?? 0,
    total: json['total'] as int? ?? 0,
    applied: json['applied'] as int? ?? 0,
    failed: json['failed'] as int? ?? 0,
    done: json['done'] as bool? ?? false,
    cancelled: json['cancelled'] as bool? ?? false,
    error: json['error'] as String?,
  );
}

class MailRule {
  const MailRule({
    this.id = '',
    required this.name,
    this.enabled = true,
    this.conditions = const RuleConditions(),
    this.exceptions,
    this.actions = const RuleActions(),
  });

  /// Vuoto per una regola nuova: l'id lo dà il core al salvataggio.
  final String id;
  final String name;
  final bool enabled;
  final RuleConditions conditions;
  final RuleConditions? exceptions;
  final RuleActions actions;

  MailRule copyWith({String? name, bool? enabled}) => MailRule(
    id: id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    conditions: conditions,
    exceptions: exceptions,
    actions: actions,
  );

  factory MailRule.fromJson(Map<String, dynamic> json) => MailRule(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    conditions: RuleConditions.fromJson(json['conditions'] as Map<String, dynamic>? ?? const {}),
    exceptions: json['exceptions'] is Map<String, dynamic>
        ? RuleConditions.fromJson(json['exceptions'] as Map<String, dynamic>)
        : null,
    actions: RuleActions.fromJson(json['actions'] as Map<String, dynamic>? ?? const {}),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'conditions': conditions.toJson(),
    'exceptions': exceptions?.toJson(),
    'actions': actions.toJson(),
  };
}
