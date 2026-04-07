import 'package:flutter/material.dart';
import 'package:ritual/core/utils/dated_entry_utils.dart';
import 'package:ritual/data/models/dated_block_entry.dart';

/// Tarjeta superior de la home con progreso, contexto y acciones/resumen.
///
/// Recibe widgets ya construidos para no duplicar reglas de negocio dentro de
/// la capa visual y mantener la presentacion aislada de `TodayPage`.
class TodayOverviewCard extends StatelessWidget {
  final Color progressColor;
  final String progressDescription;
  final List<Widget> headerChips;
  final String scheduleLabel;
  final List<Widget> noticeCards;
  final Widget? notificationCard;
  final Widget? suggestedRoutineCard;
  final Widget? upcomingEventsCard;
  final double progress;
  final List<Widget> insightChips;
  final String lastActiveLabel;

  const TodayOverviewCard({
    super.key,
    required this.progressColor,
    required this.progressDescription,
    required this.headerChips,
    required this.scheduleLabel,
    required this.noticeCards,
    required this.notificationCard,
    required this.suggestedRoutineCard,
    required this.upcomingEventsCard,
    required this.progress,
    required this.insightChips,
    required this.lastActiveLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            progressColor.withValues(alpha: 0.28),
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: progressColor.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progreso del dia',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progressDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: headerChips,
          ),
          const SizedBox(height: 8),
          Text(
            scheduleLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          if (noticeCards.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...noticeCards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: card,
                  ),
                ),
          ],
          if (notificationCard != null) ...[
            const SizedBox(height: 6),
            notificationCard!,
          ],
          if (suggestedRoutineCard != null) ...[
            const SizedBox(height: 6),
            suggestedRoutineCard!,
          ],
          if (upcomingEventsCard != null) ...[
            const SizedBox(height: 6),
            upcomingEventsCard!,
          ],
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 12,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  backgroundColor: Colors.white12,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: insightChips,
          ),
          const SizedBox(height: 10),
          Text(
            lastActiveLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de agenda puntual cercana para no depender solo del calendario.
class TodayUpcomingDatedEventsCard extends StatelessWidget {
  final DateTime todayDate;
  final String Function(DatedBlockEntry entry) dateLabelBuilder;
  final List<DatedBlockEntry> entries;
  final Set<String> scheduledNotificationSourceKeys;
  final Widget Function(DatedBlockEntry entry) actionsBuilder;
  final VoidCallback onOpenCalendar;

  const TodayUpcomingDatedEventsCard({
    super.key,
    required this.todayDate,
    required this.dateLabelBuilder,
    required this.entries,
    required this.scheduledNotificationSourceKeys,
    required this.actionsBuilder,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A6B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF7A6B).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proximos eventos puntuales',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bloques aislados por fecha que no modifican tu rutina base.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          ...entries.map((entry) {
            final isTodayEvent = DatedEntryUtils.isToday(
              entry: entry,
              todayDate: todayDate,
            );
            final pushLabel = DatedEntryUtils.buildPushLabel(
              entry: entry,
              scheduledSourceKeys: scheduledNotificationSourceKeys,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A6B).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: Color(0xFFFF7A6B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.block.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${isTodayEvent ? 'Hoy' : dateLabelBuilder(entry)} | ${entry.block.start} - ${entry.block.end}',
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
                              visualDensity: VisualDensity.compact,
                              avatar:
                                  const Icon(Icons.event_note_rounded, size: 16),
                              label: Text(dateLabelBuilder(entry)),
                            ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(
                                entry.block.isDone
                                    ? Icons.task_alt_rounded
                                    : Icons.pending_actions_rounded,
                                size: 16,
                              ),
                              label: Text(
                                DatedEntryUtils.buildStatusLabel(
                                  entry: entry,
                                  todayDate: todayDate,
                                ),
                              ),
                            ),
                            if (pushLabel != null)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(
                                  entry.block.isDone
                                      ? Icons.notifications_off_rounded
                                      : pushLabel == 'Push programado'
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_paused_rounded,
                                  size: 16,
                                ),
                                label: Text(pushLabel),
                              ),
                          ],
                        ),
                        if (entry.block.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.block.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actionsBuilder(entry),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: onOpenCalendar,
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('Ver calendario'),
          ),
        ],
      ),
    );
  }
}
