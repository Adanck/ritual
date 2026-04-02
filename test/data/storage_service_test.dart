import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
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
        blocks: [
          DayBlock(
            start: '07:00',
            end: '07:45',
            title: 'Ingles',
            description: 'Practica diaria',
            type: BlockType.habit,
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
    expect(loadedRoutines.first.blocks, hasLength(1));
    expect(loadedRoutines.first.blocks.first.title, 'Ingles');
    expect(loadedRoutines.first.blocks.first.description, 'Practica diaria');
    expect(loadedRoutines.first.blocks.first.type, BlockType.habit);
    expect(loadedRoutines.first.blocks.first.isDone, isTrue);
  });
}
