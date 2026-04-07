/// Preferencias globales de la aplicacion.
///
/// Este modelo concentra decisiones de comportamiento que no pertenecen a una
/// rutina concreta, sino a la experiencia general del usuario en Ritual.
class AppSettings {
  final bool warnOnOverlaps;
  final bool autoRequestNotificationPermissions;
  final int notificationHorizonDays;
  final bool showCompletedDatedEventsInUpcoming;

  const AppSettings({
    this.warnOnOverlaps = true,
    this.autoRequestNotificationPermissions = true,
    this.notificationHorizonDays = 21,
    this.showCompletedDatedEventsInUpcoming = true,
  });

  AppSettings copyWith({
    bool? warnOnOverlaps,
    bool? autoRequestNotificationPermissions,
    int? notificationHorizonDays,
    bool? showCompletedDatedEventsInUpcoming,
  }) {
    return AppSettings(
      warnOnOverlaps: warnOnOverlaps ?? this.warnOnOverlaps,
      autoRequestNotificationPermissions: autoRequestNotificationPermissions ??
          this.autoRequestNotificationPermissions,
      notificationHorizonDays:
          notificationHorizonDays ?? this.notificationHorizonDays,
      showCompletedDatedEventsInUpcoming: showCompletedDatedEventsInUpcoming ??
          this.showCompletedDatedEventsInUpcoming,
    );
  }
}
