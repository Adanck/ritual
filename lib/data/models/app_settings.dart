/// Preferencias globales de la aplicacion.
///
/// Este modelo concentra decisiones de comportamiento que no pertenecen a una
/// rutina concreta, sino a la experiencia general del usuario en Ritual.
enum AppVisualStyle {
  ritual(
    storageValue: 'ritual',
    label: 'Ritual',
    description: 'Mantiene la identidad actual, mas densa y orientada a panel.',
  ),
  ios(
    storageValue: 'ios',
    label: 'iOS',
    description: 'Usa superficies mas limpias, bordes suaves y transiciones tipo iPhone.',
  );

  const AppVisualStyle({
    required this.storageValue,
    required this.label,
    required this.description,
  });

  final String storageValue;
  final String label;
  final String description;

  static AppVisualStyle fromStorage(Object? value) {
    return AppVisualStyle.values.firstWhere(
      (style) => style.storageValue == value || style.name == value,
      orElse: () => AppVisualStyle.ritual,
    );
  }
}

class AppSettings {
  final bool warnOnOverlaps;
  final bool autoRequestNotificationPermissions;
  final int notificationHorizonDays;
  final bool showCompletedDatedEventsInUpcoming;
  final AppVisualStyle visualStyle;

  const AppSettings({
    this.warnOnOverlaps = true,
    this.autoRequestNotificationPermissions = true,
    this.notificationHorizonDays = 21,
    this.showCompletedDatedEventsInUpcoming = true,
    this.visualStyle = AppVisualStyle.ritual,
  });

  AppSettings copyWith({
    bool? warnOnOverlaps,
    bool? autoRequestNotificationPermissions,
    int? notificationHorizonDays,
    bool? showCompletedDatedEventsInUpcoming,
    AppVisualStyle? visualStyle,
  }) {
    return AppSettings(
      warnOnOverlaps: warnOnOverlaps ?? this.warnOnOverlaps,
      autoRequestNotificationPermissions: autoRequestNotificationPermissions ??
          this.autoRequestNotificationPermissions,
      notificationHorizonDays:
          notificationHorizonDays ?? this.notificationHorizonDays,
      showCompletedDatedEventsInUpcoming: showCompletedDatedEventsInUpcoming ??
          this.showCompletedDatedEventsInUpcoming,
      visualStyle: visualStyle ?? this.visualStyle,
    );
  }
}
