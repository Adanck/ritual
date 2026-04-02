import 'package:ritual/core/utils/date_key.dart';

/// Define durante que periodo una rutina debe considerarse vigente.
///
/// La intencion es separar el "tipo" de programacion elegido por el usuario
/// de la evaluacion concreta sobre una fecha. Asi la UI puede ofrecer atajos
/// como "semana actual" o "mes actual", pero el dominio siempre termina con
/// un rango de fechas claro.
enum RoutineScheduleType {
  always,
  currentWeek,
  currentMonth,
  customRange,
}

/// Configuracion temporal de una rutina.
///
/// Para los tipos basados en rango guardamos `startDateKey` y `endDateKey`
/// normalizados a `yyyy-MM-dd`. `endDateKey` es opcional para soportar rutinas
/// que empiezan en una fecha concreta y permanecen vigentes indefinidamente.
class RoutineSchedule {
  final RoutineScheduleType type;
  final String? startDateKey;
  final String? endDateKey;

  const RoutineSchedule({
    required this.type,
    this.startDateKey,
    this.endDateKey,
  });

  const RoutineSchedule.always()
      : type = RoutineScheduleType.always,
        startDateKey = null,
        endDateKey = null;

  factory RoutineSchedule.currentWeek({DateTime? anchorDate}) {
    final anchor = _normalize(anchorDate ?? DateTime.now());
    final start = anchor.subtract(
      Duration(days: anchor.weekday - DateTime.monday),
    );
    final end = start.add(const Duration(days: 6));

    return RoutineSchedule(
      type: RoutineScheduleType.currentWeek,
      startDateKey: DateKey.fromDate(start),
      endDateKey: DateKey.fromDate(end),
    );
  }

  factory RoutineSchedule.currentMonth({DateTime? anchorDate}) {
    final anchor = _normalize(anchorDate ?? DateTime.now());
    final start = DateTime(anchor.year, anchor.month, 1);
    final end = DateTime(anchor.year, anchor.month + 1, 0);

    return RoutineSchedule(
      type: RoutineScheduleType.currentMonth,
      startDateKey: DateKey.fromDate(start),
      endDateKey: DateKey.fromDate(end),
    );
  }

  factory RoutineSchedule.customRange({
    required String startDateKey,
    String? endDateKey,
  }) {
    return RoutineSchedule(
      type: RoutineScheduleType.customRange,
      startDateKey: startDateKey,
      endDateKey: endDateKey,
    );
  }

  RoutineSchedule copyWith({
    RoutineScheduleType? type,
    String? startDateKey,
    String? endDateKey,
    bool clearEndDate = false,
  }) {
    return RoutineSchedule(
      type: type ?? this.type,
      startDateKey: startDateKey ?? this.startDateKey,
      endDateKey: clearEndDate ? null : endDateKey ?? this.endDateKey,
    );
  }

  /// Determina si la rutina aplica para la fecha consultada.
  ///
  /// Regla: para un rango abierto solo validamos que la fecha no sea anterior
  /// al inicio. Caso borde: si falta la fecha de inicio en un tipo que deberia
  /// tener rango, devolvemos `false` para evitar asumir vigencias invalidas.
  bool appliesTo(DateTime date) {
    if (type == RoutineScheduleType.always) return true;
    if (startDateKey == null) return false;

    final normalizedDate = _normalize(date);
    final start = DateKey.toDate(startDateKey!);

    if (normalizedDate.isBefore(start)) return false;
    if (endDateKey == null) return true;

    final end = DateKey.toDate(endDateKey!);
    return !normalizedDate.isAfter(end);
  }

  /// Texto corto para superficies compactas como chips y listas.
  String get shortLabel {
    switch (type) {
      case RoutineScheduleType.always:
        return 'Siempre';
      case RoutineScheduleType.currentWeek:
        return 'Semana actual';
      case RoutineScheduleType.currentMonth:
        return 'Mes actual';
      case RoutineScheduleType.customRange:
        return 'Rango personalizado';
    }
  }

  /// Texto mas expresivo para ayudar al usuario a entender la vigencia exacta.
  String get displayLabel {
    switch (type) {
      case RoutineScheduleType.always:
        return 'Siempre disponible';
      case RoutineScheduleType.currentWeek:
        return 'Semana actual | ${DateKey.formatRange(startDateKey!, endDateKey)}';
      case RoutineScheduleType.currentMonth:
        return 'Mes actual | ${DateKey.formatRange(startDateKey!, endDateKey)}';
      case RoutineScheduleType.customRange:
        if (startDateKey == null) return 'Rango personalizado';
        if (endDateKey == null) {
          return 'Desde ${DateKey.formatForDisplay(startDateKey!)}';
        }
        return DateKey.formatRange(startDateKey!, endDateKey);
    }
  }

  static DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
