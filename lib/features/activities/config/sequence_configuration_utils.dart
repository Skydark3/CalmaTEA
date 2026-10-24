import 'models/activity_configurations.dart';

List<SequenceItemConfig> prepareSequenceItemsForSave(
  Iterable<SequenceItemConfig> items,
) {
  return items.indexed
      .map(
        (entry) => SequenceItemConfig(
          id: entry.$2.id,
          label: entry.$2.label.trim(),
          order: entry.$1,
          visualReference: entry.$2.visualReference,
        ),
      )
      .toList(growable: false);
}

List<SequenceItemConfig> reorderSequenceItems(
  List<SequenceItemConfig> items,
  int oldIndex,
  int newIndex,
) {
  final reordered = List<SequenceItemConfig>.of(items);
  final item = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, item);
  return prepareSequenceItemsForSave(reordered);
}
