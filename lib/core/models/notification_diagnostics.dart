/// Estado resumido del sistema de notificaciones locales.
///
/// Se usa para que la UI pueda mostrar permisos, cantidad de recordatorios
/// programados y soporte de plataforma sin depender de detalles del plugin.
class NotificationDiagnostics {
  final bool supportsLocalNotifications;
  final bool? notificationsEnabled;
  final int scheduledNotificationsCount;
  final int pendingDeviceNotificationsCount;
  final int scheduledDatedNotificationsCount;
  final int missingDeviceNotificationsCount;
  final int unexpectedDeviceNotificationsCount;
  final bool usedExactSourceComparison;
  final bool isScheduleAligned;
  final bool autoRepairAttempted;
  final bool autoRepairResolvedIssue;
  final DateTime? nextScheduledAt;
  final DateTime? lastRefreshedAt;
  final List<String> deviceScheduledSourceKeys;

  const NotificationDiagnostics({
    required this.supportsLocalNotifications,
    required this.notificationsEnabled,
    required this.scheduledNotificationsCount,
    required this.pendingDeviceNotificationsCount,
    this.scheduledDatedNotificationsCount = 0,
    this.missingDeviceNotificationsCount = 0,
    this.unexpectedDeviceNotificationsCount = 0,
    this.usedExactSourceComparison = false,
    this.isScheduleAligned = true,
    this.autoRepairAttempted = false,
    this.autoRepairResolvedIssue = false,
    this.nextScheduledAt,
    this.lastRefreshedAt,
    this.deviceScheduledSourceKeys = const [],
  });

  const NotificationDiagnostics.unsupported()
      : supportsLocalNotifications = false,
        notificationsEnabled = false,
        scheduledNotificationsCount = 0,
        pendingDeviceNotificationsCount = 0,
        scheduledDatedNotificationsCount = 0,
        missingDeviceNotificationsCount = 0,
        unexpectedDeviceNotificationsCount = 0,
        usedExactSourceComparison = false,
        isScheduleAligned = true,
        autoRepairAttempted = false,
        autoRepairResolvedIssue = false,
        nextScheduledAt = null,
        lastRefreshedAt = null,
        deviceScheduledSourceKeys = const [];
}
