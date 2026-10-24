import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/motor_execution_utils.dart';

void main() {
  test('formatea segundos', () {
    expect(formatMotorDuration(1), '1 segundo');
    expect(formatMotorDuration(30), '30 segundos');
  });

  test('formatea minutos y combinaciones', () {
    expect(formatMotorDuration(60), '1 minuto');
    expect(formatMotorDuration(90), '1 minuto y 30 segundos');
    expect(formatMotorDuration(120), '2 minutos');
  });

  test('formatea horas de forma amigable', () {
    expect(formatMotorDuration(3600), '1 hora');
    expect(formatMotorDuration(3661), '1 hora, 1 minuto y 1 segundo');
  });

  test('no inventa duración para valores no positivos', () {
    expect(formatMotorDuration(0), isEmpty);
    expect(formatMotorDuration(-5), isEmpty);
  });
}
