import 'package:flutter/material.dart';

/// Seccion reutilizable para agrupar rutinas por periodo o estado.
class TodayRoutineManagerSection extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const TodayRoutineManagerSection({
    super.key,
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// Tarjeta de administracion de una rutina con estado, metrics y acciones.
class TodayRoutineManagerCard extends StatelessWidget {
  final String name;
  final bool isSelected;
  final String scheduleShortLabel;
  final String scheduleDisplayLabel;
  final String scheduleStatusLabel;
  final Color scheduleStatusColor;
  final int blocksCount;
  final String? periodHintLabel;
  final String routineHint;
  final List<Widget> metricChips;
  final List<Widget> actionButtons;

  const TodayRoutineManagerCard({
    super.key,
    required this.name,
    required this.isSelected,
    required this.scheduleShortLabel,
    required this.scheduleDisplayLabel,
    required this.scheduleStatusLabel,
    required this.scheduleStatusColor,
    required this.blocksCount,
    required this.periodHintLabel,
    required this.routineHint,
    required this.metricChips,
    required this.actionButtons,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.view_list_rounded, size: 18),
                  label: Text('$blocksCount bloques'),
                ),
                Chip(
                  avatar: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(scheduleShortLabel),
                ),
                Chip(
                  backgroundColor: scheduleStatusColor.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: scheduleStatusColor.withValues(alpha: 0.24),
                  ),
                  avatar: Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: scheduleStatusColor,
                  ),
                  label: Text(scheduleStatusLabel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              scheduleDisplayLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (periodHintLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                periodHintLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              routineHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (metricChips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metricChips,
              ),
            ],
            if (actionButtons.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actionButtons,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
