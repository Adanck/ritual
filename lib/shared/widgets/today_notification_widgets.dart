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
  final VoidCallback onOpenAgenda;
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
    required this.onOpenAgenda,
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
              if (diagnostics.supportsLocalNotifications &&
                  diagnostics.missingDeviceNotificationsCount > 0)
                Chip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                  label: Text(
                    '${diagnostics.missingDeviceNotificationsCount} faltan',
                  ),
                ),
              if (diagnostics.supportsLocalNotifications &&
                  diagnostics.unexpectedDeviceNotificationsCount > 0)
                Chip(
                  avatar: const Icon(Icons.playlist_remove_rounded, size: 18),
                  label: Text(
                    '${diagnostics.unexpectedDeviceNotificationsCount} sobrantes',
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
              if (diagnostics.supportsLocalNotifications &&
                  diagnostics.autoRepairResolvedIssue)
                const Chip(
                  avatar: Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: Text('Auto-reparada'),
                ),
              if (diagnostics.supportsLocalNotifications &&
                  diagnostics.autoRepairAttempted &&
                  !diagnostics.autoRepairResolvedIssue)
                const Chip(
                  avatar: Icon(Icons.handyman_rounded, size: 18),
                  label: Text('Auto-reparacion intentada'),
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
                FilledButton.icon(
                  onPressed: isActionInProgress ? null : onOpenAgenda,
                  icon: const Icon(Icons.view_list_rounded),
                  label: const Text('Ver agenda'),
                ),
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

/// Hoja informativa con la agenda esperada de recordatorios de Ritual.
///
/// Ayuda a validar visualmente si los recordatorios que la app espera tener
/// agendados coinciden con lo que el dispositivo reporta como pendiente.
class TodayNotificationAgendaSheet extends StatelessWidget {
  final List<NotificationAgendaItemData> items;
  final List<String> unexpectedSourceKeys;
  final String Function(DateTime value) formatWhen;

  const TodayNotificationAgendaSheet({
    super.key,
    required this.items,
    this.unexpectedSourceKeys = const [],
    required this.formatWhen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agenda de recordatorios',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aqui ves los recordatorios que Ritual espera tener programados en este dispositivo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (unexpectedSourceKeys.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA24D).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFA24D).withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFD36C),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'El dispositivo todavia reporta ${unexpectedSourceKeys.length} recordatorios extra que Ritual ya no espera. Usa "Reagendar" si acabas de editar o borrar bloques.',
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
            const SizedBox(height: 16),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: const Text(
                  'No hay recordatorios futuros en la agenda actual.',
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: item.isPresentOnDevice
                                  ? const Color(0xFF2DD4BF).withValues(alpha: 0.12)
                                  : const Color(0xFFFFA24D).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.isPresentOnDevice
                                  ? Icons.verified_rounded
                                  : Icons.sync_problem_rounded,
                              color: item.isPresentOnDevice
                                  ? const Color(0xFF2DD4BF)
                                  : const Color(0xFFFFA24D),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.body,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      label: Text(formatWhen(item.when)),
                                    ),
                                    if (item.isDatedEvent)
                                      const Chip(
                                        label: Text('Puntual'),
                                      ),
                                    Chip(
                                      label: Text(
                                        item.isPresentOnDevice
                                            ? 'En dispositivo'
                                            : 'Pendiente de resincronizar',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NotificationAgendaItemData {
  final String sourceKey;
  final String title;
  final String body;
  final DateTime when;
  final bool isPresentOnDevice;

  const NotificationAgendaItemData({
    required this.sourceKey,
    required this.title,
    required this.body,
    required this.when,
    required this.isPresentOnDevice,
  });

  bool get isDatedEvent => sourceKey.startsWith('dated:');
}
