import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/sequence_execution_utils.dart';

void main() {
  const first = SequenceItemConfig(id: 'a', label: 'Paso repetido', order: 0);
  const second = SequenceItemConfig(id: 'b', label: 'Paso repetido', order: 1);
  const third = SequenceItemConfig(id: 'c', label: 'Final', order: 2);

  test('obtiene el orden correcto usando el campo order', () {
    const configuration = SequenceActivityConfig(items: [third, first, second]);

    expect(correctSequenceOrder(configuration).map((item) => item.id), [
      'a',
      'b',
      'c',
    ]);
  });

  test('el orden inicial difiere del correcto cuando hay varios pasos', () {
    final initial = initialSequenceOrder([first, second, third]);

    expect(initial.map((item) => item.id), ['c', 'b', 'a']);
    expect(isSequenceOrderCorrect(initial, [first, second, third]), isFalse);
  });

  test('compara mediante IDs aunque los textos sean iguales', () {
    expect(isSequenceOrderCorrect([second, first], [first, second]), isFalse);
    expect(isSequenceOrderCorrect([first, second], [first, second]), isTrue);
  });

  test('mueve un paso sin alterar sus datos', () {
    final reordered = moveSequenceItem([second, first, third], 0, 1);

    expect(reordered.map((item) => item.id), ['a', 'b', 'c']);
    expect(reordered[1].label, 'Paso repetido');
  });

  test('una secuencia de un paso conserva un orden válido', () {
    final initial = initialSequenceOrder([first]);

    expect(initial, [first]);
    expect(isSequenceOrderCorrect(initial, [first]), isTrue);
  });
}
