enum AssistanceLevel {
  independent,
  verbal,
  visual,
  physical;

  String get displayName {
    switch (this) {
      case AssistanceLevel.independent:
        return 'Independiente';
      case AssistanceLevel.verbal:
        return 'Apoyo verbal';
      case AssistanceLevel.visual:
        return 'Apoyo visual';
      case AssistanceLevel.physical:
        return 'Apoyo físico';
    }
  }
}

class TherapySessionModel {
  final String id;
  final String psychologistId;
  final String childId;
  final String therapyId;
  final DateTime date;
  final String observations;
  final AssistanceLevel assistanceLevel;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TherapySessionModel({
    required this.id,
    required this.psychologistId,
    required this.childId,
    required this.therapyId,
    required this.date,
    required this.observations,
    required this.assistanceLevel,
    required this.createdAt,
    this.updatedAt,
  });

  TherapySessionModel copyWith({
    String? id,
    String? psychologistId,
    String? childId,
    String? therapyId,
    DateTime? date,
    String? observations,
    AssistanceLevel? assistanceLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TherapySessionModel(
      id: id ?? this.id,
      psychologistId: psychologistId ?? this.psychologistId,
      childId: childId ?? this.childId,
      therapyId: therapyId ?? this.therapyId,
      date: date ?? this.date,
      observations: observations ?? this.observations,
      assistanceLevel: assistanceLevel ?? this.assistanceLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'psychologistId': psychologistId,
      'childId': childId,
      'therapyId': therapyId,
      'date': date.toIso8601String(),
      'observations': observations,
      'assistanceLevel': assistanceLevel.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory TherapySessionModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final levelString = map['assistanceLevel'] as String? ?? 'independent';
    final assistanceLevel = AssistanceLevel.values.firstWhere(
      (l) => l.name == levelString,
      orElse: () => AssistanceLevel.independent,
    );

    final rawDate = map['date'];
    DateTime parsedDate;
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
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

    return TherapySessionModel(
      id: id ?? (map['id'] as String? ?? ''),
      psychologistId: map['psychologistId'] as String? ?? '',
      childId: map['childId'] as String? ?? '',
      therapyId: map['therapyId'] as String? ?? '',
      date: parsedDate,
      observations: map['observations'] as String? ?? '',
      assistanceLevel: assistanceLevel,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }
}
