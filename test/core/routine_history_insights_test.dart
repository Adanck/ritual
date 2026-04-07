import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/core/utils/routine_history_insights.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/daily_record.dart';
import 'package:ritual/data/models/day_block.dart';

void main() {
  DailyRecord buildRecord({
    required String dateKey,
    required bool done,
    bool countsTowardProgress = true,
  }) {
    return DailyRecord(
      dateKey: dateKey,
      routineId: 'normal',
      routineName: 'Normal',
      blocks: [
        DayBlock(
          id: 'block-$dateKey',
          start: '07:00',
          end: '08:00',
          title: 'Bloque',
          type: BlockType.habit,
          countsTowardProgress: countsTowardProgress,
          isDone: done,
        ),
      ],
    );
  }

  test('calculates streak ignoring an incomplete current day', () {
    final insights = RoutineHistoryCalculator.calculate(
      records: [
        buildRecord(dateKey: '2026-03-31', done: true),
        buildRecord(dateKey: '2026-04-01', done: true),
        buildRecord(dateKey: '2026-04-02', done: false),
      ],
      routineId: 'normal',
      today: DateTime(2026, 4, 2),
    );

    expect(insights.currentStreak, 2);
  });

  test('calculates active days, completed blocks and completion rate', () {
    final insights = RoutineHistoryCalculator.calculate(
      records: [
        buildRecord(dateKey: '2026-04-01', done: true),
        buildRecord(dateKey: '2026-04-02', done: false),
      ],
      routineId: 'normal',
      today: DateTime(2026, 4, 2),
    );

    expect(insights.activeDays, 1);
    expect(insights.completedBlocks, 1);
    expect(insights.trackedDays, 2);
    expect(insights.completedDays, 1);
    expect(insights.completionRate, 0.5);
    expect(insights.completedDayRate, 0.5);
    expect(insights.progressBlocksCompleted, 1);
    expect(insights.progressBlocksTracked, 2);
    expect(insights.lastActiveDateKey, '2026-04-01');
  });

  test('returns zero completion rate when no blocks count toward progress', () {
    final insights = RoutineHistoryCalculator.calculate(
      records: [
        buildRecord(
          dateKey: '2026-04-02',
          done: true,
          countsTowardProgress: false,
        ),
      ],
      routineId: 'normal',
      today: DateTime(2026, 4, 2),
    );

    expect(insights.completionRate, 0);
    expect(insights.trackedDays, 0);
    expect(insights.weeklyCompletionRate, 0);
    expect(insights.monthlyCompletionRate, 0);
  });

  test('calculates best streak and rolling weekly monthly completion', () {
    final insights = RoutineHistoryCalculator.calculate(
      records: [
        buildRecord(dateKey: '2026-03-10', done: true),
        buildRecord(dateKey: '2026-03-11', done: true),
        buildRecord(dateKey: '2026-03-12', done: true),
        buildRecord(dateKey: '2026-04-01', done: true),
        buildRecord(dateKey: '2026-04-02', done: false),
        buildRecord(dateKey: '2026-04-03', done: true),
      ],
      routineId: 'normal',
      today: DateTime(2026, 4, 3),
    );

    expect(insights.bestStreak, 3);
    expect(insights.weeklyCompletionRate, closeTo(2 / 3, 0.0001));
    expect(insights.monthlyCompletionRate, closeTo(5 / 6, 0.0001));
  });
}
