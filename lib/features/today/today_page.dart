import 'package:flutter/material.dart';
import 'package:ritual/core/models/notification_diagnostics.dart';
import 'package:ritual/core/services/notification_service.dart';
import 'package:ritual/core/services/today_notification_coordinator.dart';
import 'package:ritual/core/utils/day_block_collection_utils.dart';
import 'package:ritual/core/utils/date_key.dart';
import 'package:ritual/core/utils/day_block_time_validator.dart';
import 'package:ritual/core/utils/routine_history_insights.dart';
import 'package:ritual/core/utils/today_calendar_utils.dart';
import 'package:ritual/core/utils/today_routine_utils.dart';
import 'package:ritual/data/models/block_type.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/daily_record.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:ritual/data/models/routine_schedule.dart';
import 'package:ritual/data/services/storage_service.dart';
import 'package:ritual/shared/widgets/today_calendar_widgets.dart';
import 'package:ritual/shared/widgets/time_block.dart';

/// Resultado del formulario de rutina.
///
/// Separa el borrador de la rutina persistida para no mutar el estado real
/// mientras el usuario aun esta llenando el dialogo.
class _RoutineFormResult {
  final String name;
  final RoutineSchedule schedule;

  const _RoutineFormResult({
    required this.name,
    required this.schedule,
  });
}

/// Opciones disponibles cuando el usuario cambia de rutina a mitad del dia.
///
/// Las tres estrategias existen porque cada una responde a una intencion
/// distinta: continuar el dia sumando bloques, cambiar el resto del plan o
/// reiniciar completamente el horario del dia.
enum _RoutineSwitchStrategy {
  preserveAndAdd,
  replacePending,
  restartDay,
}

/// Define a que nivel se aplica un cambio de bloques cuando ya existe un dia.
///
/// `todayOnly` modifica solo el registro diario actual. `routineOnly`
/// modifica la plantilla para los dias futuros sin reescribir el historial ya
/// consolidado.
enum _BlockChangeScope {
  todayOnly,
  routineOnly,
}

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
  List<DatedBlockEntry> datedBlocks = [];
  Routine? activeRoutine;
  NotificationDiagnostics notificationDiagnostics =
      const NotificationDiagnostics.unsupported();
  bool isNotificationActionInProgress = false;

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
    DropdownMenuItem(
      value: BlockType.reminder,
      child: Text('Recordatorio'),
    ),
    DropdownMenuItem(
      value: BlockType.event,
      child: Text('Evento puntual'),
    ),
  ];

  static const List<DropdownMenuItem<RoutineScheduleType>>
      _routineScheduleOptions = [
    DropdownMenuItem(
      value: RoutineScheduleType.always,
      child: Text('Siempre'),
    ),
    DropdownMenuItem(
      value: RoutineScheduleType.currentWeek,
      child: Text('Semana actual'),
    ),
    DropdownMenuItem(
      value: RoutineScheduleType.currentMonth,
      child: Text('Mes actual'),
    ),
    DropdownMenuItem(
      value: RoutineScheduleType.customRange,
      child: Text('Rango personalizado'),
    ),
  ];

  DateTime get todayDate => DateTime.now();

  String get todayKey => DateKey.fromDate(todayDate);

  bool get isActiveRoutineScheduledToday =>
      activeRoutine?.appliesOn(todayDate) ?? false;

  DailyRecord? get activeDayRecord {
    if (activeRoutine == null) return null;

    final index = dailyRecords.indexWhere(
      (record) =>
          record.dateKey == todayKey && record.routineId == activeRoutine!.id,
    );

    if (index == -1) return null;
    return dailyRecords[index];
  }

  /// La lista visible depende de si hoy ya existe o no un registro diario.
  ///
  /// Regla: si ya se uso la rutina hoy mostramos el registro del dia para
  /// preservar checks e historial. Si aun no se ha usado, mostramos la
  /// plantilla editable sin crear progreso accidentalmente.
  ///
  /// Caso funcional: los recordatorios puntuales del dia se mezclan con la
  /// vista para que el usuario vea su horario real en un solo lugar.
  List<DayBlock> get visibleBlocks {
    if (activeRoutine == null) return const [];
    final baseBlocks = activeDayRecord?.blocks ?? activeRoutine!.blocks;
    final reminderBlocks = getDatedBlocksForDate(todayKey).map((entry) => entry.block);

    return DayBlockCollectionUtils.sortChronologically([
      ...baseBlocks.map(DayBlockCollectionUtils.cloneForDailyRecord),
      ...reminderBlocks.map(DayBlockCollectionUtils.cloneForDailyRecord),
    ]);
  }

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

  List<DailyRecord> get activeRoutineHistoryRecords {
    if (activeRoutine == null) return const [];

    final records = dailyRecords
        .where(
          (record) =>
              record.routineId == activeRoutine!.id &&
              record.dateKey != todayKey,
        )
        .toList()
      ..sort(
        (a, b) => DateKey.toDate(b.dateKey).compareTo(DateKey.toDate(a.dateKey)),
      );

    return records;
  }

  int getTodayRecordIndexForRoutineId(String routineId) {
    return dailyRecords.indexWhere(
      (record) => record.dateKey == todayKey && record.routineId == routineId,
    );
  }

  DailyRecord? getTodayRecordForRoutineId(String routineId) {
    final index = getTodayRecordIndexForRoutineId(routineId);
    if (index == -1) return null;
    return dailyRecords[index];
  }

  List<DatedBlockEntry> getDatedBlocksForDate(String dateKey) {
    return datedBlocks.where((entry) => entry.dateKey == dateKey).toList();
  }

  /// Devuelve los proximos eventos puntuales a partir de hoy.
  ///
  /// Regla: se ordenan por fecha y hora para que el usuario vea primero lo mas
  /// cercano. Caso borde: ignoramos eventos pasados porque ya tienen mejor
  /// representacion dentro del historial o del detalle de su fecha.
  List<DatedBlockEntry> getUpcomingDatedBlocks({
    int daysAhead = 14,
    int limit = 4,
  }) {
    return DayBlockCollectionUtils.getUpcomingDatedBlocks(
      datedBlocks: datedBlocks,
      todayDate: todayDate,
      daysAhead: daysAhead,
      limit: limit,
    );
  }

  /// Vista previa pura de la agenda de notificaciones con el estado actual.
  ///
  /// Nos sirve para mostrar el siguiente recordatorio esperado y para saber si
  /// un evento puntual concreto quedo cubierto por la agenda local.
  List<NotificationPreviewEntry> get notificationPreviewEntries {
    return NotificationService.buildPreviewEntries(
      routines: routines,
      dailyRecords: dailyRecords,
      datedBlocks: datedBlocks,
      activeRoutineId: activeRoutine?.id,
      anchorDate: todayDate,
    );
  }

  Set<String> get scheduledNotificationSourceKeys {
    return notificationPreviewEntries.map((entry) => entry.sourceKey).toSet();
  }

  DateTime? get nextScheduledNotificationAt {
    final entries = notificationPreviewEntries;
    return entries.isEmpty ? null : entries.first.when;
  }

  String buildDatedEntryNotificationSourceKey(DatedBlockEntry entry) {
    return 'dated:${entry.dateKey}:${entry.block.id}';
  }

  bool isDatedEntryNotificationScheduled(DatedBlockEntry entry) {
    return scheduledNotificationSourceKeys.contains(
      buildDatedEntryNotificationSourceKey(entry),
    );
  }

  bool isBlockNotificationScheduled(DayBlock block) {
    return notificationPreviewEntries.any(
      (entry) => entry.sourceKey.endsWith(':${block.id}'),
    );
  }

  DatedBlockEntry? getDatedBlockEntryById(String blockId) {
    return datedBlocks.cast<DatedBlockEntry?>().firstWhere(
          (entry) => entry?.block.id == blockId,
          orElse: () => null,
        );
  }

  bool isDatedBlock(DayBlock block) {
    return getDatedBlockEntryById(block.id) != null;
  }

  /// Detecta si el registro de hoy ya se desvio de la plantilla base.
  ///
  /// Caso borde: aunque no haya checks, si el usuario agrego, quito o edito
  /// bloques del dia, seguimos considerando que ya hay un plan en curso.
  bool doesRecordDifferFromRoutineTemplate(
    DailyRecord record,
    Routine routine,
  ) {
    if (record.blocks.length != routine.blocks.length) return true;

    for (var index = 0; index < record.blocks.length; index++) {
      if (!DayBlockCollectionUtils.hasSameDefinition(
        record.blocks[index],
        routine.blocks[index],
      )) {
        return true;
      }
    }

    return false;
  }

  List<Routine> get routinesSuggestedForToday {
    return TodayRoutineUtils.getSuggestedForDate(
      routines: routines,
      date: todayDate,
    );
  }

  Routine? get suggestedRoutineForToday {
    if (routinesSuggestedForToday.isEmpty) return null;
    return routinesSuggestedForToday.first;
  }

  Future<void> activateRoutineSilently(Routine selectedRoutine) async {
    if (activeRoutine?.id == selectedRoutine.id) return;

    for (final routine in routines) {
      routine.isActive = routine.id == selectedRoutine.id;
    }

    activeRoutine = selectedRoutine;
    await StorageService.saveRoutines(routines);
  }

  /// Si no hay un dia iniciado, promueve automaticamente la mejor rutina.
  ///
  /// Regla: no reemplazamos el plan actual si ya existe cualquier registro de
  /// hoy, porque a partir de ahi el usuario ya pudo empezar a organizar su dia.
  Future<void> autoSelectSuggestedRoutineIfHelpful() async {
    if (activeRoutine == null) return;
    if (activeRoutine!.appliesOn(todayDate)) return;

    final suggestedRoutine = suggestedRoutineForToday;
    if (suggestedRoutine == null || suggestedRoutine.id == activeRoutine!.id) {
      return;
    }

    final hasAnyTodayRecord = dailyRecords.any(
      (record) => record.dateKey == todayKey,
    );
    if (hasAnyTodayRecord) return;

    await activateRoutineSilently(suggestedRoutine);
  }

  int getRoutineBlockIndexById(String blockId) {
    if (activeRoutine == null) return -1;
    return activeRoutine!.blocks.indexWhere((block) => block.id == blockId);
  }

  int getTodayBlockIndexById(String blockId) {
    final record = activeDayRecord;
    if (record == null) return -1;
    return record.blocks.indexWhere((block) => block.id == blockId);
  }

  /// Construye el horario esperado para una fecha concreta.
  ///
  /// Regla: si ya existe un registro real para esa fecha, ese registro manda.
  /// Caso borde: si todavia no hay registro, usamos la plantilla de la rutina
  /// solo cuando aplica para esa fecha y luego mezclamos recordatorios
  /// puntuales asociados al mismo dia.
  List<DayBlock> getPlannedBlocksForDate(DateTime date) {
    if (activeRoutine == null) return const [];

    final dateKey = DateKey.fromDate(date);
    final record = getRoutineRecordForDate(date);
    final shouldUseTemplate =
        record == null &&
        (TodayCalendarUtils.isSameCalendarDay(date, todayDate) ||
            activeRoutine!.appliesOn(date));
    final routineBlocks = record?.blocks ?? (shouldUseTemplate ? activeRoutine!.blocks : <DayBlock>[]);
    final reminderBlocks = getDatedBlocksForDate(dateKey).map((entry) => entry.block);

    return DayBlockCollectionUtils.sortChronologically([
      ...routineBlocks.map(DayBlockCollectionUtils.cloneForDailyRecord),
      ...reminderBlocks.map(DayBlockCollectionUtils.cloneForDailyRecord),
    ]);
  }

  /// Pide confirmacion cuando un bloque choca con otro en el mismo horario.
  ///
  /// Regla: los traslapes no se bloquean por completo porque a veces el
  /// usuario quiere mantener ambas cosas, pero siempre los avisamos antes de
  /// guardar para que la decision sea consciente.
  Future<bool> confirmOverlapIfNeeded({
    required DayBlock candidateBlock,
    required List<DayBlock> comparisonBlocks,
    DayBlock? blockBeingEdited,
    required String scopeLabel,
  }) async {
    final hasOverlap = DayBlockTimeValidator.hasOverlap(
      start: candidateBlock.start,
      end: candidateBlock.end,
      existingBlocks: comparisonBlocks,
      blockBeingEdited: blockBeingEdited,
    );

    if (!hasOverlap) return true;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bloque traslapado'),
          content: Text(
            'Este bloque choca con otro dentro de $scopeLabel. Puedes guardarlo de todas formas si quieres mantener ambos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar de todas formas'),
            ),
          ],
        );
      },
    );

    return shouldSave == true;
  }

  /// Construye el registro resultante cuando el usuario cambia de rutina hoy.
  ///
  /// Regla: consolidamos el dia en un solo registro para que el historial no
  /// quede fragmentado por varios cambios de rutina dentro de la misma fecha.
  List<DayBlock> buildBlocksForRoutineSwitch({
    required List<DayBlock> currentDayBlocks,
    required List<DayBlock> nextRoutineBlocks,
    required _RoutineSwitchStrategy strategy,
  }) {
    final currentBlocksBySignature = {
      for (final block in currentDayBlocks)
        DayBlockCollectionUtils.buildSignature(block): block,
    };
    final completedCurrentBlocks = currentDayBlocks
        .where((block) => block.isDone)
        .map(DayBlockCollectionUtils.cloneForDailyRecord)
        .toList();

    switch (strategy) {
      case _RoutineSwitchStrategy.preserveAndAdd:
        final mergedBlocks = currentDayBlocks
            .map(DayBlockCollectionUtils.cloneForDailyRecord)
            .toList();

        for (final templateBlock in nextRoutineBlocks) {
          final signature = DayBlockCollectionUtils.buildSignature(templateBlock);

          // Caso borde: si ambas rutinas comparten un bloque equivalente,
          // preservamos el bloque ya existente para no duplicarlo.
          if (currentBlocksBySignature.containsKey(signature)) {
            continue;
          }

          mergedBlocks.add(
            DayBlockCollectionUtils.cloneForDailyRecord(
              templateBlock,
              isDone: false,
            ),
          );
        }

        return DayBlockCollectionUtils.sortChronologically(mergedBlocks);
      case _RoutineSwitchStrategy.replacePending:
        final keptSignatures = {
          for (final block in completedCurrentBlocks)
            DayBlockCollectionUtils.buildSignature(block),
        };
        final rebuiltBlocks = [...completedCurrentBlocks];

        // Regla: al reemplazar solo el resto del dia conservamos lo ya marcado
        // y regeneramos lo pendiente desde la nueva rutina.
        for (final templateBlock in nextRoutineBlocks) {
          final signature = DayBlockCollectionUtils.buildSignature(templateBlock);
          if (keptSignatures.contains(signature)) {
            continue;
          }

          rebuiltBlocks.add(
            DayBlockCollectionUtils.cloneForDailyRecord(
              templateBlock,
              isDone: false,
            ),
          );
        }

        return DayBlockCollectionUtils.sortChronologically(rebuiltBlocks);
      case _RoutineSwitchStrategy.restartDay:
        // Regla: un reinicio total ignora el progreso previo y crea un nuevo
        // dia desde la plantilla de la rutina seleccionada.
        return DayBlockCollectionUtils.sortChronologically(
          nextRoutineBlocks
              .map(
                (block) => DayBlockCollectionUtils.cloneForDailyRecord(
                  block,
                  isDone: false,
                ),
              )
              .toList(),
        );
    }
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
      // Caso borde: si la app vuelve despues de medianoche, recalculamos la
      // rutina sugerida y luego refrescamos el registro del dia.
      () async {
        await autoSelectSuggestedRoutineIfHelpful();
        await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
        await syncNotificationsWithStoredState();
        if (mounted) {
          setState(() {});
        }
      }();
    }
  }

  /// Carga las rutinas guardadas.
  ///
  /// Si es la primera ejecucion, crea una rutina inicial para que la app tenga
  /// contenido visible desde el primer arranque.
  Future<void> loadData() async {
    final savedRoutines = await StorageService.loadRoutines();
    final savedDailyRecords = await StorageService.loadDailyRecords();
    final savedDatedBlocks = await StorageService.loadDatedBlocks();

    dailyRecords = savedDailyRecords;
    datedBlocks = savedDatedBlocks;

    if (savedRoutines.isEmpty) {
      routines = [
        Routine(
          id: '1',
          name: 'Normal',
          isActive: true,
          schedule: const RoutineSchedule.always(),
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

    await autoSelectSuggestedRoutineIfHelpful();
    await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
    await syncNotificationsWithStoredState();

    if (!mounted) return;
    setState(() {});
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
              .map(
                (block) => DayBlockCollectionUtils.cloneForDailyRecord(
                  block,
                  isDone: false,
                ),
              )
              .toList(),
        ),
      ];

      await StorageService.saveDailyRecords(dailyRecords);
      await syncNotificationsWithStoredState();
      return;
    }

    if (syncWithTemplate) {
      final record = dailyRecords[index];
      final previousBlocks = [...record.blocks];
      record.routineName = activeRoutine!.name;
      record.blocks
        ..clear()
        ..addAll(
          DayBlockCollectionUtils.syncWithTemplate(
            templateBlocks: activeRoutine!.blocks,
            currentDayBlocks: previousBlocks,
          ),
        );

      await StorageService.saveDailyRecords(dailyRecords);
      await syncNotificationsWithStoredState();
    }
  }

  /// Persiste cambios sobre la plantilla y sincroniza el dia actual.
  Future<void> syncActiveRoutineTemplateAndTodayRecord() async {
    await StorageService.saveRoutines(routines);

    // Regla: solo sincronizamos el registro diario si ya existe. Editar una
    // plantilla no deberia crear por si solo un dia "activo" accidentalmente.
    if (activeDayRecord != null) {
      await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
    }

    await syncNotificationsWithStoredState();

    if (!mounted) return;
    setState(() {});
  }

  Future<void> saveDailyRecordsAndRefresh() async {
    await StorageService.saveDailyRecords(dailyRecords);
    await syncNotificationsWithStoredState();

    if (!mounted) return;
    setState(() {});
  }

  Future<void> saveDatedBlocksAndRefresh() async {
    await StorageService.saveDatedBlocks(datedBlocks);
    await syncNotificationsWithStoredState();

    if (!mounted) return;
    setState(() {});
  }

  Future<void> saveRoutinesAndRefresh() async {
    await StorageService.saveRoutines(routines);
    await syncNotificationsWithStoredState();

    if (!mounted) return;
    setState(() {});
  }

  /// Recalcula las notificaciones futuras a partir del estado actual.
  ///
  /// Regla: usamos el mismo estado persistido de rutinas, historial y bloques
  /// fechados para que las notificaciones siempre reflejen lo ultimo que el
  /// usuario decidio en la UI.
  Future<void> syncNotificationsWithStoredState() async {
    final previewEntries = notificationPreviewEntries;
    await NotificationService.syncScheduledNotifications(
      routines: routines,
      dailyRecords: dailyRecords,
      datedBlocks: datedBlocks,
      activeRoutineId: activeRoutine?.id,
      anchorDate: todayDate,
    );
    await refreshNotificationDiagnostics(previewEntries: previewEntries);
  }

  /// Lee el estado actual de permisos y cantidad de recordatorios agendados.
  ///
  /// Regla: este diagnostico no bloquea la app. Si la plataforma no expone
  /// permisos detallados, el coordinador devuelve un estado neutro y la UI
  /// muestra solo la informacion que realmente conoce.
  Future<void> refreshNotificationDiagnostics({
    List<NotificationPreviewEntry>? previewEntries,
  }) async {
    final diagnostics = await TodayNotificationCoordinator.refreshDiagnostics(
      previewEntries: previewEntries ?? notificationPreviewEntries,
    );

    if (!mounted) return;
    setState(() {
      notificationDiagnostics = diagnostics;
    });
  }

  /// Solicita permisos de notificacion desde la UI y refresca el diagnostico.
  Future<void> requestNotificationPermissionsFromUi() async {
    if (!NotificationService.supportsLocalNotifications) return;

    setState(() {
      isNotificationActionInProgress = true;
    });

    final result = await TodayNotificationCoordinator.requestPermissions(
      syncNotifications: syncNotificationsWithStoredState,
    );

    if (!mounted) return;
    setState(() {
      notificationDiagnostics = result.diagnostics;
      isNotificationActionInProgress = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
      ),
    );
  }

  /// Recalcula manualmente todos los recordatorios futuros.
  Future<void> resyncNotificationsFromUi() async {
    if (!NotificationService.supportsLocalNotifications) return;

    setState(() {
      isNotificationActionInProgress = true;
    });

    final result = await TodayNotificationCoordinator.resync(
      syncNotifications: syncNotificationsWithStoredState,
    );

    if (!mounted) return;
    setState(() {
      notificationDiagnostics = result.diagnostics;
      isNotificationActionInProgress = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  /// Dispara una notificacion inmediata para probar el canal del dispositivo.
  Future<void> sendTestNotificationFromUi() async {
    if (!NotificationService.supportsLocalNotifications) return;

    setState(() {
      isNotificationActionInProgress = true;
    });

    final result = await TodayNotificationCoordinator.sendTestNotification();

    if (!mounted) return;
    setState(() {
      notificationDiagnostics = result.diagnostics;
      isNotificationActionInProgress = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  /// Cuando un bloque activa push, intentamos dejar listo el permiso y la
  /// agenda para que la experiencia sea mas confiable desde el primer uso.
  Future<void> prepareNotificationsForBlockIfNeeded(DayBlock block) async {
    final diagnostics = await TodayNotificationCoordinator.prepareForBlockIfNeeded(
      block: block,
      syncNotifications: syncNotificationsWithStoredState,
    );

    if (!mounted) return;
    setState(() {
      notificationDiagnostics = diagnostics;
    });
  }

  void showFeedbackMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String formatNotificationWhen(DateTime dateTime) {
    final normalizedToday = DateTime(todayDate.year, todayDate.month, todayDate.day);
    final targetDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final timeLabel = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (TodayCalendarUtils.isSameCalendarDay(targetDay, normalizedToday)) {
      return 'Hoy · $timeLabel';
    }

    if (TodayCalendarUtils.isSameCalendarDay(
      targetDay,
      normalizedToday.add(const Duration(days: 1)),
    )) {
      return 'Mañana · $timeLabel';
    }

    return '${DateKey.formatForDisplay(DateKey.fromDate(dateTime))} · $timeLabel';
  }

  String buildPushFeedbackForBlock({
    required DayBlock block,
    required String baseMessage,
    DatedBlockEntry? datedEntry,
  }) {
    if (!block.receivesPushNotification) {
      return '$baseMessage No agenda recordatorio push porque ese toggle esta apagado.';
    }

    final isScheduled = datedEntry != null
        ? isDatedEntryNotificationScheduled(datedEntry)
        : isBlockNotificationScheduled(block);
    final nextWhen = nextScheduledNotificationAt;

    if (!isScheduled) {
      return '$baseMessage Ritual intentó programar el recordatorio, pero no quedó ninguno futuro para este bloque. Revisa hora, fecha y permisos.';
    }

    if (nextWhen == null) {
      return '$baseMessage Recordatorio push programado.';
    }

    return '$baseMessage Recordatorio push programado para ${formatNotificationWhen(nextWhen)}.';
  }

  /// Marca o desmarca un bloque del registro diario activo y persiste el cambio.
  Future<void> toggleBlock(int index) async {
    if (activeDayRecord == null) {
      await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
    }

    final block = visibleBlocks[index];

    if (isDatedBlock(block)) {
      final reminderEntry = getDatedBlockEntryById(block.id);
      if (reminderEntry == null) return;

      setState(() {
        reminderEntry.block.isDone = !reminderEntry.block.isDone;
      });

      await saveDatedBlocksAndRefresh();
      return;
    }

    final currentRecord = activeDayRecord;
    if (currentRecord == null) return;
    final recordIndex = getTodayBlockIndexById(block.id);
    if (recordIndex == -1) return;

    setState(() {
      currentRecord.blocks[recordIndex].isDone =
          !currentRecord.blocks[recordIndex].isDone;
    });

    await StorageService.saveDailyRecords(dailyRecords);
    await syncNotificationsWithStoredState();
  }

  /// Explica al usuario como debe transformarse el plan del dia al cambiar
  /// desde una rutina hacia otra.
  Future<_RoutineSwitchStrategy?> showRoutineSwitchDialog({
    required Routine previousRoutine,
    required Routine nextRoutine,
  }) {
    return showModalBottomSheet<_RoutineSwitchStrategy>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);

        Widget buildStrategyTile({
          required _RoutineSwitchStrategy strategy,
          required IconData icon,
          required String title,
          required String description,
          required Color color,
        }) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(strategy),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cambiar rutina de hoy',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vas a pasar de "${previousRoutine.name}" a "${nextRoutine.name}". Elige como quieres transformar el horario de hoy.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 18),
                buildStrategyTile(
                  strategy: _RoutineSwitchStrategy.preserveAndAdd,
                  icon: Icons.merge_type_rounded,
                  color: const Color(0xFF4DA3FF),
                  title: 'Mantener lo hecho y agregar lo nuevo',
                  description:
                      'Conserva todos los bloques actuales, incluidos los completados y pendientes, y agrega los bloques que falten de la nueva rutina.',
                ),
                buildStrategyTile(
                  strategy: _RoutineSwitchStrategy.replacePending,
                  icon: Icons.update_rounded,
                  color: const Color(0xFF41C47B),
                  title: 'Mantener lo hecho y reemplazar lo pendiente',
                  description:
                      'Deja intacto lo ya completado y reemplaza el resto del dia con la nueva rutina. Es util si cambiaste de plan a mitad del dia.',
                ),
                buildStrategyTile(
                  strategy: _RoutineSwitchStrategy.restartDay,
                  icon: Icons.restart_alt_rounded,
                  color: const Color(0xFFFFA24D),
                  title: 'Reiniciar el dia con la nueva rutina',
                  description:
                      'Descarta el plan actual de hoy y crea uno nuevo desde cero con la rutina seleccionada.',
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Permite decidir si un cambio de bloques afecta solo hoy o la plantilla.
  Future<_BlockChangeScope?> showBlockChangeScopeDialog({
    required String title,
    required String todayOnlyDescription,
    required String routineOnlyDescription,
  }) {
    return showModalBottomSheet<_BlockChangeScope>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);

        Widget buildScopeTile({
          required _BlockChangeScope scope,
          required IconData icon,
          required String tileTitle,
          required String description,
          required Color color,
        }) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pop(scope),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tileTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Como ya existe un dia en curso, elige si este cambio debe afectar solo hoy o la rutina base para los proximos dias.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 18),
                buildScopeTile(
                  scope: _BlockChangeScope.todayOnly,
                  icon: Icons.today_rounded,
                  color: const Color(0xFF4DA3FF),
                  tileTitle: 'Solo hoy',
                  description: todayOnlyDescription,
                ),
                buildScopeTile(
                  scope: _BlockChangeScope.routineOnly,
                  icon: Icons.event_repeat_rounded,
                  color: const Color(0xFF41C47B),
                  tileTitle: 'Toda la rutina',
                  description: routineOnlyDescription,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Cambia cual rutina esta activa.
  ///
  /// La regla de negocio aqui es simple: solo puede existir una rutina activa
  /// a la vez. Si la nueva rutina aun no tiene registro para hoy, pedimos una
  /// estrategia de transicion para decidir como transformar el plan del dia.
  Future<void> selectRoutine(Routine selectedRoutine) async {
    if (activeRoutine?.id == selectedRoutine.id) return;

    final previousRoutine = activeRoutine;
    final previousRecord = previousRoutine == null
        ? null
        : getTodayRecordForRoutineId(previousRoutine.id);
    final selectedRoutineRecord = getTodayRecordForRoutineId(selectedRoutine.id);
    final shouldPromptForTransition =
        previousRoutine != null &&
        previousRecord != null &&
        (previousRecord.hasAnyCompletedBlocks ||
            doesRecordDifferFromRoutineTemplate(
              previousRecord,
              previousRoutine,
            ));

    if (shouldPromptForTransition && selectedRoutineRecord == null) {
      final currentSourceBlocks = previousRecord.blocks;
      final strategy = await showRoutineSwitchDialog(
        previousRoutine: previousRoutine,
        nextRoutine: selectedRoutine,
      );

      if (strategy == null) return;

      final transitionedBlocks = buildBlocksForRoutineSwitch(
        currentDayBlocks: currentSourceBlocks,
        nextRoutineBlocks: selectedRoutine.blocks,
        strategy: strategy,
      );

      setState(() {
        // Regla del MVP: un cambio de rutina consolida el dia actual en un
        // solo registro para que el calendario del dia no quede fragmentado.
        dailyRecords.removeWhere((record) => record.dateKey == todayKey);
        dailyRecords.add(
          DailyRecord(
            dateKey: todayKey,
            routineId: selectedRoutine.id,
            routineName: selectedRoutine.name,
            blocks: transitionedBlocks,
          ),
        );
      });

      await StorageService.saveDailyRecords(dailyRecords);
    }

    setState(() {
      for (final routine in routines) {
        routine.isActive = routine.id == selectedRoutine.id;
      }

      activeRoutine = selectedRoutine;
    });

    await StorageService.saveRoutines(routines);

    // Caso borde: si la rutina seleccionada ya tenia un registro para hoy,
    // lo resincronizamos con su plantilla actual. Si no, solo la mostramos.
    if (getTodayRecordForRoutineId(selectedRoutine.id) != null) {
      await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
    }

    await syncNotificationsWithStoredState();

    if (!mounted) return;
    setState(() {});
  }

  /// Abre el selector nativo de fecha y devuelve la clave ya normalizada.
  Future<String?> pickDateKey({
    required BuildContext context,
    String? initialDateKey,
  }) async {
    final initialDate =
        initialDateKey != null ? DateKey.toDate(initialDateKey) : todayDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final theme = Theme.of(context);

        return Theme(
          data: theme.copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: theme.colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return null;
    return DateKey.fromDate(pickedDate);
  }

  /// Valida el borrador de vigencia de una rutina.
  ///
  /// Regla: un rango personalizado siempre debe tener fecha inicial.
  /// Caso borde: si existe fecha final, no puede ser anterior a la inicial.
  String? validateRoutineScheduleDraft({
    required RoutineScheduleType type,
    required String? startDateKey,
    required String? endDateKey,
  }) {
    if (type != RoutineScheduleType.customRange) return null;
    if (startDateKey == null || startDateKey.isEmpty) {
      return 'Selecciona una fecha de inicio.';
    }

    if (endDateKey == null || endDateKey.isEmpty) return null;

    final start = DateKey.toDate(startDateKey);
    final end = DateKey.toDate(endDateKey);

    if (end.isBefore(start)) {
      return 'La fecha final no puede ser anterior a la fecha inicial.';
    }

    return null;
  }

  /// Construye la configuracion de vigencia real a partir del formulario.
  RoutineSchedule buildRoutineScheduleFromDraft({
    required RoutineScheduleType type,
    required String? startDateKey,
    required String? endDateKey,
  }) {
    switch (type) {
      case RoutineScheduleType.always:
        return const RoutineSchedule.always();
      case RoutineScheduleType.currentWeek:
        return RoutineSchedule.currentWeek(anchorDate: todayDate);
      case RoutineScheduleType.currentMonth:
        return RoutineSchedule.currentMonth(anchorDate: todayDate);
      case RoutineScheduleType.customRange:
        return RoutineSchedule.customRange(
          startDateKey: startDateKey!,
          endDateKey:
              endDateKey == null || endDateKey.isEmpty ? null : endDateKey,
        );
    }
  }

  /// Abre el formulario para crear o editar una rutina.
  Future<_RoutineFormResult?> showRoutineForm({Routine? existingRoutine}) async {
    final formKey = GlobalKey<FormState>();
    var name = existingRoutine?.name ?? '';
    var scheduleType =
        existingRoutine?.schedule.type ?? RoutineScheduleType.always;
    var customStartDateKey = existingRoutine?.schedule.startDateKey;
    var customEndDateKey = existingRoutine?.schedule.endDateKey;

    return showDialog<_RoutineFormResult>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final scheduleValidationMessage = validateRoutineScheduleDraft(
              type: scheduleType,
              startDateKey: customStartDateKey,
              endDateKey: customEndDateKey,
            );
            final previewSchedule = buildRoutineScheduleFromDraft(
              type: scheduleType,
              startDateKey: customStartDateKey ?? todayKey,
              endDateKey: customEndDateKey,
            );

            Future<void> handlePickStartDate() async {
              final pickedDateKey = await pickDateKey(
                context: context,
                initialDateKey: customStartDateKey,
              );
              if (pickedDateKey == null) return;

              setDialogState(() {
                customStartDateKey = pickedDateKey;

                // Caso borde: si la fecha final quedo antes de la nueva fecha
                // inicial, la limpiamos para forzar una seleccion valida.
                if (customEndDateKey != null &&
                    DateKey.toDate(customEndDateKey!)
                        .isBefore(DateKey.toDate(pickedDateKey))) {
                  customEndDateKey = null;
                }
              });
            }

            Future<void> handlePickEndDate() async {
              final pickedDateKey = await pickDateKey(
                context: context,
                initialDateKey: customEndDateKey ?? customStartDateKey,
              );
              if (pickedDateKey == null) return;

              setDialogState(() {
                customEndDateKey = pickedDateKey;
              });
            }

            return AlertDialog(
              title: Text(
                existingRoutine == null ? 'Nueva rutina' : 'Editar rutina',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: name,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Ej. Vacaciones o Semana de enfoque',
                        ),
                        onChanged: (value) => name = value,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa un nombre para la rutina.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<RoutineScheduleType>(
                        initialValue: scheduleType,
                        decoration: const InputDecoration(
                          labelText: 'Vigencia',
                        ),
                        items: _routineScheduleOptions,
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            scheduleType = value;

                            // Regla: los modos predefinidos no dependen de
                            // fechas manuales, asi que limpiamos el borrador.
                            if (value != RoutineScheduleType.customRange) {
                              customStartDateKey = null;
                              customEndDateKey = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (scheduleType == RoutineScheduleType.customRange) ...[
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: handlePickStartDate,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Fecha inicial',
                                    suffixIcon:
                                        Icon(Icons.calendar_today_outlined),
                                  ),
                                  child: Text(
                                    customStartDateKey == null
                                        ? 'Seleccionar'
                                        : DateKey.formatForDisplay(
                                            customStartDateKey!,
                                          ),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: customStartDateKey == null
                                          ? Colors.white54
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: handlePickEndDate,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Fecha final opcional',
                                    suffixIcon:
                                        Icon(Icons.event_available_outlined),
                                  ),
                                  child: Text(
                                    customEndDateKey == null
                                        ? 'Sin fin'
                                        : DateKey.formatForDisplay(
                                            customEndDateKey!,
                                          ),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: customEndDateKey == null
                                          ? Colors.white54
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (customEndDateKey != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  customEndDateKey = null;
                                });
                              },
                              icon: const Icon(Icons.clear_rounded),
                              label: const Text('Quitar fecha final'),
                            ),
                          ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.date_range_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  previewSchedule.displayLabel,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (scheduleValidationMessage != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            scheduleValidationMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
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
                    final scheduleValidationMessage =
                        validateRoutineScheduleDraft(
                      type: scheduleType,
                      startDateKey: customStartDateKey,
                      endDateKey: customEndDateKey,
                    );

                    if (!isValid || scheduleValidationMessage != null) {
                      setDialogState(() {});
                      return;
                    }

                    Navigator.of(context).pop(
                      _RoutineFormResult(
                        name: name.trim(),
                        schedule: buildRoutineScheduleFromDraft(
                          type: scheduleType,
                          startDateKey: customStartDateKey,
                          endDateKey: customEndDateKey,
                        ),
                      ),
                    );
                  },
                  child: Text(existingRoutine == null ? 'Crear' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Crea una nueva rutina vacia y la deja como rutina activa.
  Future<void> createRoutine() async {
    final formResult = await showRoutineForm();
    if (formResult == null) return;

    final newRoutine = Routine(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: formResult.name,
      blocks: [],
      isActive: true,
      schedule: formResult.schedule,
    );

    setState(() {
      for (final routine in routines) {
        routine.isActive = false;
      }

      routines = [...routines, newRoutine];
      activeRoutine = newRoutine;
    });

    await StorageService.saveRoutines(routines);
    await syncNotificationsWithStoredState();

    if (!mounted) return;
    setState(() {});
  }

  /// Permite editar nombre y vigencia de una rutina existente.
  Future<void> editRoutine(Routine routine) async {
    final formResult = await showRoutineForm(existingRoutine: routine);
    if (formResult == null) return;

    if (formResult.name == routine.name &&
        formResult.schedule.type == routine.schedule.type &&
        formResult.schedule.startDateKey == routine.schedule.startDateKey &&
        formResult.schedule.endDateKey == routine.schedule.endDateKey) {
      return;
    }

    setState(() {
      routine.name = formResult.name;
      routine.schedule = formResult.schedule;

      // Regla: el historial usa el mismo `routineId`, por lo tanto cuando el
      // nombre cambia lo reflejamos en todos los registros historicos.
      for (final record in dailyRecords.where(
        (record) => record.routineId == routine.id,
      )) {
        record.routineName = formResult.name;
      }
    });

    await StorageService.saveRoutines(routines);
    await StorageService.saveDailyRecords(dailyRecords);

    if (activeRoutine?.id == routine.id && activeDayRecord != null) {
      await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
    }

    await syncNotificationsWithStoredState();

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

    if (activeDayRecord != null) {
      await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
    }

    await syncNotificationsWithStoredState();

    if (!mounted) return;
    setState(() {});
  }

  /// Crea una copia editable de una rutina existente.
  ///
  /// Regla: duplicamos tambien los bloques con ids nuevos para que la copia no
  /// comparta identidad con la rutina original y pueda evolucionar por
  /// separado en el futuro.
  Future<void> duplicateRoutine(Routine routine) async {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final duplicatedRoutine = Routine(
      id: '$timestamp-routine-copy',
      name: '${routine.name} copia',
      isActive: false,
      schedule: routine.schedule.copyWith(),
      blocks: routine.blocks
          .asMap()
          .entries
          .map(
            (entry) => entry.value.copyWith(
              id: '$timestamp-block-copy-${entry.key}',
              isDone: false,
            ),
          )
          .toList(),
    );

    setState(() {
      routines = [...routines, duplicatedRoutine];
    });

    await saveRoutinesAndRefresh();
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
      initialEntryMode: TimePickerEntryMode.input,
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
  Future<DayBlock?> showBlockForm({
    DayBlock? existingBlock,
    BlockType initialType = BlockType.habit,
    bool initialCountsTowardProgress = true,
    bool initialReceivesPushNotification = false,
  }) async {
    final formKey = GlobalKey<FormState>();
    var selectedType = existingBlock?.type ?? initialType;
    var start = existingBlock?.start ?? '';
    var end = existingBlock?.end ?? '';
    var title = existingBlock?.title ?? '';
    var description = existingBlock?.description ?? '';
    var countsTowardProgress =
        existingBlock?.countsTowardProgress ?? initialCountsTowardProgress;
    var receivesPushNotification = existingBlock?.receivesPushNotification ??
        initialReceivesPushNotification;

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

            final timeValidationMessage =
                DayBlockTimeValidator.validateBasicTimeRange(
              start: start,
              end: end,
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
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: receivesPushNotification,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Recibir recordatorio push'),
                        subtitle: const Text(
                          'Ritual intentara programar una notificacion local para este bloque cuando la plataforma lo permita.',
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            receivesPushNotification = value;
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
                    final basicTimeValidationMessage =
                        DayBlockTimeValidator.validateBasicTimeRange(
                      start: start,
                      end: end,
                    );

                    if (!isValid || basicTimeValidationMessage != null) {
                      setDialogState(() {});
                      return;
                    }

                    Future<void> finishSave() async {
                      if (!mounted) return;

                      Navigator.of(context).pop(
                        DayBlock(
                          id: existingBlock?.id,
                          start: start.trim(),
                          end: end.trim(),
                          title: title.trim(),
                          description: description.trim(),
                          type: selectedType,
                          countsTowardProgress: countsTowardProgress,
                          receivesPushNotification: receivesPushNotification,
                          isDone: existingBlock?.isDone ?? false,
                        ),
                      );
                    }

                    finishSave();
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

  /// Permite elegir rapidamente si se quiere crear un bloque de rutina o un
  /// evento puntual con fecha especifica.
  Future<void> showQuickCreateSheet() async {
    if (activeRoutine == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);

        Widget buildActionCard({
          required IconData icon,
          required Color color,
          required String title,
          required String description,
          required Future<void> Function() onTap,
        }) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                Navigator.of(context).pop();
                await onTap();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agregar a Ritual',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige si quieres cambiar la rutina o crear algo puntual para una fecha concreta.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 18),
                buildActionCard(
                  icon: Icons.view_timeline_rounded,
                  color: const Color(0xFF4DA3FF),
                  title: 'Bloque de rutina',
                  description:
                      'Agrega un bloque a la rutina o solo al plan de hoy segun el alcance que elijas despues.',
                  onTap: createBlock,
                ),
                buildActionCard(
                  icon: Icons.event_available_rounded,
                  color: const Color(0xFFFF7A6B),
                  title: 'Evento puntual',
                  description:
                      'Crea una reunion, cita o recordatorio para una fecha especifica sin tocar la rutina base.',
                  onTap: startQuickDatedBlockFlow,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Flujo rapido para elegir una fecha y crear un evento puntual.
  Future<void> startQuickDatedBlockFlow() async {
    final selectedDateKey = await pickDateKey(
      context: context,
      initialDateKey: todayKey,
    );
    if (selectedDateKey == null) return;

    await createDatedBlockForDate(DateKey.toDate(selectedDateKey));
  }

  /// Crea un nuevo bloque dentro de la rutina activa.
  Future<void> createBlock() async {
    if (activeRoutine == null) return;
    final createdBlock = await showBlockForm();

    if (createdBlock == null) return;

    final scope = await showBlockChangeScopeDialog(
      title: 'Agregar bloque',
      todayOnlyDescription:
          'Lo agrega solo al plan de hoy, como un recordatorio puntual o una reunion excepcional.',
      routineOnlyDescription:
          'Lo agrega a la plantilla de la rutina para que aparezca en los dias futuros, sin reescribir el historial de hoy.',
    );

    if (scope == null) return;

    if (scope == _BlockChangeScope.todayOnly) {
      if (activeDayRecord == null) {
        await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
      }

      final record = activeDayRecord;
      if (record == null) return;
      final shouldSave = await confirmOverlapIfNeeded(
        candidateBlock: createdBlock,
        comparisonBlocks: visibleBlocks,
        scopeLabel: 'el horario de hoy',
      );
      if (!shouldSave) return;

      final sortedBlocks = DayBlockCollectionUtils.sortChronologically([
        ...record.blocks,
        createdBlock,
      ]);

      setState(() {
        record.blocks
          ..clear()
          ..addAll(sortedBlocks);
      });

      await saveDailyRecordsAndRefresh();
      await prepareNotificationsForBlockIfNeeded(createdBlock);
      if (createdBlock.receivesPushNotification) {
        showFeedbackMessage(
          buildPushFeedbackForBlock(
            block: createdBlock,
            baseMessage: 'Bloque agregado solo para hoy.',
          ),
        );
      }
      return;
    }

    final shouldSave = await confirmOverlapIfNeeded(
      candidateBlock: createdBlock,
      comparisonBlocks: activeRoutine!.blocks,
      scopeLabel: 'la plantilla de la rutina',
    );
    if (!shouldSave) return;

    final sortedRoutineBlocks = DayBlockCollectionUtils.sortChronologically([
      ...activeRoutine!.blocks,
      createdBlock,
    ]);

    setState(() {
      activeRoutine!.blocks
        ..clear()
        ..addAll(sortedRoutineBlocks);
    });

    await saveRoutinesAndRefresh();
    await prepareNotificationsForBlockIfNeeded(createdBlock);
    if (createdBlock.receivesPushNotification) {
      showFeedbackMessage(
        buildPushFeedbackForBlock(
          block: createdBlock,
          baseMessage: 'Bloque agregado a la rutina.',
        ),
      );
    }
  }

  /// Crea un bloque puntual asociado a una fecha concreta.
  ///
  /// A diferencia de los bloques de rutina, este bloque pertenece solo a esa
  /// fecha y sirve para reuniones, citas, recordatorios o eventos aislados.
  Future<void> createDatedBlockForDate(DateTime date) async {
    final createdBlock = await showBlockForm(
      initialType: BlockType.event,
      initialCountsTowardProgress: false,
      initialReceivesPushNotification: true,
    );

    if (createdBlock == null) return;

    final shouldSave = await confirmOverlapIfNeeded(
      candidateBlock: createdBlock,
      comparisonBlocks: getPlannedBlocksForDate(date),
      scopeLabel:
          TodayCalendarUtils.isSameCalendarDay(date, todayDate)
              ? 'el horario de hoy'
              : 'esa fecha',
    );
    if (!shouldSave) return;

    final normalizedDateKey = DateKey.fromDate(date);
    final datedBlock = createdBlock.copyWith(
      id: 'dated-${createdBlock.id}',
      isDone: false,
    );

    final updatedEntries = [
      ...getDatedBlocksForDate(normalizedDateKey),
      DatedBlockEntry(
        dateKey: normalizedDateKey,
        block: datedBlock,
      ),
    ];
    final sortedEntries = DayBlockCollectionUtils.sortChronologically(
      updatedEntries.map((entry) => entry.block).toList(),
    );

    setState(() {
      datedBlocks.removeWhere((entry) => entry.dateKey == normalizedDateKey);
      datedBlocks.addAll(
        sortedEntries.map(
          (block) => DatedBlockEntry(
            dateKey: normalizedDateKey,
            block: block,
          ),
        ),
      );
    });

    await saveDatedBlocksAndRefresh();
    await prepareNotificationsForBlockIfNeeded(datedBlock);
    showFeedbackMessage(
      buildPushFeedbackForBlock(
        block: datedBlock,
        datedEntry: DatedBlockEntry(
          dateKey: normalizedDateKey,
          block: datedBlock,
        ),
        baseMessage:
            'Evento puntual guardado para ${DateKey.formatForDisplay(normalizedDateKey)}.',
      ),
    );
  }

  /// Edita un evento puntual directamente desde el detalle de una fecha.
  Future<void> editDatedBlockEntry(DatedBlockEntry entry) async {
    final updatedBlock = await showBlockForm(existingBlock: entry.block);
    if (updatedBlock == null) return;

    final entryDate = DateKey.toDate(entry.dateKey);
    final shouldSave = await confirmOverlapIfNeeded(
      candidateBlock: updatedBlock,
      comparisonBlocks: getPlannedBlocksForDate(entryDate),
      blockBeingEdited: entry.block,
      scopeLabel:
          TodayCalendarUtils.isSameCalendarDay(entryDate, todayDate)
              ? 'el horario de hoy'
              : 'esa fecha',
    );
    if (!shouldSave) return;

    final updatedEntries = getDatedBlocksForDate(entry.dateKey)
        .map((datedEntry) =>
            datedEntry.block.id == entry.block.id ? updatedBlock : datedEntry.block)
        .toList();
    final sortedBlocks = DayBlockCollectionUtils.sortChronologically(
      updatedEntries,
    );

    setState(() {
      datedBlocks.removeWhere((datedEntry) => datedEntry.dateKey == entry.dateKey);
      datedBlocks.addAll(
        sortedBlocks.map(
          (block) => DatedBlockEntry(
            dateKey: entry.dateKey,
            block: block,
          ),
        ),
      );
    });

    await saveDatedBlocksAndRefresh();
    await prepareNotificationsForBlockIfNeeded(updatedBlock);
    showFeedbackMessage(
      buildPushFeedbackForBlock(
        block: updatedBlock,
        datedEntry: DatedBlockEntry(
          dateKey: entry.dateKey,
          block: updatedBlock,
        ),
        baseMessage: 'Evento puntual actualizado.',
      ),
    );
  }

  /// Mueve un evento puntual a otra fecha sin convertirlo en parte de la
  /// rutina base.
  Future<void> moveDatedBlockEntryToAnotherDate(DatedBlockEntry entry) async {
    final targetDateKey = await pickDateKey(
      context: context,
      initialDateKey: entry.dateKey,
    );
    if (targetDateKey == null) return;

    final targetDate = DateKey.toDate(targetDateKey);
    final shouldSave = await confirmOverlapIfNeeded(
      candidateBlock: entry.block.copyWith(isDone: false),
      comparisonBlocks: getPlannedBlocksForDate(targetDate),
      blockBeingEdited: targetDateKey == entry.dateKey ? entry.block : null,
      scopeLabel:
          TodayCalendarUtils.isSameCalendarDay(targetDate, todayDate)
              ? 'el horario de hoy'
              : 'esa fecha',
    );
    if (!shouldSave) return;

    final movedBlock = entry.block.copyWith(
      isDone: targetDateKey == entry.dateKey ? entry.block.isDone : false,
    );

    final targetBlocks = [
      ...getDatedBlocksForDate(targetDateKey).map((datedEntry) => datedEntry.block),
      if (targetDateKey != entry.dateKey) movedBlock,
    ];

    final sortedTargetBlocks = DayBlockCollectionUtils.sortChronologically(
      targetDateKey == entry.dateKey
          ? getDatedBlocksForDate(targetDateKey)
              .map((datedEntry) =>
                  datedEntry.block.id == entry.block.id ? movedBlock : datedEntry.block)
              .toList()
          : targetBlocks,
    );

    setState(() {
      datedBlocks.remove(entry);
      datedBlocks.removeWhere((datedEntry) => datedEntry.dateKey == targetDateKey);
      datedBlocks.addAll(
        sortedTargetBlocks.map(
          (block) => DatedBlockEntry(
            dateKey: targetDateKey,
            block: block,
          ),
        ),
      );
    });

    await saveDatedBlocksAndRefresh();
    await prepareNotificationsForBlockIfNeeded(movedBlock);
    showFeedbackMessage(
      buildPushFeedbackForBlock(
        block: movedBlock,
        datedEntry: DatedBlockEntry(
          dateKey: targetDateKey,
          block: movedBlock,
        ),
        baseMessage:
            'Evento puntual movido a ${DateKey.formatForDisplay(targetDateKey)}.',
      ),
    );
  }

  /// Duplica un evento puntual para otra fecha sin perder el original.
  Future<void> duplicateDatedBlockEntryToAnotherDate(DatedBlockEntry entry) async {
    final targetDateKey = await pickDateKey(
      context: context,
      initialDateKey: entry.dateKey,
    );
    if (targetDateKey == null) return;

    final duplicatedBlock = entry.block.copyWith(
      id: 'dated-copy-${DateTime.now().microsecondsSinceEpoch}',
      isDone: false,
    );
    final targetDate = DateKey.toDate(targetDateKey);
    final shouldSave = await confirmOverlapIfNeeded(
      candidateBlock: duplicatedBlock,
      comparisonBlocks: getPlannedBlocksForDate(targetDate),
      scopeLabel:
          TodayCalendarUtils.isSameCalendarDay(targetDate, todayDate)
              ? 'el horario de hoy'
              : 'esa fecha',
    );
    if (!shouldSave) return;

    final updatedEntries = [
      ...getDatedBlocksForDate(targetDateKey),
      DatedBlockEntry(
        dateKey: targetDateKey,
        block: duplicatedBlock,
      ),
    ];
    final sortedBlocks = DayBlockCollectionUtils.sortChronologically(
      updatedEntries.map((datedEntry) => datedEntry.block).toList(),
    );

    setState(() {
      datedBlocks.removeWhere((datedEntry) => datedEntry.dateKey == targetDateKey);
      datedBlocks.addAll(
        sortedBlocks.map(
          (block) => DatedBlockEntry(
            dateKey: targetDateKey,
            block: block,
          ),
        ),
      );
    });

    await saveDatedBlocksAndRefresh();
    await prepareNotificationsForBlockIfNeeded(duplicatedBlock);
    showFeedbackMessage(
      buildPushFeedbackForBlock(
        block: duplicatedBlock,
        datedEntry: DatedBlockEntry(
          dateKey: targetDateKey,
          block: duplicatedBlock,
        ),
        baseMessage:
            'Evento puntual duplicado en ${DateKey.formatForDisplay(targetDateKey)}.',
      ),
    );
  }

  /// Elimina un evento puntual sin tocar la rutina base ni el resto del dia.
  Future<void> deleteDatedBlockEntry(DatedBlockEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar evento puntual'),
          content: Text(
            'Se eliminara "${entry.block.title}" de ${DateKey.formatForDisplay(entry.dateKey)}.',
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
      datedBlocks.remove(entry);
    });

    await saveDatedBlocksAndRefresh();
    showFeedbackMessage(
      entry.block.receivesPushNotification
          ? 'Evento puntual eliminado. Si tenia recordatorio push, Ritual ya lo sacó de la agenda.'
          : 'Evento puntual eliminado.',
    );
  }

  /// Edita un bloque existente reemplazandolo por una nueva version.
  Future<void> editBlock(int index) async {
    if (activeRoutine == null) return;

    final block = visibleBlocks[index];

    if (isDatedBlock(block)) {
      final reminderEntry = getDatedBlockEntryById(block.id);
      if (reminderEntry == null) return;

      final updatedBlock = await showBlockForm(existingBlock: reminderEntry.block);
      if (updatedBlock == null) return;
      final shouldSave = await confirmOverlapIfNeeded(
        candidateBlock: updatedBlock,
        comparisonBlocks: getPlannedBlocksForDate(
          DateKey.toDate(reminderEntry.dateKey),
        ),
        blockBeingEdited: reminderEntry.block,
        scopeLabel: TodayCalendarUtils.isSameCalendarDay(
          DateKey.toDate(reminderEntry.dateKey),
          todayDate,
        )
            ? 'el horario de hoy'
            : 'esa fecha',
      );
      if (!shouldSave) return;

      final reminderDateKey = reminderEntry.dateKey;
      final updatedEntries = getDatedBlocksForDate(reminderDateKey)
          .map((entry) => entry.block.id == block.id
              ? updatedBlock
              : entry.block)
          .toList();
      final sortedBlocks = DayBlockCollectionUtils.sortChronologically(
        updatedEntries,
      );

      setState(() {
        datedBlocks.removeWhere((entry) => entry.dateKey == reminderDateKey);
        datedBlocks.addAll(
          sortedBlocks.map(
            (sortedBlock) => DatedBlockEntry(
              dateKey: reminderDateKey,
              block: sortedBlock,
            ),
          ),
        );
      });

      await saveDatedBlocksAndRefresh();
      await prepareNotificationsForBlockIfNeeded(updatedBlock);
      if (updatedBlock.receivesPushNotification) {
        showFeedbackMessage(
          buildPushFeedbackForBlock(
            block: updatedBlock,
            datedEntry: DatedBlockEntry(
              dateKey: reminderDateKey,
              block: updatedBlock,
            ),
            baseMessage: 'Evento puntual actualizado.',
          ),
        );
      }
      return;
    }

    final updatedBlock = await showBlockForm(existingBlock: block);

    if (updatedBlock == null) return;

    final scope = await showBlockChangeScopeDialog(
      title: 'Editar bloque',
      todayOnlyDescription:
          'Actualiza solo el bloque del dia actual. El historial pasado no cambia y la rutina base queda igual.',
      routineOnlyDescription:
          'Actualiza la plantilla de la rutina para los proximos dias sin modificar el plan ya consolidado de hoy.',
    );

    if (scope == null) return;

    if (scope == _BlockChangeScope.todayOnly) {
      if (activeDayRecord == null) {
        await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
      }

      final record = activeDayRecord;
      if (record == null) return;
      final shouldSave = await confirmOverlapIfNeeded(
        candidateBlock: updatedBlock,
        comparisonBlocks: visibleBlocks,
        blockBeingEdited: block,
        scopeLabel: 'el horario de hoy',
      );
      if (!shouldSave) return;
      final recordIndex = getTodayBlockIndexById(block.id);
      if (recordIndex == -1) return;

      final updatedBlocks = [...record.blocks];
      updatedBlocks[recordIndex] = updatedBlock;
      final sortedBlocks = DayBlockCollectionUtils.sortChronologically(
        updatedBlocks,
      );

      setState(() {
        record.blocks
          ..clear()
          ..addAll(sortedBlocks);
      });

      await saveDailyRecordsAndRefresh();
      await prepareNotificationsForBlockIfNeeded(updatedBlock);
      if (updatedBlock.receivesPushNotification) {
        showFeedbackMessage(
          buildPushFeedbackForBlock(
            block: updatedBlock,
            baseMessage: 'Bloque de hoy actualizado.',
          ),
        );
      }
      return;
    }

    final routineIndex = getRoutineBlockIndexById(block.id);
    if (routineIndex == -1) return;
    final shouldSave = await confirmOverlapIfNeeded(
      candidateBlock: updatedBlock,
      comparisonBlocks: activeRoutine!.blocks,
      blockBeingEdited: block,
      scopeLabel: 'la plantilla de la rutina',
    );
    if (!shouldSave) return;

    final updatedRoutineBlocks = [...activeRoutine!.blocks];
    updatedRoutineBlocks[routineIndex] = updatedBlock.copyWith(isDone: false);
    final sortedRoutineBlocks = DayBlockCollectionUtils.sortChronologically(
      updatedRoutineBlocks,
    );

    setState(() {
      activeRoutine!.blocks
        ..clear()
        ..addAll(sortedRoutineBlocks);
    });

    await saveRoutinesAndRefresh();
    await prepareNotificationsForBlockIfNeeded(updatedBlock);
    if (updatedBlock.receivesPushNotification) {
      showFeedbackMessage(
        buildPushFeedbackForBlock(
          block: updatedBlock,
          baseMessage: 'Bloque de la rutina actualizado.',
        ),
      );
    }
  }

  /// Elimina un bloque existente de la rutina activa.
  Future<void> deleteBlock(int index) async {
    if (activeRoutine == null) return;
    final block = visibleBlocks[index];

    if (isDatedBlock(block)) {
      final reminderEntry = getDatedBlockEntryById(block.id);
      if (reminderEntry == null) return;

      setState(() {
        datedBlocks.remove(reminderEntry);
      });

      await saveDatedBlocksAndRefresh();
      showFeedbackMessage(
        reminderEntry.block.receivesPushNotification
            ? 'Evento puntual eliminado del día. Si tenia push, ya se canceló.'
            : 'Evento puntual eliminado del día.',
      );
      return;
    }

    final scope = await showBlockChangeScopeDialog(
      title: 'Eliminar bloque',
      todayOnlyDescription:
          'Lo quita solo del dia actual. Es util si hoy surgio un cambio puntual y no quieres tocar la rutina base.',
      routineOnlyDescription:
          'Lo quita de la plantilla de la rutina para el futuro, sin modificar lo que ya quedo guardado en dias pasados.',
    );

    if (scope == null) return;

    if (scope == _BlockChangeScope.todayOnly) {
      if (activeDayRecord == null) {
        await ensureTodayRecordForActiveRoutine(syncWithTemplate: true);
      }

      final record = activeDayRecord;
      if (record == null) return;
      final recordIndex = getTodayBlockIndexById(block.id);
      if (recordIndex == -1) return;

      setState(() {
        record.blocks.removeAt(recordIndex);
      });

      await saveDailyRecordsAndRefresh();
      if (block.receivesPushNotification) {
        showFeedbackMessage(
          'Bloque eliminado solo de hoy. Si tenia recordatorio push, Ritual ya actualizó la agenda.',
        );
      }
      return;
    }

    final routineIndex = getRoutineBlockIndexById(block.id);
    if (routineIndex == -1) return;

    setState(() {
      activeRoutine!.blocks.removeAt(routineIndex);
    });

    await saveRoutinesAndRefresh();
    if (block.receivesPushNotification) {
      showFeedbackMessage(
        'Bloque eliminado de la rutina. Si tenia recordatorio push, Ritual ya actualizó la agenda.',
      );
    }
  }

  /// Reordena los bloques de la rutina activa.
  ///
  /// Flutter entrega `newIndex` en la posicion final esperada, pero cuando el
  /// elemento viene de arriba hacia abajo hay que ajustar el indice por el
  /// efecto de haber removido primero el item original.
  void reorderBlocks(int oldIndex, int newIndex) {
    if (activeRoutine == null) return;
    final targetBlocks = activeDayRecord?.blocks ?? activeRoutine!.blocks;

    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final movedBlock = targetBlocks.removeAt(oldIndex);
      targetBlocks.insert(newIndex, movedBlock);
    });

    if (activeDayRecord != null) {
      saveDailyRecordsAndRefresh();
      return;
    }

    saveRoutinesAndRefresh();
  }

  double getRecordProgress(DailyRecord record) {
    if (record.progressEligibleBlocksCount == 0) return 0;
    return record.completedProgressBlocksCount / record.progressEligibleBlocksCount;
  }

  String buildRecordProgressLabel(DailyRecord record) {
    if (record.progressEligibleBlocksCount == 0) {
      return 'Sin bloques medibles';
    }

    return '${record.completedProgressBlocksCount}/${record.progressEligibleBlocksCount} bloques';
  }

  /// Muestra el detalle de un registro historico concreto.
  Future<void> showDailyRecordDetails(DailyRecord record) async {
    final progress = getRecordProgress(record);
    final progressColor = record.isCompletedDay
        ? const Color(0xFF41C47B)
        : progress > 0
            ? const Color(0xFF4DA3FF)
            : Colors.white54;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.86,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TodayDailyRecordDetailView(
                record: record,
                progress: progress,
                progressColor: progressColor,
                progressLabel: buildRecordProgressLabel(record),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Abre el historial de dias anteriores de la rutina activa.
  Future<void> showHistorySheet() async {
    if (activeRoutine == null) return;

    final selectedRecord = await showModalBottomSheet<DailyRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final records = activeRoutineHistoryRecords;

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de ${activeRoutine!.name}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aqui puedes navegar los dias anteriores y abrir el detalle de cada registro guardado.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: records.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.history_toggle_off_rounded,
                                    size: 52,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Todavia no hay dias anteriores para esta rutina',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cuando completes bloques en dias distintos, aparecera aqui el historial navegable.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: records.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final record = records[index];
                              final progress = getRecordProgress(record);

                              return Card(
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        theme.colorScheme.primary.withValues(
                                      alpha: 0.18,
                                    ),
                                    child: Text(
                                      DateKey.toDate(record.dateKey)
                                          .day
                                          .toString(),
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    DateKey.formatForDisplay(
                                      record.dateKey,
                                      includeWeekday: true,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(buildRecordProgressLabel(record)),
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 6,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          progress >= 1
                                              ? const Color(0xFF41C47B)
                                              : const Color(0xFF4DA3FF),
                                        ),
                                        backgroundColor: Colors.white12,
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () => Navigator.of(context).pop(record),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selectedRecord != null && mounted) {
      await showDailyRecordDetails(selectedRecord);
    }
  }

  DailyRecord? getRoutineRecordForDate(DateTime date) {
    if (activeRoutine == null) return null;

    final dateKey = DateKey.fromDate(date);
    return dailyRecords.cast<DailyRecord?>().firstWhere(
          (record) =>
              record?.routineId == activeRoutine!.id &&
              record?.dateKey == dateKey,
          orElse: () => null,
        );
  }

  List<Routine> getRoutinesApplyingOnDate(DateTime date) {
    final routinesForDate = routines.where((routine) => routine.appliesOn(date));
    return sortRoutinesForManagement(routinesForDate);
  }

  /// Abre el detalle de una fecha concreta desde el calendario.
  ///
  /// La hoja resuelve tres estados: registro real, vista previa futura o un
  /// mensaje vacio cuando no hay una rutina asociada a esa fecha.
  Future<void> showCalendarDateDetails(DateTime date) async {
    if (activeRoutine == null) return;

    final record = getRoutineRecordForDate(date);
    final datedEntries = getDatedBlocksForDate(DateKey.fromDate(date));
    final routinesForDate = getRoutinesApplyingOnDate(date);
    final suggestedRoutine = routinesForDate.isEmpty ? null : routinesForDate.first;
    final datedBlocksForDate = datedEntries.map((entry) => entry.block).toList();
    final recordAndReminderBlocks = record == null
        ? <DayBlock>[]
        : DayBlockCollectionUtils.sortChronologically([
            ...record.blocks,
            ...datedBlocksForDate.map(
              DayBlockCollectionUtils.cloneForDailyRecord,
            ),
          ]);
    final hasRoutinePreview = activeRoutine!.appliesOn(date);
    final hasDatedEntries = datedEntries.isNotEmpty;
    final hasScheduledRoutine = hasRoutinePreview || hasDatedEntries;
    final isFuture = TodayCalendarUtils.isFutureCalendarDay(
      date: date,
      todayDate: todayDate,
    );
    final canManageDatedEntries =
        !DateTime(date.year, date.month, date.day).isBefore(
          DateTime(todayDate.year, todayDate.month, todayDate.day),
        );
    final previewBlocks = activeRoutine!.blocks
        .map(
          (block) => DayBlockCollectionUtils.cloneForDailyRecord(
            block,
            isDone: false,
          ),
        )
        .toList();
    final previewAndReminderBlocks = DayBlockCollectionUtils.sortChronologically([
      ...previewBlocks,
      ...datedBlocksForDate.map(DayBlockCollectionUtils.cloneForDailyRecord),
    ]);
    final progressEligibleBlocks = recordAndReminderBlocks
        .where((block) => block.countsTowardProgress)
        .toList();
    final progress = record == null
        ? 0.0
        : progressEligibleBlocks.isEmpty
            ? 0.0
            : progressEligibleBlocks.where((block) => block.isDone).length /
                progressEligibleBlocks.length;
    final progressColor = record == null
        ? TodayCalendarUtils.getPreviewColor(
            hasScheduledRoutine: hasScheduledRoutine,
          )
        : record.isCompletedDay
            ? const Color(0xFF41C47B)
            : progress > 0
                ? const Color(0xFF4DA3FF)
                : Colors.white54;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.86,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TodayCalendarDateDetailView(
                date: date,
                record: record,
                recordProgressLabel:
                    record == null ? null : buildRecordProgressLabel(record),
                activeRoutine: activeRoutine!,
                routinesForDate: routinesForDate,
                suggestedRoutine: suggestedRoutine,
                hasRoutinePreview: hasRoutinePreview,
                hasDatedEntries: hasDatedEntries,
                hasScheduledRoutine: hasScheduledRoutine,
                isFuture: isFuture,
                canManageDatedEntries: canManageDatedEntries,
                recordBlocks: record?.blocks ?? const [],
                previewBlocks: previewBlocks,
                datedEntries: datedEntries,
                completedBlockCount:
                    recordAndReminderBlocks.where((block) => block.isDone).length,
                previewBlockCount: previewAndReminderBlocks.length,
                progress: progress,
                progressColor: progressColor,
                scheduledNotificationSourceKeys: scheduledNotificationSourceKeys,
                onAddDatedBlock: () async {
                  Navigator.of(context).pop();
                  await createDatedBlockForDate(date);
                  if (!mounted) return;
                  await showCalendarDateDetails(date);
                },
                onManageRoutines: () async {
                  Navigator.of(context).pop();
                  await showRoutineManagerSheet();
                },
                datedEntryActionsBuilder: (entry) => buildDatedEntryActionsMenu(
                  entry: entry,
                  onOpenDateDetails: () => showCalendarDateDetails(date),
                  closeCurrentSheetFirst: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Abre el historial de la rutina activa con una vista de calendario mensual.
  Future<void> showCalendarHistorySheet() async {
    if (activeRoutine == null) return;

    final selectedDate = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        DateTime visibleMonth = TodayCalendarUtils.monthAnchor(todayDate);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final calendarDays = TodayCalendarUtils.buildGridDays(visibleMonth);
            final monthSummary = TodayCalendarUtils.buildMonthSummary(
              monthDate: visibleMonth,
              recordForDate: getRoutineRecordForDate,
              datedEntriesCountForDate: (day) =>
                  getDatedBlocksForDate(DateKey.fromDate(day)).length,
              hasPushEnabledDatedEntriesForDate: (day) => getDatedBlocksForDate(
                DateKey.fromDate(day),
              ).any((entry) => entry.block.receivesPushNotification),
              hasCompletedDatedEntriesForDate: (day) => getDatedBlocksForDate(
                DateKey.fromDate(day),
              ).any((entry) => entry.block.isDone),
              routinesApplyingCountForDate: (day) =>
                  getRoutinesApplyingOnDate(day).length,
              activeRoutineAppliesOnDay: (day) =>
                  activeRoutine?.appliesOn(day) ?? false,
            );
            final formattedMonth =
                DateKey.formatForDisplay(DateKey.fromDate(visibleMonth));
            final parts = formattedMonth.split(' ');
            final monthLabel = '${parts[1]} ${visibleMonth.year}';

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.82,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendario de ${activeRoutine!.name}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toca un dia para ver su registro real, una vista previa futura o el mensaje de que aun no hay rutina para esa fecha.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setSheetState(() {
                                  visibleMonth = DateTime(
                                    visibleMonth.year,
                                    visibleMonth.month - 1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Expanded(
                              child: Text(
                                monthLabel,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setSheetState(() {
                                  visibleMonth = DateTime(
                                    visibleMonth.year,
                                    visibleMonth.month + 1,
                                  );
                                });
                              },
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TodayCalendarSummaryChip(
                            icon: Icons.local_fire_department_outlined,
                            label: 'con actividad',
                            value: '${monthSummary.activityDays}',
                          ),
                          TodayCalendarSummaryChip(
                            icon: Icons.event_note_rounded,
                            label: 'planificados',
                            value: '${monthSummary.plannedDays}',
                          ),
                          TodayCalendarSummaryChip(
                            icon: Icons.event_available_rounded,
                            label: 'con eventos',
                            value: '${monthSummary.eventDays}',
                          ),
                          if (monthSummary.pushEventDays > 0)
                            TodayCalendarSummaryChip(
                              icon: Icons.notifications_active_outlined,
                              label: 'con push',
                              value: '${monthSummary.pushEventDays}',
                            ),
                          if (monthSummary.multiRoutineDays > 0)
                            TodayCalendarSummaryChip(
                              icon: Icons.layers_rounded,
                              label: 'con varias rutinas',
                              value: '${monthSummary.multiRoutineDays}',
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setSheetState(() {
                              visibleMonth = TodayCalendarUtils.monthAnchor(
                                todayDate,
                              );
                            });
                          },
                          icon: const Icon(Icons.today_rounded),
                          label: const Text('Volver a hoy'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.1,
                        children: const [
                          'Lun',
                          'Mar',
                          'Mie',
                          'Jue',
                          'Vie',
                          'Sab',
                          'Dom',
                        ].map((label) {
                          return TodayCalendarWeekdayCell(label: label);
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: GridView.builder(
                          itemCount: calendarDays.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.95,
                          ),
                          itemBuilder: (context, index) {
                            final day = calendarDays[index];
                            final record = getRoutineRecordForDate(day);
                            final datedEntries = getDatedBlocksForDate(
                              DateKey.fromDate(day),
                            );
                            final routinesForDate = getRoutinesApplyingOnDate(day);

                            return TodayCalendarDayTile(
                              day: day,
                              visibleMonth: visibleMonth,
                              isToday: TodayCalendarUtils.isSameCalendarDay(
                                day,
                                todayDate,
                              ),
                              isFuture: TodayCalendarUtils.isFutureCalendarDay(
                                date: day,
                                todayDate: todayDate,
                              ),
                              hasScheduledRoutine:
                                  (activeRoutine?.appliesOn(day) ?? false) ||
                                  datedEntries.isNotEmpty,
                              hasActivity:
                                  (record?.hasAnyCompletedBlocks ?? false) ||
                                  datedEntries.any(
                                    (entry) => entry.block.isDone,
                                  ),
                              isCompletedDay: record?.isCompletedDay ?? false,
                              hasDatedEntries: datedEntries.isNotEmpty,
                              hasPushEnabledDatedEntries: datedEntries.any(
                                (entry) => entry.block.receivesPushNotification,
                              ),
                              routineCount: routinesForDate.length,
                              onTap: () => Navigator.of(context).pop(day),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          TodayCalendarLegendItem(
                            marker: const Icon(
                              Icons.local_fire_department_rounded,
                              size: 16,
                              color: Color(0xFFFFA24D),
                            ),
                            label: 'Dia con actividad',
                          ),
                          TodayCalendarLegendItem(
                            marker: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                            ),
                            label: 'Dia futuro planificado',
                          ),
                          TodayCalendarLegendItem(
                            marker: const Icon(
                              Icons.event_available_rounded,
                              size: 14,
                              color: Color(0xFFFF7A6B),
                            ),
                            label: 'Evento puntual',
                          ),
                          TodayCalendarLegendItem(
                            marker: const Icon(
                              Icons.notifications_active_rounded,
                              size: 14,
                              color: Color(0xFFFFD36C),
                            ),
                            label: 'Evento con push',
                          ),
                          TodayCalendarLegendItem(
                            marker: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4DA3FF)
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '2+',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF4DA3FF),
                                ),
                              ),
                            ),
                            label: 'Varias rutinas aplican',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selectedDate != null && mounted) {
      await showCalendarDateDetails(selectedDate);
    }
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
                          'Rutinas',
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
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await showRoutineManagerSheet();
                        },
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Gestionar'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Text(
                    'Elige la rutina que quieres ver hoy o editar para mas adelante.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
                ...routines.map((routine) {
                  final isSelected = routine.id == activeRoutine?.id;
                  final canDelete = routines.length > 1;
                  final scheduleStatus = buildRoutineScheduleStatus(routine);

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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${routine.blocks.length} bloques'),
                          const SizedBox(height: 4),
                          Text(
                            routine.schedule.displayLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scheduleStatus.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheduleStatus.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar nombre y vigencia',
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await editRoutine(routine);
                            },
                            icon: const Icon(Icons.edit_note_rounded),
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

  /// Abre una vista mas completa para administrar rutinas por periodo.
  ///
  /// Aqui agrupamos las rutinas segun su relacion con la fecha actual para que
  /// sea mas facil mantener varias variantes sin depender solo del selector
  /// rapido del dia a dia.
  Future<void> showRoutineManagerSheet() async {
    if (routines.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final recommendedToday = sortRoutinesForManagement(
          routines.where((routine) => routine.id == suggestedRoutineForToday?.id),
        );
        final availableToday = sortRoutinesForManagement(
          routines.where(
            (routine) =>
                routine.appliesOn(todayDate) &&
                routine.id != suggestedRoutineForToday?.id,
          ),
        );
        final upcomingRoutines = sortRoutinesForManagement(
          routines.where(
            (routine) =>
                !routine.appliesOn(todayDate) && isRoutineUpcoming(routine),
          ),
        );
        final expiredOrDormantRoutines = sortRoutinesForManagement(
          routines.where(
            (routine) =>
                !routine.appliesOn(todayDate) && !isRoutineUpcoming(routine),
          ),
        );

        Future<void> handleAction(
          Future<void> Function() action,
        ) async {
          Navigator.of(context).pop();
          await action();
        }

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.9,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Administrar rutinas',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
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
                  const SizedBox(height: 8),
                  Text(
                    'Aqui puedes ordenar mejor tus rutinas por vigencia, revisar cual conviene hoy y mantener preparadas las que vienen despues.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        buildRoutineManagerSection(
                          context: context,
                          title: 'Recomendada para hoy',
                          description:
                              'La rutina que mejor encaja con la fecha actual segun su vigencia.',
                          routinesInSection: recommendedToday,
                          onSelect: (routine) =>
                              handleAction(() => selectRoutine(routine)),
                          onEdit: (routine) =>
                              handleAction(() => editRoutine(routine)),
                          onDuplicate: (routine) =>
                              handleAction(() => duplicateRoutine(routine)),
                          onDelete: (routine) =>
                              handleAction(() => deleteRoutine(routine)),
                        ),
                        buildRoutineManagerSection(
                          context: context,
                          title: 'Tambien disponibles hoy',
                          description:
                              'Rutinas vigentes que puedes usar hoy aunque no sean la recomendada principal.',
                          routinesInSection: availableToday,
                          onSelect: (routine) =>
                              handleAction(() => selectRoutine(routine)),
                          onEdit: (routine) =>
                              handleAction(() => editRoutine(routine)),
                          onDuplicate: (routine) =>
                              handleAction(() => duplicateRoutine(routine)),
                          onDelete: (routine) =>
                              handleAction(() => deleteRoutine(routine)),
                        ),
                        buildRoutineManagerSection(
                          context: context,
                          title: 'Proximas por iniciar',
                          description:
                              'Rutinas futuras que ya puedes dejar listas antes de que les llegue su turno.',
                          routinesInSection: upcomingRoutines,
                          onSelect: (routine) =>
                              handleAction(() => selectRoutine(routine)),
                          onEdit: (routine) =>
                              handleAction(() => editRoutine(routine)),
                          onDuplicate: (routine) =>
                              handleAction(() => duplicateRoutine(routine)),
                          onDelete: (routine) =>
                              handleAction(() => deleteRoutine(routine)),
                        ),
                        buildRoutineManagerSection(
                          context: context,
                          title: 'Fuera de rango o archivables',
                          description:
                              'Rutinas vencidas o no activas por fecha. Puedes reusarlas, duplicarlas o limpiarlas.',
                          routinesInSection: expiredOrDormantRoutines,
                          onSelect: (routine) =>
                              handleAction(() => selectRoutine(routine)),
                          onEdit: (routine) =>
                              handleAction(() => editRoutine(routine)),
                          onDuplicate: (routine) =>
                              handleAction(() => duplicateRoutine(routine)),
                          onDelete: (routine) =>
                              handleAction(() => deleteRoutine(routine)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Calcula el progreso total de la rutina activa.
  ///
  /// Regla: solo cuentan los bloques marcados como relevantes para progreso.
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

  /// Resume la vigencia de una rutina para listas compactas.
  ///
  /// Regla: mostramos un solo mensaje accionable para que el usuario entienda
  /// rapido si la rutina aplica hoy, si empieza pronto o si ya vencio.
  ({String label, Color color}) buildRoutineScheduleStatus(Routine routine) {
    final daysUntilStart = routine.schedule.daysUntilStart(todayDate);
    final daysUntilEnd = routine.schedule.daysUntilEnd(todayDate);
    final suggestedRoutine = suggestedRoutineForToday;

    if (routine.appliesOn(todayDate)) {
      if (suggestedRoutine?.id == routine.id) {
        return (
          label: 'Recomendada hoy',
          color: const Color(0xFF41C47B),
        );
      }

      if (daysUntilEnd == 0) {
        return (
          label: 'Termina hoy',
          color: const Color(0xFFFFA24D),
        );
      }

      if (daysUntilEnd != null && daysUntilEnd <= 2) {
        return (
          label: 'Termina en $daysUntilEnd d\u00EDas',
          color: const Color(0xFFFFA24D),
        );
      }

      return (
        label: 'Disponible hoy',
        color: const Color(0xFF4DA3FF),
      );
    }

    if (daysUntilStart == 0) {
      return (
        label: 'Empieza hoy',
        color: const Color(0xFF4DA3FF),
      );
    }

    if (daysUntilStart == 1) {
      return (
        label: 'Empieza ma\u00F1ana',
        color: const Color(0xFF4DA3FF),
      );
    }

    if (daysUntilStart != null && daysUntilStart <= 7) {
      return (
        label: 'Empieza en $daysUntilStart d\u00EDas',
        color: const Color(0xFF4DA3FF),
      );
    }

    if (routine.schedule.hasEndedBy(todayDate)) {
      return (
        label: 'Rango ya vencido',
        color: Colors.white54,
      );
    }

    return (
      label: 'Fuera del rango sugerido',
      color: Colors.white54,
    );
  }

  bool isRoutineUpcoming(Routine routine) {
    final daysUntilStart = routine.schedule.daysUntilStart(todayDate);
    return daysUntilStart != null && daysUntilStart >= 0;
  }

  bool isRoutineExpired(Routine routine) {
    return routine.schedule.hasEndedBy(todayDate);
  }

  int compareRoutinesForManagement(Routine a, Routine b) {
    final availabilityComparison =
        (a.appliesOn(todayDate) ? 0 : 1).compareTo(b.appliesOn(todayDate) ? 0 : 1);
    if (availabilityComparison != 0) return availabilityComparison;

    final upcomingComparison =
        (isRoutineUpcoming(a) ? 0 : 1).compareTo(isRoutineUpcoming(b) ? 0 : 1);
    if (upcomingComparison != 0) return upcomingComparison;

    return TodayRoutineUtils.compareForTodaySuggestion(a, b);
  }

  List<Routine> sortRoutinesForManagement(Iterable<Routine> source) {
    final sortedRoutines = source.toList()..sort(compareRoutinesForManagement);
    return sortedRoutines;
  }

  Widget buildRoutineManagerSection({
    required BuildContext context,
    required String title,
    required String description,
    required List<Routine> routinesInSection,
    required void Function(Routine routine) onSelect,
    required void Function(Routine routine) onEdit,
    required void Function(Routine routine) onDuplicate,
    required void Function(Routine routine) onDelete,
  }) {
    final theme = Theme.of(context);

    if (routinesInSection.isEmpty) {
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
          ...routinesInSection.map((routine) {
            final scheduleStatus = buildRoutineScheduleStatus(routine);
            final isSelected = routine.id == activeRoutine?.id;
            final daysUntilStart = routine.schedule.daysUntilStart(todayDate);
            final daysUntilEnd = routine.schedule.daysUntilEnd(todayDate);

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
                            routine.name,
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
                          label: Text('${routine.blocks.length} bloques'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.date_range_rounded, size: 18),
                          label: Text(routine.schedule.shortLabel),
                        ),
                        Chip(
                          avatar: Icon(Icons.schedule_rounded, size: 18),
                          label: Text(scheduleStatus.label),
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
                    if (daysUntilStart != null || daysUntilEnd != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (daysUntilStart != null)
                            'Empieza en $daysUntilStart dias',
                          if (daysUntilEnd != null)
                            'Termina en $daysUntilEnd dias',
                        ].join(' | '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => onSelect(routine),
                          icon: const Icon(Icons.playlist_add_check_rounded),
                          label: Text(isSelected ? 'Activa' : 'Usar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => onEdit(routine),
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Editar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => onDuplicate(routine),
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Duplicar'),
                        ),
                        if (routines.length > 1)
                          OutlinedButton.icon(
                            onPressed: () => onDelete(routine),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Eliminar'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Construye los avisos principales de vigencia que deben verse hoy.
  List<RoutineNotice> get activeRoutineNotices {
    if (activeRoutine == null) return const [];

    return TodayRoutineUtils.buildActiveRoutineNotices(
      activeRoutine: activeRoutine!,
      routines: routines,
      todayDate: todayDate,
    );
  }

  Widget buildRoutineNoticeCard({
    required BuildContext context,
    required RoutineNotice notice,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notice.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: notice.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: notice.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(notice.icon, color: notice.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notice.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Resume el estado actual del sistema de notificaciones para la UI.
  String get notificationStatusDescription {
    return TodayNotificationCoordinator.buildStatusDescription(
      notificationDiagnostics,
    );
  }

  String buildDatedEntryDateLabel(DatedBlockEntry entry) {
    final date = DateKey.toDate(entry.dateKey);
    if (TodayCalendarUtils.isSameCalendarDay(date, todayDate)) {
      return 'Hoy';
    }

    if (TodayCalendarUtils.isSameCalendarDay(
      date,
      todayDate.add(const Duration(days: 1)),
    )) {
      return 'Mañana';
    }

    return DateKey.formatForDisplay(entry.dateKey);
  }

  Widget buildNotificationStatusCard({
    required BuildContext context,
    required int pushEnabledBlocksCount,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA24D).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFA24D).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recordatorios del dispositivo',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            notificationStatusDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text('$pushEnabledBlocksCount bloques con push'),
              ),
              if (notificationDiagnostics.supportsLocalNotifications)
                Chip(
                  avatar: Icon(
                    notificationDiagnostics.notificationsEnabled == false
                        ? Icons.notifications_off_rounded
                        : Icons.notifications_rounded,
                    size: 18,
                  ),
                  label: Text(
                    notificationDiagnostics.notificationsEnabled == false
                        ? 'Permiso apagado'
                        : notificationDiagnostics.notificationsEnabled == true
                            ? 'Permiso activo'
                            : 'Permiso no confirmado',
                  ),
                ),
              if (notificationDiagnostics.supportsLocalNotifications)
                Chip(
                  avatar: const Icon(Icons.schedule_send_rounded, size: 18),
                  label: Text(
                    '${notificationDiagnostics.scheduledNotificationsCount} programadas',
                  ),
                ),
              if (notificationDiagnostics.supportsLocalNotifications &&
                  notificationDiagnostics.scheduledDatedNotificationsCount > 0)
                Chip(
                  avatar: const Icon(Icons.event_available_rounded, size: 18),
                  label: Text(
                    '${notificationDiagnostics.scheduledDatedNotificationsCount} puntuales',
                  ),
                ),
            ],
          ),
          if (notificationDiagnostics.nextScheduledAt != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.alarm_on_rounded,
                    color: Color(0xFFFFD36C),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Próximo recordatorio: ${formatNotificationWhen(notificationDiagnostics.nextScheduledAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (notificationDiagnostics.supportsLocalNotifications)
                FilledButton.tonalIcon(
                  onPressed: isNotificationActionInProgress
                      ? null
                      : requestNotificationPermissionsFromUi,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Revisar permisos'),
                ),
              if (notificationDiagnostics.supportsLocalNotifications)
                OutlinedButton.icon(
                  onPressed: isNotificationActionInProgress
                      ? null
                      : resyncNotificationsFromUi,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Reagendar'),
                ),
              if (notificationDiagnostics.supportsLocalNotifications)
                OutlinedButton.icon(
                  onPressed: isNotificationActionInProgress
                      ? null
                      : sendTestNotificationFromUi,
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Probar ahora'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Menu compacto para administrar un evento puntual sin mezclarlo con la
  /// rutina base.
  Widget buildDatedEntryActionsMenu({
    required DatedBlockEntry entry,
    required Future<void> Function() onOpenDateDetails,
    bool closeCurrentSheetFirst = false,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Acciones del evento',
      onSelected: (value) async {
        if (closeCurrentSheetFirst && mounted) {
          Navigator.of(context).pop();
        }

        switch (value) {
          case 'open':
            await onOpenDateDetails();
            break;
          case 'edit':
            await editDatedBlockEntry(entry);
            await onOpenDateDetails();
            break;
          case 'move':
            await moveDatedBlockEntryToAnotherDate(entry);
            await onOpenDateDetails();
            break;
          case 'duplicate':
            await duplicateDatedBlockEntryToAnotherDate(entry);
            await onOpenDateDetails();
            break;
          case 'delete':
            await deleteDatedBlockEntry(entry);
            if (closeCurrentSheetFirst) {
              await onOpenDateDetails();
            }
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'open',
          child: Text('Abrir fecha'),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Text('Editar'),
        ),
        PopupMenuItem(
          value: 'move',
          child: Text('Mover a otra fecha'),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: Text('Duplicar en otra fecha'),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text('Eliminar'),
        ),
      ],
    );
  }

  /// Muestra los proximos eventos puntuales para que no dependan solo del
  /// calendario como punto de acceso.
  Widget buildUpcomingDatedEventsCard({
    required BuildContext context,
    required List<DatedBlockEntry> entries,
    required Set<String> scheduledNotificationSourceKeys,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A6B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF7A6B).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proximos eventos puntuales',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bloques aislados por fecha que no modifican tu rutina base.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          ...entries.map((entry) {
            final isTodayEvent = entry.dateKey == todayKey;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A6B).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: Color(0xFFFF7A6B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.block.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${isTodayEvent ? 'Hoy' : buildDatedEntryDateLabel(entry)} | ${entry.block.start} - ${entry.block.end}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.event_note_rounded, size: 16),
                              label: Text(buildDatedEntryDateLabel(entry)),
                            ),
                            if (entry.block.receivesPushNotification)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(
                                  scheduledNotificationSourceKeys.contains(
                                    buildDatedEntryNotificationSourceKey(entry),
                                  )
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_paused_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  scheduledNotificationSourceKeys.contains(
                                    buildDatedEntryNotificationSourceKey(entry),
                                  )
                                      ? 'Push programado'
                                      : 'Push pendiente',
                                ),
                              ),
                            if (entry.block.isDone)
                              const Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(Icons.task_alt_rounded, size: 16),
                                label: Text('Hecho'),
                              ),
                          ],
                        ),
                        if (entry.block.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.block.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  buildDatedEntryActionsMenu(
                    entry: entry,
                    onOpenDateDetails: () =>
                        showCalendarDateDetails(DateKey.toDate(entry.dateKey)),
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: showCalendarHistorySheet,
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('Ver calendario'),
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
    final pushEnabledBlocksCount =
        blocks.where((block) => block.receivesPushNotification).length;
    final upcomingDatedEntries = getUpcomingDatedBlocks();
    final insights = activeRoutineInsights;
    final isScheduledToday = isActiveRoutineScheduledToday;
    final routineNotices = activeRoutineNotices;
    final suggestedRoutine = suggestedRoutineForToday;
    final shouldOfferSuggestedRoutineSwitch =
        suggestedRoutine != null &&
        suggestedRoutine.id != activeRoutine!.id &&
        suggestedRoutine.appliesOn(todayDate);
    final emptyStateDescription = isScheduledToday
        ? 'La rutina ya quedo creada. Ahora puedes agregar tu primer bloque.'
        : 'Esta rutina esta fuera de su rango sugerido para hoy, pero puedes usarla o editarla igualmente.';
    final progressDescription = progressBlocks.isEmpty
        ? 'Aun no hay bloques que cuenten para el progreso.'
        : '$completed de ${progressBlocks.length} bloques cuentan para progreso.';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hoy \u00B7 ${activeRoutine!.name}'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'Historial',
              onPressed: showCalendarHistorySheet,
              icon: const Icon(Icons.history_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'Agregar',
              onPressed: showQuickCreateSheet,
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
                    'Progreso del dia',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    progressDescription,
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
                      Chip(
                        avatar: const Icon(Icons.date_range_rounded, size: 18),
                        label: Text(activeRoutine!.schedule.shortLabel),
                      ),
                      if (!isScheduledToday)
                        Chip(
                          avatar:
                              const Icon(Icons.watch_later_outlined, size: 18),
                          label: const Text('Fuera del rango sugerido'),
                        ),
                      if (nonProgressBlocksCount > 0)
                        Chip(
                          avatar: const Icon(Icons.visibility_outlined, size: 18),
                          label: Text('$nonProgressBlocksCount informativos'),
                        ),
                      if (pushEnabledBlocksCount > 0)
                        Chip(
                          avatar: const Icon(
                            Icons.notifications_active_outlined,
                            size: 18,
                          ),
                          label: Text('$pushEnabledBlocksCount con push'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activeRoutine!.schedule.displayLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  if (routineNotices.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ...routineNotices.map(
                      (notice) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: buildRoutineNoticeCard(
                          context: context,
                          notice: notice,
                        ),
                      ),
                    ),
                  ],
                  if (pushEnabledBlocksCount > 0) ...[
                    const SizedBox(height: 6),
                    buildNotificationStatusCard(
                      context: context,
                      pushEnabledBlocksCount: pushEnabledBlocksCount,
                    ),
                  ],
                  if (shouldOfferSuggestedRoutineSwitch) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4DA3FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF4DA3FF).withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rutina sugerida para hoy',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '"${suggestedRoutine.name}" parece encajar mejor con la fecha de hoy. Puedes cambiarte con un toque o seguir usando la actual.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () => selectRoutine(suggestedRoutine),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text('Usar ${suggestedRoutine.name}'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (upcomingDatedEntries.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    buildUpcomingDatedEventsCard(
                      context: context,
                      entries: upcomingDatedEntries,
                      scheduledNotificationSourceKeys:
                          scheduledNotificationSourceKeys,
                    ),
                  ],
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
                            emptyStateDescription,
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
                          receivesPushNotification:
                              block.receivesPushNotification,
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
        onPressed: showQuickCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }
}

