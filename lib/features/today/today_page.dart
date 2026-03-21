import 'package:flutter/material.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/services/storage_service.dart';
import 'package:ritual/shared/widgets/time_block.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  List<Routine> routines = [];
  Routine? activeRoutine;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final saved = await StorageService.loadRoutines();

    if (saved.isEmpty) {
      routines = [
        Routine(
          id: '1',
          name: 'Normal',
          isActive: true,
          blocks: [
            DayBlock(
              start: '07:00',
              end: '07:45',
              title: 'Ingl\u00E9s',
              type: BlockType.habit,
            ),
            DayBlock(
              start: '08:00',
              end: '12:00',
              title: 'Trabajo',
              type: BlockType.commitment,
            ),
            DayBlock(
              start: '12:00',
              end: '13:00',
              title: 'Almuerzo',
              type: BlockType.visual,
            ),
            DayBlock(
              start: '14:00',
              end: '15:00',
              title: 'Curso',
              type: BlockType.habit,
            ),
          ],
        ),
      ];

      activeRoutine = routines.first;
      await StorageService.saveRoutines(routines);
    } else {
      routines = saved;
      activeRoutine = routines.cast<Routine?>().firstWhere(
            (routine) => routine?.isActive ?? false,
            orElse: () => routines.isNotEmpty ? routines.first : null,
          );
    }

    if (!mounted) return;
    setState(() {});
  }

  void toggleBlock(int index) {
    if (activeRoutine == null) return;

    setState(() {
      activeRoutine!.blocks[index].isDone = !activeRoutine!.blocks[index].isDone;
    });

    StorageService.saveRoutines(routines);
  }

  double get progress {
    final blocks = activeRoutine?.blocks ?? [];
    if (blocks.isEmpty) return 0;

    final done = blocks.where((block) => block.isDone).length;
    return done / blocks.length;
  }

  Color get progressColor {
    if (progress >= 0.8) return const Color(0xFFFFA24D);
    if (progress >= 0.5) return const Color(0xFF41C47B);
    return const Color(0xFF4DA3FF);
  }

  @override
  Widget build(BuildContext context) {
    if (activeRoutine == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final blocks = activeRoutine!.blocks;
    final completed = blocks.where((block) => block.isDone).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hoy \u00B7 ${activeRoutine!.name}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
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
                    'Progreso del d\u00EDa',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$completed de ${blocks.length} bloques completados',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
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
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: blocks.length,
              itemBuilder: (context, index) {
                final block = blocks[index];

                return TimeBlock(
                  start: block.start,
                  end: block.end,
                  title: block.title,
                  type: block.type,
                  isDone: block.isDone,
                  onToggle: () => toggleBlock(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
