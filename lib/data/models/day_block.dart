import 'block_type.dart';

class DayBlock {
  final String start;
  final String end;
  final String title;
  final BlockType type;
  bool isDone;

  DayBlock({
    required this.start,
    required this.end,
    required this.title,
    required this.type,
    this.isDone = false,
  });
}
