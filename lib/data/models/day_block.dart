import 'block_type.dart';

/// Unidad minima de planificacion dentro de una rutina.
///
/// Cada bloque representa una actividad acotada en el tiempo. Puede ser un
/// habito, un compromiso o un bloque visual/de contexto.
class DayBlock {
  final String start;
  final String end;
  final String title;
  final String description;
  final BlockType type;
  bool isDone;

  DayBlock({
    required this.start,
    required this.end,
    required this.title,
    this.description = '',
    required this.type,
    this.isDone = false,
  });
}
