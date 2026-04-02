import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ritual/app/ritual_app.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('ritual_widget_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('renders today page shell', (WidgetTester tester) async {
    await tester.pumpWidget(const RitualApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final showsLoading =
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    final showsTodayShell = find.textContaining('Hoy').evaluate().isNotEmpty;

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(showsLoading || showsTodayShell, isTrue);
  });
}
