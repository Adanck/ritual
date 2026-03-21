import 'package:flutter/material.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/services/storage_service.dart';
import 'package:ritual/shared/widgets/time_block.dart';

/// Pantalla principal del MVP.
///
/// Esta pantalla concentra el estado del día actual: carga rutinas,
/// identifica cuál está activa, responde a la interacción del usuario
/// y persiste los cambios en almacenamiento local.
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

/// Estado asociado a [TodayPage].
///
/// Aquí vive la lógica principal de la pantalla mientras el proyecto sigue en
/// una arquitectura sencilla basada en `StatefulWidget`.
class _TodayPageState extends State<TodayPage> {
  List<Routine> routines = [];
  Routine? activeRoutine;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  /// Carga las rutinas guardadas.
  ///
  /// Si es la primera ejecución, crea una rutina inicial para que la app tenga
  /// contenido visible desde el primer arranque.
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

  /// Marca o desmarca un bloque de la rutina activa y persiste el cambio.
  void toggleBlock(int index) {
    if (activeRoutine == null) return;

    setState(() {
      activeRoutine!.blocks[index].isDone = !activeRoutine!.blocks[index].isDone;
    });

    StorageService.saveRoutines(routines);
  }

  /// Cambia cuál rutina está activa.
  ///
  /// La regla de negocio aquí es simple: solo puede existir una rutina activa
  /// a la vez.
  Future<void> selectRoutine(Routine selectedRoutine) async {
    if (activeRoutine?.id == selectedRoutine.id) return;

    setState(() {
      for (final routine in routines) {
        routine.isActive = routine.id == selectedRoutine.id;
      }

      activeRoutine = selectedRoutine;
    });

    await StorageService.saveRoutines(routines);
  }

  /// Crea una nueva rutina vacía y la deja como rutina activa.
  ///
  /// Para este MVP la creación es deliberadamente simple: solo pedimos nombre.
  /// Los bloques se podrán agregar en el siguiente paso del roadmap.
  Future<void> createRoutine() async {
    final controller = TextEditingController();

    final routineName = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          title: const Text('Nueva rutina'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Vacaciones',
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    final normalizedName = routineName?.trim() ?? '';
    if (normalizedName.isEmpty) return;

    final newRoutine = Routine(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: normalizedName,
      blocks: [],
      isActive: true,
    );

    setState(() {
      for (final routine in routines) {
        routine.isActive = false;
      }

      routines = [...routines, newRoutine];
      activeRoutine = newRoutine;
    });

    await StorageService.saveRoutines(routines);
  }

  /// Abre el selector visual de rutinas.
  ///
  /// Usamos un bottom sheet porque funciona bien en móvil y también escala de
  /// forma razonable para escritorio.
  Future<void> showRoutineSelector() async {
    if (routines.isEmpty) return;

    final selectedRoutine = await showModalBottomSheet<Routine>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Seleccionar rutina',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await createRoutine();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva'),
                      ),
                    ],
                  ),
                ),
                if (routines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: Text(
                      'Elige cuál rutina quieres usar hoy.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ...routines.map((routine) {
                  final isSelected = routine.id == activeRoutine?.id;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                      title: Text(routine.name),
                      subtitle: Text('${routine.blocks.length} bloques'),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(routine),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selectedRoutine != null) {
      await selectRoutine(selectedRoutine);
    }
  }

  /// Calcula el progreso total de la rutina activa.
  ///
  /// Por ahora el progreso usa todos los bloques. Más adelante podríamos
  /// decidir si solo ciertos tipos deben contar para esta métrica.
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Cambiar rutina',
              onPressed: showRoutineSelector,
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tarjeta superior con el contexto del día y el progreso agregado.
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
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.auto_awesome_motion, size: 18),
                        label: Text(activeRoutine!.name),
                      ),
                      Chip(
                        avatar: const Icon(Icons.view_list_rounded, size: 18),
                        label: Text('${blocks.length} bloques'),
                      ),
                    ],
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
          // Cuerpo principal: lista de bloques o estado vacío si la rutina
          // todavía no tiene contenido.
          Expanded(
            child: blocks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_note_rounded,
                            size: 52,
                            color: theme.colorScheme.primary.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Esta rutina todavía no tiene bloques',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'La rutina ya quedó creada. El siguiente paso será agregar y editar bloques dentro de ella.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
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
