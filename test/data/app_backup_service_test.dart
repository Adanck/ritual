import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/data/models/app_settings.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/daily_record.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/models/routine_schedule.dart';
import 'package:ritual/data/services/app_backup_service.dart';

void main() {
  group('AppBackupService', () {
    test('exporta e importa el estado completo preservando relaciones', () {
      final exportData = AppBackupService.export(
        routines: [
          Routine(
            id: 'routine-1',
            name: 'Semana actual',
            isActive: true,
            schedule: RoutineSchedule.currentWeek(
              anchorDate: DateTime(2026, 4, 7),
            ),
            blocks: [
              DayBlock(
                id: 'routine-block-1',
                start: '06:00',
                end: '06:30',
                title: 'Oracion',
                description: 'Silencio y foco',
                type: BlockType.habit,
                receivesPushNotification: true,
              ),
            ],
          ),
        ],
        dailyRecords: [
          DailyRecord(
            dateKey: '2026-04-07',
            routineId: 'routine-1',
            routineName: 'Semana actual',
            blocks: [
              DayBlock(
                id: 'routine-block-1',
                start: '06:00',
                end: '06:30',
                title: 'Oracion',
                description: 'Silencio y foco',
                type: BlockType.habit,
                receivesPushNotification: true,
                isDone: true,
              ),
            ],
          ),
        ],
        datedBlocks: [
          DatedBlockEntry(
            dateKey: '2026-04-09',
            block: DayBlock(
              id: 'dated-1',
              start: '15:00',
              end: '15:30',
              title: 'Reunion',
              description: 'Seguimiento con cliente',
              type: BlockType.event,
              countsTowardProgress: false,
            ),
          ),
        ],
        appSettings: const AppSettings(
          warnOnOverlaps: false,
          autoRequestNotificationPermissions: false,
          notificationHorizonDays: 14,
          showCompletedDatedEventsInUpcoming: false,
        ),
      );

      final imported = AppBackupService.import(exportData.json);

      expect(imported.routineCount, 1);
      expect(imported.dailyRecordCount, 1);
      expect(imported.datedBlockCount, 1);
      expect(imported.routines.single.name, 'Semana actual');
      expect(imported.routines.single.isActive, isTrue);
      expect(imported.dailyRecords.single.blocks.single.isDone, isTrue);
      expect(imported.datedBlocks.single.block.title, 'Reunion');
      expect(imported.appSettings.warnOnOverlaps, isFalse);
      expect(imported.appSettings.notificationHorizonDays, 14);
    });

    test('falla si el backup no trae version valida', () {
      const invalidJson = '{"appSettings":{},"routines":[]}';

      expect(
        () => AppBackupService.import(invalidJson),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('version'),
          ),
        ),
      );
    });
  });
}
