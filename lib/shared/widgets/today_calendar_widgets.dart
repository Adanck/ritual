import 'package:flutter/material.dart';

/// Item de leyenda del calendario.
class TodayCalendarLegendItem extends StatelessWidget {
  final Widget marker;
  final String label;

  const TodayCalendarLegendItem({
    super.key,
    required this.marker,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

/// Celda de encabezado para el dia de la semana.
class TodayCalendarWeekdayCell extends StatelessWidget {
  final String label;

  const TodayCalendarWeekdayCell({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white60,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Chip resumido para insights del mes.
class TodayCalendarSummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const TodayCalendarSummaryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$value $label',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Celda principal del calendario mensual.
class TodayCalendarDayTile extends StatelessWidget {
  final DateTime day;
  final DateTime visibleMonth;
  final bool isToday;
  final bool isFuture;
  final bool hasScheduledRoutine;
  final bool hasActivity;
  final bool isCompletedDay;
  final bool hasDatedEntries;
  final int routineCount;
  final VoidCallback onTap;

  const TodayCalendarDayTile({
    super.key,
    required this.day,
    required this.visibleMonth,
    required this.isToday,
    required this.isFuture,
    required this.hasScheduledRoutine,
    required this.hasActivity,
    required this.isCompletedDay,
    required this.hasDatedEntries,
    required this.routineCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInVisibleMonth = day.month == visibleMonth.month;
    final markerColor =
        isCompletedDay ? const Color(0xFFFFA24D) : const Color(0xFF4DA3FF);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: hasActivity
              ? markerColor.withValues(alpha: 0.12)
              : routineCount > 1
                  ? const Color(0xFF4DA3FF).withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isToday
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : hasScheduledRoutine && isFuture
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.day.toString(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isInVisibleMonth ? null : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasActivity)
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: markerColor,
                        )
                      else if (hasScheduledRoutine && isFuture)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(width: 16, height: 16),
                      if (hasDatedEntries) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.event_available_rounded,
                          size: 14,
                          color: const Color(0xFFFF7A6B).withValues(
                            alpha: 0.92,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (routineCount > 1)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4DA3FF).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$routineCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4DA3FF),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
