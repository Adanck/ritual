import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/daily_record.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/models/routine_schedule.dart';
import 'package:ritual/data/services/storage_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ritual_hive_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('saveRoutines and loadRoutines preserve routine data', () async {
    final routines = [
      Routine(
        id: 'normal',
        name: 'Normal',
        isActive: true,
        schedule: RoutineSchedule.customRange(
          startDateKey: '2026-04-01',
          endDateKey: '2026-04-30',
        ),
        blocks: [
          DayBlock(
            start: '07:00',
            end: '07:45',
            title: 'Ingles',
            description: 'Practica diaria',
            type: BlockType.habit,
            countsTowardProgress: false,
            receivesPushNotification: true,
            isDone: true,
          ),
        ],
      ),
    ];

    await StorageService.saveRoutines(routines);
    final loadedRoutines = await StorageService.loadRoutines();

    expect(loadedRoutines, hasLength(1));
    expect(loadedRoutines.first.id, 'normal');
    expect(loadedRoutines.first.name, 'Normal');
    expect(loadedRoutines.first.isActive, isTrue);
    expect(loadedRoutines.first.schedule.type, RoutineScheduleType.customRange);
    expect(loadedRoutines.first.schedule.startDateKey, '2026-04-01');
    expect(loadedRoutines.first.schedule.endDateKey, '2026-04-30');
    expect(loadedRoutines.first.blocks, hasLength(1));
    expect(loadedRoutines.first.blocks.first.title, 'Ingles');
    expect(loadedRoutines.first.blocks.first.description, 'Practica diaria');
    expect(loadedRoutines.first.blocks.first.type, BlockType.habit);
    expect(loadedRoutines.first.blocks.first.countsTowardProgress, isFalse);
    expect(
      loadedRoutines.first.blocks.first.receivesPushNotification,
      isTrue,
    );
    expect(loadedRoutines.first.blocks.first.isDone, isTrue);
  });

  test('saveDailyRecords and loadDailyRecords preserve daily history', () async {
    final dailyRecords = [
      DailyRecord(
        dateKey: '2026-04-02',
        routineId: 'normal',
        routineName: 'Normal',
        blocks: [
          DayBlock(
            id: 'block-1',
            start: '07:00',
            end: '07:45',
            title: 'Ingles',
            description: 'Practica diaria',
            type: BlockType.habit,
            countsTowardProgress: true,
            receivesPushNotification: true,
            isDone: true,
          ),
        ],
      ),
    ];

    await StorageService.saveDailyRecords(dailyRecords);
    final loadedDailyRecords = await StorageService.loadDailyRecords();

    expect(loadedDailyRecords, hasLength(1));
    expect(loadedDailyRecords.first.dateKey, '2026-04-02');
    expect(loadedDailyRecords.first.routineId, 'normal');
    expect(loadedDailyRecords.first.routineName, 'Normal');
    expect(loadedDailyRecords.first.blocks, hasLength(1));
    expect(loadedDailyRecords.first.blocks.first.id, 'block-1');
    expect(loadedDailyRecords.first.blocks.first.title, 'Ingles');
    expect(
      loadedDailyRecords.first.blocks.first.receivesPushNotification,
      isTrue,
    );
    expect(loadedDailyRecords.first.blocks.first.isDone, isTrue);
  });

  test('saveDatedBlocks and loadDatedBlocks preserve dated events by date', () async {
    final datedBlocks = [
      DatedBlockEntry(
        dateKey: '2026-04-10',
        block: DayBlock(
          id: 'dated-1',
          start: '16:00',
          end: '16:30',
          title: 'Reunion',
          description: 'Llamada puntual del viernes',
          type: BlockType.event,
          countsTowardProgress: false,
          receivesPushNotification: true,
        ),
      ),
    ];

    await StorageService.saveDatedBlocks(datedBlocks);
    final loadedDatedBlocks = await StorageService.loadDatedBlocks();

    expect(loadedDatedBlocks, hasLength(1));
    expect(loadedDatedBlocks.first.dateKey, '2026-04-10');
    expect(loadedDatedBlocks.first.block.id, 'dated-1');
    expect(loadedDatedBlocks.first.block.type, BlockType.event);
    expect(loadedDatedBlocks.first.block.countsTowardProgress, isFalse);
    expect(loadedDatedBlocks.first.block.receivesPushNotification, isTrue);
  });
}
