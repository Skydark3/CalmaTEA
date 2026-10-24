import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/drag_drop_configuration_utils.dart';
import 'package:tea_app/features/activities/config/models/activity_configurations.dart';

void main() {
  test('normaliza etiquetas y conserva ids y relación', () {
    final targets = prepareDragDropTargetsForSave(const [
      DragDropTargetConfig(id: 'target-1', label: '  Frutas '),
    ]);
    final items = prepareDragDropItemsForSave(const [
      DragDropItemConfig(
        id: 'item-1',
        label: ' Manzana  ',
        targetId: 'target-1',
      ),
    ]);

    expect(targets.single.id, 'target-1');
    expect(targets.single.label, 'Frutas');
    expect(items.single.id, 'item-1');
    expect(items.single.label, 'Manzana');
    expect(items.single.targetId, 'target-1');
  });

  test('detecta referencias huérfanas y destinos en uso', () {
    const targets = [DragDropTargetConfig(id: 'target-1', label: 'Frutas')];
    const validItems = [
      DragDropItemConfig(id: 'item-1', label: 'Manzana', targetId: 'target-1'),
    ];
    const orphanItems = [
      DragDropItemConfig(
        id: 'item-2',
        label: 'Zanahoria',
        targetId: 'missing-target',
      ),
    ];

    expect(hasOrphanDragDropItems(validItems, targets), isFalse);
    expect(hasOrphanDragDropItems(orphanItems, targets), isTrue);
    expect(isDragDropTargetInUse('target-1', validItems), isTrue);
    expect(isDragDropTargetInUse('other-target', validItems), isFalse);
  });

  test('detecta duplicados case-insensitive por categoría', () {
    const targets = [
      DragDropTargetConfig(id: 'target-1', label: 'Frutas'),
      DragDropTargetConfig(id: 'target-2', label: ' frutas '),
    ];
    const items = [
      DragDropItemConfig(id: 'item-1', label: 'Manzana', targetId: 'target-1'),
      DragDropItemConfig(
        id: 'item-2',
        label: ' manzana ',
        targetId: 'target-1',
      ),
    ];

    expect(hasDuplicateDragDropTargetLabels(targets), isTrue);
    expect(hasDuplicateDragDropItemLabels(items), isTrue);
  });

  test('permite varios elementos asociados al mismo destino', () {
    const targets = [DragDropTargetConfig(id: 'target-1', label: 'Frutas')];
    const items = [
      DragDropItemConfig(id: 'item-1', label: 'Manzana', targetId: 'target-1'),
      DragDropItemConfig(id: 'item-2', label: 'Pera', targetId: 'target-1'),
    ];

    expect(hasOrphanDragDropItems(items, targets), isFalse);
    expect(
      const DragDropActivityConfig(items: items, targets: targets).isValid,
      isTrue,
    );
  });
}
