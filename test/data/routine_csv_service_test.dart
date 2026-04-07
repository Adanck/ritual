import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/models/routine_schedule.dart';
import 'package:ritual/data/services/routine_csv_service.dart';

void main() {
  group('RoutineCsvService', () {
    test('exporta e importa rutinas preservando campos relevantes', () {
      final routines = [
        Routine(
          id: 'routine-1',
          name: 'Semana sobria',
          isActive: true,
          schedule: const RoutineSchedule(
            type: RoutineScheduleType.customRange,
            startDateKey: '2026-04-07',
            endDateKey: '2026-04-14',
          ),
          blocks: [
            DayBlock(
              id: 'block-1',
              start: '06:30',
              end: '07:00',
              title: 'Oracion',
              description: 'Silencio, cafe y libreta',
              type: BlockType.habit,
              countsTowardProgress: true,
              receivesPushNotification: true,
            ),
            DayBlock(
              id: 'block-2',
              start: '13:30',
              end: '14:00',
              title: 'Almuerzo',
              description: 'Ligero',
              type: BlockType.visual,
              countsTowardProgress: false,
              receivesPushNotification: false,
            ),
          ],
        ),
      ];

      final exported = RoutineCsvService.exportRoutines(routines);
      final imported = RoutineCsvService.importRoutines(exported.csv);

      expect(exported.routineCount, 1);
      expect(exported.blockCount, 2);
      expect(imported.routineCount, 1);
      expect(imported.blockCount, 2);

      final importedRoutine = imported.routines.single;
      expect(importedRoutine.name, 'Semana sobria');
      expect(importedRoutine.isActive, isTrue);
      expect(
        importedRoutine.schedule.type,
        RoutineScheduleType.customRange,
      );
      expect(importedRoutine.schedule.startDateKey, '2026-04-07');
      expect(importedRoutine.schedule.endDateKey, '2026-04-14');
      expect(importedRoutine.blocks, hasLength(2));
      expect(importedRoutine.blocks.first.start, '06:30');
      expect(importedRoutine.blocks.first.receivesPushNotification, isTrue);
      expect(importedRoutine.blocks.last.countsTowardProgress, isFalse);
    });

    test('soporta rutinas sin bloques para no perder la biblioteca', () {
      final routines = [
        Routine(
          id: 'routine-empty',
          name: 'Solo estructura',
          blocks: const [],
          schedule: const RoutineSchedule.always(),
        ),
      ];

      final exported = RoutineCsvService.exportRoutines(routines);
      final imported = RoutineCsvService.importRoutines(exported.csv);

      expect(imported.routineCount, 1);
      expect(imported.blockCount, 0);
      expect(imported.routines.single.name, 'Solo estructura');
      expect(imported.routines.single.blocks, isEmpty);
    });

    test('falla si un bloque viene incompleto desde Excel', () {
      const csv = '''
routine_id,routine_name,routine_is_active,schedule_type,schedule_start_date,schedule_end_date,block_id,block_start,block_end,block_title,block_description,block_type,counts_toward_progress,receives_push_notification
routine-1,Rutina rota,false,always,,,,06:00,,Bloque sin cierre,,habit,true,false
''';

      expect(
        () => RoutineCsvService.importRoutines(csv),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('bloque incompleto'),
          ),
        ),
      );
    });

    test('soporta texto con comas y saltos de linea', () {
      final routines = [
        Routine(
          id: 'routine-quoted',
          name: 'Lectura profunda',
          blocks: [
            DayBlock(
              id: 'block-quoted',
              start: '20:00',
              end: '20:45',
              title: 'Resumen',
              description: 'Anotar ideas, dudas y cierre\nsin perder contexto',
              type: BlockType.commitment,
            ),
          ],
        ),
      ];

      final exported = RoutineCsvService.exportRoutines(routines);
      final imported = RoutineCsvService.importRoutines(exported.csv);

      expect(
        imported.routines.single.blocks.single.description,
        'Anotar ideas, dudas y cierre\nsin perder contexto',
      );
    });
  });
}
