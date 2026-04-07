import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/models/routine_schedule.dart';

/// Modo de importacion disponible para la biblioteca de rutinas.
///
/// `merge` agrega la biblioteca importada encima de la existente. `replace`
/// reemplaza la biblioteca actual por la importada, pero sin tocar historial.
enum RoutineCsvImportMode {
  merge,
  replace,
}

/// Resultado listo para mostrar cuando se exporta la biblioteca de rutinas.
class RoutineCsvExportData {
  final String csv;
  final int routineCount;
  final int blockCount;

  const RoutineCsvExportData({
    required this.csv,
    required this.routineCount,
    required this.blockCount,
  });
}

/// Resultado estructurado de una importacion ya parseada desde CSV.
class RoutineCsvImportData {
  final List<Routine> routines;
  final int routineCount;
  final int blockCount;

  const RoutineCsvImportData({
    required this.routines,
    required this.routineCount,
    required this.blockCount,
  });
}

/// Convierte la biblioteca de rutinas a/desde un CSV compatible con Excel.
///
/// El formato aplana la jerarquia rutina -> bloques en una fila por bloque.
/// Si una rutina no tiene bloques, exportamos una fila "vacia" para que no se
/// pierda al abrir y volver a importar el archivo.
class RoutineCsvService {
  static const List<String> _header = [
    'routine_id',
    'routine_name',
    'routine_is_active',
    'schedule_type',
    'schedule_start_date',
    'schedule_end_date',
    'block_id',
    'block_start',
    'block_end',
    'block_title',
    'block_description',
    'block_type',
    'counts_toward_progress',
    'receives_push_notification',
  ];

  /// Serializa la biblioteca a CSV usando una fila por bloque.
  static RoutineCsvExportData exportRoutines(List<Routine> routines) {
    final rows = <List<String>>[_header];
    var blockCount = 0;

    for (final routine in routines) {
      if (routine.blocks.isEmpty) {
        rows.add([
          routine.id,
          routine.name,
          routine.isActive.toString(),
          _encodeScheduleType(routine.schedule.type),
          routine.schedule.startDateKey ?? '',
          routine.schedule.endDateKey ?? '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ]);
        continue;
      }

      for (final block in routine.blocks) {
        blockCount += 1;
        rows.add([
          routine.id,
          routine.name,
          routine.isActive.toString(),
          _encodeScheduleType(routine.schedule.type),
          routine.schedule.startDateKey ?? '',
          routine.schedule.endDateKey ?? '',
          block.id,
          block.start,
          block.end,
          block.title,
          block.description,
          _encodeBlockType(block.type),
          block.countsTowardProgress.toString(),
          block.receivesPushNotification.toString(),
        ]);
      }
    }

    final csv = rows.map(_encodeCsvRow).join('\n');
    return RoutineCsvExportData(
      csv: csv,
      routineCount: routines.length,
      blockCount: blockCount,
    );
  }

  /// Reconstruye la biblioteca desde CSV tolerando columnas reordenadas.
  ///
  /// Regla: ignoramos filas completamente vacias para soportar edicion manual
  /// en Excel. Caso borde: si falta una columna requerida, lanzamos un error
  /// explicito para que el usuario no importe una biblioteca incompleta.
  static RoutineCsvImportData importRoutines(String csv) {
    final rows = _parseCsv(csv);
    if (rows.isEmpty) {
      throw const FormatException(
        'El CSV esta vacio. Exporta o pega una biblioteca valida para importar.',
      );
    }

    final header = rows.first
        .map((value) => value.replaceFirst('\uFEFF', '').trim())
        .toList();
    final columnIndexes = <String, int>{
      for (var i = 0; i < header.length; i++) header[i]: i,
    };

    for (final column in _header) {
      if (!columnIndexes.containsKey(column)) {
        throw FormatException(
          'Falta la columna "$column". Usa el CSV exportado por Ritual como base.',
        );
      }
    }

    final drafts = <String, _RoutineImportDraft>{};
    final routineOrder = <String>[];
    var blockCount = 0;

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = _normalizeRow(rows[rowIndex], header.length);

      if (row.every((value) => value.trim().isEmpty)) {
        continue;
      }

      final routineId = _readCell(row, columnIndexes, 'routine_id');
      final routineKey = routineId.isNotEmpty ? routineId : 'row-$rowIndex';
      final routineName = _readCell(row, columnIndexes, 'routine_name');

      // Regla: una rutina sin nombre no se puede reconstruir de forma segura.
      if (routineName.isEmpty) {
        throw FormatException(
          'La fila ${rowIndex + 1} no tiene nombre de rutina.',
        );
      }

      final draft = drafts.putIfAbsent(routineKey, () {
        routineOrder.add(routineKey);
        return _RoutineImportDraft(
          name: routineName,
          isActive: _parseBool(
            _readCell(row, columnIndexes, 'routine_is_active'),
            defaultValue: false,
            fieldName: 'routine_is_active',
            rowNumber: rowIndex + 1,
          ),
          schedule: _parseSchedule(
            typeValue: _readCell(row, columnIndexes, 'schedule_type'),
            startDateKey: _readCell(row, columnIndexes, 'schedule_start_date'),
            endDateKey: _readCell(row, columnIndexes, 'schedule_end_date'),
            rowNumber: rowIndex + 1,
            routineName: routineName,
          ),
        );
      });

      final hasBlockData = _hasBlockData(row, columnIndexes);
      if (!hasBlockData) continue;

      draft.blocks.add(
        _parseBlock(
          row: row,
          columnIndexes: columnIndexes,
          rowNumber: rowIndex + 1,
        ),
      );
      blockCount += 1;
    }

    final importedRoutines = routineOrder.map((routineKey) {
      final draft = drafts[routineKey]!;

      return Routine(
        id: routineKey,
        name: draft.name,
        isActive: draft.isActive,
        schedule: draft.schedule,
        blocks: draft.blocks,
      );
    }).toList();

    return RoutineCsvImportData(
      routines: importedRoutines,
      routineCount: importedRoutines.length,
      blockCount: blockCount,
    );
  }

  static String _encodeCsvRow(List<String> values) {
    return values.map(_escapeCsvValue).join(',');
  }

  static String _escapeCsvValue(String value) {
    final escapedValue = value.replaceAll('"', '""');
    final needsQuotes = escapedValue.contains(',') ||
        escapedValue.contains('"') ||
        escapedValue.contains('\n') ||
        escapedValue.contains('\r');

    return needsQuotes ? '"$escapedValue"' : escapedValue;
  }

  static List<List<String>> _parseCsv(String source) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentField = StringBuffer();
    var isInsideQuotes = false;

    for (var index = 0; index < source.length; index++) {
      final char = source[index];

      if (isInsideQuotes) {
        if (char == '"') {
          final nextChar = index + 1 < source.length ? source[index + 1] : null;

          if (nextChar == '"') {
            currentField.write('"');
            index += 1;
          } else {
            isInsideQuotes = false;
          }
        } else {
          currentField.write(char);
        }

        continue;
      }

      if (char == '"') {
        isInsideQuotes = true;
        continue;
      }

      if (char == ',') {
        currentRow.add(currentField.toString());
        currentField.clear();
        continue;
      }

      if (char == '\n') {
        currentRow.add(currentField.toString());
        currentField.clear();
        rows.add([...currentRow]);
        currentRow.clear();
        continue;
      }

      if (char == '\r') {
        continue;
      }

      currentField.write(char);
    }

    final hasPendingField = currentField.isNotEmpty || currentRow.isNotEmpty;
    if (hasPendingField) {
      currentRow.add(currentField.toString());
      rows.add([...currentRow]);
    }

    return rows;
  }

  static List<String> _normalizeRow(List<String> row, int expectedLength) {
    if (row.length >= expectedLength) return row;

    return [
      ...row,
      ...List.filled(expectedLength - row.length, ''),
    ];
  }

  static String _readCell(
    List<String> row,
    Map<String, int> columnIndexes,
    String columnName,
  ) {
    final index = columnIndexes[columnName];
    if (index == null || index >= row.length) return '';
    return row[index].replaceFirst('\uFEFF', '').trim();
  }

  static bool _hasBlockData(
    List<String> row,
    Map<String, int> columnIndexes,
  ) {
    return _readCell(row, columnIndexes, 'block_title').isNotEmpty ||
        _readCell(row, columnIndexes, 'block_start').isNotEmpty ||
        _readCell(row, columnIndexes, 'block_end').isNotEmpty ||
        _readCell(row, columnIndexes, 'block_type').isNotEmpty;
  }

  static DayBlock _parseBlock({
    required List<String> row,
    required Map<String, int> columnIndexes,
    required int rowNumber,
  }) {
    final title = _readCell(row, columnIndexes, 'block_title');
    final start = _readCell(row, columnIndexes, 'block_start');
    final end = _readCell(row, columnIndexes, 'block_end');
    final blockTypeValue = _readCell(row, columnIndexes, 'block_type');

    // Regla: si la fila representa un bloque, titulo y horas deben existir.
    if (title.isEmpty || start.isEmpty || end.isEmpty || blockTypeValue.isEmpty) {
      throw FormatException(
        'La fila $rowNumber tiene un bloque incompleto. Revisa titulo, hora inicial, hora final y tipo.',
      );
    }

    return DayBlock(
      id: _readCell(row, columnIndexes, 'block_id').ifEmpty('row-$rowNumber'),
      start: start,
      end: end,
      title: title,
      description: _readCell(row, columnIndexes, 'block_description'),
      type: _parseBlockType(blockTypeValue, rowNumber),
      countsTowardProgress: _parseBool(
        _readCell(row, columnIndexes, 'counts_toward_progress'),
        defaultValue: true,
        fieldName: 'counts_toward_progress',
        rowNumber: rowNumber,
      ),
      receivesPushNotification: _parseBool(
        _readCell(row, columnIndexes, 'receives_push_notification'),
        defaultValue: false,
        fieldName: 'receives_push_notification',
        rowNumber: rowNumber,
      ),
    );
  }

  static RoutineSchedule _parseSchedule({
    required String typeValue,
    required String startDateKey,
    required String endDateKey,
    required int rowNumber,
    required String routineName,
  }) {
    final type = _parseScheduleType(typeValue, rowNumber);

    if (type == RoutineScheduleType.always) {
      return const RoutineSchedule.always();
    }

    // Regla: cualquier vigencia distinta de "always" necesita fecha inicial.
    if (startDateKey.isEmpty) {
      throw FormatException(
        'La fila $rowNumber de "$routineName" necesita schedule_start_date.',
      );
    }

    // Caso borde: semana actual y mes actual deben conservar un rango cerrado.
    if ((type == RoutineScheduleType.currentWeek ||
            type == RoutineScheduleType.currentMonth) &&
        endDateKey.isEmpty) {
      throw FormatException(
        'La fila $rowNumber de "$routineName" necesita schedule_end_date para $typeValue.',
      );
    }

    return RoutineSchedule(
      type: type,
      startDateKey: startDateKey,
      endDateKey: endDateKey.isEmpty ? null : endDateKey,
    );
  }

  static RoutineScheduleType _parseScheduleType(String rawValue, int rowNumber) {
    final normalizedValue = _normalizeEnumValue(rawValue);

    switch (normalizedValue) {
      case 'always':
      case 'siempre':
        return RoutineScheduleType.always;
      case 'currentweek':
      case 'current_week':
      case 'semanaactual':
      case 'semana_actual':
        return RoutineScheduleType.currentWeek;
      case 'currentmonth':
      case 'current_month':
      case 'mesactual':
      case 'mes_actual':
        return RoutineScheduleType.currentMonth;
      case 'customrange':
      case 'custom_range':
      case 'rangopersonalizado':
      case 'rango_personalizado':
        return RoutineScheduleType.customRange;
      default:
        throw FormatException(
          'La fila $rowNumber tiene un schedule_type invalido: "$rawValue".',
        );
    }
  }

  static BlockType _parseBlockType(String rawValue, int rowNumber) {
    final normalizedValue = _normalizeEnumValue(rawValue);

    switch (normalizedValue) {
      case 'habit':
      case 'habito':
        return BlockType.habit;
      case 'commitment':
      case 'compromiso':
        return BlockType.commitment;
      case 'visual':
        return BlockType.visual;
      case 'reminder':
      case 'recordatorio':
        return BlockType.reminder;
      case 'event':
      case 'eventopuntual':
      case 'evento_puntual':
        return BlockType.event;
      default:
        throw FormatException(
          'La fila $rowNumber tiene un block_type invalido: "$rawValue".',
        );
    }
  }

  static bool _parseBool(
    String rawValue, {
    required bool defaultValue,
    required String fieldName,
    required int rowNumber,
  }) {
    final normalizedValue = rawValue.trim().toLowerCase();
    if (normalizedValue.isEmpty) return defaultValue;

    if ([
      'true',
      '1',
      'yes',
      'y',
      'si',
      'sí',
      'x',
    ].contains(normalizedValue)) {
      return true;
    }

    if ([
      'false',
      '0',
      'no',
      'n',
    ].contains(normalizedValue)) {
      return false;
    }

    throw FormatException(
      'La fila $rowNumber tiene un valor invalido en $fieldName: "$rawValue".',
    );
  }

  static String _encodeScheduleType(RoutineScheduleType type) {
    switch (type) {
      case RoutineScheduleType.always:
        return 'always';
      case RoutineScheduleType.currentWeek:
        return 'current_week';
      case RoutineScheduleType.currentMonth:
        return 'current_month';
      case RoutineScheduleType.customRange:
        return 'custom_range';
    }
  }

  static String _encodeBlockType(BlockType type) {
    switch (type) {
      case BlockType.habit:
        return 'habit';
      case BlockType.commitment:
        return 'commitment';
      case BlockType.visual:
        return 'visual';
      case BlockType.reminder:
        return 'reminder';
      case BlockType.event:
        return 'event';
    }
  }

  static String _normalizeEnumValue(String rawValue) {
    return rawValue
        .trim()
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('-', '_');
  }
}

class _RoutineImportDraft {
  final String name;
  final bool isActive;
  final RoutineSchedule schedule;
  final List<DayBlock> blocks = [];

  _RoutineImportDraft({
    required this.name,
    required this.isActive,
    required this.schedule,
  });
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
