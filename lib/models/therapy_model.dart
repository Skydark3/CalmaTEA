enum TherapyType {
  occupational,
  schoolOccupational,
  physicalPsychomotor,
  language,
  psychology;

  String get displayName {
    switch (this) {
      case TherapyType.occupational:
        return 'Terapia Ocupacional';
      case TherapyType.schoolOccupational:
        return 'Terapia Ocupacional Escolarizada';
      case TherapyType.physicalPsychomotor:
        return 'Terapia Física y Psicomotricidad';
      case TherapyType.language:
        return 'Terapia de Lenguaje';
      case TherapyType.psychology:
        return 'Psicología';
    }
  }
}

enum TherapyStatus {
  active,
  pending,
  completed,
  paused;

  String get displayName {
    switch (this) {
      case TherapyStatus.active:
        return 'Activa';
      case TherapyStatus.pending:
        return 'Pendiente';
      case TherapyStatus.completed:
        return 'Finalizada';
      case TherapyStatus.paused:
        return 'Pausada';
    }
  }
}

class TherapyModel {
  final String id;
  final String childId;
  final String psychologistId;
  final TherapyType type;
  final TherapyStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TherapyModel({
    required this.id,
    required this.childId,
    required this.psychologistId,
    required this.type,
    required this.status,
    required this.startDate,
    this.endDate,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Título visible obtenido dinámicamente del enum
  String get name => type.displayName;

  TherapyModel copyWith({
    String? id,
    String? childId,
    String? psychologistId,
    TherapyType? type,
    TherapyStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TherapyModel(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      psychologistId: psychologistId ?? this.psychologistId,
      type: type ?? this.type,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'childId': childId,
      'psychologistId': psychologistId,
      'type': type.name,
      'status': status.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory TherapyModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final typeString = map['type'] as String? ?? 'occupational';
    final therapyType = TherapyType.values.firstWhere(
      (t) => t.name == typeString,
      orElse: () => TherapyType.occupational,
    );

    final statusString = map['status'] as String? ?? 'active';
    final therapyStatus = TherapyStatus.values.firstWhere(
      (s) => s.name == statusString,
      orElse: () => TherapyStatus.active,
    );

    final rawStartDate = map['startDate'];
    DateTime parsedStartDate;
    if (rawStartDate is String) {
      parsedStartDate = DateTime.tryParse(rawStartDate) ?? DateTime.now();
    } else {
      parsedStartDate = DateTime.now();
    }

    final rawEndDate = map['endDate'];
    DateTime? parsedEndDate;
    if (rawEndDate is String) {
      parsedEndDate = DateTime.tryParse(rawEndDate);
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

    return TherapyModel(
      id: id ?? (map['id'] as String? ?? ''),
      childId: map['childId'] as String? ?? '',
      psychologistId: map['psychologistId'] as String? ?? '',
      type: therapyType,
      status: therapyStatus,
      startDate: parsedStartDate,
      endDate: parsedEndDate,
      notes: map['notes'] as String?,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }
}
