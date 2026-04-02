import 'date_key.dart';
import 'package:ritual/data/models/daily_record.dart';

/// Agrupa las metricas basicas derivadas del historial de una rutina.
class RoutineHistoryInsights {
  final int currentStreak;
  final int activeDays;
  final int trackedDays;
  final int completedDays;
  final int completedBlocks;
  final double completionRate;

  const RoutineHistoryInsights({
    required this.currentStreak,
    required this.activeDays,
    required this.trackedDays,
    required this.completedDays,
    required this.completedBlocks,
    required this.completionRate,
  });
}

/// Calcula rachas y estadisticas simples a partir del historial.
class RoutineHistoryCalculator {
  static RoutineHistoryInsights calculate({
    required List<DailyRecord> records,
    required String routineId,
    DateTime? today,
  }) {
    final filteredRecords =
        records.where((record) => record.routineId == routineId).toList()
          ..sort(
            (a, b) => DateKey.toDate(a.dateKey).compareTo(DateKey.toDate(b.dateKey)),
          );

    final trackedRecords = filteredRecords
        .where((record) => record.progressEligibleBlocksCount > 0)
        .toList();

    final totalEligibleBlocks = trackedRecords.fold<int>(
      0,
      (total, record) => total + record.progressEligibleBlocksCount,
    );

    final totalCompletedProgressBlocks = trackedRecords.fold<int>(
      0,
      (total, record) => total + record.completedProgressBlocksCount,
    );

    return RoutineHistoryInsights(
      currentStreak: _calculateCurrentStreak(
        records: trackedRecords,
        today: today ?? DateTime.now(),
      ),
      activeDays:
          filteredRecords.where((record) => record.hasAnyCompletedBlocks).length,
      trackedDays: trackedRecords.length,
      completedDays:
          trackedRecords.where((record) => record.isCompletedDay).length,
      completedBlocks:
          filteredRecords.fold<int>(0, (total, record) => total + record.completedBlocksCount),
      completionRate: totalEligibleBlocks == 0
          ? 0
          : totalCompletedProgressBlocks / totalEligibleBlocks,
    );
  }

  static int _calculateCurrentStreak({
    required List<DailyRecord> records,
    required DateTime today,
  }) {
    final completedKeys = records
        .where((record) => record.isCompletedDay)
        .map((record) => record.dateKey)
        .toSet();

    var cursor = DateTime(today.year, today.month, today.day);
    final todayKey = DateKey.fromDate(cursor);

    // Caso borde: si el dia actual aun no esta completo, no rompemos la racha
    // por estar a mitad del dia; empezamos a revisar desde ayer.
    if (!completedKeys.contains(todayKey)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;

    while (completedKeys.contains(DateKey.fromDate(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }
}
