import 'package:flutter/material.dart';
import 'package:ritual/data/models/day_block.dart';

/// Reune las reglas de validacion horaria de los bloques del dia.
///
/// La idea es centralizar estas reglas para reutilizarlas en UI y tests.
class DayBlockTimeValidator {
  static const String overlapMessage =
      'Este bloque se traslapa con otro bloque existente.';

  /// Convierte un texto `HH:mm` en un [TimeOfDay] cuando el formato es valido.
  static TimeOfDay? parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    // Regla: la hora debe tener componentes numericos validos.
    if (hour == null || minute == null) return null;

    // Caso borde: se rechazan horas fuera del rango 00:00 a 23:59.
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Formatea una hora como `HH:mm` para persistencia y visualizacion.
  static String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Convierte una hora a minutos para facilitar comparaciones.
  static int? toMinutes(String value) {
    final time = parseTime(value);
    if (time == null) return null;
    return time.hour * 60 + time.minute;
  }

  /// Determina si el rango horario es estricto: fin debe ser mayor que inicio.
  static bool isEndAfterStart(String start, String end) {
    final startMinutes = toMinutes(start);
    final endMinutes = toMinutes(end);
    if (startMinutes == null || endMinutes == null) return false;
    return endMinutes > startMinutes;
  }

  /// Determina si el bloque propuesto se traslapa con otro ya existente.
  static bool hasOverlap({
    required String start,
    required String end,
    required List<DayBlock> existingBlocks,
    DayBlock? blockBeingEdited,
  }) {
    final startMinutes = toMinutes(start);
    final endMinutes = toMinutes(end);
    if (startMinutes == null || endMinutes == null) return false;

    for (final block in existingBlocks) {
      // Regla: cuando editamos un bloque, ignoramos su version original.
      if (identical(block, blockBeingEdited) ||
          (blockBeingEdited != null && block.id == blockBeingEdited.id)) {
        continue;
      }

      final blockStart = toMinutes(block.start);
      final blockEnd = toMinutes(block.end);
      if (blockStart == null || blockEnd == null) continue;

      // Regla: existe traslape si ambos rangos comparten minutos reales.
      if (startMinutes < blockEnd && endMinutes > blockStart) {
        return true;
      }
    }

    return false;
  }

  /// Devuelve un mensaje listo para UI cuando alguna regla falla.
  static String? validateBasicTimeRange({
    required String start,
    required String end,
  }) {
    // Regla: ambos extremos del rango deben existir antes de guardar.
    if (start.isEmpty || end.isEmpty) {
      return 'Selecciona hora de inicio y fin.';
    }

    // Caso borde: se rechaza cualquier formato horario invalido.
    if (parseTime(start) == null || parseTime(end) == null) {
      return 'Selecciona una hora valida.';
    }

    // Regla: no se permiten bloques con duracion cero o negativa.
    if (!isEndAfterStart(start, end)) {
      return 'La hora de fin debe ser mayor que la de inicio.';
    }

    return null;
  }

  /// Devuelve un mensaje listo para UI cuando alguna regla falla.
  static String? validateTimeRange({
    required String start,
    required String end,
    required List<DayBlock> existingBlocks,
    DayBlock? blockBeingEdited,
  }) {
    final basicValidationMessage = validateBasicTimeRange(
      start: start,
      end: end,
    );
    if (basicValidationMessage != null) return basicValidationMessage;

    // Regla: no se permiten traslapes con otros bloques de la rutina.
    if (hasOverlap(
      start: start,
      end: end,
      existingBlocks: existingBlocks,
      blockBeingEdited: blockBeingEdited,
    )) {
      return overlapMessage;
    }

    return null;
  }
}
