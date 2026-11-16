/// Date, ore e numeri nella lingua dell'app (tappa «Lingua», L5).
///
/// Le forme (ordine di giorno e mese, orologio a 24 o 12 ore) sono testi delle traduzioni (`fmt…` nei file .arb):
/// ogni lingua ha le sue. I nomi di giorni e mesi vengono da `intl` (dati di `flutter_localizations`).
///
/// La lingua è quella dell'app: la imposta `MaterialApp.builder` a ogni cambio (`setFormatLanguage`), così le
/// funzioni di formato si possono chiamare anche fuori dai widget (modelli, PDF). Senza app (alcuni test): italiano.
library;

import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart';

import 'app_localizations.dart';

AppLocalizations _l = lookupAppLocalizations(const Locale('it'));

/// Lingua usata dalle funzioni di formato. La chiama l'app quando la lingua cambia.
void setFormatLanguage(AppLocalizations l) => _l = l;

/// Traduzioni della lingua dei formati (per i testi delle funzioni senza BuildContext).
AppLocalizations get formatL10n => _l;

String _format(String pattern, DateTime d) => DateFormat(pattern, _l.localeName).format(d);

/// Ora: «14:30» / «2:30 PM».
String formatTime(DateTime d) => _format(_l.fmtTime, d);

/// Ora da minuti dopo la mezzanotte (orario lavorativo): 510 → «08:30» / «8:30 AM».
String formatMinutes(int minutes) => formatTime(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));

/// Giorno e mese: «05/11» / «11/5».
String formatDayMonth(DateTime d) => _format(_l.fmtDayMonth, d);

/// Data: «05/11/2026» / «11/5/2026».
String formatDate(DateTime d) => _format(_l.fmtDate, d);

/// Giorno della settimana abbreviato e data: «gio 05/11/2026» / «Thu 11/5/2026».
String formatWeekdayDate(DateTime d) => _format(_l.fmtWeekdayDate, d);

/// Giorno abbreviato, data e ora: «gio 05/11/2026 08:30» / «Thu 11/5/2026 8:30 AM».
String formatWeekdayDateTime(DateTime d) => _format(_l.fmtWeekdayDateTime, d);

/// Giorno abbreviato e ora: «gio 14:30» / «Thu 2:30 PM».
String formatWeekdayTime(DateTime d) => _format(_l.fmtWeekdayTime, d);

/// Data lunga con il giorno e l'ora: «lunedì 9 novembre 2026 10:05» / «Monday, November 9, 2026 10:05 AM».
String formatLongDateTime(DateTime d) => _format(_l.fmtLongDateTime, d);

/// Mese e anno: «novembre 2026» / «November 2026».
String formatMonthYear(DateTime d) => _format(_l.fmtMonthYear, d);

/// Data intera con il giorno: «lunedì 9 novembre 2026» / «Monday, November 9, 2026».
String formatFullDate(DateTime d) => _format(_l.fmtFullDate, d);

/// Ora piena della griglia del calendario: «08:00» / «8 AM».
String formatHour(int hour) => _format(_l.fmtHour, DateTime(2000, 1, 1, hour));

/// Periodo di più giorni, come Outlook: «9 – 13 novembre 2026», «30 novembre – 4 dicembre 2026»
/// / «November 9 – 13, 2026», «November 30 – December 4, 2026».
String formatDayRange(DateTime a, DateTime b) {
  final (start, end) = a.year != b.year
      ? (_l.fmtRangeOtherYearStart, _l.fmtRangeOtherYearEnd)
      : a.month != b.month
      ? (_l.fmtRangeOtherMonthStart, _l.fmtRangeOtherMonthEnd)
      : (_l.fmtRangeSameMonthStart, _l.fmtRangeSameMonthEnd);
  return '${_format(start, a)} – ${_format(end, b)}';
}

/// Nome del giorno (1 = lunedì … 7 = domenica), con l'iniziale come nella lingua: «lunedì» / «Monday».
String weekdayName(int weekday) => DateFormat('EEEE', _l.localeName).format(_weekdayDate(weekday));

/// Nome abbreviato del giorno: «lun» / «Mon».
String weekdayShortName(int weekday) => DateFormat('EEE', _l.localeName).format(_weekdayDate(weekday));

/// Nome del mese (1–12): «novembre» / «November».
String monthName(int month) => DateFormat('MMMM', _l.localeName).format(DateTime(2000, month));

/// Il 3 gennaio 2000 era un lunedì.
DateTime _weekdayDate(int weekday) => DateTime(2000, 1, 2 + weekday);

/// Prima lettera maiuscola («lunedì» → «Lunedì»), per i titoli dei gruppi.
String capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Numero con un decimale nella lingua: «1,4» / «1.4».
String formatOneDecimal(double value) => NumberFormat('0.0', _l.localeName).format(value);

/// Dimensione in megabyte: «1,4 MB» / «1.4 MB».
String formatMegabytes(int bytes) => '${formatOneDecimal(bytes / (1024 * 1024))} MB';
