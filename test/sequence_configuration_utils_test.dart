import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/activities/config/sequence_configuration_utils.dart';

void main() {
  group('Sequence configuration editor utilities', () {
    test('reorder preserves IDs and assigns contiguous order values', () {
      const items = [
        SequenceItemConfig(id: 'a', label: 'Primero', order: 0),
        SequenceItemConfig(id: 'b', label: 'Segundo', order: 1),
        SequenceItemConfig(id: 'c', label: 'Tercero', order: 2),
      ];

      final reordered = reorderSequenceItems(items, 0, 2);

      expect(reordered.map((item) => item.id), ['b', 'c', 'a']);
      expect(reordered.map((item) => item.order), [0, 1, 2]);
    });

    test('save preparation trims labels and preserves visual references', () {
      const items = [
        SequenceItemConfig(
          id: 'a',
          label: '  Lavarse las manos  ',
          order: 8,
          visualReference: 'future-resource',
        ),
      ];

      final prepared = prepareSequenceItemsForSave(items);

      expect(prepared.single.label, 'Lavarse las manos');
      expect(prepared.single.order, 0);
      expect(prepared.single.visualReference, 'future-resource');
    });
  });
}
