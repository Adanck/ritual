import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/core/services/notification_service.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/daily_record.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';

void main() {
  test('buildPreviewEntries prioriza el registro real de hoy sobre la plantilla', () {
    final routines = [
      Routine(
        id: 'normal',
        name: 'Normal',
        isActive: true,
        blocks: [
          DayBlock(
            id: 'routine-block',
            start: '09:00',
            end: '09:30',
            title: 'Bloque plantilla',
            type: BlockType.habit,
            receivesPushNotification: true,
          ),
        ],
      ),
    ];

    final dailyRecords = [
      DailyRecord(
        dateKey: '2026-04-06',
        routineId: 'normal',
        routineName: 'Normal',
        blocks: [
          DayBlock(
            id: 'record-block',
            start: '10:00',
            end: '10:30',
            title: 'Bloque real',
            type: BlockType.habit,
            receivesPushNotification: true,
          ),
        ],
      ),
    ];

    final previewEntries = NotificationService.buildPreviewEntries(
      routines: routines,
      dailyRecords: dailyRecords,
      datedBlocks: const [],
      activeRoutineId: 'normal',
      anchorDate: DateTime(2026, 4, 6, 8, 0),
      horizonDays: 0,
    );

    expect(previewEntries, hasLength(1));
    expect(previewEntries.first.sourceKey, 'record:normal:2026-04-06:record-block');
    expect(previewEntries.first.title, 'Bloque real');
  });

  test('buildPreviewEntries mezcla rutina activa y eventos puntuales futuros ordenados', () {
    final routines = [
      Routine(
        id: 'manana',
        name: 'Mañana',
        isActive: true,
        blocks: [
          DayBlock(
            id: 'routine-1',
            start: '09:00',
            end: '09:30',
            title: 'Oración',
            type: BlockType.habit,
            receivesPushNotification: true,
          ),
        ],
      ),
      Routine(
        id: 'otra',
        name: 'Otra',
        isActive: false,
        blocks: [
          DayBlock(
            id: 'routine-2',
            start: '11:00',
            end: '11:30',
            title: 'No debería entrar hoy',
            type: BlockType.commitment,
            receivesPushNotification: true,
          ),
        ],
      ),
    ];

    final datedBlocks = [
      DatedBlockEntry(
        dateKey: '2026-04-07',
        block: DayBlock(
          id: 'dated-1',
          start: '07:30',
          end: '08:00',
          title: 'Cita médica',
          type: BlockType.event,
          receivesPushNotification: true,
        ),
      ),
      DatedBlockEntry(
        dateKey: '2026-04-06',
        block: DayBlock(
          id: 'dated-past',
          start: '07:00',
          end: '07:15',
          title: 'Ya pasó',
          type: BlockType.reminder,
          receivesPushNotification: true,
        ),
      ),
    ];

    final previewEntries = NotificationService.buildPreviewEntries(
      routines: routines,
      dailyRecords: const [],
      datedBlocks: datedBlocks,
      activeRoutineId: 'manana',
      anchorDate: DateTime(2026, 4, 6, 8, 0),
      horizonDays: 1,
    );

    expect(previewEntries, hasLength(4));
    expect(previewEntries[0].sourceKey, 'routine:manana:2026-04-06:routine-1');
    expect(
      previewEntries.map((entry) => entry.sourceKey),
      containsAll([
        'dated:2026-04-07:dated-1',
        'routine:manana:2026-04-07:routine-1',
        'routine:otra:2026-04-07:routine-2',
      ]),
    );
    expect(
      previewEntries[1].sourceKey,
      'dated:2026-04-07:dated-1',
    );
    expect(
      previewEntries.where((entry) => entry.sourceKey.contains('dated-past')),
      isEmpty,
    );
    expect(
      previewEntries.where((entry) => entry.sourceKey.contains('routine-2')),
      isNotEmpty,
    );
  });
}
