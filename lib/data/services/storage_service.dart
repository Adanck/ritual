import 'package:hive/hive.dart';

import '../models/block_type.dart';
import '../models/dated_block_entry.dart';
import '../models/daily_record.dart';
import '../models/day_block.dart';
import '../models/routine.dart';
import '../models/routine_schedule.dart';

/// Encapsula la persistencia local del MVP usando Hive.
class StorageService {
  static const String boxName = 'routines';
  static const String routinesKey = 'routines';
  static const String dailyRecordsKey = 'dailyRecords';
  static const String datedBlocksKey = 'datedBlocks';

  /// Serializa y guarda todas las rutinas.
  static Future<void> saveRoutines(List<Routine> routines) async {
    final box = await Hive.openBox(boxName);

    final data = routines.map((routine) {
      return {
        'id': routine.id,
        'name': routine.name,
        'isActive': routine.isActive,
        'schedule': {
          'type': routine.schedule.type.name,
          'startDateKey': routine.schedule.startDateKey,
          'endDateKey': routine.schedule.endDateKey,
        },
        'blocks': routine.blocks.map((block) {
          return {
            'id': block.id,
            'start': block.start,
            'end': block.end,
            'title': block.title,
            'description': block.description,
            'type': block.type.name,
            'countsTowardProgress': block.countsTowardProgress,
            'receivesPushNotification': block.receivesPushNotification,
            'isDone': block.isDone,
          };
        }).toList(),
      };
    }).toList();

    await box.put(routinesKey, data);
  }

  /// Carga las rutinas guardadas y las reconstruye como objetos de dominio.
  static Future<List<Routine>> loadRoutines() async {
    final box = await Hive.openBox(boxName);
    final data = box.get(routinesKey);

    if (data == null) return [];

    return (data as List).map((item) {
      final scheduleData = item['schedule'];

      return Routine(
        id: item['id'],
        name: item['name'],
        isActive: item['isActive'],
        schedule: scheduleData is Map
            ? RoutineSchedule(
                type: RoutineScheduleType.values.firstWhere(
                  (type) => type.name == scheduleData['type'],
                  orElse: () => RoutineScheduleType.always,
                ),
                startDateKey: scheduleData['startDateKey'],
                endDateKey: scheduleData['endDateKey'],
              )
            : const RoutineSchedule.always(),
        blocks: (item['blocks'] as List).map((block) {
          return DayBlock(
            id: block['id'],
            start: block['start'],
            end: block['end'],
            title: block['title'],
            description: block['description'] ?? '',
            type: BlockType.values.firstWhere(
              (type) => type.name == block['type'],
            ),
            countsTowardProgress: block['countsTowardProgress'] ?? true,
            receivesPushNotification:
                block['receivesPushNotification'] ?? false,
            isDone: block['isDone'],
          );
        }).toList(),
      );
    }).toList();
  }

  /// Serializa y guarda el historial diario independiente de las rutinas.
  static Future<void> saveDailyRecords(List<DailyRecord> dailyRecords) async {
    final box = await Hive.openBox(boxName);

    final data = dailyRecords.map((record) {
      return {
        'dateKey': record.dateKey,
        'routineId': record.routineId,
        'routineName': record.routineName,
        'blocks': record.blocks.map((block) {
          return {
            'id': block.id,
            'start': block.start,
            'end': block.end,
            'title': block.title,
            'description': block.description,
            'type': block.type.name,
            'countsTowardProgress': block.countsTowardProgress,
            'receivesPushNotification': block.receivesPushNotification,
            'isDone': block.isDone,
          };
        }).toList(),
      };
    }).toList();

    await box.put(dailyRecordsKey, data);
  }

  /// Carga el historial diario persistido.
  static Future<List<DailyRecord>> loadDailyRecords() async {
    final box = await Hive.openBox(boxName);
    final data = box.get(dailyRecordsKey);

    if (data == null) return [];

    return (data as List).map((item) {
      return DailyRecord(
        dateKey: item['dateKey'],
        routineId: item['routineId'],
        routineName: item['routineName'],
        blocks: (item['blocks'] as List).map((block) {
          return DayBlock(
            id: block['id'],
            start: block['start'],
            end: block['end'],
            title: block['title'],
            description: block['description'] ?? '',
            type: BlockType.values.firstWhere(
              (type) => type.name == block['type'],
            ),
            countsTowardProgress: block['countsTowardProgress'] ?? true,
            receivesPushNotification:
                block['receivesPushNotification'] ?? false,
            isDone: block['isDone'],
          );
        }).toList(),
      );
    }).toList();
  }

  /// Guarda bloques puntuales asociados a fechas concretas.
  static Future<void> saveDatedBlocks(List<DatedBlockEntry> datedBlocks) async {
    final box = await Hive.openBox(boxName);

    final data = datedBlocks.map((entry) {
      return {
        'dateKey': entry.dateKey,
        'block': {
          'id': entry.block.id,
          'start': entry.block.start,
          'end': entry.block.end,
          'title': entry.block.title,
          'description': entry.block.description,
          'type': entry.block.type.name,
          'countsTowardProgress': entry.block.countsTowardProgress,
          'receivesPushNotification': entry.block.receivesPushNotification,
          'isDone': entry.block.isDone,
        },
      };
    }).toList();

    await box.put(datedBlocksKey, data);
  }

  /// Carga bloques puntuales asociados a una fecha concreta.
  static Future<List<DatedBlockEntry>> loadDatedBlocks() async {
    final box = await Hive.openBox(boxName);
    final data = box.get(datedBlocksKey);

    if (data == null) return [];

    return (data as List).map((item) {
      final block = item['block'];

      return DatedBlockEntry(
        dateKey: item['dateKey'],
        block: DayBlock(
          id: block['id'],
          start: block['start'],
          end: block['end'],
          title: block['title'],
          description: block['description'] ?? '',
          type: BlockType.values.firstWhere(
            (type) => type.name == block['type'],
          ),
          countsTowardProgress: block['countsTowardProgress'] ?? false,
          receivesPushNotification:
              block['receivesPushNotification'] ?? false,
          isDone: block['isDone'],
        ),
      );
    }).toList();
  }
}
