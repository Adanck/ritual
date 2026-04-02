import 'day_block.dart';

/// Representa un bloque puntual asociado a una fecha concreta.
///
/// A diferencia de una rutina, este bloque no se replica automaticamente a
/// otros dias. Sirve para recordatorios o eventos excepcionales como una
/// reunion el viernes, una cita o una llamada puntual.
class DatedBlockEntry {
  final String dateKey;
  final DayBlock block;

  DatedBlockEntry({
    required this.dateKey,
    required this.block,
  });
}
