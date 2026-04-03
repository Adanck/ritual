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
    final pendingEntries = _collectEntries(
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

    const details = NotificationDetails(
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

    for (final entry in pendingEntries) {
      await _plugin.zonedSchedule(
        entry.id,
        entry.title,
        entry.body,
        tz.TZDateTime.from(entry.when, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: entry.payload,
      );
    }
  }

  /// Reune los recordatorios futuros que se deben agendar.
  static List<_ScheduledNotificationEntry> _collectEntries({
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
    final scheduledEntries = <_ScheduledNotificationEntry>[];
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
        _ScheduledNotificationEntry(
          id: Object.hash(sourceKey, when.millisecondsSinceEpoch) & 0x7fffffff,
          title: title,
          body: body,
          when: when,
          payload: sourceKey,
        ),
      );
    }

    for (final entry in datedBlocks) {
      final block = entry.block;
      if (!block.receivesPushNotification) continue;

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
          if (!block.receivesPushNotification) continue;

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
    final parts = block.start.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

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
}

/// Representa una notificacion concreta lista para ser agendada.
class _ScheduledNotificationEntry {
  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String payload;

  const _ScheduledNotificationEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
  });
}
