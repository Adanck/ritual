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
  final bool isScheduleAligned;
  final DateTime? nextScheduledAt;
  final DateTime? lastRefreshedAt;

  const NotificationDiagnostics({
    required this.supportsLocalNotifications,
    required this.notificationsEnabled,
    required this.scheduledNotificationsCount,
    required this.pendingDeviceNotificationsCount,
    this.scheduledDatedNotificationsCount = 0,
    this.isScheduleAligned = true,
    this.nextScheduledAt,
    this.lastRefreshedAt,
  });

  const NotificationDiagnostics.unsupported()
      : supportsLocalNotifications = false,
        notificationsEnabled = false,
        scheduledNotificationsCount = 0,
        pendingDeviceNotificationsCount = 0,
        scheduledDatedNotificationsCount = 0,
        isScheduleAligned = true,
        nextScheduledAt = null,
        lastRefreshedAt = null;
}
