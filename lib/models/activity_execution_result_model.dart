import 'activity_model.dart';

sealed class ActivityExecutionMetrics {
  const ActivityExecutionMetrics();

  ActivityType get activityType;

  Map<String, dynamic> toMap();

  factory ActivityExecutionMetrics.fromMap(
    ActivityType activityType,
    Map<String, dynamic> map,
  ) {
    try {
      return switch (activityType) {
        ActivityType.sequence => SequenceExecutionMetrics.fromMap(map),
        ActivityType.matching => MatchingExecutionMetrics.fromMap(map),
        ActivityType.emotion => EmotionExecutionMetrics.fromMap(map),
        ActivityType.pictogram => PictogramExecutionMetrics.fromMap(map),
        ActivityType.dragDrop => DragDropExecutionMetrics.fromMap(map),
        ActivityType.timer => TimerExecutionMetrics.fromMap(map),
        ActivityType.tracing => TracingExecutionMetrics.fromMap(map),
        ActivityType.motor => MotorExecutionMetrics.fromMap(map),
      };
    } on ArgumentError catch (error) {
      throw FormatException(error.message?.toString() ?? error.toString());
    }
  }
}

class SequenceExecutionMetrics extends ActivityExecutionMetrics {
  final int itemsCount;
  final int checksCount;

  const SequenceExecutionMetrics._({
    required this.itemsCount,
    required this.checksCount,
  });

  factory SequenceExecutionMetrics({
    required int itemsCount,
    required int checksCount,
  }) {
    _requirePositive(itemsCount, 'itemsCount');
    _requirePositive(checksCount, 'checksCount');
    return SequenceExecutionMetrics._(
      itemsCount: itemsCount,
      checksCount: checksCount,
    );
  }

  factory SequenceExecutionMetrics.fromMap(Map<String, dynamic> map) {
    _requireExactKeys(map, {'itemsCount', 'checksCount'});
    return SequenceExecutionMetrics(
      itemsCount: _requiredInt(map, 'itemsCount'),
      checksCount: _requiredInt(map, 'checksCount'),
    );
  }

  @override
  ActivityType get activityType => ActivityType.sequence;

  @override
  Map<String, dynamic> toMap() => {
    'itemsCount': itemsCount,
    'checksCount': checksCount,
  };
}

class MatchingExecutionMetrics extends ActivityExecutionMetrics {
  final int relationsCompleted;
  final int checksCount;

  const MatchingExecutionMetrics._({
    required this.relationsCompleted,
    required this.checksCount,
  });

  factory MatchingExecutionMetrics({
    required int relationsCompleted,
    required int checksCount,
  }) {
    _requirePositive(relationsCompleted, 'relationsCompleted');
    _requirePositive(checksCount, 'checksCount');
    return MatchingExecutionMetrics._(
      relationsCompleted: relationsCompleted,
      checksCount: checksCount,
    );
  }

  factory MatchingExecutionMetrics.fromMap(Map<String, dynamic> map) {
    _requireExactKeys(map, {'relationsCompleted', 'checksCount'});
    return MatchingExecutionMetrics(
      relationsCompleted: _requiredInt(map, 'relationsCompleted'),
      checksCount: _requiredInt(map, 'checksCount'),
    );
  }

  @override
  ActivityType get activityType => ActivityType.matching;

  @override
  Map<String, dynamic> toMap() => {
    'relationsCompleted': relationsCompleted,
    'checksCount': checksCount,
  };
}

class EmotionExecutionMetrics extends ActivityExecutionMetrics {
  final int exercisesReviewed;

  const EmotionExecutionMetrics._({required this.exercisesReviewed});

  factory EmotionExecutionMetrics({required int exercisesReviewed}) {
    _requirePositive(exercisesReviewed, 'exercisesReviewed');
    return EmotionExecutionMetrics._(exercisesReviewed: exercisesReviewed);
  }

  factory EmotionExecutionMetrics.fromMap(Map<String, dynamic> map) {
    _requireExactKeys(map, {'exercisesReviewed'});
    return EmotionExecutionMetrics(
      exercisesReviewed: _requiredInt(map, 'exercisesReviewed'),
    );
  }

  @override
  ActivityType get activityType => ActivityType.emotion;

  @override
  Map<String, dynamic> toMap() => {'exercisesReviewed': exercisesReviewed};
}

class PictogramExecutionMetrics extends ActivityExecutionMetrics {
  final int interactionsCount;

  const PictogramExecutionMetrics._({required this.interactionsCount});

  factory PictogramExecutionMetrics({required int interactionsCount}) {
    _requirePositive(interactionsCount, 'interactionsCount');
    return PictogramExecutionMetrics._(interactionsCount: interactionsCount);
  }

  factory PictogramExecutionMetrics.fromMap(Map<String, dynamic> map) {
    _requireExactKeys(map, {'interactionsCount'});
    return PictogramExecutionMetrics(
      interactionsCount: _requiredInt(map, 'interactionsCount'),
    );
  }

  @override
  ActivityType get activityType => ActivityType.pictogram;

  @override
  Map<String, dynamic> toMap() => {'interactionsCount': interactionsCount};
}

class DragDropExecutionMetrics extends ActivityExecutionMetrics {
  final int itemsPlaced;
  final int checksCount;

  const DragDropExecutionMetrics._({
    required this.itemsPlaced,
    required this.checksCount,
  });

  factory DragDropExecutionMetrics({
    required int itemsPlaced,
    required int checksCount,
  }) {
    _requirePositive(itemsPlaced, 'itemsPlaced');
    _requirePositive(checksCount, 'checksCount');
    return DragDropExecutionMetrics._(
      itemsPlaced: itemsPlaced,
      checksCount: checksCount,
    );
  }

  factory DragDropExecutionMetrics.fromMap(Map<String, dynamic> map) {
    _requireExactKeys(map, {'itemsPlaced', 'checksCount'});
    return DragDropExecutionMetrics(
      itemsPlaced: _requiredInt(map, 'itemsPlaced'),
      checksCount: _requiredInt(map, 'checksCount'),
    );
  }

  @override
  ActivityType get activityType => ActivityType.dragDrop;

  @override
  Map<String, dynamic> toMap() => {
    'itemsPlaced': itemsPlaced,
    'checksCount': checksCount,
  };
}

class TimerExecutionMetrics extends ActivityExecutionMetrics {
  final int configuredDurationSeconds;
  final int elapsedSeconds;

  const TimerExecutionMetrics._({
    required this.configuredDurationSeconds,
    required this.elapsedSeconds,
  });

  factory TimerExecutionMetrics({
    required int configuredDurationSeconds,
    required int elapsedSeconds,
  }) {
    _requirePositive(configuredDurationSeconds, 'configuredDurationSeconds');
    _requirePositive(elapsedSeconds, 'elapsedSeconds');
    return TimerExecutionMetrics._(
      configuredDurationSeconds: configuredDurationSeconds,
      elapsedSeconds: elapsedSeconds,
    );
  }

  factory TimerExecutionMetrics.fromMap(Map<String, dynamic> map) {
    _requireExactKeys(map, {'configuredDurationSeconds', 'elapsedSeconds'});
    return TimerExecutionMetrics(
      configuredDurationSeconds: _requiredInt(map, 'configuredDurationSeconds'),
      elapsedSeconds: _requiredInt(map, 'elapsedSeconds'),
    );
  }

  @override
  ActivityType get activityType => ActivityType.timer;

  @override
  Map<String, dynamic> toMap() => {
    'configuredDurationSeconds': configuredDurationSeconds,
    'elapsedSeconds': elapsedSeconds,
  };
}

class TracingExecutionMetrics extends ActivityExecutionMetrics {
  final bool practiceCompleted;
  final int? strokesCount;

  const TracingExecutionMetrics._({
    required this.practiceCompleted,
    required this.strokesCount,
  });

  factory TracingExecutionMetrics({
    required bool practiceCompleted,
    int? strokesCount,
  }) {
    if (!practiceCompleted) {
      throw ArgumentError.value(
        practiceCompleted,
        'practiceCompleted',
        'Un resultado de trazado debe representar una práctica realizada.',
      );
    }
    if (strokesCount != null) _requirePositive(strokesCount, 'strokesCount');
    return TracingExecutionMetrics._(
      practiceCompleted: practiceCompleted,
      strokesCount: strokesCount,
    );
  }

  factory TracingExecutionMetrics.fromMap(Map<String, dynamic> map) {
    _requireExactKeys(map, {'practiceCompleted'}, optional: {'strokesCount'});
    return TracingExecutionMetrics(
      practiceCompleted: _requiredBool(map, 'practiceCompleted'),
      strokesCount: map.containsKey('strokesCount')
          ? _requiredInt(map, 'strokesCount')
          : null,
    );
  }

  @override
  ActivityType get activityType => ActivityType.tracing;

  @override
  Map<String, dynamic> toMap() => {
    'practiceCompleted': practiceCompleted,
    if (strokesCount != null) 'strokesCount': strokesCount,
  };
}

class MotorExecutionMetrics extends ActivityExecutionMetrics {
  final int stepsVisited;

  const MotorExecutionMetrics._({required this.stepsVisited});

  factory MotorExecutionMetrics({required int stepsVisited}) {
    _requirePositive(stepsVisited, 'stepsVisited');
    return MotorExecutionMetrics._(stepsVisited: stepsVisited);
  }

  factory MotorExecutionMetrics.fromMap(Map<String, dynamic> map) {
    _requireExactKeys(map, {'stepsVisited'});
    return MotorExecutionMetrics(
      stepsVisited: _requiredInt(map, 'stepsVisited'),
    );
  }

  @override
  ActivityType get activityType => ActivityType.motor;

  @override
  Map<String, dynamic> toMap() => {'stepsVisited': stepsVisited};
}

class ActivityExecutionResultModel {
  static const int currentSchemaVersion = 1;

  final String id;
  final String activityId;
  final String therapyId;
  final String childId;
  final String psychologistId;
  final String childUserId;
  final ActivityType activityType;
  final DateTime completedAt;
  final int? durationSeconds;
  final ActivityExecutionMetrics metrics;
  final int schemaVersion;

  const ActivityExecutionResultModel._({
    required this.id,
    required this.activityId,
    required this.therapyId,
    required this.childId,
    required this.psychologistId,
    required this.childUserId,
    required this.activityType,
    required this.completedAt,
    required this.durationSeconds,
    required this.metrics,
    required this.schemaVersion,
  });

  factory ActivityExecutionResultModel({
    required String id,
    required String activityId,
    required String therapyId,
    required String childId,
    required String psychologistId,
    required String childUserId,
    required ActivityType activityType,
    required DateTime completedAt,
    int? durationSeconds,
    required ActivityExecutionMetrics metrics,
    int schemaVersion = currentSchemaVersion,
  }) {
    _validateId(id, 'id');
    _validateId(activityId, 'activityId');
    _validateId(therapyId, 'therapyId');
    _validateId(childId, 'childId');
    _validateId(psychologistId, 'psychologistId');
    _validateId(childUserId, 'childUserId');
    if (durationSeconds != null && durationSeconds < 0) {
      throw ArgumentError.value(
        durationSeconds,
        'durationSeconds',
        'No puede ser negativo.',
      );
    }
    if (schemaVersion != currentSchemaVersion) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Versión de resultado no compatible.',
      );
    }
    if (metrics.activityType != activityType) {
      throw ArgumentError('Las métricas no corresponden al tipo de actividad.');
    }

    return ActivityExecutionResultModel._(
      id: id,
      activityId: activityId,
      therapyId: therapyId,
      childId: childId,
      psychologistId: psychologistId,
      childUserId: childUserId,
      activityType: activityType,
      completedAt: completedAt,
      durationSeconds: durationSeconds,
      metrics: metrics,
      schemaVersion: schemaVersion,
    );
  }

  ActivityExecutionResultModel copyWith({
    String? id,
    String? activityId,
    String? therapyId,
    String? childId,
    String? psychologistId,
    String? childUserId,
    ActivityType? activityType,
    DateTime? completedAt,
    int? durationSeconds,
    bool clearDurationSeconds = false,
    ActivityExecutionMetrics? metrics,
    int? schemaVersion,
  }) {
    if (clearDurationSeconds && durationSeconds != null) {
      throw ArgumentError(
        'durationSeconds y clearDurationSeconds no pueden usarse juntos.',
      );
    }

    return ActivityExecutionResultModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      therapyId: therapyId ?? this.therapyId,
      childId: childId ?? this.childId,
      psychologistId: psychologistId ?? this.psychologistId,
      childUserId: childUserId ?? this.childUserId,
      activityType: activityType ?? this.activityType,
      completedAt: completedAt ?? this.completedAt,
      durationSeconds: clearDurationSeconds
          ? null
          : durationSeconds ?? this.durationSeconds,
      metrics: metrics ?? this.metrics,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activityId': activityId,
      'therapyId': therapyId,
      'childId': childId,
      'psychologistId': psychologistId,
      'childUserId': childUserId,
      'activityType': activityType.name,
      'completedAt': completedAt.toIso8601String(),
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      'metrics': metrics.toMap(),
      'schemaVersion': schemaVersion,
    };
  }

  factory ActivityExecutionResultModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    _validateMapKeys(
      map,
      required: {
        if (id == null) 'id',
        'activityId',
        'therapyId',
        'childId',
        'psychologistId',
        'childUserId',
        'activityType',
        'completedAt',
        'metrics',
        'schemaVersion',
      },
      allowed: {
        'id',
        'activityId',
        'therapyId',
        'childId',
        'psychologistId',
        'childUserId',
        'activityType',
        'completedAt',
        'durationSeconds',
        'metrics',
        'schemaVersion',
      },
    );

    final mappedId = map['id'];
    if (mappedId != null && mappedId is! String) {
      throw const FormatException('id debe ser un String.');
    }
    if (id != null && mappedId != null && mappedId != id) {
      throw const FormatException(
        'El id del documento no coincide con el id serializado.',
      );
    }

    final activityType = _activityTypeFromName(
      _requiredString(map, 'activityType'),
    );
    final rawMetrics = map['metrics'];
    if (rawMetrics is! Map) {
      throw const FormatException('metrics debe ser un mapa válido.');
    }
    final metricsMap = <String, dynamic>{};
    for (final entry in rawMetrics.entries) {
      if (entry.key is! String) {
        throw const FormatException('Las claves de metrics deben ser String.');
      }
      metricsMap[entry.key as String] = entry.value;
    }

    final rawDuration = map['durationSeconds'];
    if (rawDuration != null && rawDuration is! int) {
      throw const FormatException('durationSeconds debe ser un entero.');
    }
    final rawSchemaVersion = map['schemaVersion'];
    if (rawSchemaVersion is! int) {
      throw const FormatException('schemaVersion debe ser un entero.');
    }

    try {
      return ActivityExecutionResultModel(
        id: id ?? _requiredString(map, 'id'),
        activityId: _requiredString(map, 'activityId'),
        therapyId: _requiredString(map, 'therapyId'),
        childId: _requiredString(map, 'childId'),
        psychologistId: _requiredString(map, 'psychologistId'),
        childUserId: _requiredString(map, 'childUserId'),
        activityType: activityType,
        completedAt: _requiredDateTime(map, 'completedAt'),
        durationSeconds: rawDuration as int?,
        metrics: ActivityExecutionMetrics.fromMap(activityType, metricsMap),
        schemaVersion: rawSchemaVersion,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message?.toString() ?? error.toString());
    }
  }

  static void _validateId(String value, String field) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, field, 'No puede estar vacío.');
    }
  }

  static ActivityType _activityTypeFromName(String value) {
    for (final type in ActivityType.values) {
      if (type.name == value) return type;
    }
    throw FormatException('Tipo de actividad no reconocido: $value.');
  }

  static String _requiredString(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field debe ser un String no vacío.');
    }
    return value;
  }

  static DateTime _requiredDateTime(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is! String) {
      throw FormatException('$field debe ser una fecha ISO-8601.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$field contiene una fecha inválida.');
    }
    return parsed;
  }

  static void _validateMapKeys(
    Map<String, dynamic> map, {
    required Set<String> required,
    required Set<String> allowed,
  }) {
    final missing = required.difference(map.keys.toSet());
    if (missing.isNotEmpty) {
      throw FormatException(
        'Faltan campos obligatorios: ${missing.join(', ')}.',
      );
    }
    final unknown = map.keys.toSet().difference(allowed);
    if (unknown.isNotEmpty) {
      throw FormatException('Campos no reconocidos: ${unknown.join(', ')}.');
    }
  }
}

void _requirePositive(int value, String field) {
  if (value <= 0) {
    throw ArgumentError.value(value, field, 'Debe ser mayor que cero.');
  }
}

int _requiredInt(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is! int) {
    throw FormatException('$field debe ser un entero.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is! bool) {
    throw FormatException('$field debe ser booleano.');
  }
  return value;
}

void _requireExactKeys(
  Map<String, dynamic> map,
  Set<String> required, {
  Set<String> optional = const {},
}) {
  final keys = map.keys.toSet();
  final missing = required.difference(keys);
  if (missing.isNotEmpty) {
    throw FormatException(
      'Faltan métricas obligatorias: ${missing.join(', ')}.',
    );
  }
  final unknown = keys.difference({...required, ...optional});
  if (unknown.isNotEmpty) {
    throw FormatException('Métricas no permitidas: ${unknown.join(', ')}.');
  }
}
