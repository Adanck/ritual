import 'day_time.dart';
import 'block_type.dart';

/// Unidad minima de planificacion dentro de una rutina.
///
/// Cada bloque representa una actividad acotada en el tiempo. Puede ser un
/// habito, un compromiso o un bloque visual/de contexto.
class DayBlock {
  final String id;
  final int _startMinutes;
  final int _endMinutes;
  final String title;
  final String description;
  final BlockType type;
  final bool countsTowardProgress;
  final bool receivesPushNotification;
  bool isDone;

  /// Hora inicial del bloque como `HH:mm` para la UI.
  String get start => DayTimeCodec.formatMinutes(_startMinutes);

  /// Hora final del bloque como `HH:mm` para la UI.
  String get end => DayTimeCodec.formatMinutes(_endMinutes);

  /// Hora inicial del bloque en minutos desde medianoche.
  int get startMinutes => _startMinutes;

  /// Hora final del bloque en minutos desde medianoche.
  int get endMinutes => _endMinutes;

  DayBlock({
    String? id,
    String? start,
    String? end,
    int? startMinutes,
    int? endMinutes,
    required this.title,
    this.description = '',
    required this.type,
    this.countsTowardProgress = true,
    this.receivesPushNotification = false,
    this.isDone = false,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        _startMinutes = _resolveMinutes(
          explicitMinutes: startMinutes,
          timeLabel: start,
          parameterName: 'start',
        ),
        _endMinutes = _resolveMinutes(
          explicitMinutes: endMinutes,
          timeLabel: end,
          parameterName: 'end',
        );

  /// Crea una copia del bloque preservando los campos no modificados.
  DayBlock copyWith({
    String? id,
    String? start,
    String? end,
    int? startMinutes,
    int? endMinutes,
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
      startMinutes: start == null ? startMinutes : null,
      endMinutes: end == null ? endMinutes : null,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      countsTowardProgress: countsTowardProgress ?? this.countsTowardProgress,
      receivesPushNotification:
          receivesPushNotification ?? this.receivesPushNotification,
      isDone: isDone ?? this.isDone,
    );
  }

  /// Resuelve la hora del constructor desde minutos directos o texto `HH:mm`.
  ///
  /// Regla: aceptamos ambas formas para facilitar migraciones de datos y para
  /// no romper el resto de la app mientras seguimos mostrando horas como texto.
  static int _resolveMinutes({
    required int? explicitMinutes,
    required String? timeLabel,
    required String parameterName,
  }) {
    if (explicitMinutes != null) return explicitMinutes;

    if (timeLabel == null) {
      throw ArgumentError('DayBlock requiere $parameterName o ${parameterName}Minutes.');
    }

    final parsedMinutes = DayTimeCodec.parseMinutes(timeLabel);
    if (parsedMinutes == null) {
      throw ArgumentError('La hora "$timeLabel" no es valida para $parameterName.');
    }

    return parsedMinutes;
  }
}
