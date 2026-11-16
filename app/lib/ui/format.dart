import '../l10n/formats.dart';

/// Data compatta per la lista, come Outlook: ora se è oggi, giorno abbreviato e ora negli ultimi
/// sette giorni, giorno/mese se è quest'anno, altrimenti data completa. Nella lingua dell'app (L5).
String formatListDate(DateTime? date, {DateTime? now}) {
  if (date == null) return '';
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (!date.isBefore(today)) return formatTime(date);
  if (!date.isBefore(today.subtract(const Duration(days: 6)))) return formatWeekdayTime(date);
  if (date.year == now.year) return formatDayMonth(date);
  return formatDate(date);
}

/// Gruppo della lista per data, come in Outlook classico: Oggi, Ieri, i giorni di questa settimana
/// (che comincia il lunedì), Settimana scorsa, Due settimane fa, Tre settimane fa, Prima in questo
/// mese, Mese scorso, Più vecchi.
String listGroupLabel(DateTime? date, {DateTime? now}) {
  final l = formatL10n;
  if (date == null) return l.groupNoDate;
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final monthStart = DateTime(now.year, now.month);
  final lastMonthStart = DateTime(now.year, now.month - 1);

  if (!date.isBefore(today)) return l.today;
  if (!date.isBefore(today.subtract(const Duration(days: 1)))) return l.groupYesterday;
  if (!date.isBefore(weekStart)) return capitalized(weekdayName(date.weekday));
  if (!date.isBefore(weekStart.subtract(const Duration(days: 7)))) return l.groupLastWeek;
  if (!date.isBefore(weekStart.subtract(const Duration(days: 14)))) return l.groupTwoWeeksAgo;
  if (!date.isBefore(weekStart.subtract(const Duration(days: 21)))) return l.groupThreeWeeksAgo;
  if (!date.isBefore(monthStart)) return l.groupEarlierThisMonth;
  if (!date.isBefore(lastMonthStart)) return l.groupLastMonth;
  return l.groupOlder;
}

/// Momento dell'invio differito (3.8) e data del messaggio: «gio 05/11/2026 08:30» / «Thu 11/5/2026 8:30 AM».
String formatSendAfter(DateTime d) => formatWeekdayDateTime(d);

/// Gruppo per dimensione della lista ordinata per "Dimensione" (3.9), con le fasce di Outlook.
String sizeGroupLabel(int? bytes) {
  final l = formatL10n;
  const kb = 1024;
  final b = bytes ?? 0;
  if (b < 10 * kb) return l.sizeTiny;
  if (b < 25 * kb) return l.sizeSmall;
  if (b < 100 * kb) return l.sizeMedium;
  if (b < 500 * kb) return l.sizeLarge;
  if (b < 1024 * kb) return l.sizeVeryLarge;
  if (b < 5 * 1024 * kb) return l.sizeHuge;
  return l.sizeEnormous;
}

/// Dimensione nella colonna "Dimensione": "12 KB", "1,4 MB".
String formatMailSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes >= 1024 * 1024) return formatMegabytes(bytes);
  return '${(bytes / 1024).ceil()} KB';
}
