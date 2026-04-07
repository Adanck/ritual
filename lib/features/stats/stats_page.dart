import 'package:flutter/material.dart';
import 'package:ritual/core/utils/date_key.dart';
import 'package:ritual/core/utils/routine_history_insights.dart';
import 'package:ritual/core/utils/today_routine_utils.dart';
import 'package:ritual/data/models/daily_record.dart';
import 'package:ritual/data/models/routine.dart';

/// Filtros simples para leer las estadisticas por contexto temporal.
enum _StatsRoutineFilter {
  all,
  today,
  upcoming,
  library,
}

/// Pantalla dedicada para explorar estadisticas globales y por rutina.
///
/// La home conserva un resumen corto, pero esta vista da espacio para leer el
/// historial con mas calma sin mezclarlo con la operacion diaria del plan.
class StatsPage extends StatefulWidget {
  final List<Routine> routines;
  final List<DailyRecord> dailyRecords;
  final DateTime todayDate;
  final String? activeRoutineId;
  final String? suggestedRoutineId;

  const StatsPage({
    super.key,
    required this.routines,
    required this.dailyRecords,
    required this.todayDate,
    required this.activeRoutineId,
    required this.suggestedRoutineId,
  });

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _StatsRoutineFilter filter = _StatsRoutineFilter.all;

  Map<String, RoutineHistoryInsights> get insightsByRoutineId {
    return {
      for (final routine in widget.routines)
        routine.id: RoutineHistoryCalculator.calculate(
          records: widget.dailyRecords,
          routineId: routine.id,
          today: widget.todayDate,
        ),
    };
  }

  List<Routine> get filteredRoutines {
    final routines = [...widget.routines];

    bool matchesFilter(Routine routine) {
      switch (filter) {
        case _StatsRoutineFilter.all:
          return true;
        case _StatsRoutineFilter.today:
          return routine.appliesOn(widget.todayDate);
        case _StatsRoutineFilter.upcoming:
          return !routine.appliesOn(widget.todayDate) &&
              (routine.schedule.daysUntilStart(widget.todayDate) ?? 9999) >= 0 &&
              (routine.schedule.daysUntilStart(widget.todayDate) ?? 9999) <= 14;
        case _StatsRoutineFilter.library:
          return !routine.appliesOn(widget.todayDate) &&
              (routine.schedule.daysUntilStart(widget.todayDate) == null ||
                  routine.schedule.daysUntilStart(widget.todayDate)! > 14);
      }
    }

    routines.retainWhere(matchesFilter);
    routines.sort((a, b) {
      final aInsights = insightsByRoutineId[a.id]!;
      final bInsights = insightsByRoutineId[b.id]!;
      final aIsActive = a.id == widget.activeRoutineId ? 0 : 1;
      final bIsActive = b.id == widget.activeRoutineId ? 0 : 1;
      final activeCompare = aIsActive.compareTo(bIsActive);
      if (activeCompare != 0) return activeCompare;

      final streakCompare = bInsights.currentStreak.compareTo(aInsights.currentStreak);
      if (streakCompare != 0) return streakCompare;

      return TodayRoutineUtils.compareForTodaySuggestion(a, b);
    });

    return routines;
  }

  int get totalTrackedDays => insightsByRoutineId.values.fold<int>(
        0,
        (total, insights) => total + insights.trackedDays,
      );

  int get totalCompletedBlocks => insightsByRoutineId.values.fold<int>(
        0,
        (total, insights) => total + insights.completedBlocks,
      );

  int get totalCompletedDays => insightsByRoutineId.values.fold<int>(
        0,
        (total, insights) => total + insights.completedDays,
      );

  int get bestStreakAcrossRoutines => insightsByRoutineId.values.fold<int>(
        0,
        (best, insights) =>
            insights.bestStreak > best ? insights.bestStreak : best,
      );

  double get globalCompletionRate {
    final completed = insightsByRoutineId.values.fold<int>(
      0,
      (total, insights) => total + insights.progressBlocksCompleted,
    );
    final tracked = insightsByRoutineId.values.fold<int>(
      0,
      (total, insights) => total + insights.progressBlocksTracked,
    );
    if (tracked == 0) return 0;
    return completed / tracked;
  }

  int get routinesAvailableToday =>
      widget.routines.where((routine) => routine.appliesOn(widget.todayDate)).length;

  String formatPercent(double value) => '${(value * 100).round()}%';

  String buildRoutineSubtitle(Routine routine, RoutineHistoryInsights insights) {
    final lastActive = insights.lastActiveDateKey;
    final daysUntilStart = routine.schedule.daysUntilStart(widget.todayDate);
    final daysUntilEnd = routine.schedule.daysUntilEnd(widget.todayDate);

    if (routine.appliesOn(widget.todayDate) && daysUntilEnd == 0) {
      return 'Su periodo sugerido termina hoy.';
    }

    if (daysUntilStart != null && daysUntilStart <= 7) {
      return 'Empieza pronto. Conviene dejarla lista antes de usarla.';
    }

    if (lastActive != null) {
      return 'Ultima actividad: ${DateKey.formatForDisplay(lastActive)}';
    }

    return 'Sin actividad registrada todavia.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routineInsights = insightsByRoutineId;
    final routines = filteredRoutines;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadisticas'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _StatsSection(
            title: 'Vision general',
            description:
                'Una lectura rapida del sistema completo para entender constancia, volumen y salud general del plan.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatTile(
                  icon: Icons.auto_awesome_motion_rounded,
                  label: 'Rutinas',
                  value: '${widget.routines.length}',
                ),
                _StatTile(
                  icon: Icons.today_outlined,
                  label: 'Vigentes hoy',
                  value: '$routinesAvailableToday',
                ),
                _StatTile(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Mejor racha',
                  value: '$bestStreakAcrossRoutines',
                ),
                _StatTile(
                  icon: Icons.percent_rounded,
                  label: 'Cumplimiento global',
                  value: formatPercent(globalCompletionRate),
                ),
                _StatTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Dias seguidos',
                  value: '$totalTrackedDays',
                ),
                _StatTile(
                  icon: Icons.task_alt_outlined,
                  label: 'Bloques completados',
                  value: '$totalCompletedBlocks',
                ),
                _StatTile(
                  icon: Icons.verified_outlined,
                  label: 'Dias completos',
                  value: '$totalCompletedDays',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _StatsSection(
            title: 'Por rutina',
            description:
                'Filtra tus plantillas para ver cuales sostienen mejor la constancia y cuales necesitan ajuste.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(label: 'Todas', value: _StatsRoutineFilter.all),
                    _buildFilterChip(label: 'Hoy', value: _StatsRoutineFilter.today),
                    _buildFilterChip(
                      label: 'Proximas',
                      value: _StatsRoutineFilter.upcoming,
                    ),
                    _buildFilterChip(
                      label: 'Biblioteca',
                      value: _StatsRoutineFilter.library,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (routines.isEmpty)
                  Text(
                    'No hay rutinas que coincidan con este filtro todavia.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  )
                else
                  ...routines.map((routine) {
                    final insights = routineInsights[routine.id]!;
                    final scheduleStatus = TodayRoutineUtils.buildScheduleStatus(
                      routine: routine,
                      todayDate: widget.todayDate,
                      suggestedRoutineId: widget.suggestedRoutineId,
                    );
                    final isActive = routine.id == widget.activeRoutineId;

                    return _RoutineStatsCard(
                      routine: routine,
                      insights: insights,
                      scheduleStatus: scheduleStatus,
                      subtitle: buildRoutineSubtitle(routine, insights),
                      isActive: isActive,
                      completionLabel: formatPercent(insights.completionRate),
                      weeklyLabel: formatPercent(insights.weeklyCompletionRate),
                      monthlyLabel: formatPercent(insights.monthlyCompletionRate),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required _StatsRoutineFilter value,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: filter == value,
      onSelected: (_) {
        setState(() {
          filter = value;
        });
      },
    );
  }
}

/// Seccion visual reutilizable de la pantalla de estadisticas.
class _StatsSection extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _StatsSection({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Pequeña tarjeta numerica para el resumen superior.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta rica por rutina para leer su rendimiento y vigencia de un vistazo.
class _RoutineStatsCard extends StatelessWidget {
  final Routine routine;
  final RoutineHistoryInsights insights;
  final ({String label, Color color}) scheduleStatus;
  final String subtitle;
  final bool isActive;
  final String completionLabel;
  final String weeklyLabel;
  final String monthlyLabel;

  const _RoutineStatsCard({
    required this.routine,
    required this.insights,
    required this.scheduleStatus,
    required this.subtitle,
    required this.isActive,
    required this.completionLabel,
    required this.weeklyLabel,
    required this.monthlyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    routine.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isActive)
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(routine.schedule.shortLabel),
                ),
                Chip(
                  backgroundColor: scheduleStatus.color.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: scheduleStatus.color.withValues(alpha: 0.24),
                  ),
                  avatar: Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: scheduleStatus.color,
                  ),
                  label: Text(scheduleStatus.label),
                ),
                Chip(
                  avatar: const Icon(Icons.view_list_rounded, size: 18),
                  label: Text('${routine.blocks.length} bloques'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              routine.schedule.displayLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniMetric(label: 'Racha', value: '${insights.currentStreak}'),
                _MiniMetric(
                  label: 'Mejor',
                  value: '${insights.bestStreak}',
                ),
                _MiniMetric(label: '7d', value: weeklyLabel),
                _MiniMetric(label: '30d', value: monthlyLabel),
                _MiniMetric(label: 'Global', value: completionLabel),
                _MiniMetric(
                  label: 'Dias completos',
                  value: '${insights.completedDays}/${insights.trackedDays}',
                ),
                _MiniMetric(
                  label: 'Progreso',
                  value:
                      '${insights.progressBlocksCompleted}/${insights.progressBlocksTracked}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pildora compacta de metrica secundaria.
class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Text(
        '$value $label',
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
