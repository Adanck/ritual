import 'day_block.dart';
import 'routine_schedule.dart';

/// Representa una plantilla de dia completa.
///
/// Una `Routine` agrupa varios bloques de tiempo y permite que el usuario
/// tenga distintos "modos" de dia, por ejemplo `Normal` o `Vacaciones`.
/// Tambien define durante que fechas debe considerarse vigente.
class Routine {
  final String id;
  String name;
  final List<DayBlock> blocks;
  bool isActive;
  RoutineSchedule schedule;

  Routine({
    required this.id,
    required this.name,
    required this.blocks,
    this.isActive = false,
    this.schedule = const RoutineSchedule.always(),
  });

  /// Delegamos en [RoutineSchedule] la evaluacion de vigencia para mantener
  /// esa regla de negocio encapsulada en un solo lugar.
  bool appliesOn(DateTime date) => schedule.appliesTo(date);
}
