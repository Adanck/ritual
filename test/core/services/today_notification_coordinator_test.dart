import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/core/models/notification_diagnostics.dart';
import 'package:ritual/core/services/notification_service.dart';
import 'package:ritual/core/services/today_notification_coordinator.dart';

void main() {
  test('shouldAttemptAutoRepair solo se activa cuando la agenda sigue desalineada', () {
    final misaligned = NotificationDiagnostics(
      supportsLocalNotifications: true,
      notificationsEnabled: true,
      scheduledNotificationsCount: 2,
      pendingDeviceNotificationsCount: 1,
      missingDeviceNotificationsCount: 1,
      unexpectedDeviceNotificationsCount: 0,
      usedExactSourceComparison: true,
      isScheduleAligned: false,
      nextScheduledAt: DateTime(2026, 4, 7, 10, 0),
      lastRefreshedAt: DateTime(2026, 4, 7, 9, 0),
    );

    final disabled = NotificationDiagnostics(
      supportsLocalNotifications: true,
      notificationsEnabled: false,
      scheduledNotificationsCount: 2,
      pendingDeviceNotificationsCount: 1,
      missingDeviceNotificationsCount: 1,
      unexpectedDeviceNotificationsCount: 0,
      usedExactSourceComparison: true,
      isScheduleAligned: false,
      nextScheduledAt: DateTime(2026, 4, 7, 10, 0),
      lastRefreshedAt: DateTime(2026, 4, 7, 9, 0),
    );

    expect(
      TodayNotificationCoordinator.shouldAttemptAutoRepair(misaligned),
      isTrue,
    );
    expect(
      TodayNotificationCoordinator.shouldAttemptAutoRepair(disabled),
      isFalse,
    );
    expect(
      TodayNotificationCoordinator.shouldAttemptAutoRepair(
        const NotificationDiagnostics.unsupported(),
      ),
      isFalse,
    );
  });

  test('buildDiagnostics detecta faltantes y sobrantes por sourceKey exacta', () {
    final diagnostics = TodayNotificationCoordinator.buildDiagnostics(
      notificationsEnabled: true,
      pendingDeviceNotificationsCount: 2,
      pendingDeviceSourceKeys: const {
        'routine:normal:2026-04-07:block-1',
        'dated:2026-04-08:dated-extra',
      },
      previewEntries: [
        NotificationPreviewEntry(
          id: 1,
          sourceKey: 'routine:normal:2026-04-07:block-1',
          title: 'Oracion',
          body: 'Normal | 06:00',
          when: DateTime(2026, 4, 7, 6, 0),
          payload: 'routine:normal:2026-04-07:block-1',
        ),
        NotificationPreviewEntry(
          id: 2,
          sourceKey: 'dated:2026-04-07:dated-1',
          title: 'Reunion',
          body: '07 abr | 09:00',
          when: DateTime(2026, 4, 7, 9, 0),
          payload: 'dated:2026-04-07:dated-1',
        ),
      ],
      refreshedAt: DateTime(2026, 4, 7, 5, 0),
    );

    expect(diagnostics.usedExactSourceComparison, isTrue);
    expect(diagnostics.missingDeviceNotificationsCount, 1);
    expect(diagnostics.unexpectedDeviceNotificationsCount, 1);
    expect(diagnostics.isScheduleAligned, isFalse);
  });

  test('buildStatusDescription explica cuando la agenda no esta alineada', () {
    final diagnostics = NotificationDiagnostics(
      supportsLocalNotifications: true,
      notificationsEnabled: true,
      scheduledNotificationsCount: 3,
      pendingDeviceNotificationsCount: 1,
      missingDeviceNotificationsCount: 2,
      unexpectedDeviceNotificationsCount: 0,
      usedExactSourceComparison: true,
      isScheduleAligned: false,
      scheduledDatedNotificationsCount: 1,
      nextScheduledAt: DateTime(2026, 4, 7, 10, 0),
      lastRefreshedAt: DateTime(2026, 4, 7, 9, 0),
    );

    expect(
      TodayNotificationCoordinator.buildStatusDescription(diagnostics),
      allOf(contains('no coincide'), contains('Faltan 2')),
    );
  });

  test('buildStatusDescription explica cuando la auto-reparacion no basto', () {
    final diagnostics = NotificationDiagnostics(
      supportsLocalNotifications: true,
      notificationsEnabled: true,
      scheduledNotificationsCount: 3,
      pendingDeviceNotificationsCount: 1,
      missingDeviceNotificationsCount: 2,
      unexpectedDeviceNotificationsCount: 1,
      usedExactSourceComparison: true,
      isScheduleAligned: false,
      autoRepairAttempted: true,
      nextScheduledAt: DateTime(2026, 4, 7, 10, 0),
      lastRefreshedAt: DateTime(2026, 4, 7, 9, 0),
    );

    expect(
      TodayNotificationCoordinator.buildStatusDescription(diagnostics),
      allOf(contains('intento corregir'), contains('todavia no coincide')),
    );
  });

  test('buildStatusDescription resume cuando la auto-reparacion resolvio', () {
    final diagnostics = NotificationDiagnostics(
      supportsLocalNotifications: true,
      notificationsEnabled: true,
      scheduledNotificationsCount: 2,
      pendingDeviceNotificationsCount: 2,
      isScheduleAligned: true,
      autoRepairAttempted: true,
      autoRepairResolvedIssue: true,
      nextScheduledAt: DateTime(2026, 4, 7, 10, 0),
      lastRefreshedAt: DateTime(2026, 4, 7, 9, 0),
    );

    expect(
      TodayNotificationCoordinator.buildStatusDescription(diagnostics),
      contains('corrigio automaticamente'),
    );
  });

  test('buildStatusDescription resume siguiente recordatorio cuando esta alineada', () {
    final diagnostics = NotificationDiagnostics(
      supportsLocalNotifications: true,
      notificationsEnabled: true,
      scheduledNotificationsCount: 2,
      pendingDeviceNotificationsCount: 2,
      isScheduleAligned: true,
      scheduledDatedNotificationsCount: 1,
      nextScheduledAt: DateTime(2026, 4, 7, 10, 0),
      lastRefreshedAt: DateTime(2026, 4, 7, 9, 0),
    );

    expect(
      TodayNotificationCoordinator.buildStatusDescription(diagnostics),
      contains('siguiente ya quedo calculado'),
    );
  });

  test('buildStatusDescription cubre plataformas sin soporte', () {
    expect(
      TodayNotificationCoordinator.buildStatusDescription(
        const NotificationDiagnostics.unsupported(),
      ),
      contains('web'),
    );
  });
}
