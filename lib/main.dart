import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ritual/app/app_settings_controller.dart';
import 'package:ritual/core/services/notification_service.dart';
import 'app/ritual_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AppSettingsController.instance.load();
  runApp(const RitualApp());

  // No bloqueamos el arranque visual por notificaciones. Si esta
  // inicializacion tarda o falla en un dispositivo concreto, la app igual debe
  // poder abrir y luego preparar recordatorios cuando haga falta.
  unawaited(_warmUpNotificationService());
}

Future<void> _warmUpNotificationService() async {
  try {
    await NotificationService.initialize().timeout(
      const Duration(seconds: 5),
    );
  } catch (_) {
    // La app puede seguir funcionando aunque el warmup falle. Las rutas de
    // notificaciones volveran a intentar inicializar el servicio al usarse.
  }
}
