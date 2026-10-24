import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/emotion_configuration_utils.dart';
import 'package:tea_app/features/activities/config/models/activity_configurations.dart';

void main() {
  test('normaliza textos y conserva id y respuesta esperada', () {
    final result = prepareEmotionOptionsForSave(const [
      EmotionOptionConfig(
        id: 'emotion-1',
        label: '  Felicidad ',
        prompt: ' ¿Cómo podría sentirse?  ',
        expectedValue: ' felicidad ',
      ),
    ]);

    expect(result.single.id, 'emotion-1');
    expect(result.single.label, 'Felicidad');
    expect(result.single.prompt, '¿Cómo podría sentirse?');
    expect(result.single.expectedValue, 'felicidad');
    expect(EmotionActivityConfig(options: result).isValid, isTrue);
  });

  test('rechaza campos requeridos vacíos', () {
    const option = EmotionOptionConfig(
      id: 'emotion-1',
      label: 'Felicidad',
      prompt: '   ',
      expectedValue: 'felicidad',
    );

    expect(option.isValid, isFalse);
    expect(const EmotionActivityConfig(options: [option]).isValid, isFalse);
  });

  test('detecta únicamente ejercicios completos duplicados', () {
    const duplicated = [
      EmotionOptionConfig(
        id: 'emotion-1',
        label: 'Felicidad',
        prompt: 'Recibe un regalo',
        expectedValue: 'felicidad',
      ),
      EmotionOptionConfig(
        id: 'emotion-2',
        label: ' Felicidad ',
        prompt: ' Recibe un regalo ',
        expectedValue: ' felicidad ',
      ),
    ];
    const repeatedEmotion = [
      EmotionOptionConfig(
        id: 'emotion-1',
        label: 'Felicidad',
        prompt: 'Recibe un regalo',
        expectedValue: 'felicidad',
      ),
      EmotionOptionConfig(
        id: 'emotion-2',
        label: 'Felicidad',
        prompt: 'Juega con sus amigos',
        expectedValue: 'alegría',
      ),
    ];

    expect(hasDuplicateEmotionOptions(duplicated), isTrue);
    expect(hasDuplicateEmotionOptions(repeatedEmotion), isFalse);
  });
}
