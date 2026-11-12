/// Importanza di una mail (P1), come in Outlook: «Priorità alta» o «Priorità bassa». In JSON "normal", "high", "low".
enum MailImportance {
  normal,
  high,
  low;

  static MailImportance fromJson(Object? value) => switch (value) {
    'high' => MailImportance.high,
    'low' => MailImportance.low,
    _ => MailImportance.normal,
  };

  String toJson() => name;
}
