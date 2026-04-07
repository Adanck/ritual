import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/core/models/notification_diagnostics.dart';
import 'package:ritual/core/services/today_notification_coordinator.dart';

void main() {
  test('buildStatusDescription explica cuando la agenda no esta alineada', () {
    final diagnostics = NotificationDiagnostics(
      supportsLocalNotifications: true,
      notificationsEnabled: true,
      scheduledNotificationsCount: 3,
      pendingDeviceNotificationsCount: 1,
      isScheduleAligned: false,
      scheduledDatedNotificationsCount: 1,
      nextScheduledAt: DateTime(2026, 4, 7, 10, 0),
      lastRefreshedAt: DateTime(2026, 4, 7, 9, 0),
    );

    expect(
      TodayNotificationCoordinator.buildStatusDescription(diagnostics),
      contains('no coincide'),
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
