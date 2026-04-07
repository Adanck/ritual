import 'package:ritual/core/utils/date_key.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/day_block.dart';

/// Reune operaciones de colecciones de bloques para no duplicar logica en UI.
///
/// La idea es mantener en un solo lugar las reglas de comparacion, clonacion,
/// orden cronologico y manejo de bloques puntuales por fecha.
class DayBlockCollectionUtils {
  /// Crea una copia del bloque para usarla en registros diarios o previews.
  static DayBlock cloneForDailyRecord(DayBlock block, {bool? isDone}) {
    return block.copyWith(isDone: isDone ?? block.isDone);
  }

  /// Genera una firma funcional del bloque para detectar equivalencias.
  static String buildSignature(DayBlock block) {
    return '${block.startMinutes}|${block.endMinutes}|${block.title.trim().toLowerCase()}';
  }

  /// Compara dos bloques por definicion funcional y no solo por referencia.
  static bool hasSameDefinition(DayBlock a, DayBlock b) {
    return a.id == b.id &&
        a.startMinutes == b.startMinutes &&
        a.endMinutes == b.endMinutes &&
        a.title == b.title &&
        a.description == b.description &&
        a.type == b.type &&
        a.countsTowardProgress == b.countsTowardProgress &&
        a.receivesPushNotification == b.receivesPushNotification;
  }

  /// Ordena bloques por su hora de inicio.
  static List<DayBlock> sortChronologically(List<DayBlock> blocks) {
    final sortedBlocks = [...blocks];
    sortedBlocks.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return sortedBlocks;
  }

  /// Sincroniza el registro diario con la plantilla preservando checks por id.
  static List<DayBlock> syncWithTemplate({
    required List<DayBlock> templateBlocks,
    required List<DayBlock> currentDayBlocks,
  }) {
    final completedStateById = {
      for (final block in currentDayBlocks) block.id: block.isDone,
    };

    return templateBlocks.map((templateBlock) {
      return cloneForDailyRecord(
        templateBlock,
        isDone: completedStateById[templateBlock.id] ?? false,
      );
    }).toList();
  }

  /// Devuelve los proximos eventos puntuales ordenados por fecha y hora.
  static List<DatedBlockEntry> getUpcomingDatedBlocks({
    required List<DatedBlockEntry> datedBlocks,
    required DateTime todayDate,
    int daysAhead = 14,
    int limit = 4,
  }) {
    final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
    final lastDate = today.add(Duration(days: daysAhead));
    final sortedEntries = [...datedBlocks]
      ..sort((a, b) {
        final aDateTime = DateKey.toDate(a.dateKey);
        final bDateTime = DateKey.toDate(b.dateKey);
        final dateComparison = aDateTime.compareTo(bDateTime);
        if (dateComparison != 0) return dateComparison;

        return a.block.startMinutes.compareTo(b.block.startMinutes);
      });

    return sortedEntries
        .where((entry) {
          final entryDate = DateKey.toDate(entry.dateKey);
          return !entryDate.isBefore(today) && !entryDate.isAfter(lastDate);
        })
        .take(limit)
        .toList();
  }
}
