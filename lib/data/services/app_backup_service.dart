import 'dart:convert';

import 'package:ritual/data/models/app_settings.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/daily_record.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/models/routine_schedule.dart';

/// Version actual del formato de backup completo.
const int currentAppBackupVersion = 1;

/// Resultado listo para mostrar cuando se exporta un backup completo.
class AppBackupExportData {
  final String json;
  final int routineCount;
  final int dailyRecordCount;
  final int datedBlockCount;

  const AppBackupExportData({
    required this.json,
    required this.routineCount,
    required this.dailyRecordCount,
    required this.datedBlockCount,
  });
}

/// Estado completo reconstruido desde un backup importado.
class AppBackupImportData {
  final List<Routine> routines;
  final List<DailyRecord> dailyRecords;
  final List<DatedBlockEntry> datedBlocks;
  final AppSettings appSettings;

  const AppBackupImportData({
    required this.routines,
    required this.dailyRecords,
    required this.datedBlocks,
    required this.appSettings,
  });

  int get routineCount => routines.length;
  int get dailyRecordCount => dailyRecords.length;
  int get datedBlockCount => datedBlocks.length;
}

/// Exporta e importa un respaldo completo de Ritual en JSON.
///
/// A diferencia del CSV de rutinas, este formato conserva relaciones internas
/// entre biblioteca, historial, eventos puntuales y ajustes globales.
class AppBackupService {
  /// Serializa el estado completo de la app en un JSON versionado.
  static AppBackupExportData export({
    required List<Routine> routines,
    required List<DailyRecord> dailyRecords,
    required List<DatedBlockEntry> datedBlocks,
    required AppSettings appSettings,
  }) {
    final payload = {
      'version': currentAppBackupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appSettings': _appSettingsToMap(appSettings),
      'routines': routines.map(_routineToMap).toList(),
      'dailyRecords': dailyRecords.map(_dailyRecordToMap).toList(),
      'datedBlocks': datedBlocks.map(_datedBlockToMap).toList(),
    };

    return AppBackupExportData(
      json: const JsonEncoder.withIndent('  ').convert(payload),
      routineCount: routines.length,
      dailyRecordCount: dailyRecords.length,
      datedBlockCount: datedBlocks.length,
    );
  }

  /// Reconstruye el estado completo desde JSON.
  ///
  /// Regla: exigimos un objeto versionado para no aceptar pegados ambiguos.
  /// Caso borde: si faltan listas, las tratamos como vacias para soportar
  /// backups antiguos o minimos sin romper la importacion completa.
  static AppBackupImportData import(String jsonSource) {
    final decoded = json.decode(jsonSource);
    if (decoded is! Map) {
      throw const FormatException(
        'El backup no es un objeto JSON valido.',
      );
    }

    final version = decoded['version'];
    if (version is! int) {
      throw const FormatException(
        'El backup no incluye una version valida.',
      );
    }

    if (version > currentAppBackupVersion) {
      throw FormatException(
        'Este backup usa una version futura ($version) que Ritual todavia no entiende.',
      );
    }

    final appSettingsData = decoded['appSettings'];
    if (appSettingsData is! Map) {
      throw const FormatException(
        'El backup no incluye ajustes validos.',
      );
    }

    final routinesData = decoded['routines'];
    final dailyRecordsData = decoded['dailyRecords'];
    final datedBlocksData = decoded['datedBlocks'];

    return AppBackupImportData(
      appSettings: _appSettingsFromMap(appSettingsData),
      routines: _parseMapList(routinesData, 'routines')
          .map(_routineFromMap)
          .toList(),
      dailyRecords: _parseMapList(dailyRecordsData, 'dailyRecords')
          .map(_dailyRecordFromMap)
          .toList(),
      datedBlocks: _parseMapList(datedBlocksData, 'datedBlocks')
          .map(_datedBlockFromMap)
          .toList(),
    );
  }

  static List<Map> _parseMapList(Object? value, String fieldName) {
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('El campo "$fieldName" no es una lista valida.');
    }

    return value.map((item) {
      if (item is! Map) {
        throw FormatException('El campo "$fieldName" contiene una fila invalida.');
      }
      return item;
    }).toList();
  }

  static Map<String, dynamic> _routineToMap(Routine routine) {
    return {
      'id': routine.id,
      'name': routine.name,
      'isActive': routine.isActive,
      'schedule': {
        'type': routine.schedule.type.name,
        'startDateKey': routine.schedule.startDateKey,
        'endDateKey': routine.schedule.endDateKey,
      },
      'blocks': routine.blocks.map(_dayBlockToMap).toList(),
    };
  }

  static Routine _routineFromMap(Map data) {
    final scheduleData = data['schedule'];
    if (scheduleData is! Map) {
      throw const FormatException('Una rutina del backup no tiene schedule valido.');
    }

    return Routine(
      id: data['id'],
      name: data['name'],
      isActive: data['isActive'] ?? false,
      schedule: RoutineSchedule(
        type: RoutineScheduleType.values.firstWhere(
          (type) => type.name == scheduleData['type'],
          orElse: () => RoutineScheduleType.always,
        ),
        startDateKey: scheduleData['startDateKey'],
        endDateKey: scheduleData['endDateKey'],
      ),
      blocks: _parseMapList(data['blocks'], 'routine.blocks')
          .map(_dayBlockFromMap)
          .toList(),
    );
  }

  static Map<String, dynamic> _dailyRecordToMap(DailyRecord record) {
    return {
      'dateKey': record.dateKey,
      'routineId': record.routineId,
      'routineName': record.routineName,
      'blocks': record.blocks.map(_dayBlockToMap).toList(),
    };
  }

  static DailyRecord _dailyRecordFromMap(Map data) {
    return DailyRecord(
      dateKey: data['dateKey'],
      routineId: data['routineId'],
      routineName: data['routineName'],
      blocks: _parseMapList(data['blocks'], 'dailyRecord.blocks')
          .map(_dayBlockFromMap)
          .toList(),
    );
  }

  static Map<String, dynamic> _datedBlockToMap(DatedBlockEntry entry) {
    return {
      'dateKey': entry.dateKey,
      'block': _dayBlockToMap(entry.block),
    };
  }

  static DatedBlockEntry _datedBlockFromMap(Map data) {
    final blockData = data['block'];
    if (blockData is! Map) {
      throw const FormatException('Un evento puntual del backup no tiene bloque valido.');
    }

    return DatedBlockEntry(
      dateKey: data['dateKey'],
      block: _dayBlockFromMap(blockData),
    );
  }

  static Map<String, dynamic> _dayBlockToMap(DayBlock block) {
    return {
      'id': block.id,
      'start': block.start,
      'end': block.end,
      'startMinutes': block.startMinutes,
      'endMinutes': block.endMinutes,
      'title': block.title,
      'description': block.description,
      'type': block.type.name,
      'countsTowardProgress': block.countsTowardProgress,
      'receivesPushNotification': block.receivesPushNotification,
      'isDone': block.isDone,
    };
  }

  static DayBlock _dayBlockFromMap(Map data) {
    return DayBlock(
      id: data['id'],
      start: data['start'],
      end: data['end'],
      startMinutes: data['startMinutes'],
      endMinutes: data['endMinutes'],
      title: data['title'],
      description: data['description'] ?? '',
      type: BlockType.values.firstWhere(
        (type) => type.name == data['type'],
      ),
      countsTowardProgress: data['countsTowardProgress'] ?? true,
      receivesPushNotification: data['receivesPushNotification'] ?? false,
      isDone: data['isDone'] ?? false,
    );
  }

  static Map<String, dynamic> _appSettingsToMap(AppSettings settings) {
    return {
      'warnOnOverlaps': settings.warnOnOverlaps,
      'autoRequestNotificationPermissions':
          settings.autoRequestNotificationPermissions,
      'notificationHorizonDays': settings.notificationHorizonDays,
      'showCompletedDatedEventsInUpcoming':
          settings.showCompletedDatedEventsInUpcoming,
      'visualStyle': settings.visualStyle.storageValue,
    };
  }

  static AppSettings _appSettingsFromMap(Map data) {
    return AppSettings(
      warnOnOverlaps: data['warnOnOverlaps'] ?? true,
      autoRequestNotificationPermissions:
          data['autoRequestNotificationPermissions'] ?? true,
      notificationHorizonDays: data['notificationHorizonDays'] ?? 21,
      showCompletedDatedEventsInUpcoming:
          data['showCompletedDatedEventsInUpcoming'] ?? true,
      visualStyle: AppVisualStyle.fromStorage(data['visualStyle']),
    );
  }
}
