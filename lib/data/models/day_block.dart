import 'block_type.dart';

/// Unidad minima de planificacion dentro de una rutina.
///
/// Cada bloque representa una actividad acotada en el tiempo. Puede ser un
/// habito, un compromiso o un bloque visual/de contexto.
class DayBlock {
  final String id;
  final String start;
  final String end;
  final String title;
  final String description;
  final BlockType type;
  final bool countsTowardProgress;
  final bool receivesPushNotification;
  bool isDone;

  DayBlock({
    String? id,
    required this.start,
    required this.end,
    required this.title,
    this.description = '',
    required this.type,
    this.countsTowardProgress = true,
    this.receivesPushNotification = false,
    this.isDone = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  /// Crea una copia del bloque preservando los campos no modificados.
  DayBlock copyWith({
    String? id,
    String? start,
    String? end,
    String? title,
    String? description,
    BlockType? type,
    bool? countsTowardProgress,
    bool? receivesPushNotification,
    bool? isDone,
  }) {
    return DayBlock(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      countsTowardProgress: countsTowardProgress ?? this.countsTowardProgress,
      receivesPushNotification:
          receivesPushNotification ?? this.receivesPushNotification,
      isDone: isDone ?? this.isDone,
    );
  }
}
