import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/core/utils/dated_entry_utils.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/day_block.dart';

void main() {
  DatedBlockEntry buildEntry({
    required String dateKey,
    bool isDone = false,
    bool receivesPushNotification = false,
  }) {
    return DatedBlockEntry(
      dateKey: dateKey,
      block: DayBlock(
        id: 'dated-$dateKey',
        start: '09:00',
        end: '09:30',
        title: 'Evento',
        type: BlockType.event,
        isDone: isDone,
        receivesPushNotification: receivesPushNotification,
      ),
    );
  }

  test('buildStatusLabel reconoce hoy manana y completado', () {
    final today = DateTime(2026, 4, 7);

    expect(
      DatedEntryUtils.buildStatusLabel(
        entry: buildEntry(dateKey: '2026-04-07'),
        todayDate: today,
      ),
      'Pendiente hoy',
    );

    expect(
      DatedEntryUtils.buildStatusLabel(
        entry: buildEntry(dateKey: '2026-04-08'),
        todayDate: today,
      ),
      'Pendiente manana',
    );

    expect(
      DatedEntryUtils.buildStatusLabel(
        entry: buildEntry(dateKey: '2026-04-09', isDone: true),
        todayDate: today,
      ),
      'Completado',
    );
  });

  test('buildPushLabel distingue programado pendiente y omitido', () {
    final scheduledEntry = buildEntry(
      dateKey: '2026-04-08',
      receivesPushNotification: true,
    );
    final doneEntry = buildEntry(
      dateKey: '2026-04-08',
      receivesPushNotification: true,
      isDone: true,
    );

    expect(
      DatedEntryUtils.buildPushLabel(
        entry: scheduledEntry,
        scheduledSourceKeys: {'dated:2026-04-08:${scheduledEntry.block.id}'},
      ),
      'Push programado',
    );

    expect(
      DatedEntryUtils.buildPushLabel(
        entry: scheduledEntry,
        scheduledSourceKeys: const {},
      ),
      'Push pendiente',
    );

    expect(
      DatedEntryUtils.buildPushLabel(
        entry: doneEntry,
        scheduledSourceKeys: {'dated:2026-04-08:${doneEntry.block.id}'},
      ),
      'Push omitido',
    );
  });
}
