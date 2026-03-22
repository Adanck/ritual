import 'package:flutter/material.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/services/storage_service.dart';
import 'package:ritual/shared/widgets/time_block.dart';

/// Pantalla principal del MVP.
///
/// Esta pantalla concentra el estado del dia actual: carga rutinas, identifica
/// cual esta activa, responde a la interaccion del usuario y persiste cambios.
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

/// Estado asociado a [TodayPage].
///
/// Aqui vive la logica principal de la pantalla mientras el proyecto sigue con
/// una arquitectura sencilla basada en `StatefulWidget`.
class _TodayPageState extends State<TodayPage> {
  List<Routine> routines = [];
  Routine? activeRoutine;

  static const List<DropdownMenuItem<BlockType>> _blockTypeOptions = [
    DropdownMenuItem(
      value: BlockType.habit,
      child: Text('H\u00E1bito'),
    ),
    DropdownMenuItem(
      value: BlockType.commitment,
      child: Text('Compromiso'),
    ),
    DropdownMenuItem(
      value: BlockType.visual,
      child: Text('Visual'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  /// Carga las rutinas guardadas.
  ///
  /// Si es la primera ejecucion, crea una rutina inicial para que la app tenga
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
              description: 'Practica diaria para mantener constancia.',
              type: BlockType.habit,
            ),
            DayBlock(
              start: '08:00',
              end: '12:00',
              title: 'Trabajo',
              description: 'Bloque principal de trabajo profundo.',
              type: BlockType.commitment,
            ),
            DayBlock(
              start: '12:00',
              end: '13:00',
              title: 'Almuerzo',
              description: 'Pausa para comer y recargar energia.',
              type: BlockType.visual,
            ),
            DayBlock(
              start: '14:00',
              end: '15:00',
              title: 'Curso',
              description: 'Espacio de aprendizaje y avance profesional.',
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

  /// Cambia cual rutina esta activa.
  ///
  /// La regla de negocio aqui es simple: solo puede existir una rutina activa
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

  /// Crea una nueva rutina vacia y la deja como rutina activa.
  Future<void> createRoutine() async {
    var draftName = '';

    final routineName = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          title: const Text('Nueva rutina'),
          content: TextField(
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Vacaciones',
            ),
            onChanged: (value) => draftName = value,
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
              onPressed: () => Navigator.of(context).pop(draftName.trim()),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

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

  /// Convierte un texto `HH:mm` en un [TimeOfDay] cuando el formato es valido.
  TimeOfDay? parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Da formato consistente `HH:mm` a una hora para mostrarla y persistirla.
  String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Compara horas para validar que el rango tenga sentido.
  bool isEndAfterStart(String start, String end) {
    final startTime = parseTime(start);
    final endTime = parseTime(end);
    if (startTime == null || endTime == null) return false;

    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return endMinutes > startMinutes;
  }

  /// Abre el selector nativo de hora y devuelve el valor ya formateado.
  Future<String?> pickTime({
    required BuildContext context,
    String? initialValue,
  }) async {
    final initialTime = parseTime(initialValue ?? '') ?? TimeOfDay.now();

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        final theme = Theme.of(context);

        return Theme(
          data: theme.copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: theme.colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null) return null;
    return formatTimeOfDay(selectedTime);
  }

  /// Abre el formulario de bloque en modo crear o editar.
  ///
  /// Si [existingBlock] viene informado, el formulario se precarga y al guardar
  /// devolvemos un bloque actualizado. Si no, se crea uno nuevo desde cero.
  Future<DayBlock?> showBlockForm({DayBlock? existingBlock}) async {
    final formKey = GlobalKey<FormState>();
    var selectedType = existingBlock?.type ?? BlockType.habit;
    var start = existingBlock?.start ?? '';
    var end = existingBlock?.end ?? '';
    var title = existingBlock?.title ?? '';
    var description = existingBlock?.description ?? '';

    return showDialog<DayBlock>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handlePickStartTime() async {
              final pickedTime = await pickTime(
                context: context,
                initialValue: start,
              );
              if (pickedTime == null) return;

              setDialogState(() {
                start = pickedTime;
              });
            }

            Future<void> handlePickEndTime() async {
              final pickedTime = await pickTime(
                context: context,
                initialValue: end,
              );
              if (pickedTime == null) return;

              setDialogState(() {
                end = pickedTime;
              });
            }

            return AlertDialog(
              title: Text(
                existingBlock == null ? 'Nuevo bloque' : 'Editar bloque',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: title,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Titulo',
                          hintText: 'Ej. Leer 10 paginas',
                        ),
                        onChanged: (value) => title = value,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa un titulo.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: description,
                        textInputAction: TextInputAction.next,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripcion opcional',
                          hintText: 'Contexto o detalle del bloque',
                        ),
                        onChanged: (value) => description = value,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: handlePickStartTime,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Inicio',
                                  suffixIcon: Icon(Icons.schedule_rounded),
                                ),
                                child: Text(
                                  start.isEmpty ? 'Seleccionar' : start,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: start.isEmpty ? Colors.white54 : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: handlePickEndTime,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Fin',
                                  suffixIcon: Icon(Icons.schedule_rounded),
                                ),
                                child: Text(
                                  end.isEmpty ? 'Seleccionar' : end,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: end.isEmpty ? Colors.white54 : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (start.isEmpty || end.isEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Selecciona hora de inicio y fin.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ] else if (!isEndAfterStart(start, end)) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'La hora de fin debe ser mayor que la de inicio.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<BlockType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de bloque',
                        ),
                        items: _blockTypeOptions,
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedType = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
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
                  onPressed: () {
                    final isValid = formKey.currentState?.validate() ?? false;
                    final hasValidTimeRange =
                        start.isNotEmpty &&
                        end.isNotEmpty &&
                        isEndAfterStart(start, end);

                    if (!isValid || !hasValidTimeRange) {
                      setDialogState(() {});
                      return;
                    }

                    Navigator.of(context).pop(
                      DayBlock(
                        start: start.trim(),
                        end: end.trim(),
                        title: title.trim(),
                        description: description.trim(),
                        type: selectedType,
                        isDone: existingBlock?.isDone ?? false,
                      ),
                    );
                  },
                  child: Text(existingBlock == null ? 'Guardar' : 'Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Crea un nuevo bloque dentro de la rutina activa.
  Future<void> createBlock() async {
    if (activeRoutine == null) return;
    final createdBlock = await showBlockForm();

    if (createdBlock == null) return;

    setState(() {
      activeRoutine!.blocks.add(createdBlock);
    });

    await StorageService.saveRoutines(routines);
  }

  /// Edita un bloque existente reemplazandolo por una nueva version.
  Future<void> editBlock(int index) async {
    if (activeRoutine == null) return;

    final block = activeRoutine!.blocks[index];
    final updatedBlock = await showBlockForm(existingBlock: block);

    if (updatedBlock == null) return;

    setState(() {
      activeRoutine!.blocks[index] = updatedBlock;
    });

    await StorageService.saveRoutines(routines);
  }

  /// Elimina un bloque existente de la rutina activa.
  Future<void> deleteBlock(int index) async {
    if (activeRoutine == null) return;

    setState(() {
      activeRoutine!.blocks.removeAt(index);
    });

    await StorageService.saveRoutines(routines);
  }

  /// Abre el selector visual de rutinas.
  ///
  /// Usamos un bottom sheet porque funciona bien en movil y tambien escala de
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Text(
                    'Elige cual rutina quieres usar hoy.',
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
  /// Por ahora el progreso usa todos los bloques. Mas adelante podriamos
  /// decidir si solo ciertos tipos deben contar para esta metrica.
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
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'Agregar bloque',
              onPressed: createBlock,
              icon: const Icon(Icons.add_task_rounded),
            ),
          ),
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
          // Tarjeta superior con el contexto del dia y el progreso agregado.
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
          // Cuerpo principal: lista de bloques o estado vacio si la rutina aun
          // no tiene contenido.
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
                            'Esta rutina todav\u00EDa no tiene bloques',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'La rutina ya quedo creada. Ahora puedes agregar tu primer bloque.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: createBlock,
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar bloque'),
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
                      final blockKey = '${activeRoutine!.id}-${block.start}-${block.title}-$index';

                      return Dismissible(
                        key: ValueKey(blockKey),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Editar',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Eliminar',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.delete_outline_rounded,
                                color: theme.colorScheme.error,
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            await editBlock(index);
                            return false;
                          }

                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Eliminar bloque'),
                                content: Text(
                                  'Se eliminara "${block.title}". Esta accion no se puede deshacer.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              );
                            },
                          );

                          return shouldDelete ?? false;
                        },
                        onDismissed: (_) => deleteBlock(index),
                        child: TimeBlock(
                          start: block.start,
                          end: block.end,
                          title: block.title,
                          description: block.description,
                          type: block.type,
                          isDone: block.isDone,
                          onTap: () => toggleBlock(index),
                          onToggle: () => toggleBlock(index),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createBlock,
        icon: const Icon(Icons.add),
        label: const Text('Bloque'),
      ),
    );
  }
}
