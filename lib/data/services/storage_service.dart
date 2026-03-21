import 'package:hive/hive.dart';

import '../models/block_type.dart';
import '../models/day_block.dart';
import '../models/routine.dart';

class StorageService {
  static const String boxName = 'routines';

  static Future<void> saveRoutines(List<Routine> routines) async {
    final box = await Hive.openBox(boxName);

    final data = routines.map((routine) {
      return {
        'id': routine.id,
        'name': routine.name,
        'isActive': routine.isActive,
        'blocks': routine.blocks.map((block) {
          return {
            'start': block.start,
            'end': block.end,
            'title': block.title,
            'type': block.type.name,
            'isDone': block.isDone,
          };
        }).toList(),
      };
    }).toList();

    await box.put('routines', data);
  }

  static Future<List<Routine>> loadRoutines() async {
    final box = await Hive.openBox(boxName);
    final data = box.get('routines');

    if (data == null) return [];

    return (data as List).map((item) {
      return Routine(
        id: item['id'],
        name: item['name'],
        isActive: item['isActive'],
        blocks: (item['blocks'] as List).map((block) {
          return DayBlock(
            start: block['start'],
            end: block['end'],
            title: block['title'],
            type: BlockType.values.firstWhere((type) => type.name == block['type']),
            isDone: block['isDone'],
          );
        }).toList(),
      );
    }).toList();
  }
}
