import 'package:flutter/widgets.dart';

enum TracingGuideKind { typographic, circle, square, triangle, freeform }

TracingGuideKind resolveTracingGuide(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.runes.length == 1 &&
      RegExp(r'^[A-Za-zÀ-ÖØ-öø-ÿ0-9]$').hasMatch(normalized)) {
    return TracingGuideKind.typographic;
  }

  return switch (normalized) {
    'círculo' || 'circulo' => TracingGuideKind.circle,
    'cuadrado' => TracingGuideKind.square,
    'triángulo' || 'triangulo' => TracingGuideKind.triangle,
    _ => TracingGuideKind.freeform,
  };
}

Offset normalizeTracingPoint(Offset localPoint, Size surfaceSize) {
  if (surfaceSize.width <= 0 || surfaceSize.height <= 0) {
    return Offset.zero;
  }
  return Offset(
    (localPoint.dx / surfaceSize.width).clamp(0.0, 1.0),
    (localPoint.dy / surfaceSize.height).clamp(0.0, 1.0),
  );
}

Offset denormalizeTracingPoint(Offset normalizedPoint, Size surfaceSize) {
  return Offset(
    normalizedPoint.dx.clamp(0.0, 1.0) * surfaceSize.width,
    normalizedPoint.dy.clamp(0.0, 1.0) * surfaceSize.height,
  );
}
