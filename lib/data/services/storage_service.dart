import 'package:hive/hive.dart';

import '../models/block_type.dart';
import '../models/day_block.dart';
import '../models/routine.dart';

/// Encapsula la persistencia local del MVP usando Hive.
class StorageService {
  static const String boxName = 'routines';

  /// Serializa y guarda todas las rutinas.
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
            'description': block.description,
            'type': block.type.name,
            'isDone': block.isDone,
          };
        }).toList(),
      };
    }).toList();

    await box.put('routines', data);
  }

  /// Carga las rutinas guardadas y las reconstruye como objetos de dominio.
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
            description: block['description'] ?? '',
            type: BlockType.values.firstWhere(
              (type) => type.name == block['type'],
            ),
            isDone: block['isDone'],
          );
        }).toList(),
      );
    }).toList();
  }
}
