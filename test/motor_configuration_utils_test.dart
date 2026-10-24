import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/activities/config/motor_configuration_utils.dart';

void main() {
  test('normaliza instrucciones y conserva ids y valores', () {
    final result = prepareMotorStepsForSave(const [
      MotorStepConfig(
        id: 'step-1',
        instruction: '  Levantar ambos brazos  ',
        durationSeconds: 20,
        repetitions: 3,
      ),
    ]);

    expect(result.single.id, 'step-1');
    expect(result.single.instruction, 'Levantar ambos brazos');
    expect(result.single.durationSeconds, 20);
    expect(result.single.repetitions, 3);
    expect(MotorActivityConfig(steps: result).isValid, isTrue);
  });

  test('acepta valores opcionales vacíos y rechaza no positivos', () {
    expect(isValidOptionalPositiveIntInput(''), isTrue);
    expect(optionalPositiveIntFromInput(''), isNull);
    expect(isValidOptionalPositiveIntInput('5'), isTrue);
    expect(optionalPositiveIntFromInput('5'), 5);
    expect(isValidOptionalPositiveIntInput('0'), isFalse);
    expect(isValidOptionalPositiveIntInput('-1'), isFalse);
  });

  test('rechaza pasos con instrucción o valores inválidos', () {
    const missingInstruction = MotorStepConfig(id: 'step-1', instruction: ' ');
    const invalidDuration = MotorStepConfig(
      id: 'step-2',
      instruction: 'Caminar',
      durationSeconds: 0,
    );
    const invalidRepetitions = MotorStepConfig(
      id: 'step-3',
      instruction: 'Tocar los hombros',
      repetitions: -1,
    );

    expect(missingInstruction.isValid, isFalse);
    expect(invalidDuration.isValid, isFalse);
    expect(invalidRepetitions.isValid, isFalse);
  });

  test('reordena pasos conservando ids y configuración existente', () {
    const steps = [
      MotorStepConfig(
        id: 'step-1',
        instruction: 'Levantar brazos',
        durationSeconds: 10,
      ),
      MotorStepConfig(
        id: 'step-2',
        instruction: 'Tocar hombros',
        repetitions: 4,
      ),
      MotorStepConfig(id: 'step-3', instruction: 'Descansar'),
    ];

    final reordered = reorderMotorSteps(steps, 0, 3);

    expect(reordered.map((step) => step.id), ['step-2', 'step-3', 'step-1']);
    expect(reordered.last.durationSeconds, 10);
    expect(reordered.first.repetitions, 4);
  });
}
