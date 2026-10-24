import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/drag_drop_execution_utils.dart';

void main() {
  const fruits = DragDropTargetConfig(id: 'fruits-id', label: 'Alimentos');
  const vegetables = DragDropTargetConfig(
    id: 'vegetables-id',
    label: 'Alimentos',
  );

  test('valida relaciones usando IDs y no etiquetas', () {
    const item = DragDropItemConfig(
      id: 'apple-id',
      label: 'Comida',
      targetId: 'fruits-id',
    );

    expect(isDragDropRelationCorrect(item, fruits), isTrue);
    expect(isDragDropRelationCorrect(item, vegetables), isFalse);
  });

  test('permite que varios elementos compartan un destino', () {
    const apple = DragDropItemConfig(
      id: 'apple-id',
      label: 'Manzana',
      targetId: 'fruits-id',
    );
    const banana = DragDropItemConfig(
      id: 'banana-id',
      label: 'Plátano',
      targetId: 'fruits-id',
    );

    expect(isDragDropRelationCorrect(apple, fruits), isTrue);
    expect(isDragDropRelationCorrect(banana, fruits), isTrue);
  });
}
