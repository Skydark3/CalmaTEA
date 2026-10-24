import 'activity_configuration.dart';

const int currentActivityConfigurationVersion = 1;

class SequenceItemConfig {
  final String id;
  final String label;
  final int order;
  final String? visualReference;

  const SequenceItemConfig({
    required this.id,
    required this.label,
    required this.order,
    this.visualReference,
  });

  bool get isValid => id.trim().isNotEmpty && label.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'order': order,
    if (visualReference != null) 'visualReference': visualReference,
  };

  factory SequenceItemConfig.fromMap(Map<String, dynamic> map) {
    return SequenceItemConfig(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      visualReference: map['visualReference'] as String?,
    );
  }
}

class SequenceActivityConfig implements ActivityConfiguration {
  @override
  final int version;
  final List<SequenceItemConfig> items;

  const SequenceActivityConfig({
    this.version = currentActivityConfigurationVersion,
    this.items = const [],
  });

  @override
  bool get isValid {
    if (version != currentActivityConfigurationVersion || items.isEmpty) {
      return false;
    }
    final ids = items.map((item) => item.id).toSet();
    final orders = items.map((item) => item.order).toSet();
    return items.every((item) => item.isValid) &&
        ids.length == items.length &&
        orders.length == items.length;
  }

  @override
  Map<String, dynamic> toMap() => {
    'version': version,
    'items': items.map((item) => item.toMap()).toList(),
  };

  factory SequenceActivityConfig.fromMap(Map<String, dynamic> map) {
    return SequenceActivityConfig(
      version: _versionFromMap(map),
      items: _mapsFrom(map['items']).map(SequenceItemConfig.fromMap).toList(),
    );
  }
}

class DragDropItemConfig {
  final String id;
  final String label;
  final String targetId;

  const DragDropItemConfig({
    required this.id,
    required this.label,
    required this.targetId,
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      label.trim().isNotEmpty &&
      targetId.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'targetId': targetId,
  };

  factory DragDropItemConfig.fromMap(Map<String, dynamic> map) {
    return DragDropItemConfig(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      targetId: map['targetId'] as String? ?? '',
    );
  }
}

class DragDropTargetConfig {
  final String id;
  final String label;

  const DragDropTargetConfig({required this.id, required this.label});

  bool get isValid => id.trim().isNotEmpty && label.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {'id': id, 'label': label};

  factory DragDropTargetConfig.fromMap(Map<String, dynamic> map) {
    return DragDropTargetConfig(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
    );
  }
}

class DragDropActivityConfig implements ActivityConfiguration {
  @override
  final int version;
  final List<DragDropItemConfig> items;
  final List<DragDropTargetConfig> targets;

  const DragDropActivityConfig({
    this.version = currentActivityConfigurationVersion,
    this.items = const [],
    this.targets = const [],
  });

  @override
  bool get isValid {
    if (version != currentActivityConfigurationVersion ||
        items.isEmpty ||
        targets.isEmpty) {
      return false;
    }
    final itemIds = items.map((item) => item.id).toSet();
    final targetIds = targets.map((target) => target.id).toSet();
    return items.every(
          (item) => item.isValid && targetIds.contains(item.targetId),
        ) &&
        targets.every((target) => target.isValid) &&
        itemIds.length == items.length &&
        targetIds.length == targets.length;
  }

  @override
  Map<String, dynamic> toMap() => {
    'version': version,
    'items': items.map((item) => item.toMap()).toList(),
    'targets': targets.map((target) => target.toMap()).toList(),
  };

  factory DragDropActivityConfig.fromMap(Map<String, dynamic> map) {
    return DragDropActivityConfig(
      version: _versionFromMap(map),
      items: _mapsFrom(map['items']).map(DragDropItemConfig.fromMap).toList(),
      targets: _mapsFrom(map['targets'])
          .map(DragDropTargetConfig.fromMap)
          .toList(),
    );
  }
}

class MatchingPairConfig {
  final String id;
  final String left;
  final String right;
  final String? leftResourceReference;
  final String? rightResourceReference;

  const MatchingPairConfig({
    required this.id,
    required this.left,
    required this.right,
    this.leftResourceReference,
    this.rightResourceReference,
  });

  bool get isValid =>
      id.trim().isNotEmpty && left.trim().isNotEmpty && right.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'id': id,
    'left': left,
    'right': right,
    if (leftResourceReference != null)
      'leftResourceReference': leftResourceReference,
    if (rightResourceReference != null)
      'rightResourceReference': rightResourceReference,
  };

  factory MatchingPairConfig.fromMap(Map<String, dynamic> map) {
    return MatchingPairConfig(
      id: map['id'] as String? ?? '',
      left: map['left'] as String? ?? '',
      right: map['right'] as String? ?? '',
      leftResourceReference: map['leftResourceReference'] as String?,
      rightResourceReference: map['rightResourceReference'] as String?,
    );
  }
}

class MatchingActivityConfig implements ActivityConfiguration {
  @override
  final int version;
  final List<MatchingPairConfig> pairs;

  const MatchingActivityConfig({
    this.version = currentActivityConfigurationVersion,
    this.pairs = const [],
  });

  @override
  bool get isValid {
    if (version != currentActivityConfigurationVersion || pairs.isEmpty) {
      return false;
    }
    final ids = pairs.map((pair) => pair.id).toSet();
    return pairs.every((pair) => pair.isValid) && ids.length == pairs.length;
  }

  @override
  Map<String, dynamic> toMap() => {
    'version': version,
    'pairs': pairs.map((pair) => pair.toMap()).toList(),
  };

  factory MatchingActivityConfig.fromMap(Map<String, dynamic> map) {
    return MatchingActivityConfig(
      version: _versionFromMap(map),
      pairs: _mapsFrom(map['pairs']).map(MatchingPairConfig.fromMap).toList(),
    );
  }
}

class PictogramOptionConfig {
  final String id;
  final String label;
  final String? resourceReference;

  const PictogramOptionConfig({
    required this.id,
    required this.label,
    this.resourceReference,
  });

  bool get isValid => id.trim().isNotEmpty && label.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    if (resourceReference != null) 'resourceReference': resourceReference,
  };

  factory PictogramOptionConfig.fromMap(Map<String, dynamic> map) {
    return PictogramOptionConfig(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      resourceReference: map['resourceReference'] as String?,
    );
  }
}

class PictogramActivityConfig implements ActivityConfiguration {
  @override
  final int version;
  final List<PictogramOptionConfig> options;

  const PictogramActivityConfig({
    this.version = currentActivityConfigurationVersion,
    this.options = const [],
  });

  @override
  bool get isValid =>
      version == currentActivityConfigurationVersion &&
      options.isNotEmpty &&
      options.every((option) => option.isValid) &&
      options.map((option) => option.id).toSet().length == options.length;

  @override
  Map<String, dynamic> toMap() => {
    'version': version,
    'options': options.map((option) => option.toMap()).toList(),
  };

  factory PictogramActivityConfig.fromMap(Map<String, dynamic> map) {
    return PictogramActivityConfig(
      version: _versionFromMap(map),
      options: _mapsFrom(map['options'])
          .map(PictogramOptionConfig.fromMap)
          .toList(),
    );
  }
}

class EmotionOptionConfig {
  final String id;
  final String label;
  final String prompt;
  final String expectedValue;

  const EmotionOptionConfig({
    required this.id,
    required this.label,
    required this.prompt,
    required this.expectedValue,
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      label.trim().isNotEmpty &&
      prompt.trim().isNotEmpty &&
      expectedValue.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'prompt': prompt,
    'expectedValue': expectedValue,
  };

  factory EmotionOptionConfig.fromMap(Map<String, dynamic> map) {
    return EmotionOptionConfig(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      expectedValue: map['expectedValue'] as String? ?? '',
    );
  }
}

class EmotionActivityConfig implements ActivityConfiguration {
  @override
  final int version;
  final List<EmotionOptionConfig> options;

  const EmotionActivityConfig({
    this.version = currentActivityConfigurationVersion,
    this.options = const [],
  });

  @override
  bool get isValid =>
      version == currentActivityConfigurationVersion &&
      options.isNotEmpty &&
      options.every((option) => option.isValid) &&
      options.map((option) => option.id).toSet().length == options.length;

  @override
  Map<String, dynamic> toMap() => {
    'version': version,
    'options': options.map((option) => option.toMap()).toList(),
  };

  factory EmotionActivityConfig.fromMap(Map<String, dynamic> map) {
    return EmotionActivityConfig(
      version: _versionFromMap(map),
      options: _mapsFrom(map['options'])
          .map(EmotionOptionConfig.fromMap)
          .toList(),
    );
  }
}

class TracingActivityConfig implements ActivityConfiguration {
  @override
  final int version;
  final String pattern;
  final String value;
  final String? difficultyHint;

  const TracingActivityConfig({
    this.version = currentActivityConfigurationVersion,
    required this.pattern,
    required this.value,
    this.difficultyHint,
  });

  @override
  bool get isValid =>
      version == currentActivityConfigurationVersion &&
      pattern.trim().isNotEmpty &&
      value.trim().isNotEmpty;

  @override
  Map<String, dynamic> toMap() => {
    'version': version,
    'pattern': pattern,
    'value': value,
    if (difficultyHint != null) 'difficultyHint': difficultyHint,
  };

  factory TracingActivityConfig.fromMap(Map<String, dynamic> map) {
    return TracingActivityConfig(
      version: _versionFromMap(map),
      pattern: map['pattern'] as String? ?? '',
      value: map['value'] as String? ?? '',
      difficultyHint: map['difficultyHint'] as String?,
    );
  }
}

class TimerActivityConfig implements ActivityConfiguration {
  @override
  final int version;
  final int durationSeconds;
  final String? label;

  const TimerActivityConfig({
    this.version = currentActivityConfigurationVersion,
    required this.durationSeconds,
    this.label,
  });

  @override
  bool get isValid =>
      version == currentActivityConfigurationVersion && durationSeconds > 0;

  @override
  Map<String, dynamic> toMap() => {
    'version': version,
    'durationSeconds': durationSeconds,
    if (label != null) 'label': label,
  };

  factory TimerActivityConfig.fromMap(Map<String, dynamic> map) {
    return TimerActivityConfig(
      version: _versionFromMap(map),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      label: map['label'] as String?,
    );
  }
}

class MotorStepConfig {
  final String id;
  final String instruction;
  final int? durationSeconds;
  final int? repetitions;

  const MotorStepConfig({
    required this.id,
    required this.instruction,
    this.durationSeconds,
    this.repetitions,
  });

  bool get isValid =>
      id.trim().isNotEmpty &&
      instruction.trim().isNotEmpty &&
      (durationSeconds == null || durationSeconds! > 0) &&
      (repetitions == null || repetitions! > 0);

  Map<String, dynamic> toMap() => {
    'id': id,
    'instruction': instruction,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (repetitions != null) 'repetitions': repetitions,
  };

  factory MotorStepConfig.fromMap(Map<String, dynamic> map) {
    return MotorStepConfig(
      id: map['id'] as String? ?? '',
      instruction: map['instruction'] as String? ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
      repetitions: (map['repetitions'] as num?)?.toInt(),
    );
  }
}

class MotorActivityConfig implements ActivityConfiguration {
  @override
  final int version;
  final List<MotorStepConfig> steps;

  const MotorActivityConfig({
    this.version = currentActivityConfigurationVersion,
    this.steps = const [],
  });

  @override
  bool get isValid =>
      version == currentActivityConfigurationVersion &&
      steps.isNotEmpty &&
      steps.every((step) => step.isValid) &&
      steps.map((step) => step.id).toSet().length == steps.length;

  @override
  Map<String, dynamic> toMap() => {
    'version': version,
    'steps': steps.map((step) => step.toMap()).toList(),
  };

  factory MotorActivityConfig.fromMap(Map<String, dynamic> map) {
    return MotorActivityConfig(
      version: _versionFromMap(map),
      steps: _mapsFrom(map['steps']).map(MotorStepConfig.fromMap).toList(),
    );
  }
}

int _versionFromMap(Map<String, dynamic> map) {
  return (map['version'] as num?)?.toInt() ??
      currentActivityConfigurationVersion;
}

Iterable<Map<String, dynamic>> _mapsFrom(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(Map<String, dynamic>.from);
}
