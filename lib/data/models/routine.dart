import 'day_block.dart';

class Routine {
  final String id;
  final String name;
  final List<DayBlock> blocks;
  bool isActive;

  Routine({
    required this.id,
    required this.name,
    required this.blocks,
    this.isActive = false,
  });
}
