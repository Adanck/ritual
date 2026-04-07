/// Estado resumido del sistema de notificaciones locales.
///
/// Se usa para que la UI pueda mostrar permisos, cantidad de recordatorios
/// programados y soporte de plataforma sin depender de detalles del plugin.
class NotificationDiagnostics {
  final bool supportsLocalNotifications;
  final bool? notificationsEnabled;
  final int scheduledNotificationsCount;
  final int scheduledDatedNotificationsCount;
  final DateTime? nextScheduledAt;

  const NotificationDiagnostics({
    required this.supportsLocalNotifications,
    required this.notificationsEnabled,
    required this.scheduledNotificationsCount,
    this.scheduledDatedNotificationsCount = 0,
    this.nextScheduledAt,
  });

  const NotificationDiagnostics.unsupported()
      : supportsLocalNotifications = false,
        notificationsEnabled = false,
        scheduledNotificationsCount = 0,
        scheduledDatedNotificationsCount = 0,
        nextScheduledAt = null;
}
