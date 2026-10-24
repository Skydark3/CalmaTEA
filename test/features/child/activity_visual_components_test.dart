import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/widgets/activity_visual_components.dart';

void main() {
  testWidgets('respeta reducir movimiento en selecciones visuales', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ActivityIllustrationBadge(
              icon: Icons.star_rounded,
              selected: true,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
      Duration.zero,
    );
    expect(
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
      Duration.zero,
    );
  });

  testWidgets(
    'encabezado compacto admite tablet, pantalla estrecha y texto ampliado',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ActivityVisualHeader(
                  icon: Icons.route_rounded,
                  title: 'Actividad con un título amplio',
                  instructions: 'Instrucciones claras y extensas para completar la actividad con calma.',
                  progressLabel: 'Paso 1 de 3',
                  progress: 1 / 3,
                  compact: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Paso 1 de 3'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('usa icono de respaldo sin depender de recursos externos', () {
    expect(
      activityIconForLabel('opción personalizada', fallback: Icons.extension),
      Icons.extension,
    );
  });
}
