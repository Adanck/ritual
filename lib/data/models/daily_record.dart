import 'day_block.dart';

/// Representa lo que realmente paso en una fecha concreta para una rutina.
///
/// A diferencia de [Routine], que es una plantilla editable, `DailyRecord`
/// guarda el estado historico de un dia especifico y por eso conserva
/// completados, bloques visibles y metadatos de esa fecha.
class DailyRecord {
  final String dateKey;
  final String routineId;
  String routineName;
  final List<DayBlock> blocks;

  DailyRecord({
    required this.dateKey,
    required this.routineId,
    required this.routineName,
    required this.blocks,
  });

  /// Regla: un dia cuenta como completado solo si todos los bloques que
  /// participan en el progreso fueron completados y existe al menos uno.
  bool get isCompletedDay {
    final progressBlocks = blocks.where((block) => block.countsTowardProgress);
    return progressBlocks.isNotEmpty && progressBlocks.every((block) => block.isDone);
  }

  /// Estadistica basica: dias con al menos una accion completada.
  bool get hasAnyCompletedBlocks => blocks.any((block) => block.isDone);

  int get completedBlocksCount => blocks.where((block) => block.isDone).length;

  int get progressEligibleBlocksCount =>
      blocks.where((block) => block.countsTowardProgress).length;

  int get completedProgressBlocksCount => blocks
      .where((block) => block.countsTowardProgress && block.isDone)
      .length;
}
