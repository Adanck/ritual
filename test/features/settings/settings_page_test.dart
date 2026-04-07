import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/data/models/app_settings.dart';
import 'package:ritual/features/settings/settings_page.dart';

void main() {
  testWidgets('SettingsPage muestra opciones y devuelve ajustes guardados', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
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
}
