import 'package:flutter/material.dart';
import 'package:ritual/core/models/notification_diagnostics.dart';

/// Tarjeta de diagnostico de notificaciones para la home.
///
/// Recibe callbacks y textos ya resueltos para mantener la logica fuera de la
/// capa visual y reutilizar la presentacion si mas adelante abrimos otra vista
/// de diagnostico.
class TodayNotificationStatusCard extends StatelessWidget {
  final NotificationDiagnostics diagnostics;
  final int pushEnabledBlocksCount;
  final String statusDescription;
  final String Function(DateTime value) formatWhen;
  final bool isActionInProgress;
  final VoidCallback onReviewPermissions;
  final VoidCallback onResync;
  final VoidCallback onSendTest;

  const TodayNotificationStatusCard({
    super.key,
    required this.diagnostics,
    required this.pushEnabledBlocksCount,
    required this.statusDescription,
    required this.formatWhen,
    required this.isActionInProgress,
    required this.onReviewPermissions,
    required this.onResync,
    required this.onSendTest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA24D).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFA24D).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recordatorios del dispositivo',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar:
                    const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text('$pushEnabledBlocksCount bloques con push'),
              ),
              if (diagnostics.supportsLocalNotifications)
                Chip(
                  avatar: Icon(
                    diagnostics.notificationsEnabled == false
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_rounded,
                    size: 18,
                  ),
                  label: Text(
                    diagnostics.notificationsEnabled == false
                        ? 'Permiso apagado'
                        : diagnostics.notificationsEnabled == true
                            ? 'Permiso activo'
                            : 'Permiso no confirmado',
                  ),
                ),
              if (diagnostics.supportsLocalNotifications)
                Chip(
                  avatar: const Icon(Icons.schedule_send_rounded, size: 18),
                  label: Text('${diagnostics.scheduledNotificationsCount} programadas'),
                ),
              if (diagnostics.supportsLocalNotifications)
                Chip(
                  avatar: const Icon(Icons.phone_android_rounded, size: 18),
                  label: Text(
                    '${diagnostics.pendingDeviceNotificationsCount} en dispositivo',
                  ),
                ),
              if (diagnostics.supportsLocalNotifications &&
                  diagnostics.scheduledDatedNotificationsCount > 0)
                Chip(
                  avatar: const Icon(Icons.event_available_rounded, size: 18),
                  label: Text(
                    '${diagnostics.scheduledDatedNotificationsCount} puntuales',
                  ),
                ),
              if (diagnostics.supportsLocalNotifications)
                Chip(
                  avatar: Icon(
                    diagnostics.isScheduleAligned
                        ? Icons.verified_rounded
                        : Icons.sync_problem_rounded,
                    size: 18,
                  ),
                  label: Text(
                    diagnostics.isScheduleAligned
                        ? 'Agenda alineada'
                        : 'Agenda por revisar',
                  ),
                ),
            ],
          ),
          if (diagnostics.nextScheduledAt != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.alarm_on_rounded,
                    color: Color(0xFFFFD36C),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Proximo recordatorio: ${formatWhen(diagnostics.nextScheduledAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (diagnostics.lastRefreshedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ultima revision: ${formatWhen(diagnostics.lastRefreshedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (diagnostics.supportsLocalNotifications)
                FilledButton.tonalIcon(
                  onPressed: isActionInProgress ? null : onReviewPermissions,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Revisar permisos'),
                ),
              if (diagnostics.supportsLocalNotifications)
                OutlinedButton.icon(
                  onPressed: isActionInProgress ? null : onResync,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Reagendar'),
                ),
              if (diagnostics.supportsLocalNotifications)
                OutlinedButton.icon(
                  onPressed: isActionInProgress ? null : onSendTest,
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Probar ahora'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
