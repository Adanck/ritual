/// Utilidades para convertir fechas a una clave estable `yyyy-MM-dd`.
class DateKey {
  static const List<String> _weekdays = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
    'Domingo',
  ];

  static const List<String> _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static String fromDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  static DateTime toDate(String value) {
    final parts = value.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static String formatForDisplay(String value, {bool includeWeekday = false}) {
    final date = toDate(value);
    final base = '${date.day} ${_months[date.month - 1]} ${date.year}';

    if (!includeWeekday) return base;
    return '${_weekdays[date.weekday - 1]}, $base';
  }

  static String formatShort(String value) {
    final date = toDate(value);
    return '${date.day} ${_months[date.month - 1]}';
  }

  static String formatRange(String startDateKey, String? endDateKey) {
    if (endDateKey == null || endDateKey == startDateKey) {
      return formatForDisplay(startDateKey);
    }

    return '${formatShort(startDateKey)} - ${formatForDisplay(endDateKey)}';
  }
}
