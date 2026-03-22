import 'package:flutter/material.dart';
import 'package:ritual/data/models/block_type.dart';

/// Tarjeta visual reutilizable para renderizar un bloque del dia.
class TimeBlock extends StatelessWidget {
  final String start;
  final String end;
  final String title;
  final String description;
  final BlockType type;
  final bool isDone;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  const TimeBlock({
    super.key,
    required this.start,
    required this.end,
    required this.title,
    required this.description,
    required this.type,
    required this.isDone,
    required this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = switch (type) {
      BlockType.habit => const Color(0xFF41C47B),
      BlockType.commitment => const Color(0xFF4DA3FF),
      BlockType.visual => const Color(0xFFB0BAC5),
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
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
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
        trailing: AnimatedSwitcher(
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
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            key: ValueKey(isDone),
            color: isDone ? color : Colors.white38,
          ),
        ),
      ),
    );
  }
}
