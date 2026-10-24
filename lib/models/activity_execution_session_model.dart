enum ActivityExecutionSessionStatus { inProgress, completed, interrupted }

class ActivityExecutionSessionModel {
  final String id;
  final String activityId;
  final String therapyId;
  final String childId;
  final String psychologistId;
  final String childUserId;
  final ActivityExecutionSessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;

  const ActivityExecutionSessionModel._({
    required this.id,
    required this.activityId,
    required this.therapyId,
    required this.childId,
    required this.psychologistId,
    required this.childUserId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
  });

  factory ActivityExecutionSessionModel({
    required String id,
    required String activityId,
    required String therapyId,
    required String childId,
    required String psychologistId,
    required String childUserId,
    required ActivityExecutionSessionStatus status,
    required DateTime startedAt,
    DateTime? endedAt,
  }) {
    _validateId(id, 'id');
    _validateId(activityId, 'activityId');
    _validateId(therapyId, 'therapyId');
    _validateId(childId, 'childId');
    _validateId(psychologistId, 'psychologistId');
    _validateId(childUserId, 'childUserId');
    _validateDates(status: status, startedAt: startedAt, endedAt: endedAt);

    return ActivityExecutionSessionModel._(
      id: id,
      activityId: activityId,
      therapyId: therapyId,
      childId: childId,
      psychologistId: psychologistId,
      childUserId: childUserId,
      status: status,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }

  ActivityExecutionSessionModel copyWith({
    String? id,
    String? activityId,
    String? therapyId,
    String? childId,
    String? psychologistId,
    String? childUserId,
    ActivityExecutionSessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
  }) {
    if (clearEndedAt && endedAt != null) {
      throw ArgumentError('endedAt y clearEndedAt no pueden usarse juntos.');
    }

    return ActivityExecutionSessionModel(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      therapyId: therapyId ?? this.therapyId,
      childId: childId ?? this.childId,
      psychologistId: psychologistId ?? this.psychologistId,
      childUserId: childUserId ?? this.childUserId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : endedAt ?? this.endedAt,
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
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    };
  }

  factory ActivityExecutionSessionModel.fromMap(
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
        'status',
        'startedAt',
      },
      allowed: {
        'id',
        'activityId',
        'therapyId',
        'childId',
        'psychologistId',
        'childUserId',
        'status',
        'startedAt',
        'endedAt',
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

    final rawStatus = _requiredString(map, 'status');
    final status = _statusFromName(rawStatus);

    try {
      return ActivityExecutionSessionModel(
        id: id ?? _requiredString(map, 'id'),
        activityId: _requiredString(map, 'activityId'),
        therapyId: _requiredString(map, 'therapyId'),
        childId: _requiredString(map, 'childId'),
        psychologistId: _requiredString(map, 'psychologistId'),
        childUserId: _requiredString(map, 'childUserId'),
        status: status,
        startedAt: _requiredDateTime(map, 'startedAt'),
        endedAt: _optionalDateTime(map, 'endedAt'),
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

  static void _validateDates({
    required ActivityExecutionSessionStatus status,
    required DateTime startedAt,
    required DateTime? endedAt,
  }) {
    if (status == ActivityExecutionSessionStatus.inProgress &&
        endedAt != null) {
      throw ArgumentError('Una sesión inProgress no puede contener endedAt.');
    }
    if (status != ActivityExecutionSessionStatus.inProgress &&
        endedAt == null) {
      throw ArgumentError(
        'Una sesión completed o interrupted requiere endedAt.',
      );
    }
    if (endedAt != null && endedAt.isBefore(startedAt)) {
      throw ArgumentError('endedAt no puede ser anterior a startedAt.');
    }
  }

  static ActivityExecutionSessionStatus _statusFromName(String value) {
    for (final status in ActivityExecutionSessionStatus.values) {
      if (status.name == value) return status;
    }
    throw FormatException('Estado de sesión no reconocido: $value.');
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

  static DateTime? _optionalDateTime(Map<String, dynamic> map, String field) {
    if (!map.containsKey(field) || map[field] == null) return null;
    return _requiredDateTime(map, field);
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
