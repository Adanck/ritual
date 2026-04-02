import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/data/models/routine_schedule.dart';

void main() {
  test('always schedule applies to any day', () {
    const schedule = RoutineSchedule.always();

    expect(schedule.appliesTo(DateTime(2026, 4, 2)), isTrue);
    expect(schedule.appliesTo(DateTime(2027, 1, 1)), isTrue);
  });

  test('current week uses the full week around the anchor date', () {
    final schedule = RoutineSchedule.currentWeek(
      anchorDate: DateTime(2026, 4, 2),
    );

    expect(schedule.startDateKey, '2026-03-30');
    expect(schedule.endDateKey, '2026-04-05');
    expect(schedule.appliesTo(DateTime(2026, 4, 4)), isTrue);
    expect(schedule.appliesTo(DateTime(2026, 4, 6)), isFalse);
  });

  test('custom range supports open ended schedules', () {
    final schedule = RoutineSchedule.customRange(
      startDateKey: '2026-04-10',
    );

    // Regla: un rango abierto sigue vigente desde la fecha de inicio.
    expect(schedule.appliesTo(DateTime(2026, 4, 9)), isFalse);
    expect(schedule.appliesTo(DateTime(2026, 4, 10)), isTrue);
    expect(schedule.appliesTo(DateTime(2026, 5, 1)), isTrue);
  });

  test('daysUntilStart reports upcoming scheduled routines', () {
    final schedule = RoutineSchedule.customRange(
      startDateKey: '2026-04-10',
      endDateKey: '2026-04-20',
    );

    expect(schedule.daysUntilStart(DateTime(2026, 4, 7)), 3);
    expect(schedule.daysUntilStart(DateTime(2026, 4, 10)), isNull);
  });

  test('daysUntilEnd reports remaining validity days', () {
    final schedule = RoutineSchedule.customRange(
      startDateKey: '2026-04-10',
      endDateKey: '2026-04-20',
    );

    expect(schedule.daysUntilEnd(DateTime(2026, 4, 18)), 2);
    expect(schedule.daysUntilEnd(DateTime(2026, 4, 21)), isNull);
  });
}
