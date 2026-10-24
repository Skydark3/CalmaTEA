import '../../../activities/config/models/activity_configurations.dart';

List<SequenceItemConfig> correctSequenceOrder(
  SequenceActivityConfig configuration,
) {
  final items = List<SequenceItemConfig>.of(configuration.items);
  items.sort((first, second) => first.order.compareTo(second.order));
  return items;
}

List<SequenceItemConfig> initialSequenceOrder(
  List<SequenceItemConfig> correctItems,
) {
  if (correctItems.length < 2) return List.of(correctItems);
  return correctItems.reversed.toList(growable: true);
}

List<SequenceItemConfig> moveSequenceItem(
  List<SequenceItemConfig> items,
  int oldIndex,
  int newIndex,
) {
  final reordered = List<SequenceItemConfig>.of(items);
  final item = reordered.removeAt(oldIndex);
  reordered.insert(newIndex, item);
  return reordered;
}

bool isSequenceOrderCorrect(
  List<SequenceItemConfig> currentItems,
  List<SequenceItemConfig> correctItems,
) {
  if (currentItems.length != correctItems.length) return false;
  for (var index = 0; index < correctItems.length; index++) {
    if (currentItems[index].id != correctItems[index].id) return false;
  }
  return true;
}
