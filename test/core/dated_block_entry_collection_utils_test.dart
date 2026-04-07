import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/core/utils/dated_block_entry_collection_utils.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/day_block.dart';

void main() {
  DayBlock block({
    required String id,
    required String start,
    bool isDone = false,
  }) {
    return DayBlock(
      id: id,
      start: start,
      end: '10:00',
      title: id,
      type: BlockType.event,
      isDone: isDone,
    );
  }

  DatedBlockEntry entry({
    required String dateKey,
    required DayBlock block,
  }) {
    return DatedBlockEntry(dateKey: dateKey, block: block);
  }

  test('addEntry inserts event and preserves chronological order for date', () {
    final source = [
      entry(dateKey: '2026-04-09', block: block(id: 'b', start: '11:00')),
    ];

    final updated = DatedBlockEntryCollectionUtils.addEntry(
      source: source,
      dateKey: '2026-04-09',
      block: block(id: 'a', start: '08:00'),
    );

    final blocks = DatedBlockEntryCollectionUtils.getBlocksForDate(
      source: updated,
      dateKey: '2026-04-09',
    );

    expect(blocks.map((item) => item.id).toList(), ['a', 'b']);
  });

  test('moveEntry changes date and resets completion when date changes', () {
    final source = [
      entry(
        dateKey: '2026-04-09',
        block: block(id: 'event-1', start: '08:00', isDone: true),
      ),
    ];

    final updated = DatedBlockEntryCollectionUtils.moveEntry(
      source: source,
      entry: source.first,
      targetDateKey: '2026-04-10',
    );

    expect(
      DatedBlockEntryCollectionUtils.getBlocksForDate(
        source: updated,
        dateKey: '2026-04-09',
      ),
      isEmpty,
    );
    final moved = DatedBlockEntryCollectionUtils.getBlocksForDate(
      source: updated,
      dateKey: '2026-04-10',
    ).single;
    expect(moved.id, 'event-1');
    expect(moved.isDone, isFalse);
  });

  test('toggleCompletion only changes the targeted dated entry', () {
    final source = [
      entry(dateKey: '2026-04-09', block: block(id: 'event-1', start: '08:00')),
      entry(dateKey: '2026-04-09', block: block(id: 'event-2', start: '09:00')),
    ];

    final updated = DatedBlockEntryCollectionUtils.toggleCompletion(
      source: source,
      entry: source.first,
    );

    final blocks = DatedBlockEntryCollectionUtils.getBlocksForDate(
      source: updated,
      dateKey: '2026-04-09',
    );
    expect(blocks.firstWhere((item) => item.id == 'event-1').isDone, isTrue);
    expect(blocks.firstWhere((item) => item.id == 'event-2').isDone, isFalse);
  });
}
