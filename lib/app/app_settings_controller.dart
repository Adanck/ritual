import 'package:flutter/material.dart';
import 'package:ritual/data/models/app_settings.dart';
import 'package:ritual/data/services/storage_service.dart';

/// Mantiene las preferencias globales disponibles para toda la app.
///
/// Lo usamos para que cambios de apariencia se reflejen sin reiniciar Ritual y
/// sin obligar a que cada pantalla vuelva a leer Hive manualmente.
class AppSettingsController {
  AppSettingsController._();

  static final AppSettingsController instance = AppSettingsController._();

  final ValueNotifier<AppSettings> settings = ValueNotifier(
    const AppSettings(),
  );

  Future<void> load() async {
    settings.value = await StorageService.loadAppSettings();
  }

  void apply(AppSettings nextSettings) {
    settings.value = nextSettings;
  }
}
