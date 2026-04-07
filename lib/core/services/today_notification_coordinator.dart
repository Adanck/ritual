import 'package:ritual/core/models/notification_diagnostics.dart';
import 'package:ritual/core/services/notification_service.dart';
import 'package:ritual/data/models/day_block.dart';

/// Resultado de una accion manual de notificaciones disparada desde la UI.
class NotificationActionResult {
  final NotificationDiagnostics diagnostics;
  final String message;

  const NotificationActionResult({
    required this.diagnostics,
    required this.message,
  });
}

/// Coordina las operaciones de diagnostico y prueba de notificaciones para la
/// pantalla principal.
///
/// La idea es sacar de la UI la secuencia de pedir permisos, refrescar estado,
/// reagendar recordatorios y construir mensajes de feedback.
class TodayNotificationCoordinator {
  /// Consulta el estado actual de soporte, permisos y recordatorios futuros.
  static Future<NotificationDiagnostics> refreshDiagnostics({
    List<NotificationPreviewEntry>? previewEntries,
  }) async {
    if (!NotificationService.supportsLocalNotifications) {
      return const NotificationDiagnostics.unsupported();
    }

    final enabled = await NotificationService.areNotificationsEnabled();
    final pendingCount = await NotificationService.getPendingNotificationsCount();
    final scheduledCount = previewEntries?.length ?? pendingCount;
    final scheduledDatedNotificationsCount =
        previewEntries
            ?.where((entry) => entry.sourceKey.startsWith('dated:'))
            .length ??
        0;

    return NotificationDiagnostics(
      supportsLocalNotifications: true,
      notificationsEnabled: enabled,
      scheduledNotificationsCount: scheduledCount,
      pendingDeviceNotificationsCount: pendingCount,
      scheduledDatedNotificationsCount: scheduledDatedNotificationsCount,
      isScheduleAligned:
          previewEntries == null ? true : pendingCount == scheduledCount,
      nextScheduledAt:
          previewEntries == null || previewEntries.isEmpty
              ? null
              : previewEntries.first.when,
      lastRefreshedAt: DateTime.now(),
    );
  }

  /// Pide permisos y luego recalcula el diagnostico.
  static Future<NotificationActionResult> requestPermissions({
    required Future<void> Function() syncNotifications,
    required List<NotificationPreviewEntry> Function() getPreviewEntries,
  }) async {
    if (!NotificationService.supportsLocalNotifications) {
      return const NotificationActionResult(
        diagnostics: NotificationDiagnostics.unsupported(),
        message:
            'Esta plataforma no agenda notificaciones locales con la implementacion actual.',
      );
    }

    await NotificationService.requestPermissionsIfNeeded();
    await syncNotifications();
    final diagnostics = await refreshDiagnostics(
      previewEntries: getPreviewEntries(),
    );

    return NotificationActionResult(
      diagnostics: diagnostics,
      message: diagnostics.notificationsEnabled == false
          ? 'Ritual no pudo confirmar el permiso de notificaciones. Revisa la configuracion del dispositivo.'
          : 'Permisos de notificacion revisados.',
    );
  }

  /// Reagenda manualmente los recordatorios futuros y devuelve el nuevo estado.
  static Future<NotificationActionResult> resync({
    required Future<void> Function() syncNotifications,
    required List<NotificationPreviewEntry> Function() getPreviewEntries,
  }) async {
    if (!NotificationService.supportsLocalNotifications) {
      return const NotificationActionResult(
        diagnostics: NotificationDiagnostics.unsupported(),
        message:
            'Esta plataforma no agenda notificaciones locales con la implementacion actual.',
      );
    }

    await syncNotifications();
    final diagnostics = await refreshDiagnostics(
      previewEntries: getPreviewEntries(),
    );

    return NotificationActionResult(
      diagnostics: diagnostics,
      message: diagnostics.scheduledNotificationsCount == 0
          ? 'No hay recordatorios futuros por programar.'
          : 'Ritual reagendo ${diagnostics.scheduledNotificationsCount} recordatorios.',
    );
  }

  /// Lanza una notificacion inmediata y refresca el diagnostico.
  static Future<NotificationActionResult> sendTestNotification({
    required List<NotificationPreviewEntry> Function() getPreviewEntries,
  }) async {
    if (!NotificationService.supportsLocalNotifications) {
      return const NotificationActionResult(
        diagnostics: NotificationDiagnostics.unsupported(),
        message:
            'Esta plataforma no agenda notificaciones locales con la implementacion actual.',
      );
    }

    await NotificationService.showTestNotificationNow();
    final diagnostics = await refreshDiagnostics(
      previewEntries: getPreviewEntries(),
    );

    return NotificationActionResult(
      diagnostics: diagnostics,
      message:
          'Ritual envio una notificacion de prueba. Revisa el panel del dispositivo.',
    );
  }

  /// Cuando un bloque activa push, intenta dejar listo el permiso y la agenda.
  static Future<NotificationDiagnostics> prepareForBlockIfNeeded({
    required DayBlock block,
    required Future<void> Function() syncNotifications,
  }) async {
    if (!block.receivesPushNotification ||
        !NotificationService.supportsLocalNotifications) {
      return refreshDiagnostics();
    }

    await NotificationService.requestPermissionsIfNeeded();
    await syncNotifications();
    return refreshDiagnostics();
  }

  /// Texto listo para UI con el estado resumido de las notificaciones.
  static String buildStatusDescription(NotificationDiagnostics diagnostics) {
    if (!diagnostics.supportsLocalNotifications) {
      return 'Esta plataforma web conserva la preferencia, pero no agenda recordatorios locales.';
    }

    if (diagnostics.notificationsEnabled == false) {
      return 'Los recordatorios existen, pero el dispositivo parece tener las notificaciones desactivadas.';
    }

    if (!diagnostics.isScheduleAligned) {
      return 'La agenda del dispositivo no coincide todavia con lo que Ritual espera. Usa "Reagendar" si acabas de editar bloques o eventos.';
    }

    if (diagnostics.scheduledNotificationsCount == 0) {
      return 'Aun no hay recordatorios futuros programados. Revisa si los bloques con push estan en el futuro.';
    }

    if (diagnostics.nextScheduledAt != null) {
      return 'Ritual tiene ${diagnostics.scheduledNotificationsCount} recordatorios futuros programados y el siguiente ya quedo calculado.';
    }

    return 'Ritual tiene ${diagnostics.scheduledNotificationsCount} recordatorios futuros programados en este dispositivo.';
  }
}
