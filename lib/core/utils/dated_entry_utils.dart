import 'package:ritual/core/utils/date_key.dart';
import 'package:ritual/core/utils/today_calendar_utils.dart';
import 'package:ritual/data/models/dated_block_entry.dart';

/// Helpers puros para dar contexto legible a eventos puntuales por fecha.
class DatedEntryUtils {
  /// Resume si el evento sigue pendiente, si cae hoy o si ya fue resuelto.
  static String buildStatusLabel({
    required DatedBlockEntry entry,
    required DateTime todayDate,
  }) {
    if (entry.block.isDone) return 'Completado';

    final date = DateKey.toDate(entry.dateKey);
    final normalizedToday = DateTime(todayDate.year, todayDate.month, todayDate.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final diff = normalizedDate.difference(normalizedToday).inDays;

    if (diff == 0) return 'Pendiente hoy';
    if (diff == 1) return 'Pendiente manana';
    if (diff > 1) return 'Pendiente en $diff dias';
    return 'Fecha pasada';
  }

  /// Da una etiqueta legible para el estado real del push asociado al evento.
  ///
  /// Regla: si el evento ya fue completado, el push se considera omitido aunque
  /// el toggle siga encendido, porque ya no conviene recordarlo.
  static String? buildPushLabel({
    required DatedBlockEntry entry,
    required Set<String> scheduledSourceKeys,
  }) {
    if (!entry.block.receivesPushNotification) return null;
    if (entry.block.isDone) return 'Push omitido';

    return scheduledSourceKeys.contains(
      'dated:${entry.dateKey}:${entry.block.id}',
    )
        ? 'Push programado'
        : 'Push pendiente';
  }

  /// Determina si la fecha del evento es hoy para superficies que cambian la
  /// forma de presentar el texto principal.
  static bool isToday({
    required DatedBlockEntry entry,
    required DateTime todayDate,
  }) {
    return TodayCalendarUtils.isSameCalendarDay(
      DateKey.toDate(entry.dateKey),
      todayDate,
    );
  }
}
