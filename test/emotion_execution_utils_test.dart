import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/emotion_execution_utils.dart';

void main() {
  test('normaliza espacios, mayúsculas y minúsculas', () {
    expect(normalizeEmotionAnswer('  Muy   FELIZ  '), 'muy feliz');
  });

  test('acepta respuestas textualmente equivalentes', () {
    expect(emotionAnswersMatch('  Alegría ', 'alegría'), isTrue);
    expect(emotionAnswersMatch('muy   feliz', 'MUY FELIZ'), isTrue);
  });

  test('no inventa sinónimos ni equivalencias semánticas', () {
    expect(emotionAnswersMatch('contento', 'alegría'), isFalse);
  });

  test('no elimina diferencias de acentuación no configuradas', () {
    expect(emotionAnswersMatch('alegria', 'alegría'), isFalse);
  });
}
