import 'models/activity_configurations.dart';

List<DragDropTargetConfig> prepareDragDropTargetsForSave(
  Iterable<DragDropTargetConfig> targets,
) {
  return targets
      .map(
        (target) =>
            DragDropTargetConfig(id: target.id, label: target.label.trim()),
      )
      .toList(growable: false);
}

List<DragDropItemConfig> prepareDragDropItemsForSave(
  Iterable<DragDropItemConfig> items,
) {
  return items
      .map(
        (item) => DragDropItemConfig(
          id: item.id,
          label: item.label.trim(),
          targetId: item.targetId,
        ),
      )
      .toList(growable: false);
}

bool hasDuplicateDragDropTargetLabels(Iterable<DragDropTargetConfig> targets) {
  final labels = <String>{};
  for (final target in targets) {
    if (!labels.add(target.label.trim().toLowerCase())) return true;
  }
  return false;
}

bool hasDuplicateDragDropItemLabels(Iterable<DragDropItemConfig> items) {
  final labels = <String>{};
  for (final item in items) {
    if (!labels.add(item.label.trim().toLowerCase())) return true;
  }
  return false;
}

bool isDragDropTargetInUse(
  String targetId,
  Iterable<DragDropItemConfig> items,
) {
  return items.any((item) => item.targetId == targetId);
}

bool hasOrphanDragDropItems(
  Iterable<DragDropItemConfig> items,
  Iterable<DragDropTargetConfig> targets,
) {
  final targetIds = targets.map((target) => target.id).toSet();
  return items.any((item) => !targetIds.contains(item.targetId));
}
