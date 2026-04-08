import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/core/models/notification_diagnostics.dart';
import 'package:ritual/shared/widgets/today_notification_widgets.dart';

void main() {
  testWidgets('TodayNotificationStatusCard muestra chips de faltantes y sobrantes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(
          useMaterial3: true,
        ).copyWith(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: TodayNotificationStatusCard(
            diagnostics: NotificationDiagnostics(
              supportsLocalNotifications: true,
              notificationsEnabled: true,
              scheduledNotificationsCount: 3,
              pendingDeviceNotificationsCount: 2,
              scheduledDatedNotificationsCount: 1,
              missingDeviceNotificationsCount: 1,
              unexpectedDeviceNotificationsCount: 2,
              usedExactSourceComparison: true,
              isScheduleAligned: false,
              nextScheduledAt: DateTime(2026, 4, 7, 10, 0),
              lastRefreshedAt: DateTime(2026, 4, 7, 9, 0),
            ),
            pushEnabledBlocksCount: 4,
            statusDescription: 'La agenda no coincide.',
            formatWhen: (_) => 'Hoy 10:00',
            isActionInProgress: false,
            onOpenAgenda: () {},
            onReviewPermissions: () {},
            onResync: () {},
            onSendTest: () {},
          ),
        ),
      ),
    );

    expect(find.text('1 faltan'), findsOneWidget);
    expect(find.text('2 sobrantes'), findsOneWidget);
    expect(find.text('Ver agenda'), findsOneWidget);
  });

  testWidgets('TodayNotificationStatusCard muestra estado de auto-reparacion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(
          useMaterial3: true,
        ).copyWith(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: TodayNotificationStatusCard(
            diagnostics: NotificationDiagnostics(
              supportsLocalNotifications: true,
              notificationsEnabled: true,
              scheduledNotificationsCount: 2,
              pendingDeviceNotificationsCount: 2,
              usedExactSourceComparison: true,
              isScheduleAligned: true,
              autoRepairAttempted: true,
              autoRepairResolvedIssue: true,
              nextScheduledAt: DateTime(2026, 4, 7, 10, 0),
              lastRefreshedAt: DateTime(2026, 4, 7, 9, 0),
            ),
            pushEnabledBlocksCount: 2,
            statusDescription: 'Ritual detecto una desalineacion y la corrigio automaticamente.',
            formatWhen: (_) => 'Hoy 10:00',
            isActionInProgress: false,
            onOpenAgenda: () {},
            onReviewPermissions: () {},
            onResync: () {},
            onSendTest: () {},
          ),
        ),
      ),
    );

    expect(find.text('Auto-reparada'), findsOneWidget);
  });

  testWidgets('TodayNotificationAgendaSheet muestra estado de cada recordatorio', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(
          useMaterial3: true,
        ).copyWith(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: TodayNotificationAgendaSheet(
            items: [
              NotificationAgendaItemData(
                sourceKey: 'dated:2026-04-07:dated-1',
                title: 'Reunion',
                body: '07 abr | 09:00',
                when: DateTime(2026, 4, 7, 9, 0),
                isPresentOnDevice: false,
              ),
              NotificationAgendaItemData(
                sourceKey: 'routine:normal:2026-04-07:block-1',
                title: 'Oracion',
                body: 'Normal | 06:00',
                when: DateTime(2026, 4, 7, 6, 0),
                isPresentOnDevice: true,
              ),
            ],
            unexpectedSourceKeys: const ['dated:2026-04-08:ghost'],
            formatWhen: (_) => 'Hoy',
          ),
        ),
      ),
    );

    expect(find.text('Agenda de recordatorios'), findsOneWidget);
    expect(find.text('Reunion'), findsOneWidget);
    expect(find.text('Oracion'), findsOneWidget);
    expect(find.text('Pendiente de resincronizar'), findsOneWidget);
    expect(find.text('En dispositivo'), findsOneWidget);
    expect(find.textContaining('recordatorios extra'), findsOneWidget);
  });
}
