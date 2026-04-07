/// Estado resumido del sistema de notificaciones locales.
///
/// Se usa para que la UI pueda mostrar permisos, cantidad de recordatorios
/// programados y soporte de plataforma sin depender de detalles del plugin.
class NotificationDiagnostics {
  final bool supportsLocalNotifications;
  final bool? notificationsEnabled;
  final int scheduledNotificationsCount;

  const NotificationDiagnostics({
    required this.supportsLocalNotifications,
    required this.notificationsEnabled,
    required this.scheduledNotificationsCount,
  });

  const NotificationDiagnostics.unsupported()
      : supportsLocalNotifications = false,
        notificationsEnabled = false,
        scheduledNotificationsCount = 0;
}
