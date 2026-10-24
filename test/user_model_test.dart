import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/models/user_model.dart';

void main() {
  group('UserModel and UserRole tests', () {
    test('UserRole.fromString correctly parses valid roles and rejects invalid strings', () {
      expect(UserRole.fromString('psychologist'), UserRole.psychologist);
      expect(UserRole.fromString('PSYCHOLOGIST'), UserRole.psychologist);
      expect(UserRole.fromString('child'), UserRole.child);
      expect(UserRole.fromString('CHILD'), UserRole.child);

      // Valores desconocidos NUNCA deben resolverse como psychologist ni child
      expect(UserRole.fromString(null), isNull);
      expect(UserRole.fromString(''), isNull);
      expect(UserRole.fromString('unknown_role'), isNull);
      expect(UserRole.fromString('admin'), isNull);
      expect(UserRole.fromString('family'), isNull);
    });

    test('serializes and deserializes psychologist role correctly', () {
      final user = UserModel(
        id: 'uid123',
        name: 'Dra. María Lopez',
        email: 'maria@calmatea.com',
        role: UserRole.psychologist,
        createdAt: DateTime(2026, 1, 15, 10, 30),
      );

      final map = user.toMap();
      expect(map['id'], 'uid123');
      expect(map['role'], 'psychologist');
      expect(map.containsKey('childId'), isFalse);

      final deserialized = UserModel.fromMap(map);
      expect(deserialized.id, 'uid123');
      expect(deserialized.role, UserRole.psychologist);
      expect(deserialized.name, 'Dra. María Lopez');
      expect(deserialized.childId, isNull);
      expect(deserialized.hasValidChildLink, isTrue);
    });

    test('serializes and deserializes child role correctly', () {
      final user = UserModel(
        id: 'uid456',
        name: 'Mateo',
        email: 'mateo@calmatea.com',
        role: UserRole.child,
        childId: 'child-123',
        createdAt: DateTime(2026, 2, 20),
      );

      final map = user.toMap();
      expect(map['role'], 'child');
      expect(map['childId'], 'child-123');

      final deserialized = UserModel.fromMap(map);
      expect(deserialized.role, UserRole.child);
      expect(deserialized.name, 'Mateo');
      expect(deserialized.childId, 'child-123');
      expect(deserialized.hasValidChildLink, isTrue);
    });

    test('child without a structurally valid childId is blocked', () {
      final missingLink = UserModel.fromMap({
        'id': 'uid-child',
        'name': 'Paciente',
        'email': 'paciente@calmatea.com',
        'role': 'child',
        'createdAt': '2026-02-20T00:00:00.000',
      });
      final emptyLink = UserModel.fromMap({
        'id': 'uid-child',
        'name': 'Paciente',
        'email': 'paciente@calmatea.com',
        'role': 'child',
        'childId': '   ',
        'createdAt': '2026-02-20T00:00:00.000',
      });
      final invalidPath = missingLink.copyWith(childId: 'children/child-123');

      expect(missingLink.hasValidChildLink, isFalse);
      expect(emptyLink.hasValidChildLink, isFalse);
      expect(invalidPath.hasValidChildLink, isFalse);
    });

    test('copyWith and round trip preserve childId', () {
      final child = UserModel(
        id: 'uid-child',
        name: 'Paciente',
        email: 'paciente@calmatea.com',
        role: UserRole.child,
        childId: 'child-original',
        createdAt: DateTime(2026, 2, 20),
      );

      final updated = child.copyWith(name: 'Paciente actualizado');
      final roundTrip = UserModel.fromMap(updated.toMap());

      expect(updated.childId, 'child-original');
      expect(roundTrip.childId, 'child-original');
      expect(roundTrip.hasValidChildLink, isTrue);
    });

    test('throws FormatException and NEVER grants psychologist access if role is unrecognized', () {
      final invalidMap = {
        'id': 'uid789',
        'name': 'Usuario Inseguro',
        'email': 'inseguro@calmatea.com',
        'role': 'unknown_role',
        'createdAt': '2026-03-01T00:00:00.000',
      };

      expect(
        () => UserModel.fromMap(invalidMap),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
