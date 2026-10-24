import 'package:flutter/widgets.dart';

import '../../../models/activity_model.dart';
import '../config/activity_configuration_factory.dart';
import '../config/models/activity_configuration.dart';

enum ActivityExecutionState {
  ready,
  unconfigured,
  invalidConfiguration,
  blockedStatus,
  engineUnavailable,
  unsupported,
}

enum ActivityExecutionMode { unavailable, persistent, preview }

typedef ActivityExecutionHandler = Future<void> Function(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
);

class ActivityExecutionResolution {
  final ActivityExecutionState state;
  final ActivityType? type;
  final ActivityConfiguration? configuration;

  const ActivityExecutionResolution._({
    required this.state,
    this.type,
    this.configuration,
  });

  bool get canStart =>
      state == ActivityExecutionState.ready ||
      state == ActivityExecutionState.engineUnavailable;

  bool get hasValidConfiguration => configuration?.isValid ?? false;

  String? get childMessage {
    return switch (state) {
      ActivityExecutionState.ready => null,
      ActivityExecutionState.unconfigured =>
        'Esta actividad todavía está siendo preparada.',
      ActivityExecutionState.invalidConfiguration =>
        'No pudimos preparar esta actividad.',
      ActivityExecutionState.engineUnavailable =>
        'Esta actividad estará disponible próximamente.',
      ActivityExecutionState.blockedStatus ||
      ActivityExecutionState.unsupported =>
        'Esta actividad no está disponible.',
    };
  }
}

/// Punto único de resolución y navegación para los motores infantiles.
class ActivityExecutionRouter {
  final Map<ActivityType, ActivityExecutionHandler> _handlers;
  final ActivityExecutionMode mode;

  const ActivityExecutionRouter({
    Map<ActivityType, ActivityExecutionHandler> handlers = const {},
    this.mode = ActivityExecutionMode.unavailable,
  }) : _handlers = handlers;

  bool get isPreview => mode == ActivityExecutionMode.preview;

  bool recognizes(ActivityType type) {
    return switch (type) {
      ActivityType.sequence ||
      ActivityType.dragDrop ||
      ActivityType.matching ||
      ActivityType.pictogram ||
      ActivityType.emotion ||
      ActivityType.tracing ||
      ActivityType.timer ||
      ActivityType.motor => true,
    };
  }

  ActivityExecutionResolution resolve(ActivityModel activity) {
    if (activity.status != ActivityStatus.assigned &&
        activity.status != ActivityStatus.inProgress) {
      return ActivityExecutionResolution._(
        state: ActivityExecutionState.blockedStatus,
        type: activity.type,
      );
    }

    if (activity.configuration.isEmpty) {
      return ActivityExecutionResolution._(
        state: ActivityExecutionState.unconfigured,
        type: activity.type,
      );
    }

    ActivityConfiguration? configuration;
    try {
      configuration = ActivityConfigurationFactory.fromMap(
        activity.type,
        activity.configuration,
      );
    } catch (_) {
      return ActivityExecutionResolution._(
        state: ActivityExecutionState.invalidConfiguration,
        type: activity.type,
      );
    }

    if (configuration == null || !configuration.isValid) {
      return ActivityExecutionResolution._(
        state: ActivityExecutionState.invalidConfiguration,
        type: activity.type,
      );
    }

    if (!recognizes(activity.type)) {
      return ActivityExecutionResolution._(
        state: ActivityExecutionState.unsupported,
        type: activity.type,
        configuration: configuration,
      );
    }

    return ActivityExecutionResolution._(
      state: _handlers.containsKey(activity.type)
          ? ActivityExecutionState.ready
          : ActivityExecutionState.engineUnavailable,
      type: activity.type,
      configuration: configuration,
    );
  }

  Future<ActivityExecutionResolution> open(
    BuildContext context,
    ActivityModel activity,
  ) async {
    final resolution = resolve(activity);
    if (resolution.state != ActivityExecutionState.ready) {
      return resolution;
    }

    await _handlers[activity.type]!(
      context,
      activity,
      resolution.configuration!,
    );
    return resolution;
  }
}
