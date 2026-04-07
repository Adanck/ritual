import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/core/utils/today_routine_utils.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/models/routine_schedule.dart';

void main() {
  Routine buildRoutine({
    required String id,
    required RoutineSchedule schedule,
  }) {
    return Routine(
      id: id,
      name: id,
      blocks: [],
      schedule: schedule,
    );
  }

  test('buildScheduleStatus marca recomendada hoy cuando coincide', () {
    final routine = buildRoutine(
      id: 'normal',
      schedule: const RoutineSchedule.always(),
    );

    final status = TodayRoutineUtils.buildScheduleStatus(
      routine: routine,
      todayDate: DateTime(2026, 4, 7),
      suggestedRoutineId: 'normal',
    );

    expect(status.label, 'Recomendada hoy');
    expect(status.color, const Color(0xFF41C47B));
  });

  test('buildScheduleStatus detecta proximidad de inicio', () {
    final routine = buildRoutine(
      id: 'futura',
      schedule: RoutineSchedule.customRange(
        startDateKey: '2026-04-09',
        endDateKey: '2026-04-20',
      ),
    );

    final status = TodayRoutineUtils.buildScheduleStatus(
      routine: routine,
      todayDate: DateTime(2026, 4, 7),
    );

    expect(status.label, 'Empieza en 2 dias');
  });

  test('buildScheduleStatus detecta rango vencido', () {
    final routine = buildRoutine(
      id: 'vieja',
      schedule: RoutineSchedule.customRange(
        startDateKey: '2026-03-01',
        endDateKey: '2026-03-10',
      ),
    );

    final status = TodayRoutineUtils.buildScheduleStatus(
      routine: routine,
      todayDate: DateTime(2026, 4, 7),
    );

    expect(status.label, 'Rango ya vencido');
  });
}
