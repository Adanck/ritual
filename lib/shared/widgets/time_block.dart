import 'package:flutter/material.dart';
import 'package:ritual/data/models/block_type.dart';

class TimeBlock extends StatelessWidget {
  final String start;
  final String end;
  final String title;
  final BlockType type;
  final bool isDone;
  final VoidCallback onToggle;

  const TimeBlock({
    super.key,
    required this.start,
    required this.end,
    required this.title,
    required this.type,
    required this.isDone,
    required this.onToggle,
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
        subtitle: Text(
          switch (type) {
            BlockType.habit => 'Hábito',
            BlockType.commitment => 'Compromiso',
            BlockType.visual => 'Visual',
          },
          style: theme.textTheme.bodySmall?.copyWith(
            color: color.withValues(alpha: 0.92),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: type == BlockType.habit
            ? IconButton(
                icon: Icon(
                  isDone ? Icons.check_circle : Icons.check_circle_outline,
                  color: isDone ? color : null,
                ),
                onPressed: onToggle,
              )
            : null,
      ),
    );
  }
}
