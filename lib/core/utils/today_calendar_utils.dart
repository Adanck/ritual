import 'package:flutter/material.dart';
import 'package:ritual/data/models/daily_record.dart';

/// Resumen mensual del calendario para chips e insights rápidos.
class CalendarMonthSummary {
  final int activityDays;
  final int plannedDays;
  final int eventDays;
  final int pushEventDays;
  final int multiRoutineDays;

  const CalendarMonthSummary({
    required this.activityDays,
    required this.plannedDays,
    required this.eventDays,
    required this.pushEventDays,
    required this.multiRoutineDays,
  });
}

/// Reune helpers puros de calendario para la pantalla principal.
///
/// La idea es mantener fuera de `TodayPage` los calculos de fechas, grillas
/// mensuales y pequeños resúmenes que no necesitan conocer detalles de la UI.
class TodayCalendarUtils {
  static DateTime monthAnchor(DateTime todayDate) {
    return DateTime(todayDate.year, todayDate.month);
  }

  static DateTime getMonthStart(DateTime monthDate) {
    return DateTime(monthDate.year, monthDate.month);
  }

  static DateTime getGridStart(DateTime monthDate) {
    final monthStart = getMonthStart(monthDate);
    return monthStart.subtract(Duration(days: monthStart.weekday - 1));
  }

  static List<DateTime> buildGridDays(DateTime monthDate) {
    final gridStart = getGridStart(monthDate);
    return List.generate(42, (index) => gridStart.add(Duration(days: index)));
  }

  static bool isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isFutureCalendarDay({
    required DateTime date,
    required DateTime todayDate,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
    return normalizedDate.isAfter(today);
  }

  static Color getPreviewColor({required bool hasScheduledRoutine}) {
    return hasScheduledRoutine ? const Color(0xFF4DA3FF) : Colors.white54;
  }

  /// Construye un resumen del mes a partir de callbacks de consulta.
  ///
  /// Esto mantiene el helper agnóstico del origen de datos, pero saca el bucle
  /// mensual de la pantalla principal.
  static CalendarMonthSummary buildMonthSummary({
    required DateTime monthDate,
    required DailyRecord? Function(DateTime day) recordForDate,
    required int Function(DateTime day) datedEntriesCountForDate,
    required bool Function(DateTime day) hasPushEnabledDatedEntriesForDate,
    required bool Function(DateTime day) hasCompletedDatedEntriesForDate,
    required int Function(DateTime day) routinesApplyingCountForDate,
    required bool Function(DateTime day) activeRoutineAppliesOnDay,
  }) {
    final monthEnd = DateTime(monthDate.year, monthDate.month + 1, 0);
    final daysInMonth = List.generate(
      monthEnd.day,
      (index) => DateTime(monthDate.year, monthDate.month, index + 1),
    );

    var activityDays = 0;
    var plannedDays = 0;
    var eventDays = 0;
    var pushEventDays = 0;
    var multiRoutineDays = 0;

    for (final day in daysInMonth) {
      final record = recordForDate(day);
      final datedEntriesCount = datedEntriesCountForDate(day);
      final routinesCount = routinesApplyingCountForDate(day);
      final hasScheduledRoutine =
          activeRoutineAppliesOnDay(day) || datedEntriesCount > 0;
      final hasActivity =
          (record?.hasAnyCompletedBlocks ?? false) ||
          hasCompletedDatedEntriesForDate(day);

      if (hasActivity) activityDays += 1;
      if (hasScheduledRoutine) plannedDays += 1;
      if (datedEntriesCount > 0) eventDays += 1;
      if (hasPushEnabledDatedEntriesForDate(day)) pushEventDays += 1;
      if (routinesCount > 1) multiRoutineDays += 1;
    }

    return CalendarMonthSummary(
      activityDays: activityDays,
      plannedDays: plannedDays,
      eventDays: eventDays,
      pushEventDays: pushEventDays,
      multiRoutineDays: multiRoutineDays,
    );
  }
}
