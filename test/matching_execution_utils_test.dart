import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/matching_execution_utils.dart';

void main() {
  const first = MatchingPairConfig(id: 'a', left: 'Gato', right: 'Animal');
  const second = MatchingPairConfig(id: 'b', left: 'Azul', right: 'Color');

  test('crea respuestas con IDs estables sin modificar la configuración', () {
    const configuration = MatchingActivityConfig(pairs: [first, second]);
    final answers = matchingAnswerOptions(configuration);

    expect(answers.map((answer) => answer.id), ['a', 'b']);
    expect(answers.map((answer) => answer.text), ['Animal', 'Color']);
    expect(configuration.pairs, [first, second]);
  });

  test('el orden inicial de respuestas es independiente', () {
    final answers = [
      const MatchingAnswerOption(id: 'a', text: 'Animal'),
      const MatchingAnswerOption(id: 'b', text: 'Color'),
    ];
    final initial = initialMatchingAnswerOrder(answers);

    expect(initial.map((answer) => answer.id), ['b', 'a']);
    expect(answers.map((answer) => answer.id), ['a', 'b']);
  });

  test('valida la relación por su respuesta real y no por índice', () {
    const correct = MatchingAnswerOption(id: 'option-b', text: 'Animal');
    const incorrect = MatchingAnswerOption(id: 'option-a', text: 'Color');

    expect(isMatchingAnswerCorrect(first, correct), isTrue);
    expect(isMatchingAnswerCorrect(first, incorrect), isFalse);
  });

  test('acepta respuestas textuales repetidas visualmente equivalentes', () {
    const pair = MatchingPairConfig(
      id: 'home-a',
      left: 'Casa',
      right: 'Vivienda',
    );
    const equivalentAnswer = MatchingAnswerOption(
      id: 'home-b',
      text: '  vivienda  ',
    );

    expect(isMatchingAnswerCorrect(pair, equivalentAnswer), isTrue);
  });

  test('un único par conserva su respuesta disponible', () {
    const answer = MatchingAnswerOption(id: 'a', text: 'Animal');

    expect(initialMatchingAnswerOrder([answer]), [answer]);
  });
}
