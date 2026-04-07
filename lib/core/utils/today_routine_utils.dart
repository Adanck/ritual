import 'package:flutter/material.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/models/routine_schedule.dart';

/// Aviso contextual sobre la vigencia o recomendación de una rutina.
class RoutineNotice {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const RoutineNotice({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

/// Helpers puros para sugerencias y avisos de rutinas.
class TodayRoutineUtils {
  static int getSuggestionWeight(Routine routine) {
    switch (routine.schedule.type) {
      case RoutineScheduleType.customRange:
        return 4;
      case RoutineScheduleType.currentWeek:
        return 3;
      case RoutineScheduleType.currentMonth:
        return 2;
      case RoutineScheduleType.always:
        return 1;
    }
  }

  static DateTime? getSuggestionStartDate(Routine routine) {
    final startDateKey = routine.schedule.startDateKey;
    if (startDateKey == null || startDateKey.isEmpty) return null;
    return DateTime.parse(startDateKey);
  }

  static int compareForTodaySuggestion(Routine a, Routine b) {
    final weightComparison =
        getSuggestionWeight(b).compareTo(getSuggestionWeight(a));
    if (weightComparison != 0) return weightComparison;

    final aStart = getSuggestionStartDate(a);
    final bStart = getSuggestionStartDate(b);
    if (aStart != null && bStart != null) {
      final startComparison = bStart.compareTo(aStart);
      if (startComparison != 0) return startComparison;
    } else if (aStart == null && bStart != null) {
      return 1;
    } else if (aStart != null && bStart == null) {
      return -1;
    }

    final blockCountComparison = b.blocks.length.compareTo(a.blocks.length);
    if (blockCountComparison != 0) return blockCountComparison;

    return a.name.compareTo(b.name);
  }

  static List<Routine> getSuggestedForDate({
    required List<Routine> routines,
    required DateTime date,
  }) {
    final suggestedRoutines = routines
        .where((routine) => routine.appliesOn(date))
        .toList()
      ..sort(compareForTodaySuggestion);

    return suggestedRoutines;
  }

  /// Resume el estado temporal actual de una rutina para chips y listas.
  static ({String label, Color color}) buildScheduleStatus({
    required Routine routine,
    required DateTime todayDate,
    String? suggestedRoutineId,
  }) {
    final daysUntilStart = routine.schedule.daysUntilStart(todayDate);
    final daysUntilEnd = routine.schedule.daysUntilEnd(todayDate);

    if (routine.appliesOn(todayDate)) {
      if (suggestedRoutineId == routine.id) {
        return (
          label: 'Recomendada hoy',
          color: const Color(0xFF41C47B),
        );
      }

      if (daysUntilEnd == 0) {
        return (
          label: 'Termina hoy',
          color: const Color(0xFFFFA24D),
        );
      }

      if (daysUntilEnd != null && daysUntilEnd <= 2) {
        return (
          label: 'Termina en $daysUntilEnd dias',
          color: const Color(0xFFFFA24D),
        );
      }

      return (
        label: 'Disponible hoy',
        color: const Color(0xFF4DA3FF),
      );
    }

    if (daysUntilStart == 0) {
      return (
        label: 'Empieza hoy',
        color: const Color(0xFF4DA3FF),
      );
    }

    if (daysUntilStart == 1) {
      return (
        label: 'Empieza manana',
        color: const Color(0xFF4DA3FF),
      );
    }

    if (daysUntilStart != null && daysUntilStart <= 7) {
      return (
        label: 'Empieza en $daysUntilStart dias',
        color: const Color(0xFF4DA3FF),
      );
    }

    if (routine.schedule.hasEndedBy(todayDate)) {
      return (
        label: 'Rango ya vencido',
        color: Colors.white54,
      );
    }

    return (
      label: 'Fuera del rango sugerido',
      color: Colors.white54,
    );
  }

  static List<RoutineNotice> buildActiveRoutineNotices({
    required Routine activeRoutine,
    required List<Routine> routines,
    required DateTime todayDate,
  }) {
    final notices = <RoutineNotice>[];
    final activeSchedule = activeRoutine.schedule;
    final activeDaysUntilEnd = activeSchedule.daysUntilEnd(todayDate);

    if (!activeRoutine.appliesOn(todayDate)) {
      notices.add(
        const RoutineNotice(
          icon: Icons.schedule_send_outlined,
          color: Color(0xFF4DA3FF),
          title: 'Rutina fuera de rango sugerido',
          description:
              'Puedes seguir usandola o editarla, pero hoy no es la rutina sugerida por su vigencia.',
        ),
      );
    } else if (activeDaysUntilEnd == 0) {
      notices.add(
        const RoutineNotice(
          icon: Icons.event_busy_outlined,
          color: Color(0xFFFFA24D),
          title: 'Esta rutina termina hoy',
          description:
              'Si quieres continuar con ella despues, conviene extender su rango o preparar una nueva rutina.',
        ),
      );
    } else if (activeDaysUntilEnd != null && activeDaysUntilEnd <= 2) {
      notices.add(
        RoutineNotice(
          icon: Icons.hourglass_bottom_rounded,
          color: const Color(0xFFFFA24D),
          title: 'Esta rutina esta por terminar',
          description:
              'Su vigencia termina en $activeDaysUntilEnd dias. Puedes dejarla asi o preparar la siguiente.',
        ),
      );
    }

    final upcomingRoutines = routines
        .where((routine) => routine.id != activeRoutine.id)
        .where(
          (routine) => (routine.schedule.daysUntilStart(todayDate) ?? 9999) <= 7,
        )
        .toList()
      ..sort(
        (a, b) => (a.schedule.daysUntilStart(todayDate) ?? 9999)
            .compareTo(b.schedule.daysUntilStart(todayDate) ?? 9999),
      );

    if (upcomingRoutines.isNotEmpty) {
      final nextRoutine = upcomingRoutines.first;
      final daysUntilStart = nextRoutine.schedule.daysUntilStart(todayDate) ?? 0;
      final startText = switch (daysUntilStart) {
        0 => 'hoy',
        1 => 'manana',
        _ => 'en $daysUntilStart dias',
      };

      notices.add(
        RoutineNotice(
          icon: Icons.upcoming_rounded,
          color: const Color(0xFF4DA3FF),
          title: 'Hay otra rutina programada',
          description:
              '"${nextRoutine.name}" empieza $startText. Puedes revisarla desde el selector cuando quieras.',
        ),
      );
    }

    return notices;
  }
}
