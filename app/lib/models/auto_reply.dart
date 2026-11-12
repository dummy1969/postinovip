/// Risposte automatiche di un account (GET/PUT …/autoreply): stesse impostazioni della finestra di Outlook.
class AutoReplySettings {
  const AutoReplySettings({
    this.enabled = false,
    this.start,
    this.end,
    this.html = '',
    this.text = '',
    this.document,
    this.active = false,
  });

  final bool enabled;

  /// "Invia solo durante questo intervallo di tempo": null = sempre.
  final DateTime? start;
  final DateTime? end;
  final String html;
  final String text;

  /// Documento dell'editor (JSON del Delta), per riaprire il messaggio senza perdite.
  final String? document;

  /// Secondo il core: si inviano adesso.
  final bool active;

  /// Si inviano in questo momento (calcolato qui, così la barra gialla segue l'orologio).
  bool activeAt(DateTime now) =>
      enabled && (start == null || !now.isBefore(start!)) && (end == null || now.isBefore(end!));

  factory AutoReplySettings.fromJson(Map<String, dynamic> json) => AutoReplySettings(
    enabled: json['enabled'] as bool? ?? false,
    start: json['start'] == null ? null : DateTime.parse(json['start'] as String).toLocal(),
    end: json['end'] == null ? null : DateTime.parse(json['end'] as String).toLocal(),
    html: json['html'] as String? ?? '',
    text: json['text'] as String? ?? '',
    document: json['document'] as String?,
    active: json['active'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'start': start?.toUtc().toIso8601String(),
    'end': end?.toUtc().toIso8601String(),
    'html': html,
    'text': text,
    'document': document,
  };

  AutoReplySettings copyWith({bool? enabled}) => AutoReplySettings(
    enabled: enabled ?? this.enabled,
    start: start,
    end: end,
    html: html,
    text: text,
    document: document,
  );
}
