import 'package:flutter/material.dart';
import 'package:ritual/data/models/block_type.dart';

/// Tarjeta visual reutilizable para renderizar un bloque del dia.
class TimeBlock extends StatelessWidget {
  final String start;
  final String end;
  final String title;
  final String description;
  final BlockType type;
  final bool countsTowardProgress;
  final bool isDone;
  final VoidCallback? onTap;
  final Widget? secondaryAction;

  const TimeBlock({
    super.key,
    required this.start,
    required this.end,
    required this.title,
    required this.description,
    required this.type,
    required this.countsTowardProgress,
    required this.isDone,
    this.onTap,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = switch (type) {
      BlockType.habit => const Color(0xFF41C47B),
      BlockType.commitment => const Color(0xFF4DA3FF),
      BlockType.visual => const Color(0xFFB0BAC5),
      BlockType.reminder => const Color(0xFFFFA24D),
    };

    return Card(
      color: isDone ? color.withValues(alpha: 0.16) : theme.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Text(
          '$start\n$end',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              switch (type) {
                BlockType.habit => 'H\u00E1bito',
                BlockType.commitment => 'Compromiso',
                BlockType.visual => 'Visual',
                BlockType.reminder => 'Recordatorio',
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!countsTowardProgress) ...[
              const SizedBox(height: 4),
              Text(
                'No cuenta para el progreso del d\u00EDa',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Icon(
                isDone
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: ValueKey(isDone),
                color: isDone ? color : Colors.white38,
              ),
            ),
            if (secondaryAction != null) ...[
              const SizedBox(width: 10),
              secondaryAction!,
            ],
          ],
        ),
      ),
    );
  }
}
