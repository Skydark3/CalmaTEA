import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/tracing_execution_utils.dart';

void main() {
  test('reconoce letras y números como guías tipográficas', () {
    expect(resolveTracingGuide('A'), TracingGuideKind.typographic);
    expect(resolveTracingGuide('ñ'), TracingGuideKind.typographic);
    expect(resolveTracingGuide('2'), TracingGuideKind.typographic);
  });

  test('reconoce únicamente las formas geométricas soportadas', () {
    expect(resolveTracingGuide('círculo'), TracingGuideKind.circle);
    expect(resolveTracingGuide('Cuadrado'), TracingGuideKind.square);
    expect(resolveTracingGuide('triangulo'), TracingGuideKind.triangle);
  });

  test('mantiene valores no reconocidos como dibujo libre', () {
    expect(resolveTracingGuide('casa'), TracingGuideKind.freeform);
    expect(resolveTracingGuide('AB'), TracingGuideKind.freeform);
  });

  test('normaliza coordenadas, limita bordes y permite reconstruirlas', () {
    const size = Size(200, 100);

    expect(
      normalizeTracingPoint(const Offset(100, 25), size),
      const Offset(0.5, 0.25),
    );
    expect(
      normalizeTracingPoint(const Offset(-20, 140), size),
      const Offset(0, 1),
    );
    expect(
      denormalizeTracingPoint(const Offset(0.5, 0.25), size),
      const Offset(100, 25),
    );
  });
}
