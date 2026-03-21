import 'package:flutter_test/flutter_test.dart';

import 'package:ritual/app/ritual_app.dart';

void main() {
  testWidgets('renders today page shell', (WidgetTester tester) async {
    await tester.pumpWidget(const RitualApp());
    await tester.pump();

    expect(find.textContaining('Hoy'), findsOneWidget);
    expect(find.textContaining('Progreso del'), findsOneWidget);
  });
}
