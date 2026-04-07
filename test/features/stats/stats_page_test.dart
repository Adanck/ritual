import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/daily_record.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/models/routine_schedule.dart';
import 'package:ritual/features/stats/stats_page.dart';

void main() {
  testWidgets('StatsPage muestra resumen y lista rutinas filtrables', (
    WidgetTester tester,
  ) async {
    final routines = [
      Routine(
        id: 'normal',
        name: 'Normal',
        isActive: true,
        schedule: const RoutineSchedule.always(),
        blocks: [
          DayBlock(
            id: 'block-1',
            start: '07:00',
            end: '08:00',
            title: 'Ingles',
            type: BlockType.habit,
          ),
        ],
      ),
      Routine(
        id: 'vacaciones',
        name: 'Vacaciones',
        schedule: RoutineSchedule.customRange(
          startDateKey: '2026-04-10',
          endDateKey: '2026-04-20',
        ),
        blocks: [
          DayBlock(
            id: 'block-2',
            start: '09:00',
            end: '10:00',
            title: 'Lectura',
            type: BlockType.habit,
          ),
        ],
      ),
    ];

    final records = [
      DailyRecord(
        dateKey: '2026-04-06',
        routineId: 'normal',
        routineName: 'Normal',
        blocks: [
          DayBlock(
            id: 'block-1',
            start: '07:00',
            end: '08:00',
            title: 'Ingles',
            type: BlockType.habit,
            isDone: true,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: StatsPage(
          routines: routines,
          dailyRecords: records,
          todayDate: DateTime(2026, 4, 7),
          activeRoutineId: 'normal',
          suggestedRoutineId: 'normal',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estadisticas'), findsOneWidget);
    expect(find.text('Vision general'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Vacaciones'), findsOneWidget);

    final proximasFinder = find.text('Proximas');
    await tester.ensureVisible(proximasFinder);
    await tester.pumpAndSettle();
    await tester.tap(proximasFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Vacaciones'), findsOneWidget);
  });
}
