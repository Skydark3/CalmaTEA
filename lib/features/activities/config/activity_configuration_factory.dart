import '../../../models/activity_model.dart';
import 'models/activity_configuration.dart';
import 'models/activity_configurations.dart';

abstract final class ActivityConfigurationFactory {
  static ActivityConfiguration? fromMap(
    ActivityType type,
    Map<String, dynamic> configuration,
  ) {
    if (configuration.isEmpty) return null;

    return switch (type) {
      ActivityType.sequence => SequenceActivityConfig.fromMap(configuration),
      ActivityType.dragDrop => DragDropActivityConfig.fromMap(configuration),
      ActivityType.matching => MatchingActivityConfig.fromMap(configuration),
      ActivityType.pictogram => PictogramActivityConfig.fromMap(configuration),
      ActivityType.emotion => EmotionActivityConfig.fromMap(configuration),
      ActivityType.tracing => TracingActivityConfig.fromMap(configuration),
      ActivityType.timer => TimerActivityConfig.fromMap(configuration),
      ActivityType.motor => MotorActivityConfig.fromMap(configuration),
    };
  }
}
