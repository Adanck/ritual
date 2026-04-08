import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:ritual/core/utils/date_key.dart';
import 'package:ritual/data/models/daily_record.dart';
import 'package:ritual/data/models/dated_block_entry.dart';
import 'package:ritual/data/models/day_block.dart';
import 'package:ritual/data/models/routine.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Encapsula la programacion de notificaciones locales del proyecto.
///
/// Por ahora se usa para recordatorios locales en plataformas compatibles
/// como Android y Windows. En web la preferencia de push se conserva, pero no
/// se agenda ninguna notificacion porque esta ruta tecnica no tiene soporte.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'ritual_day_blocks';
  static const String _channelName = 'Bloques de Ritual';
  static const String _channelDescription =
      'Recordatorios locales para bloques y eventos de Ritual.';
  static bool _initialized = false;
  static bool _timeZoneInitialized = false;
  static const Set<String> _ritualPayloadPrefixes = {
    'routine:',
    'record:',
    'dated:',
  };

  /// Indica si la plataforma actual soporta esta estrategia de notificaciones.
  static bool get supportsLocalNotifications => !kIsWeb;

  /// Inicializa el plugin y la zona horaria local.
  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings('ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Abrir Ritual',
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: 'Ritual',
      appUserModelId: 'com.example.ritual',
      guid: 'd7f9f6aa-7a67-4b69-a613-f53f9a8a7d61',
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Pide permisos cuando la plataforma lo requiere.
  ///
  /// Regla: solo los solicitamos si ya existe al menos un bloque con push
  /// habilitado para evitar prompts innecesarios en usuarios que no usen esta
  /// funcionalidad.
  static Future<void> requestPermissionsIfNeeded() async {
    if (kIsWeb) return;
    await initialize();

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Consulta si las notificaciones estan habilitadas cuando la plataforma lo
  /// expone de forma nativa.
  ///
  /// Caso borde: algunas plataformas de escritorio no ofrecen esta consulta en
  /// el plugin, asi que devolvemos `null` para que la UI muestre un estado
  /// neutro en lugar de asumir que estan desactivadas.
  static Future<bool?> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    await initialize();

    try {
      final androidEnabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      if (androidEnabled != null) return androidEnabled;
    } catch (_) {}

    return null;
  }

  /// Devuelve cuantas notificaciones futuras de Ritual quedaron programadas.
  ///
  /// Regla: preferimos contar solo payloads reconocidas de Ritual para que el
  /// diagnostico no se contamine con entradas residuales o ajenas a la agenda
  /// normal de bloques y eventos puntuales.
  static Future<int> getPendingNotificationsCount() async {
    if (kIsWeb) return 0;
    await initialize();

    try {
      final snapshot = await getPendingNotificationSnapshot();
      return snapshot.count;
    } catch (_) {
      return 0;
    }
  }

  /// Devuelve una vista consistente del estado pendiente dentro del dispositivo.
  ///
  /// Regla: filtramos las payloads que pertenecen a Ritual para poder comparar
  /// la agenda esperada contra la agenda real sin ruido de otras acciones que
  /// no formen parte de recordatorios programados por bloques o eventos.
  static Future<PendingNotificationSnapshot> getPendingNotificationSnapshot() async {
    if (kIsWeb) {
      return const PendingNotificationSnapshot(
        count: 0,
        ritualSourceKeys: {},
      );
    }

    await initialize();

    try {
      final pendingRequests = await _plugin.pendingNotificationRequests();
      final ritualSourceKeys = pendingRequests
          .map((request) => request.payload)
          .whereType<String>()
          .where((payload) {
            return _ritualPayloadPrefixes.any(payload.startsWith);
          })
          .toSet();

      return PendingNotificationSnapshot(
        count: ritualSourceKeys.length,
        ritualSourceKeys: ritualSourceKeys,
      );
    } catch (_) {
      return const PendingNotificationSnapshot(
        count: 0,
        ritualSourceKeys: {},
      );
    }
  }

  /// Lanza una notificacion inmediata para validar permisos y canal.
  ///
  /// Regla: se usa como herramienta de diagnostico manual desde la app para
  /// verificar rapidamente si el dispositivo puede mostrar recordatorios.
  static Future<void> showTestNotificationNow() async {
    if (kIsWeb) return;

    await initialize();
    await requestPermissionsIfNeeded();

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Ritual esta listo',
      'Si ves este aviso, las notificaciones locales estan funcionando.',
      _buildNotificationDetails(),
      payload: 'ritual:test-notification',
    );
  }

  /// Reagenda las notificaciones futuras a partir del estado actual.
  ///
  /// Regla: se recalcula todo para que la agenda quede alineada con cambios de
  /// rutina, bloques puntuales, ediciones de horario o toggles de la
  /// preferencia `receivesPushNotification`.
  static Future<void> syncScheduledNotifications({
    required List<Routine> routines,
    required List<DailyRecord> dailyRecords,
    required List<DatedBlockEntry> datedBlocks,
    required String? activeRoutineId,
    DateTime? anchorDate,
    int horizonDays = 21,
  }) async {
    if (kIsWeb) return;

    final now = (anchorDate ?? DateTime.now()).toLocal();
    final pendingEntries = buildPreviewEntries(
      routines: routines,
      dailyRecords: dailyRecords,
      datedBlocks: datedBlocks,
      activeRoutineId: activeRoutineId,
      anchorDate: now,
      horizonDays: horizonDays,
    );

    await initialize();
    await _plugin.cancelAll();

    if (pendingEntries.isEmpty) return;

    await requestPermissionsIfNeeded();

    for (final entry in pendingEntries) {
      await _plugin.zonedSchedule(
        entry.id,
        entry.title,
        entry.body,
        tz.TZDateTime.from(entry.when, tz.local),
        _buildNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: entry.payload,
      );
    }
  }

  /// Expone la agenda calculada antes de programarla para diagnostico y UI.
  ///
  /// Esto nos permite mostrar en la app cual es el proximo recordatorio y si
  /// un evento puntual concreto quedo cubierto por la agenda local.
  static List<NotificationPreviewEntry> buildPreviewEntries({
    required List<Routine> routines,
    required List<DailyRecord> dailyRecords,
    required List<DatedBlockEntry> datedBlocks,
    required String? activeRoutineId,
    DateTime? anchorDate,
    int horizonDays = 21,
  }) {
    final now = (anchorDate ?? DateTime.now()).toLocal();
    return _collectEntries(
      routines: routines,
      dailyRecords: dailyRecords,
      datedBlocks: datedBlocks,
      activeRoutineId: activeRoutineId,
      anchorDate: now,
      horizonDays: horizonDays,
    );
  }

  /// Reune los recordatorios futuros que se deben agendar.
  static List<NotificationPreviewEntry> _collectEntries({
    required List<Routine> routines,
    required List<DailyRecord> dailyRecords,
    required List<DatedBlockEntry> datedBlocks,
    required String? activeRoutineId,
    required DateTime anchorDate,
    required int horizonDays,
  }) {
    final normalizedToday = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
    );
    final scheduledEntries = <NotificationPreviewEntry>[];
    final seenKeys = <String>{};

    void addEntry({
      required String sourceKey,
      required String dateKey,
      required DayBlock block,
      required String title,
      required String body,
    }) {
      final when = _buildDateTimeForBlock(dateKey: dateKey, block: block);
      if (!when.isAfter(anchorDate)) return;
      if (!seenKeys.add(sourceKey)) return;

      scheduledEntries.add(
        NotificationPreviewEntry(
          id: Object.hash(sourceKey, when.millisecondsSinceEpoch) & 0x7fffffff,
          sourceKey: sourceKey,
          title: title,
          body: body,
          when: when,
          payload: sourceKey,
        ),
      );
    }

    for (final entry in datedBlocks) {
      final block = entry.block;
      // Regla: si un evento puntual ya esta marcado como hecho, no dejamos un
      // recordatorio futuro colgado para algo que el usuario ya resolvio.
      if (!block.receivesPushNotification || block.isDone) continue;

      addEntry(
        sourceKey: 'dated:${entry.dateKey}:${block.id}',
        dateKey: entry.dateKey,
        block: block,
        title: block.title,
        body: '${DateKey.formatForDisplay(entry.dateKey)} | ${block.start}',
      );
    }

    for (var offset = 0; offset <= horizonDays; offset++) {
      final date = normalizedToday.add(Duration(days: offset));
      final dateKey = DateKey.fromDate(date);

      final todaysRecord = dailyRecords.cast<DailyRecord?>().firstWhere(
        (record) => record?.dateKey == dateKey,
        orElse: () => null,
      );

      if (offset == 0 && todaysRecord != null) {
        for (final block in todaysRecord.blocks) {
          // Caso borde: el registro real de hoy puede tener checks hechos. Si
          // ya se completo el bloque, no conviene recordarlo otra vez.
          if (!block.receivesPushNotification || block.isDone) continue;

          addEntry(
            sourceKey: 'record:${todaysRecord.routineId}:$dateKey:${block.id}',
            dateKey: dateKey,
            block: block,
            title: block.title,
            body: '${todaysRecord.routineName} | ${block.start}',
          );
        }

        continue;
      }

      for (final routine in routines) {
        if (offset == 0 &&
            activeRoutineId != null &&
            routine.id != activeRoutineId) {
          continue;
        }

        if (!routine.appliesOn(date)) continue;

        for (final block in routine.blocks) {
          if (!block.receivesPushNotification) continue;

          addEntry(
            sourceKey: 'routine:${routine.id}:$dateKey:${block.id}',
            dateKey: dateKey,
            block: block,
            title: block.title,
            body: '${routine.name} | ${block.start}',
          );
        }
      }
    }

    scheduledEntries.sort((a, b) => a.when.compareTo(b.when));
    return scheduledEntries;
  }

  /// Convierte la fecha del bloque en un `DateTime` local listo para agendar.
  static DateTime _buildDateTimeForBlock({
    required String dateKey,
    required DayBlock block,
  }) {
    final date = DateKey.toDate(dateKey);
    final hour = block.startMinutes ~/ 60;
    final minute = block.startMinutes % 60;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Inicializa la base de zonas y selecciona la local del dispositivo.
  static Future<void> _configureLocalTimeZone() async {
    if (_timeZoneInitialized) return;

    tz.initializeTimeZones();

    try {
      final localTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    _timeZoneInitialized = true;
  }

  /// Centraliza los detalles visuales para no duplicar configuracion al agendar
  /// recordatorios o disparar una notificacion de prueba.
  static NotificationDetails _buildNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );
  }
}

/// Representa una notificacion concreta lista para ser agendada.
class NotificationPreviewEntry {
  final int id;
  final String sourceKey;
  final String title;
  final String body;
  final DateTime when;
  final String payload;

  const NotificationPreviewEntry({
    required this.id,
    required this.sourceKey,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
  });
}

/// Estado pendiente observado en el dispositivo para la app actual.
class PendingNotificationSnapshot {
  final int count;
  final Set<String> ritualSourceKeys;

  const PendingNotificationSnapshot({
    required this.count,
    required this.ritualSourceKeys,
  });
}
