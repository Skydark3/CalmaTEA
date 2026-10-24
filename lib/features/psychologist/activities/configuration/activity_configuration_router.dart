import 'package:flutter/material.dart';

import '../../../../models/activity_model.dart';
import 'presentation/drag_drop_configuration_screen.dart';
import 'presentation/emotion_configuration_screen.dart';
import 'presentation/matching_configuration_screen.dart';
import 'presentation/motor_configuration_screen.dart';
import 'presentation/pictogram_configuration_screen.dart';
import 'presentation/sequence_configuration_screen.dart';
import 'presentation/timer_configuration_screen.dart';
import 'presentation/tracing_configuration_screen.dart';

abstract final class ActivityConfigurationRouter {
  static bool supports(ActivityType type) => switch (type) {
    ActivityType.sequence ||
    ActivityType.dragDrop ||
    ActivityType.matching ||
    ActivityType.pictogram ||
    ActivityType.emotion ||
    ActivityType.tracing ||
    ActivityType.timer ||
    ActivityType.motor => true,
  };

  static Widget resolve(ActivityModel activity, {bool persistChanges = true}) =>
      switch (activity.type) {
        ActivityType.sequence => SequenceConfigurationScreen(
          activity: activity,
          persistChanges: persistChanges,
        ),
        ActivityType.dragDrop => DragDropConfigurationScreen(
          activity: activity,
          persistChanges: persistChanges,
        ),
        ActivityType.matching => MatchingConfigurationScreen(
          activity: activity,
          persistChanges: persistChanges,
        ),
        ActivityType.pictogram => PictogramConfigurationScreen(
          activity: activity,
          persistChanges: persistChanges,
        ),
        ActivityType.emotion => EmotionConfigurationScreen(
          activity: activity,
          persistChanges: persistChanges,
        ),
        ActivityType.tracing => TracingConfigurationScreen(
          activity: activity,
          persistChanges: persistChanges,
        ),
        ActivityType.timer => TimerConfigurationScreen(
          activity: activity,
          persistChanges: persistChanges,
        ),
        ActivityType.motor => MotorConfigurationScreen(
          activity: activity,
          persistChanges: persistChanges,
        ),
      };

  static Future<ActivityModel?> open(
    BuildContext context,
    ActivityModel activity, {
    bool persistChanges = true,
  }) {
    return Navigator.of(context).push<ActivityModel>(
      MaterialPageRoute(
        builder: (_) => resolve(activity, persistChanges: persistChanges),
      ),
    );
  }
}
