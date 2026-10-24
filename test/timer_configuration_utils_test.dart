import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/timer_configuration_utils.dart';

void main() {
  test('convierte minutos y segundos a durationSeconds', () {
    expect(durationSecondsFromParts(minutes: 2, seconds: 30), 150);
    expect(durationSecondsFromParts(minutes: 0, seconds: 30), 30);
  });

  test('rechaza duración cero y segundos fuera de rango', () {
    expect(durationSecondsFromParts(minutes: 0, seconds: 0), isNull);
    expect(durationSecondsFromParts(minutes: 1, seconds: 60), isNull);
    expect(durationSecondsFromParts(minutes: -1, seconds: 30), isNull);
  });

  test('normaliza etiqueta opcional', () {
    expect(
      normalizeTimerLabel('  Tiempo de respiración  '),
      'Tiempo de respiración',
    );
    expect(normalizeTimerLabel('   '), isNull);
  });

  test('formatea duraciones para el profesional', () {
    expect(formatTimerDuration(30), '30 s');
    expect(formatTimerDuration(60), '1 min');
    expect(formatTimerDuration(90), '1 min 30 s');
    expect(formatTimerDuration(120), '2 min');
    expect(formatTimerDuration(3660), '61 min');
  });

  test('descompone una configuración existente sin perder duración', () {
    final parts = timerDurationParts(150);

    expect(parts.minutes, 2);
    expect(parts.seconds, 30);
    expect(
      durationSecondsFromParts(minutes: parts.minutes, seconds: parts.seconds),
      150,
    );
  });
}
