/// Scadenze del contrassegno come nel menu "Completa" di Outlook (3.3).
enum FollowUpChoice {
  today('Oggi'),
  tomorrow('Domani'),
  thisWeek('Questa settimana'),
  nextWeek('Settimana prossima'),
  noDate('Nessuna data');

  const FollowUpChoice(this.label);

  final String label;

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

const _days = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];

/// "gio 05/11/2026".
String formatDueDate(DateTime day) =>
    '${_days[day.weekday - 1]} ${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
