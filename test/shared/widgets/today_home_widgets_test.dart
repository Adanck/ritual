import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/shared/widgets/today_home_widgets.dart';

void main() {
  testWidgets('TodayUpcomingDatedEventsCard permite marcar un evento rapido', (
    WidgetTester tester,
  ) async {
    var toggledEntryId = '';

    final entry = DatedBlockEntry(
      dateKey: '2026-04-09',
      block: DayBlock(
        id: 'event-1',
        start: '09:00',
        end: '10:00',
        title: 'Cita',
        type: BlockType.event,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(
          useMaterial3: true,
        ).copyWith(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: TodayUpcomingDatedEventsCard(
            todayDate: DateTime(2026, 4, 7),
            dateLabelBuilder: (_) => '9 abr 2026',
            entries: [entry],
            scheduledNotificationSourceKeys: const {},
            onToggleCompletion: (selectedEntry) async {
              toggledEntryId = selectedEntry.block.id;
            },
            actionsBuilder: (_) => const SizedBox.shrink(),
            onOpenCalendar: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Proximos eventos puntuales'), findsOneWidget);
    expect(find.text('Pendiente en 2 dias'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
    await tester.pumpAndSettle();

    expect(toggledEntryId, 'event-1');
  });
}
