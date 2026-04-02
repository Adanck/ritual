import 'package:flutter/material.dart';
import 'package:ritual/core/utils/date_key.dart';
import 'package:ritual/core/utils/day_block_time_validator.dart';
import 'package:ritual/core/utils/routine_history_insights.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/daily_record.dart';
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
class _TodayPageState extends State<TodayPage> with WidgetsBindingObserver {
  List<Routine> routines = [];
  List<DailyRecord> dailyRecords = [];
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

  String get todayKey => DateKey.fromDate(DateTime.now());

  DailyRecord? get activeDayRecord {
    if (activeRoutine == null) return null;

    final index = dailyRecords.indexWhere(
      (record) =>
          record.dateKey == todayKey && record.routineId == activeRoutine!.id,
    );

    if (index == -1) return null;
    return dailyRecords[index];
  }

  List<DayBlock> get visibleBlocks => activeDayRecord?.blocks ?? const [];

  RoutineHistoryInsights get activeRoutineInsights {
    if (activeRoutine == null) {
      return const RoutineHistoryInsights(
        currentStreak: 0,
        activeDays: 0,
        trackedDays: 0,
        completedDays: 0,
        completedBlocks: 0,
        completionRate: 0,
      );
    }

    return RoutineHistoryCalculator.calculate(
      records: dailyRecords,
      routineId: activeRoutine!.id,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Caso borde: si la app vuelve despues de medianoche, refrescamos el
      // registro del dia para aplicar el reset diario automatico.
      ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
      if (mounted) {
        setState(() {});
      }
    }
  }

  /// Carga las rutinas guardadas.
  ///
  /// Si es la primera ejecucion, crea una rutina inicial para que la app tenga
  /// contenido visible desde el primer arranque.
  Future<void> loadData() async {
    final savedRoutines = await StorageService.loadRoutines();
    final savedDailyRecords = await StorageService.loadDailyRecords();

    dailyRecords = savedDailyRecords;

    if (savedRoutines.isEmpty) {
      routines = [
        Routine(
          id: '1',
          name: 'Normal',
          isActive: true,
          blocks: [
            DayBlock(
              id: 'block-english',
              start: '07:00',
              end: '07:45',
              title: 'Ingl\u00E9s',
              description: 'Practica diaria para mantener constancia.',
              type: BlockType.habit,
              countsTowardProgress: true,
            ),
            DayBlock(
              id: 'block-work',
              start: '08:00',
              end: '12:00',
              title: 'Trabajo',
              description: 'Bloque principal de trabajo profundo.',
              type: BlockType.commitment,
              countsTowardProgress: true,
            ),
            DayBlock(
              id: 'block-lunch',
              start: '12:00',
              end: '13:00',
              title: 'Almuerzo',
              description: 'Pausa para comer y recargar energia.',
              type: BlockType.visual,
              countsTowardProgress: false,
            ),
            DayBlock(
              id: 'block-course',
              start: '14:00',
              end: '15:00',
              title: 'Curso',
              description: 'Espacio de aprendizaje y avance profesional.',
              type: BlockType.habit,
              countsTowardProgress: true,
            ),
          ],
        ),
      ];

      activeRoutine = routines.first;
      await StorageService.saveRoutines(routines);
    } else {
      routines = savedRoutines;
      activeRoutine = routines.cast<Routine?>().firstWhere(
            (routine) => routine?.isActive ?? false,
            orElse: () => routines.isNotEmpty ? routines.first : null,
          );

      // Caso borde: si ninguna rutina venia marcada como activa, promovemos la
      // primera para mantener una experiencia consistente.
      if (activeRoutine != null && !activeRoutine!.isActive) {
        activeRoutine!.isActive = true;
        await StorageService.saveRoutines(routines);
      }
    }

    await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);

    if (!mounted) return;
    setState(() {});
  }

  /// Crea una copia del bloque de plantilla para usarlo dentro del historial.
  DayBlock cloneBlockForDailyRecord(DayBlock block, {bool? isDone}) {
    return block.copyWith(isDone: isDone ?? false);
  }

  /// Sincroniza los bloques del registro diario con la plantilla actual.
  ///
  /// Regla: preservamos `isDone` por `id` para no perder el progreso del dia
  /// cuando el usuario reordena o edita la estructura de la rutina.
  List<DayBlock> syncTodayBlocksWithTemplate({
    required List<DayBlock> templateBlocks,
    required List<DayBlock> currentDayBlocks,
  }) {
    final completedStateById = {
      for (final block in currentDayBlocks) block.id: block.isDone,
    };

    return templateBlocks.map((templateBlock) {
      return cloneBlockForDailyRecord(
        templateBlock,
        isDone: completedStateById[templateBlock.id] ?? false,
      );
    }).toList();
  }

  /// Garantiza que exista un registro para la rutina activa en la fecha actual.
  ///
  /// Esta es la base del reset diario automatico: cuando cambia el dia y no
  /// existe registro para hoy, se crea uno nuevo desde la plantilla con todos
  /// los checks apagados.
  Future<void> ensureTodayRecordForActiveRoutine({
    bool syncWithTemplate = false,
  }) async {
    if (activeRoutine == null) return;

    final index = dailyRecords.indexWhere(
      (record) =>
          record.dateKey == todayKey && record.routineId == activeRoutine!.id,
    );

    if (index == -1) {
      dailyRecords = [
        ...dailyRecords,
        DailyRecord(
          dateKey: todayKey,
          routineId: activeRoutine!.id,
          routineName: activeRoutine!.name,
          blocks: activeRoutine!.blocks
              .map((block) => cloneBlockForDailyRecord(block))
              .toList(),
        ),
      ];

      await StorageService.saveDailyRecords(dailyRecords);
      return;
    }

    if (syncWithTemplate) {
      final record = dailyRecords[index];
      final previousBlocks = [...record.blocks];
      record.routineName = activeRoutine!.name;
      record.blocks
        ..clear()
        ..addAll(
          syncTodayBlocksWithTemplate(
            templateBlocks: activeRoutine!.blocks,
            currentDayBlocks: previousBlocks,
          ),
        );

      await StorageService.saveDailyRecords(dailyRecords);
    }
  }

  /// Persiste cambios sobre la plantilla y sincroniza el dia actual.
  Future<void> syncActiveRoutineTemplateAndTodayRecord() async {
    await StorageService.saveRoutines(routines);
    await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);

    if (!mounted) return;
    setState(() {});
  }

  /// Marca o desmarca un bloque del registro diario activo y persiste el cambio.
  Future<void> toggleBlock(int index) async {
    final currentRecord = activeDayRecord;
    if (currentRecord == null) return;

    setState(() {
      currentRecord.blocks[index].isDone = !currentRecord.blocks[index].isDone;
    });

    await StorageService.saveDailyRecords(dailyRecords);
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
    await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);

    if (!mounted) return;
    setState(() {});
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
    await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);

    if (!mounted) return;
    setState(() {});
  }

  /// Permite renombrar una rutina existente sin alterar sus bloques.
  Future<void> renameRoutine(Routine routine) async {
    var draftName = routine.name;

    final routineName = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          title: const Text('Renombrar rutina'),
          content: TextFormField(
            initialValue: routine.name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Vacaciones',
            ),
            onChanged: (value) => draftName = value,
            onFieldSubmitted: (value) => Navigator.of(context).pop(value.trim()),
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
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    final normalizedName = routineName?.trim() ?? '';
    if (normalizedName.isEmpty || normalizedName == routine.name) return;

    setState(() {
      routine.name = normalizedName;

      // Regla: el historial usa el mismo `routineId`, por lo tanto cuando el
      // nombre cambia lo reflejamos en todos los registros historicos.
      for (final record in dailyRecords.where(
        (record) => record.routineId == routine.id,
      )) {
        record.routineName = normalizedName;
      }
    });

    await StorageService.saveRoutines(routines);
    await StorageService.saveDailyRecords(dailyRecords);
    await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);

    if (!mounted) return;
    setState(() {});
  }

  /// Elimina una rutina existente de forma segura.
  ///
  /// Regla: nunca dejamos la app sin al menos una rutina disponible.
  /// Caso borde: si se elimina la rutina activa, activamos otra automaticamente.
  Future<void> deleteRoutine(Routine routine) async {
    // Regla: la ultima rutina no se puede borrar para evitar un estado vacio
    // estructural de la app.
    if (routines.length <= 1) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe existir al menos una rutina.'),
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar rutina'),
          content: Text(
            'Se eliminara "${routine.name}" con todos sus bloques. Esta accion no se puede deshacer.',
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

    if (shouldDelete != true) return;

    setState(() {
      routines.removeWhere((item) => item.id == routine.id);
      dailyRecords.removeWhere((record) => record.routineId == routine.id);

      // Caso borde: si la rutina activa fue eliminada, promovemos la primera
      // disponible como nueva rutina activa.
      if (activeRoutine?.id == routine.id && routines.isNotEmpty) {
        for (final item in routines) {
          item.isActive = false;
        }

        routines.first.isActive = true;
        activeRoutine = routines.first;
      }
    });

    await StorageService.saveRoutines(routines);
    await StorageService.saveDailyRecords(dailyRecords);
    await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);

    if (!mounted) return;
    setState(() {});
  }

  /// Abre el selector nativo de hora y devuelve el valor ya formateado.
  Future<String?> pickTime({
    required BuildContext context,
    String? initialValue,
  }) async {
    final initialTime =
        DayBlockTimeValidator.parseTime(initialValue ?? '') ?? TimeOfDay.now();

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
    return DayBlockTimeValidator.formatTimeOfDay(selectedTime);
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
    var countsTowardProgress = existingBlock?.countsTowardProgress ?? true;

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

            final timeValidationMessage = DayBlockTimeValidator.validateTimeRange(
              start: start,
              end: end,
              existingBlocks: activeRoutine?.blocks ?? const [],
              blockBeingEdited: existingBlock,
            );

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
                      if (timeValidationMessage != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            timeValidationMessage,
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
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: countsTowardProgress,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Contar para el progreso del d\u00EDa'),
                        subtitle: const Text(
                          'Desact\u00EDvalo si este bloque solo sirve como referencia o contexto.',
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            countsTowardProgress = value;
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
                    final timeValidationMessage =
                        DayBlockTimeValidator.validateTimeRange(
                          start: start,
                          end: end,
                          existingBlocks: activeRoutine?.blocks ?? const [],
                          blockBeingEdited: existingBlock,
                        );

                    if (!isValid || timeValidationMessage != null) {
                      setDialogState(() {});
                      return;
                    }

                    Navigator.of(context).pop(
                      DayBlock(
                        id: existingBlock?.id,
                        start: start.trim(),
                        end: end.trim(),
                        title: title.trim(),
                        description: description.trim(),
                        type: selectedType,
                        countsTowardProgress: countsTowardProgress,
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

    await syncActiveRoutineTemplateAndTodayRecord();
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

    await syncActiveRoutineTemplateAndTodayRecord();
  }

  /// Elimina un bloque existente de la rutina activa.
  Future<void> deleteBlock(int index) async {
    if (activeRoutine == null) return;

    setState(() {
      activeRoutine!.blocks.removeAt(index);
    });

    await syncActiveRoutineTemplateAndTodayRecord();
  }

  /// Reordena los bloques de la rutina activa.
  ///
  /// Flutter entrega `newIndex` en la posicion final esperada, pero cuando el
  /// elemento viene de arriba hacia abajo hay que ajustar el indice por el
  /// efecto de haber removido primero el item original.
  void reorderBlocks(int oldIndex, int newIndex) {
    if (activeRoutine == null) return;

    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final movedBlock = activeRoutine!.blocks.removeAt(oldIndex);
      activeRoutine!.blocks.insert(newIndex, movedBlock);
    });

    syncActiveRoutineTemplateAndTodayRecord();
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
                  final canDelete = routines.length > 1;

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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Renombrar rutina',
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await renameRoutine(routine);
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: canDelete
                                ? 'Eliminar rutina'
                                : 'Debe existir al menos una rutina',
                            onPressed: canDelete
                                ? () async {
                                    Navigator.of(context).pop();
                                    await deleteRoutine(routine);
                                  }
                                : null,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
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
  /// Regla: solo cuentan los bloques marcados como relevantes para progreso.
  ///
  /// Caso borde: si la rutina no tiene bloques elegibles, devolvemos 0 para
  /// evitar divisiones por cero y para expresar que aun no hay progreso medible.
  double get progress {
    final progressBlocks =
        visibleBlocks.where((block) => block.countsTowardProgress).toList();
    if (progressBlocks.isEmpty) return 0;

    final done = progressBlocks.where((block) => block.isDone).length;
    return done / progressBlocks.length;
  }

  Color get progressColor {
    if (progress >= 0.8) return const Color(0xFFFFA24D);
    if (progress >= 0.5) return const Color(0xFF41C47B);
    return const Color(0xFF4DA3FF);
  }

  Widget buildInsightChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
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

  @override
  Widget build(BuildContext context) {
    if (activeRoutine == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final blocks = visibleBlocks;
    final progressBlocks =
        blocks.where((block) => block.countsTowardProgress).toList();
    final completed = progressBlocks.where((block) => block.isDone).length;
    final nonProgressBlocksCount =
        blocks.where((block) => !block.countsTowardProgress).length;
    final insights = activeRoutineInsights;

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
                    progressBlocks.isEmpty
                        ? 'A\u00FAn no hay bloques que cuenten para el progreso'
                        : '$completed de ${progressBlocks.length} bloques que cuentan para progreso',
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
                      if (nonProgressBlocksCount > 0)
                        Chip(
                          avatar: const Icon(Icons.visibility_outlined, size: 18),
                          label: Text('$nonProgressBlocksCount informativos'),
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
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      buildInsightChip(
                        context: context,
                        icon: Icons.local_fire_department_outlined,
                        label: 'racha',
                        value: '${insights.currentStreak}',
                      ),
                      buildInsightChip(
                        context: context,
                        icon: Icons.calendar_today_outlined,
                        label: 'd\u00EDas activos',
                        value: '${insights.activeDays}',
                      ),
                      buildInsightChip(
                        context: context,
                        icon: Icons.percent_rounded,
                        label: 'cumplimiento',
                        value: '${(insights.completionRate * 100).round()}%',
                      ),
                      buildInsightChip(
                        context: context,
                        icon: Icons.task_alt_outlined,
                        label: 'bloques',
                        value: '${insights.completedBlocks}',
                      ),
                    ],
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
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    buildDefaultDragHandles: false,
                    itemCount: blocks.length,
                    onReorder: reorderBlocks,
                    itemBuilder: (context, index) {
                      final block = blocks[index];
                      final blockKey =
                          '${activeRoutine!.id}-${block.id}-${block.title}-$index';

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
                          countsTowardProgress: block.countsTowardProgress,
                          isDone: block.isDone,
                          onTap: () => toggleBlock(index),
                          secondaryAction: ReorderableDelayedDragStartListener(
                            index: index,
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              color: Colors.white38,
                            ),
                          ),
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
