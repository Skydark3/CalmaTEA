import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/matching_configuration_utils.dart';
import 'package:tea_app/features/activities/config/models/activity_configurations.dart';

void main() {
  test('normaliza textos y conserva id y referencias visuales', () {
    final result = prepareMatchingPairsForSave(const [
      MatchingPairConfig(
        id: 'pair-1',
        left: '  Perro ',
        right: ' Animal  ',
        leftResourceReference: 'left-ref',
        rightResourceReference: 'right-ref',
      ),
    ]);

    expect(result.single.id, 'pair-1');
    expect(result.single.left, 'Perro');
    expect(result.single.right, 'Animal');
    expect(result.single.leftResourceReference, 'left-ref');
    expect(result.single.rightResourceReference, 'right-ref');
  });

  test('detecta pares exactos duplicados después de normalizar', () {
    const pairs = [
      MatchingPairConfig(id: 'pair-1', left: 'Perro', right: 'Animal'),
      MatchingPairConfig(id: 'pair-2', left: ' Perro ', right: ' Animal '),
    ];

    expect(hasDuplicateMatchingPairs(pairs), isTrue);
  });

  test('permite repetir el lado derecho con lados izquierdos diferentes', () {
    const pairs = [
      MatchingPairConfig(id: 'pair-1', left: 'Perro', right: 'Animal'),
      MatchingPairConfig(id: 'pair-2', left: 'Gato', right: 'Animal'),
    ];

    expect(hasDuplicateMatchingPairs(pairs), isFalse);
    expect(MatchingActivityConfig(pairs: pairs).isValid, isTrue);
  });
}
