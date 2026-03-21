import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app/ritual_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const RitualApp());
}
