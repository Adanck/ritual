import 'date_key.dart';
import 'package:ritual/data/models/daily_record.dart';

/// Agrupa las metricas basicas derivadas del historial de una rutina.
class RoutineHistoryInsights {
  final int currentStreak;
  final int bestStreak;
  final int activeDays;
  final int trackedDays;
  final int completedDays;
  final int completedBlocks;
  final int progressBlocksCompleted;
  final int progressBlocksTracked;
  final double completionRate;
  final double completedDayRate;
  final double weeklyCompletionRate;
  final double monthlyCompletionRate;
  final String? lastActiveDateKey;

  const RoutineHistoryInsights({
    required this.currentStreak,
    required this.bestStreak,
    required this.activeDays,
    required this.trackedDays,
    required this.completedDays,
    required this.completedBlocks,
    required this.progressBlocksCompleted,
    required this.progressBlocksTracked,
    required this.completionRate,
    required this.completedDayRate,
    required this.weeklyCompletionRate,
    required this.monthlyCompletionRate,
    required this.lastActiveDateKey,
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

    // Regla: las ventanas de 7 y 30 dias usan solo dias con bloques que
    // cuentan para progreso. Asi la comparacion temporal no se contamina con
    // dias meramente informativos.
    final weeklyRecords = _filterRecordsWithinWindow(
      records: trackedRecords,
      endDate: today ?? DateTime.now(),
      days: 7,
    );
    final monthlyRecords = _filterRecordsWithinWindow(
      records: trackedRecords,
      endDate: today ?? DateTime.now(),
      days: 30,
    );

    return RoutineHistoryInsights(
      currentStreak: _calculateCurrentStreak(
        records: trackedRecords,
        today: today ?? DateTime.now(),
      ),
      bestStreak: _calculateBestStreak(records: trackedRecords),
      activeDays:
          filteredRecords.where((record) => record.hasAnyCompletedBlocks).length,
      trackedDays: trackedRecords.length,
      completedDays:
          trackedRecords.where((record) => record.isCompletedDay).length,
      completedBlocks:
          filteredRecords.fold<int>(0, (total, record) => total + record.completedBlocksCount),
      progressBlocksCompleted: totalCompletedProgressBlocks,
      progressBlocksTracked: totalEligibleBlocks,
      completionRate: totalEligibleBlocks == 0
          ? 0
          : totalCompletedProgressBlocks / totalEligibleBlocks,
      completedDayRate: trackedRecords.isEmpty
          ? 0
          : trackedRecords.where((record) => record.isCompletedDay).length /
              trackedRecords.length,
      weeklyCompletionRate: _calculateWindowCompletionRate(weeklyRecords),
      monthlyCompletionRate: _calculateWindowCompletionRate(monthlyRecords),
      lastActiveDateKey: _findLastActiveDateKey(filteredRecords),
    );
  }

  static List<DailyRecord> _filterRecordsWithinWindow({
    required List<DailyRecord> records,
    required DateTime endDate,
    required int days,
  }) {
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);
    final windowStart = normalizedEnd.subtract(Duration(days: days - 1));

    return records.where((record) {
      final recordDate = DateKey.toDate(record.dateKey);
      return !recordDate.isBefore(windowStart) && !recordDate.isAfter(normalizedEnd);
    }).toList();
  }

  static double _calculateWindowCompletionRate(List<DailyRecord> records) {
    final progressTracked = records.fold<int>(
      0,
      (total, record) => total + record.progressEligibleBlocksCount,
    );
    if (progressTracked == 0) return 0;

    final progressCompleted = records.fold<int>(
      0,
      (total, record) => total + record.completedProgressBlocksCount,
    );

    return progressCompleted / progressTracked;
  }

  static String? _findLastActiveDateKey(List<DailyRecord> records) {
    for (final record in records.reversed) {
      if (record.hasAnyCompletedBlocks) return record.dateKey;
    }
    return null;
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

  static int _calculateBestStreak({
    required List<DailyRecord> records,
  }) {
    if (records.isEmpty) return 0;

    final completedDates = records
        .where((record) => record.isCompletedDay)
        .map((record) => DateKey.toDate(record.dateKey))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    if (completedDates.isEmpty) return 0;

    var best = 1;
    var current = 1;

    for (var index = 1; index < completedDates.length; index += 1) {
      final previous = completedDates[index - 1];
      final currentDate = completedDates[index];

      // Regla: solo extendemos la racha maxima si los dias completos fueron
      // consecutivos. Un hueco reinicia el conteo historico.
      if (currentDate.difference(previous).inDays == 1) {
        current += 1;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }

    return best;
  }
}
