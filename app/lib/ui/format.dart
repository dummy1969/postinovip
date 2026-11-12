const _weekdays = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];

/// Data compatta per la lista, come Outlook: ora se è oggi, giorno abbreviato e ora negli ultimi
/// sette giorni, giorno/mese se è quest'anno, altrimenti data completa.
String formatListDate(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  now ??= DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(date.hour)}:${two(date.minute)}';

  final today = DateTime(now.year, now.month, now.day);
  if (!date.isBefore(today)) return time;
  if (!date.isBefore(today.subtract(const Duration(days: 6)))) {
    return '${_weekdays[date.weekday - 1].substring(0, 3).toLowerCase()} $time';
  }
  if (date.year == now.year) return '${two(date.day)}/${two(date.month)}';
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

/// Gruppo della lista per data, come in Outlook classico: Oggi, Ieri, i giorni di questa settimana
/// (che comincia il lunedì), Settimana scorsa, Due settimane fa, Tre settimane fa, Prima in questo
/// mese, Mese scorso, Più vecchi.
String listGroupLabel(DateTime? date, {DateTime? now}) {
  if (date == null) return 'Senza data';
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final monthStart = DateTime(now.year, now.month);
  final lastMonthStart = DateTime(now.year, now.month - 1);

  if (!date.isBefore(today)) return 'Oggi';
  if (!date.isBefore(today.subtract(const Duration(days: 1)))) return 'Ieri';
  if (!date.isBefore(weekStart)) return _weekdays[date.weekday - 1];
  if (!date.isBefore(weekStart.subtract(const Duration(days: 7)))) return 'Settimana scorsa';
  if (!date.isBefore(weekStart.subtract(const Duration(days: 14)))) return 'Due settimane fa';
  if (!date.isBefore(weekStart.subtract(const Duration(days: 21)))) return 'Tre settimane fa';
  if (!date.isBefore(monthStart)) return 'Prima in questo mese';
  if (!date.isBefore(lastMonthStart)) return 'Mese scorso';
  return 'Più vecchi';
}

/// Momento dell'invio differito (3.8): "gio 05/11/2026 08:30".
String formatSendAfter(DateTime d) {
  const days = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
  String two(int n) => n.toString().padLeft(2, '0');
  return '${days[d.weekday - 1]} ${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Gruppo per dimensione della lista ordinata per "Dimensione" (3.9), con le fasce di Outlook.
String sizeGroupLabel(int? bytes) {
  const kb = 1024;
  final b = bytes ?? 0;
  if (b < 10 * kb) return 'Minuscola (meno di 10 KB)';
  if (b < 25 * kb) return 'Piccola (10–25 KB)';
  if (b < 100 * kb) return 'Media (25–100 KB)';
  if (b < 500 * kb) return 'Grande (100–500 KB)';
  if (b < 1024 * kb) return 'Molto grande (500 KB–1 MB)';
  if (b < 5 * 1024 * kb) return 'Enorme (1–5 MB)';
  return 'Gigantesca (oltre 5 MB)';
}

/// Dimensione nella colonna "Dimensione": "12 KB", "1,4 MB".
String formatMailSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  return '${(bytes / 1024).ceil()} KB';
}
