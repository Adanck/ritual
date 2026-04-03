import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ritual/core/services/notification_service.dart';
import 'app/ritual_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await NotificationService.initialize();
  runApp(const RitualApp());
}
