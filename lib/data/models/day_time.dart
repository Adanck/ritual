/// Utilidades pequenas para convertir horas del formato `HH:mm` a una
/// representacion numerica mas estable.
///
/// La app sigue mostrando horas como texto, pero internamente conviene usar
/// minutos desde medianoche para ordenar, comparar y persistir con menos
/// ambiguedad.
class DayTimeCodec {
  /// Convierte `HH:mm` a minutos desde medianoche.
  ///
  /// Devuelve `null` si el formato no es valido.
  static int? parseMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return (hour * 60) + minute;
  }

  /// Formatea minutos desde medianoche como `HH:mm`.
  static String formatMinutes(int minutes) {
    final normalizedMinutes = minutes.clamp(0, (24 * 60) - 1);
    final hour = (normalizedMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (normalizedMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
