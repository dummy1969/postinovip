import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';

/// Scadenze del contrassegno come nel menu "Completa" di Outlook (3.3).
enum FollowUpChoice {
  today,
  tomorrow,
  thisWeek,
  nextWeek,
  noDate;

  String label(AppLocalizations l) => switch (this) {
    today => l.today,
    tomorrow => l.followUpTomorrow,
    thisWeek => l.followUpThisWeek,
    nextWeek => l.followUpNextWeek,
    noDate => l.followUpNoDate,
  };

  /// Giorno di scadenza (a mezzanotte, ora locale): "questa settimana" = venerdì (oggi se è già
  /// sabato o domenica), "settimana prossima" = venerdì della settimana dopo; null per [noDate].
  DateTime? dueFrom(DateTime now) {
    DateTime day(int add) => DateTime(now.year, now.month, now.day + add);
    return switch (this) {
      today => day(0),
      tomorrow => day(1),
      thisWeek => day(now.weekday <= DateTime.friday ? DateTime.friday - now.weekday : 0),
      nextWeek => day(7 - now.weekday + DateTime.friday),
      noDate => null,
    };
  }
}

/// "gio 05/11/2026" / "Thu 11/5/2026".
String formatDueDate(DateTime day) => formatWeekdayDate(day);
