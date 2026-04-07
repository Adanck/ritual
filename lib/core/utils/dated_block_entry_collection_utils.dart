import 'package:ritual/core/utils/day_block_collection_utils.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/day_block.dart';

/// Reune operaciones puras sobre eventos puntuales por fecha.
///
/// La meta es que mover, duplicar o editar eventos no dependa de bloques de
/// UI repetidos dentro de `TodayPage`, sino de una unica fuente de verdad.
class DatedBlockEntryCollectionUtils {
  /// Reemplaza completamente la lista de eventos de una fecha concreta.
  static List<DatedBlockEntry> replaceEntriesForDate({
    required List<DatedBlockEntry> source,
    required String dateKey,
    required List<DayBlock> blocks,
  }) {
    final updated = [...source]..removeWhere((entry) => entry.dateKey == dateKey);
    final sortedBlocks = DayBlockCollectionUtils.sortChronologically(blocks);

    updated.addAll(
      sortedBlocks.map(
        (block) => DatedBlockEntry(
          dateKey: dateKey,
          block: block,
        ),
      ),
    );

    return updated;
  }

  /// Agrega un evento puntual nuevo a una fecha y devuelve la coleccion final.
  static List<DatedBlockEntry> addEntry({
    required List<DatedBlockEntry> source,
    required String dateKey,
    required DayBlock block,
  }) {
    final blocksForDate = [
      ...getBlocksForDate(source: source, dateKey: dateKey),
      block,
    ];

    return replaceEntriesForDate(
      source: source,
      dateKey: dateKey,
      blocks: blocksForDate,
    );
  }

  /// Actualiza un evento puntual existente manteniendo su fecha actual.
  static List<DatedBlockEntry> updateEntry({
    required List<DatedBlockEntry> source,
    required DatedBlockEntry originalEntry,
    required DayBlock updatedBlock,
  }) {
    final blocksForDate = getBlocksForDate(
      source: source,
      dateKey: originalEntry.dateKey,
    ).map((block) {
      return block.id == originalEntry.block.id ? updatedBlock : block;
    }).toList();

    return replaceEntriesForDate(
      source: source,
      dateKey: originalEntry.dateKey,
      blocks: blocksForDate,
    );
  }

  /// Mueve un evento puntual a otra fecha. Si cambia de dia, reinicia su check
  /// para que el nuevo contexto empiece limpio.
  static List<DatedBlockEntry> moveEntry({
    required List<DatedBlockEntry> source,
    required DatedBlockEntry entry,
    required String targetDateKey,
  }) {
    final withoutOriginal = removeEntry(
      source: source,
      entry: entry,
    );
    final movedBlock = entry.block.copyWith(
      isDone: targetDateKey == entry.dateKey ? entry.block.isDone : false,
    );

    return addEntry(
      source: withoutOriginal,
      dateKey: targetDateKey,
      block: movedBlock,
    );
  }

  /// Duplica un evento en otra fecha sin tocar el original.
  static List<DatedBlockEntry> duplicateEntry({
    required List<DatedBlockEntry> source,
    required String targetDateKey,
    required DayBlock duplicatedBlock,
  }) {
    return addEntry(
      source: source,
      dateKey: targetDateKey,
      block: duplicatedBlock.copyWith(isDone: false),
    );
  }

  /// Elimina un unico evento puntual por identidad de fecha e id del bloque.
  static List<DatedBlockEntry> removeEntry({
    required List<DatedBlockEntry> source,
    required DatedBlockEntry entry,
  }) {
    return source
        .where(
          (item) =>
              !(item.dateKey == entry.dateKey &&
                  item.block.id == entry.block.id),
        )
        .toList();
  }

  /// Cambia el estado completado de un evento puntual conservando orden.
  static List<DatedBlockEntry> toggleCompletion({
    required List<DatedBlockEntry> source,
    required DatedBlockEntry entry,
  }) {
    final blocksForDate = getBlocksForDate(
      source: source,
      dateKey: entry.dateKey,
    ).map((block) {
      return block.id == entry.block.id
          ? block.copyWith(isDone: !block.isDone)
          : block;
    }).toList();

    return replaceEntriesForDate(
      source: source,
      dateKey: entry.dateKey,
      blocks: blocksForDate,
    );
  }

  /// Lee solo los bloques de una fecha concreta.
  static List<DayBlock> getBlocksForDate({
    required List<DatedBlockEntry> source,
    required String dateKey,
  }) {
    return source
        .where((entry) => entry.dateKey == dateKey)
        .map((entry) => entry.block)
        .toList();
  }
}
