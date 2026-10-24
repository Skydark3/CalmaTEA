import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';

void main() {
  group('ActivityExecutionSessionModel', () {
    test('acepta una sesión inProgress sin endedAt', () {
      final session = _session(
        status: ActivityExecutionSessionStatus.inProgress,
      );

      expect(session.status, ActivityExecutionSessionStatus.inProgress);
      expect(session.endedAt, isNull);
      expect(session.toMap().containsKey('endedAt'), isFalse);
    });

    test('acepta una sesión completed con endedAt válido', () {
      final session = _session(
        status: ActivityExecutionSessionStatus.completed,
        endedAt: DateTime.utc(2026, 10, 10, 12, 5),
      );

      expect(session.status, ActivityExecutionSessionStatus.completed);
      expect(session.endedAt, DateTime.utc(2026, 10, 10, 12, 5));
    });

    test('acepta una sesión interrupted con endedAt válido', () {
      final session = _session(
        status: ActivityExecutionSessionStatus.interrupted,
        endedAt: DateTime.utc(2026, 10, 10, 12, 2),
      );

      expect(session.status, ActivityExecutionSessionStatus.interrupted);
      expect(session.endedAt, isNotNull);
    });

    test('rechaza IDs vacíos', () {
      expect(() => _session(id: '  '), throwsArgumentError);
      expect(() => _session(activityId: ''), throwsArgumentError);
      expect(() => _session(therapyId: ''), throwsArgumentError);
      expect(() => _session(childId: ''), throwsArgumentError);
      expect(() => _session(psychologistId: ''), throwsArgumentError);
      expect(() => _session(childUserId: ''), throwsArgumentError);
    });

    test('rechaza un status desconocido', () {
      final map = _validMap()..['status'] = 'unknown';

      expect(
        () => ActivityExecutionSessionModel.fromMap(map),
        throwsFormatException,
      );
    });

    test('rechaza startedAt ausente o inválido', () {
      final missing = _validMap()..remove('startedAt');
      final invalid = _validMap()..['startedAt'] = 'not-a-date';

      expect(
        () => ActivityExecutionSessionModel.fromMap(missing),
        throwsFormatException,
      );
      expect(
        () => ActivityExecutionSessionModel.fromMap(invalid),
        throwsFormatException,
      );
    });

    test('exige endedAt para completed e interrupted', () {
      expect(
        () => _session(status: ActivityExecutionSessionStatus.completed),
        throwsArgumentError,
      );
      expect(
        () => _session(status: ActivityExecutionSessionStatus.interrupted),
        throwsArgumentError,
      );
    });

    test('rechaza endedAt en una sesión inProgress', () {
      expect(
        () => _session(
          status: ActivityExecutionSessionStatus.inProgress,
          endedAt: DateTime.utc(2026, 10, 10, 12, 5),
        ),
        throwsArgumentError,
      );
    });

    test('rechaza endedAt anterior a startedAt', () {
      expect(
        () => _session(
          status: ActivityExecutionSessionStatus.completed,
          endedAt: DateTime.utc(2026, 10, 10, 11, 59),
        ),
        throwsArgumentError,
      );
    });

    test('serializa y deserializa sin perder datos', () {
      final original = _session(
        status: ActivityExecutionSessionStatus.completed,
        endedAt: DateTime.utc(2026, 10, 10, 12, 5),
      );

      final restored = ActivityExecutionSessionModel.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.activityId, original.activityId);
      expect(restored.therapyId, original.therapyId);
      expect(restored.childId, original.childId);
      expect(restored.psychologistId, original.psychologistId);
      expect(restored.childUserId, original.childUserId);
      expect(restored.status, original.status);
      expect(restored.startedAt, original.startedAt);
      expect(restored.endedAt, original.endedAt);
    });

    test('rechaza discrepancia entre document id e id serializado', () {
      expect(
        () => ActivityExecutionSessionModel.fromMap(
          _validMap(),
          id: 'another-session',
        ),
        throwsFormatException,
      );
    });
  });
}

ActivityExecutionSessionModel _session({
  String id = 'session-id',
  String activityId = 'activity-id',
  String therapyId = 'therapy-id',
  String childId = 'child-id',
  String psychologistId = 'psychologist-id',
  String childUserId = 'child-user-id',
  ActivityExecutionSessionStatus status =
      ActivityExecutionSessionStatus.inProgress,
  DateTime? endedAt,
}) {
  return ActivityExecutionSessionModel(
    id: id,
    activityId: activityId,
    therapyId: therapyId,
    childId: childId,
    psychologistId: psychologistId,
    childUserId: childUserId,
    status: status,
    startedAt: DateTime.utc(2026, 10, 10, 12),
    endedAt: endedAt,
  );
}

Map<String, dynamic> _validMap() {
  return {
    'id': 'session-id',
    'activityId': 'activity-id',
    'therapyId': 'therapy-id',
    'childId': 'child-id',
    'psychologistId': 'psychologist-id',
    'childUserId': 'child-user-id',
    'status': 'inProgress',
    'startedAt': '2026-10-10T12:00:00.000Z',
  };
}
