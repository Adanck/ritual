import 'day_block.dart';

/// Representa una plantilla de día completa.
///
/// Una `Routine` agrupa varios bloques de tiempo y permite que el usuario
/// tenga distintos "modos" de día, por ejemplo `Normal` o `Vacaciones`.
class Routine {
  final String id;
  String name;
  final List<DayBlock> blocks;
  bool isActive;

  Routine({
    required this.id,
    required this.name,
    required this.blocks,
    this.isActive = false,
  });
}
