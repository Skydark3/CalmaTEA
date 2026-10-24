class ChildModel {
  final String id;
  final String psychologistId;
  final String fullName;
  final DateTime birthDate;
  final String supportLevel;
  final String? notes;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ChildModel({
    required this.id,
    required this.psychologistId,
    required this.fullName,
    required this.birthDate,
    required this.supportLevel,
    this.notes,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  /// Edad calculada dinámicamente según la fecha de nacimiento.
  /// NO se persiste como propiedad fija.
  int get age {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age >= 0 ? age : 0;
  }

  ChildModel copyWith({
    String? id,
    String? psychologistId,
    String? fullName,
    DateTime? birthDate,
    String? supportLevel,
    String? notes,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChildModel(
      id: id ?? this.id,
      psychologistId: psychologistId ?? this.psychologistId,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      supportLevel: supportLevel ?? this.supportLevel,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'psychologistId': psychologistId,
      'fullName': fullName,
      'birthDate': birthDate.toIso8601String(),
      'supportLevel': supportLevel,
      'notes': notes,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ChildModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawBirthDate = map['birthDate'];
    DateTime parsedBirthDate;
    if (rawBirthDate is String) {
      parsedBirthDate = DateTime.tryParse(rawBirthDate) ?? DateTime(2015, 1, 1);
    } else {
      parsedBirthDate = DateTime(2015, 1, 1);
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

    return ChildModel(
      id: id ?? (map['id'] as String? ?? ''),
      psychologistId: map['psychologistId'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      birthDate: parsedBirthDate,
      supportLevel: map['supportLevel'] as String? ?? '',
      notes: map['notes'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }
}
