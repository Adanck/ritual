import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/day_block.dart';

void main() {
  test('DayBlock stores time internally as minutes and exposes HH:mm getters', () {
    final block = DayBlock(
      start: '07:05',
      end: '08:40',
      title: 'Lectura',
      type: BlockType.habit,
    );

    expect(block.startMinutes, 425);
    expect(block.endMinutes, 520);
    expect(block.start, '07:05');
    expect(block.end, '08:40');
  });

  test('DayBlock can be created directly from minute values', () {
    final block = DayBlock(
      startMinutes: 810,
      endMinutes: 855,
      title: 'Reunion',
      type: BlockType.event,
    );

    expect(block.start, '13:30');
    expect(block.end, '14:15');
  });
}
