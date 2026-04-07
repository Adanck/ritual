import 'package:flutter/material.dart';
import 'package:ritual/core/utils/date_key.dart';
import 'package:ritual/data/models/daily_record.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/shared/widgets/time_block.dart';

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
  final bool hasPushEnabledDatedEntries;
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
    required this.hasPushEnabledDatedEntries,
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
                        if (hasPushEnabledDatedEntries) ...[
                          const SizedBox(width: 3),
                          Icon(
                            Icons.notifications_active_rounded,
                            size: 13,
                            color: const Color(0xFFFFD36C).withValues(
                              alpha: 0.96,
                            ),
                          ),
                        ],
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

/// Resume visualmente el estado de un registro diario.
///
/// Se usa tanto en el detalle de un dia historico como en la vista por fecha
/// del calendario para no repetir la misma semantica visual.
class TodayRecordStatusPill extends StatelessWidget {
  final DailyRecord record;

  const TodayRecordStatusPill({
    super.key,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = record.isCompletedDay
        ? const Color(0xFF41C47B)
        : record.hasAnyCompletedBlocks
            ? const Color(0xFF4DA3FF)
            : Colors.white54;
    final label = record.isCompletedDay
        ? 'Dia completo'
        : record.hasAnyCompletedBlocks
            ? 'Con avance'
            : 'Sin checks';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Contenido visual del detalle de un registro diario ya guardado.
///
/// La hoja modal vive en la pantalla, pero este widget encapsula la
/// presentacion para mantener la pagina principal mas liviana.
class TodayDailyRecordDetailView extends StatelessWidget {
  final DailyRecord record;
  final double progress;
  final Color progressColor;
  final String progressLabel;

  const TodayDailyRecordDetailView({
    super.key,
    required this.record,
    required this.progress,
    required this.progressColor,
    required this.progressLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateKey.formatForDisplay(
            record.dateKey,
            includeWeekday: true,
          ),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${record.routineName} · $progressLabel',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TodayRecordStatusPill(record: record),
            Chip(
              avatar: const Icon(Icons.percent_rounded, size: 18),
              label: Text('${(progress * 100).round()}% progreso'),
            ),
            Chip(
              avatar: const Icon(Icons.task_alt_outlined, size: 18),
              label: Text('${record.completedBlocksCount} completados'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            backgroundColor: Colors.white12,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: record.blocks.isEmpty
              ? Center(
                  child: Text(
                    'Este dia no tuvo bloques registrados.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: record.blocks.length,
                  itemBuilder: (context, index) {
                    final block = record.blocks[index];

                    return TimeBlock(
                      start: block.start,
                      end: block.end,
                      title: block.title,
                      description: block.description,
                      type: block.type,
                      countsTowardProgress: block.countsTowardProgress,
                      receivesPushNotification:
                          block.receivesPushNotification,
                      isDone: block.isDone,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Contenido visual del detalle de una fecha dentro del calendario.
///
/// Este widget encapsula los tres estados del dia: registro real, vista
/// previa y fecha vacia sin plan asociado.
class TodayCalendarDateDetailView extends StatelessWidget {
  final DateTime date;
  final DailyRecord? record;
  final String? recordProgressLabel;
  final Routine activeRoutine;
  final List<Routine> routinesForDate;
  final Routine? suggestedRoutine;
  final bool hasRoutinePreview;
  final bool hasDatedEntries;
  final bool hasScheduledRoutine;
  final bool isFuture;
  final bool canManageDatedEntries;
  final List<DayBlock> recordBlocks;
  final List<DayBlock> previewBlocks;
  final List<DatedBlockEntry> datedEntries;
  final int completedBlockCount;
  final int previewBlockCount;
  final double progress;
  final Color progressColor;
  final Set<String> scheduledNotificationSourceKeys;
  final Future<void> Function() onAddDatedBlock;
  final Future<void> Function() onManageRoutines;
  final Widget Function(DatedBlockEntry entry) datedEntryActionsBuilder;

  const TodayCalendarDateDetailView({
    super.key,
    required this.date,
    required this.record,
    required this.recordProgressLabel,
    required this.activeRoutine,
    required this.routinesForDate,
    required this.suggestedRoutine,
    required this.hasRoutinePreview,
    required this.hasDatedEntries,
    required this.hasScheduledRoutine,
    required this.isFuture,
    required this.canManageDatedEntries,
    required this.recordBlocks,
    required this.previewBlocks,
    required this.datedEntries,
    required this.completedBlockCount,
    required this.previewBlockCount,
    required this.progress,
    required this.progressColor,
    this.scheduledNotificationSourceKeys = const {},
    required this.onAddDatedBlock,
    required this.onManageRoutines,
    required this.datedEntryActionsBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateKey.formatForDisplay(
            DateKey.fromDate(date),
            includeWeekday: true,
          ),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _buildSubtitle(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _buildHeaderChips(),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            backgroundColor: Colors.white12,
          ),
        ),
        if (routinesForDate.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TodayDateRoutinesCard(
            routinesForDate: routinesForDate,
            suggestedRoutine: suggestedRoutine,
          ),
        ],
        if (canManageDatedEntries) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () async {
                await onAddDatedBlock();
              },
              icon: const Icon(Icons.event_available_rounded),
              label: Text(
                isFuture
                    ? 'Agregar bloque puntual para esta fecha'
                    : 'Agregar bloque puntual para hoy',
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Expanded(
          child: _buildBody(context),
        ),
      ],
    );
  }

  String _buildSubtitle() {
    if (record != null) {
      return '${record!.routineName} | ${recordProgressLabel ?? ''}';
    }

    if (hasRoutinePreview) {
      return isFuture
          ? 'Vista previa de ${activeRoutine.name} para esta fecha'
          : 'No hay registro guardado, pero esta rutina aplica en esta fecha';
    }

    if (hasDatedEntries) {
      return 'No hay rutina base para esta fecha, pero si tienes eventos puntuales guardados.';
    }

    return 'No hay una rutina configurada para esta fecha.';
  }

  List<Widget> _buildHeaderChips() {
    if (record != null) {
      return [
        TodayRecordStatusPill(record: record!),
        Chip(
          avatar: const Icon(Icons.percent_rounded, size: 18),
          label: Text('${(progress * 100).round()}% progreso'),
        ),
        Chip(
          avatar: const Icon(Icons.task_alt_outlined, size: 18),
          label: Text('$completedBlockCount completados'),
        ),
        if (routinesForDate.length > 1)
          Chip(
            avatar: const Icon(Icons.layers_rounded, size: 18),
            label: Text('${routinesForDate.length} rutinas aplican'),
          ),
      ];
    }

    if (hasScheduledRoutine) {
      return [
        Chip(
          avatar: const Icon(Icons.visibility_outlined, size: 18),
          label: Text(
            hasRoutinePreview
                ? (isFuture ? 'Vista previa' : 'Sin registro')
                : 'Solo eventos puntuales',
          ),
        ),
        Chip(
          avatar: const Icon(Icons.view_list_rounded, size: 18),
          label: Text('$previewBlockCount bloques'),
        ),
        if (datedEntries.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.event_available_rounded, size: 18),
            label: Text('${datedEntries.length} puntuales'),
          ),
        if (routinesForDate.length > 1)
          Chip(
            avatar: const Icon(Icons.layers_rounded, size: 18),
            label: Text('${routinesForDate.length} rutinas aplican'),
          ),
      ];
    }

    return const [
      Chip(
        avatar: Icon(Icons.info_outline_rounded, size: 18),
        label: Text('Sin plan para este dia'),
      ),
    ];
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    if (record != null) {
      if (recordBlocks.isEmpty && datedEntries.isEmpty) {
        return Center(
          child: Text(
            'Este dia no tuvo bloques registrados.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
        );
      }

      return ListView(
        children: [
          if (recordBlocks.isNotEmpty) ...[
            _TodayDateSectionTitle(label: 'Rutina registrada'),
            const SizedBox(height: 10),
            ...recordBlocks.map(_buildTimeBlock),
          ],
          if (datedEntries.isNotEmpty) ...[
            if (recordBlocks.isNotEmpty) const SizedBox(height: 14),
            _TodayDateSectionTitle(label: 'Eventos puntuales'),
            const SizedBox(height: 8),
            ...datedEntries.map(_buildDatedEntryCard),
          ],
        ],
      );
    }

    if (hasScheduledRoutine) {
      if (previewBlocks.isEmpty && datedEntries.isEmpty) {
        return Center(
          child: Text(
            'La rutina aplica en esta fecha, pero todavia no tiene bloques.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
        );
      }

      return ListView(
        children: [
          if (previewBlocks.isNotEmpty) ...[
            _TodayDateSectionTitle(
              label: hasRoutinePreview ? 'Vista previa de la rutina' : 'Plan base',
            ),
            const SizedBox(height: 10),
            ...previewBlocks.map(_buildTimeBlock),
          ],
          if (datedEntries.isNotEmpty) ...[
            if (previewBlocks.isNotEmpty) const SizedBox(height: 14),
            _TodayDateSectionTitle(label: 'Eventos puntuales'),
            const SizedBox(height: 8),
            ...datedEntries.map(_buildDatedEntryCard),
          ],
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 52,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'No hay una rutina configurada para esta fecha',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes crear o editar una rutina con rango de fechas para planificar este dia, o dejar un bloque puntual si solo necesitas algo aislado.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await onManageRoutines();
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Gestionar rutinas'),
                ),
                if (canManageDatedEntries)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await onAddDatedBlock();
                    },
                    icon: const Icon(Icons.event_available_rounded),
                    label: const Text('Agregar evento puntual'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBlock(DayBlock block) {
    return TimeBlock(
      start: block.start,
      end: block.end,
      title: block.title,
      description: block.description,
      type: block.type,
      countsTowardProgress: block.countsTowardProgress,
      receivesPushNotification: block.receivesPushNotification,
      isDone: block.isDone,
    );
  }

  Widget _buildDatedEntryCard(DatedBlockEntry entry) {
    final block = entry.block;
    final description = block.description.trim();
    final isScheduled = scheduledNotificationSourceKeys.contains(
      'dated:${entry.dateKey}:${entry.block.id}',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.event_available_rounded),
        title: Text(block.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${block.start} - ${block.end}${description.isEmpty ? '' : ' | $description'}',
            ),
            const SizedBox(height: 6),
            Text(
              block.isDone ? 'Estado: completado' : 'Estado: pendiente',
              style: TextStyle(
                color: block.isDone
                    ? const Color(0xFF41C47B)
                    : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (block.receivesPushNotification) ...[
              const SizedBox(height: 6),
              Text(
                block.isDone
                    ? 'Push omitido por completado'
                    : isScheduled
                        ? 'Push programado'
                        : 'Push activado',
                style: const TextStyle(
                  color: Color(0xFFFFD36C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        trailing: canManageDatedEntries ? datedEntryActionsBuilder(entry) : null,
      ),
    );
  }
}

class _TodayDateSectionTitle extends StatelessWidget {
  final String label;

  const _TodayDateSectionTitle({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _TodayDateRoutinesCard extends StatelessWidget {
  final List<Routine> routinesForDate;
  final Routine? suggestedRoutine;

  const _TodayDateRoutinesCard({
    required this.routinesForDate,
    required this.suggestedRoutine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rutinas que aplican en esta fecha',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            suggestedRoutine == null
                ? 'No hay una sugerencia clara para este dia.'
                : 'La rutina recomendada para esta fecha es "${suggestedRoutine!.name}".',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: routinesForDate.take(4).map((routine) {
              final isRecommended = routine.id == suggestedRoutine?.id;

              return Chip(
                avatar: Icon(
                  isRecommended
                      ? Icons.auto_awesome_rounded
                      : Icons.event_repeat_rounded,
                  size: 18,
                ),
                label: Text(routine.name),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
