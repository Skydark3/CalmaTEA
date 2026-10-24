class PsychologistModel {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String? specialty;
  final String? professionalLicense;
  final String? workCenter;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PsychologistModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    this.specialty,
    this.professionalLicense,
    this.workCenter,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  PsychologistModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? specialty,
    String? professionalLicense,
    String? workCenter,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PsychologistModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      specialty: specialty ?? this.specialty,
      professionalLicense: professionalLicense ?? this.professionalLicense,
      workCenter: workCenter ?? this.workCenter,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'specialty': specialty,
      'professionalLicense': professionalLicense,
      'workCenter': workCenter,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory PsychologistModel.fromMap(Map<String, dynamic> map, {String? id}) {
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

    return PsychologistModel(
      id: id ?? (map['id'] as String? ?? ''),
      userId: map['userId'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      specialty: map['specialty'] as String?,
      professionalLicense: map['professionalLicense'] as String?,
      workCenter: map['workCenter'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }
}
