import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/activities/config/tracing_configuration_utils.dart';

void main() {
  test('normaliza pattern, value y dificultad opcional', () {
    final config = prepareTracingConfigurationForSave(
      pattern: '  Letra ',
      value: ' A  ',
      difficultyHint: '  Seguir las líneas punteadas ',
    );

    expect(config.pattern, 'Letra');
    expect(config.value, 'A');
    expect(config.difficultyHint, 'Seguir las líneas punteadas');
    expect(config.isValid, isTrue);
  });

  test('convierte una dificultad vacía en null', () {
    final config = prepareTracingConfigurationForSave(
      pattern: 'Número',
      value: '2',
      difficultyHint: '   ',
    );

    expect(config.difficultyHint, isNull);
    expect(config.toMap().containsKey('difficultyHint'), isFalse);
  });

  test('rechaza pattern o value obligatorios vacíos', () {
    final missingPattern = prepareTracingConfigurationForSave(
      pattern: ' ',
      value: 'A',
    );
    final missingValue = prepareTracingConfigurationForSave(
      pattern: 'Letra',
      value: ' ',
    );

    expect(missingPattern.isValid, isFalse);
    expect(missingValue.isValid, isFalse);
  });

  test('conserva una configuración existente al cargar y preparar', () {
    final existing = TracingActivityConfig.fromMap(const {
      'version': 1,
      'pattern': 'Forma',
      'value': 'Círculo',
      'difficultyHint': 'Trazo amplio',
    });
    final prepared = prepareTracingConfigurationForSave(
      pattern: existing.pattern,
      value: existing.value,
      difficultyHint: existing.difficultyHint,
    );

    expect(prepared.toMap(), existing.toMap());
  });
}
