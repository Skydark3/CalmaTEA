import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tea_app/core/services/app_state.dart';
import 'package:tea_app/main.dart';

void main() {
  testWidgets('CalmaTeaApp smoke test - SplashScreen loads', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(create: (_) => AppState(), child: const CalmaTeaApp()),
    );
    // La pantalla de inicio de CalmaTEA debe mostrar el nombre y el botón Comenzar
    expect(find.text('CalmaTEA'), findsOneWidget);
    expect(find.text('Comenzar'), findsOneWidget);
  });
}
