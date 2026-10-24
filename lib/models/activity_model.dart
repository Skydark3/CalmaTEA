enum ActivityType {
  sequence,
  dragDrop,
  matching,
  pictogram,
  emotion,
  tracing,
  timer,
  motor;

  String get displayName {
    switch (this) {
      case ActivityType.sequence:
        return 'Secuencia';
      case ActivityType.dragDrop:
        return 'Arrastrar y soltar';
      case ActivityType.matching:
        return 'Emparejamiento';
      case ActivityType.pictogram:
        return 'Pictogramas';
      case ActivityType.emotion:
        return 'Emociones';
      case ActivityType.tracing:
        return 'Trazado';
      case ActivityType.timer:
        return 'Temporizador';
      case ActivityType.motor:
        return 'Actividad motora';
    }
  }
}

enum ActivityStatus {
  assigned,
  inProgress,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case ActivityStatus.assigned:
        return 'Asignada';
      case ActivityStatus.inProgress:
        return 'En progreso';
      case ActivityStatus.completed:
        return 'Completada';
      case ActivityStatus.cancelled:
        return 'Cancelada';
    }
  }
}

class ActivityModel {
  final String id;
  final String therapyId;
  final String childId;
  final String psychologistId;
  final String title;
  final String description;
  final ActivityType type;
  final int difficulty;
  final String instructions;
  final Map<String, dynamic> configuration;
  final ActivityStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ActivityModel({
    required this.id,
    required this.therapyId,
    required this.childId,
    required this.psychologistId,
    required this.title,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.instructions,
    required this.configuration,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  ActivityModel copyWith({
    String? id,
    String? therapyId,
    String? childId,
    String? psychologistId,
    String? title,
    String? description,
    ActivityType? type,
    int? difficulty,
    String? instructions,
    Map<String, dynamic>? configuration,
    ActivityStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      therapyId: therapyId ?? this.therapyId,
      childId: childId ?? this.childId,
      psychologistId: psychologistId ?? this.psychologistId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      instructions: instructions ?? this.instructions,
      configuration: configuration ?? this.configuration,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'therapyId': therapyId,
      'childId': childId,
      'psychologistId': psychologistId,
      'title': title,
      'description': description,
      'type': type.name,
      'difficulty': difficulty,
      'instructions': instructions,
      'configuration': configuration,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final typeString = map['type'];
    if (typeString is! String) {
      throw const FormatException('Tipo de actividad ausente o inválido.');
    }
    final activityType = ActivityType.values
        .where((type) => type.name == typeString)
        .firstOrNull;
    if (activityType == null) {
      throw FormatException('Tipo de actividad no reconocido: $typeString.');
    }

    final statusString = map['status'];
    if (statusString is! String) {
      throw const FormatException('Estado de actividad ausente o inválido.');
    }
    final activityStatus = ActivityStatus.values
        .where((status) => status.name == statusString)
        .firstOrNull;
    if (activityStatus == null) {
      throw FormatException(
        'Estado de actividad no reconocido: $statusString.',
      );
    }

    final rawCreatedAt = map['createdAt'];
    DateTime parsedCreatedAt;
    if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    final rawUpdatedAt = map['updatedAt'];
    DateTime? parsedUpdatedAt;
    if (rawUpdatedAt is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    }

    return ActivityModel(
      id: id ?? (map['id'] as String? ?? ''),
      therapyId: map['therapyId'] as String? ?? '',
      childId: map['childId'] as String? ?? '',
      psychologistId: map['psychologistId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: activityType,
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 1,
      instructions: map['instructions'] as String? ?? '',
      configuration: Map<String, dynamic>.from(
        map['configuration'] as Map? ?? {},
      ),
      status: activityStatus,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }
}
