import 'package:flutter/material.dart';

import '../../../../models/activity_model.dart';
import '../../../activities/config/models/activity_configuration.dart';
import '../../../activities/config/models/activity_configurations.dart';
import '../../../activities/execution/activity_execution_router.dart';
import 'activity_preview_persistence.dart';
import 'drag_drop_execution_screen.dart';
import 'emotion_execution_screen.dart';
import 'matching_execution_screen.dart';
import 'motor_execution_screen.dart';
import 'pictogram_execution_screen.dart';
import 'sequence_execution_screen.dart';
import 'timer_execution_screen.dart';
import 'tracing_execution_screen.dart';

ActivityExecutionRouter buildActivityPreviewRouter() {
  return ActivityExecutionRouter(
    mode: ActivityExecutionMode.preview,
    handlers: {
      ActivityType.sequence: _openSequencePreview,
      ActivityType.dragDrop: _openDragDropPreview,
      ActivityType.matching: _openMatchingPreview,
      ActivityType.emotion: _openEmotionPreview,
      ActivityType.pictogram: _openPictogramPreview,
      ActivityType.timer: _openTimerPreview,
      ActivityType.tracing: _openTracingPreview,
      ActivityType.motor: _openMotorPreview,
    },
  );
}

Future<void> _openSequencePreview(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! SequenceActivityConfig) return;
  await _push(
    context,
    SequenceExecutionScreen(
      activity: activity,
      configuration: configuration,
      persistence: SequencePreviewPersistence(),
      previewMode: true,
    ),
  );
}

Future<void> _openDragDropPreview(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! DragDropActivityConfig) return;
  await _push(
    context,
    DragDropExecutionScreen(
      activity: activity,
      configuration: configuration,
      persistence: DragDropPreviewPersistence(),
      previewMode: true,
    ),
  );
}

Future<void> _openMatchingPreview(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! MatchingActivityConfig) return;
  await _push(
    context,
    MatchingExecutionScreen(
      activity: activity,
      configuration: configuration,
      persistence: MatchingPreviewPersistence(),
      previewMode: true,
    ),
  );
}

Future<void> _openEmotionPreview(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! EmotionActivityConfig) return;
  await _push(
    context,
    EmotionExecutionScreen(
      activity: activity,
      configuration: configuration,
      persistence: EmotionPreviewPersistence(),
      previewMode: true,
    ),
  );
}

Future<void> _openPictogramPreview(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! PictogramActivityConfig) return;
  await _push(
    context,
    PictogramExecutionScreen(
      activity: activity,
      configuration: configuration,
      persistence: PictogramPreviewPersistence(),
      previewMode: true,
    ),
  );
}

Future<void> _openTimerPreview(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! TimerActivityConfig) return;
  await _push(
    context,
    TimerExecutionScreen(
      activity: activity,
      configuration: configuration,
      persistence: TimerPreviewPersistence(),
      previewMode: true,
    ),
  );
}

Future<void> _openTracingPreview(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! TracingActivityConfig) return;
  await _push(
    context,
    TracingExecutionScreen(
      activity: activity,
      configuration: configuration,
      persistence: TracingPreviewPersistence(),
      previewMode: true,
    ),
  );
}

Future<void> _openMotorPreview(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! MotorActivityConfig) return;
  await _push(
    context,
    MotorExecutionScreen(
      activity: activity,
      configuration: configuration,
      persistence: MotorPreviewPersistence(),
      previewMode: true,
    ),
  );
}

Future<void> _push(BuildContext context, Widget screen) {
  return Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => screen));
}
