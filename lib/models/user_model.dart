enum UserRole {
  psychologist,
  child;

  /// Convierte una cadena de texto a [UserRole].
  /// Retorna `null` si el valor no corresponde a un rol válido conocido.
  /// NUNCA retorna un rol por defecto para evitar escalamiento de privilegios.
  static UserRole? fromString(String? value) {
    if (value == null) return null;
    switch (value.trim().toLowerCase()) {
      case 'psychologist':
        return UserRole.psychologist;
      case 'child':
        return UserRole.child;
      default:
        return null;
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? childId;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.childId,
    required this.createdAt,
  });

  bool get hasValidChildLink {
    if (role != UserRole.child) return true;
    final linkedId = childId?.trim();
    return linkedId != null && linkedId.isNotEmpty && !linkedId.contains('/');
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? childId,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      childId: childId ?? this.childId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      if (childId != null) 'childId': childId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final roleString = map['role'] as String?;
    final userRole = UserRole.fromString(roleString);
    final rawChildId = map['childId'];
    final childId = rawChildId is String ? rawChildId.trim() : null;

    if (userRole == null) {
      throw FormatException(
        'El rol de usuario "$roleString" no es válido o no está reconocido por el sistema.',
      );
    }

    final rawCreatedAt = map['createdAt'];
    DateTime parsedCreatedAt;
    if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return UserModel(
      id: id ?? (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: userRole,
      childId: childId,
      createdAt: parsedCreatedAt,
    );
  }
}
