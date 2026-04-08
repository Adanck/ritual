import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/data/models/app_settings.dart';
import 'package:ritual/data/services/app_backup_service.dart';
import 'package:ritual/data/services/routine_csv_service.dart';
import 'package:ritual/features/settings/settings_page.dart';

void main() {
  testWidgets('SettingsPage muestra opciones y devuelve ajustes guardados', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(
          useMaterial3: true,
        ).copyWith(splashFactory: NoSplash.splashFactory),
        home: const SettingsPage(
          initialSettings: AppSettings(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.textContaining('Planificaci'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Respaldo de rutinas'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Respaldo de rutinas'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Importar CSV'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Backup completo'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Backup completo'), findsOneWidget);
    expect(find.text('Exportar backup'), findsOneWidget);
    expect(find.text('Importar backup'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);

    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('CSV import dialog bloquea import vacio y envia modo seleccionado', (
    WidgetTester tester,
  ) async {
    String? importedCsv;
    RoutineCsvImportMode? importedMode;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(
          useMaterial3: true,
        ).copyWith(splashFactory: NoSplash.splashFactory),
        home: SettingsPage(
          initialSettings: const AppSettings(),
          onImportRoutineCsv: (csv, mode) async {
            importedCsv = csv;
            importedMode = mode;
            return const RoutineCsvImportData(
              routines: [],
              routineCount: 0,
              blockCount: 0,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Importar CSV'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final openCsvImportFinder = find.widgetWithText(
      OutlinedButton,
      'Importar CSV',
    );
    final openCsvImportButton = tester.widget<OutlinedButton>(
      openCsvImportFinder,
    );
    openCsvImportButton.onPressed!.call();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    final importButtonFinder = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Importar'),
    );
    final importButton = tester.widget<FilledButton>(
      importButtonFinder,
    );
    expect(importButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'routine_id,routine_name');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reemplazar'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(importButtonFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(importedCsv, 'routine_id,routine_name');
    expect(importedMode, RoutineCsvImportMode.replace);
  });

  testWidgets('Backup import dialog bloquea restauracion vacia y envia contenido', (
    WidgetTester tester,
  ) async {
    String? importedJson;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(
          useMaterial3: true,
        ).copyWith(splashFactory: NoSplash.splashFactory),
        home: SettingsPage(
          initialSettings: const AppSettings(),
          onImportAppBackup: (json) async {
            importedJson = json;
            return const AppBackupImportData(
              routines: [],
              dailyRecords: [],
              datedBlocks: [],
              appSettings: AppSettings(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Importar backup'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final openBackupImportFinder = find.widgetWithText(
      OutlinedButton,
      'Importar backup',
    );
    final openBackupImportButton = tester.widget<OutlinedButton>(
      openBackupImportFinder,
    );
    openBackupImportButton.onPressed!.call();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    final restoreButtonFinder = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Restaurar'),
    );
    final restoreButton = tester.widget<FilledButton>(
      restoreButtonFinder,
    );
    expect(restoreButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, '{"version":1}');
    await tester.pumpAndSettle();
    await tester.tap(restoreButtonFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(importedJson, '{"version":1}');
  });
}
