import '../../../activities/config/models/activity_configurations.dart';

bool isDragDropRelationCorrect(
  DragDropItemConfig item,
  DragDropTargetConfig target,
) {
  return item.targetId == target.id;
}
