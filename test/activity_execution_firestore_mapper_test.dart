import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';
import 'package:tea_app/services/activity_execution_firestore_mapper.dart';

void main() {
  group('ActivityExecutionFirestoreMapper', () {
    test('convierte Timestamp de una sesion sin inventar fechas', () {
      final startedAt = DateTime.utc(2026, 10, 10, 14, 30);
      final session = ActivityExecutionFirestoreMapper.sessionFromData(
        id: 'session-1',
        data: {
          'id': 'session-1',
          'activityId': 'activity-1',
          'therapyId': 'therapy-1',
          'childId': 'child-1',
          'psychologistId': 'psychologist-1',
          'childUserId': 'child-user-1',
          'status': 'inProgress',
          'startedAt': Timestamp.fromDate(startedAt),
        },
      );

      expect(session.status, ActivityExecutionSessionStatus.inProgress);
      expect(session.startedAt.isAtSameMomentAs(startedAt), isTrue);
      expect(session.endedAt, isNull);
    });

    test('convierte resultado y reconstruye metricas estrictas', () {
      final completedAt = DateTime.utc(2026, 10, 10, 14, 35);
      final executionResult = ActivityExecutionFirestoreMapper.resultFromData(
        id: 'session-1',
        data: {
          'id': 'session-1',
          'activityId': 'activity-1',
          'therapyId': 'therapy-1',
          'childId': 'child-1',
          'psychologistId': 'psychologist-1',
          'childUserId': 'child-user-1',
          'activityType': 'sequence',
          'completedAt': Timestamp.fromDate(completedAt),
          'durationSeconds': 30,
          'metrics': {'itemsCount': 3, 'checksCount': 2},
          'schemaVersion': 1,
        },
      );

      expect(executionResult.activityType, ActivityType.sequence);
      expect(executionResult.completedAt.isAtSameMomentAs(completedAt), isTrue);
      expect(executionResult.metrics, isA<SequenceExecutionMetrics>());
      expect(executionResult.metrics.toMap(), {
        'itemsCount': 3,
        'checksCount': 2,
      });
    });

    test('no reemplaza un server timestamp pendiente con hora local', () {
      expect(
        () => ActivityExecutionFirestoreMapper.sessionFromData(
          id: 'session-1',
          hasPendingWrites: true,
          data: {
            'id': 'session-1',
            'activityId': 'activity-1',
            'therapyId': 'therapy-1',
            'childId': 'child-1',
            'psychologistId': 'psychologist-1',
            'childUserId': 'child-user-1',
            'status': 'inProgress',
            'startedAt': null,
          },
        ),
        throwsStateError,
      );
    });

    test('rechaza un tipo distinto de Timestamp confirmado', () {
      expect(
        () => ActivityExecutionFirestoreMapper.resultFromData(
          id: 'session-1',
          data: {
            'id': 'session-1',
            'activityId': 'activity-1',
            'therapyId': 'therapy-1',
            'childId': 'child-1',
            'psychologistId': 'psychologist-1',
            'childUserId': 'child-user-1',
            'activityType': 'motor',
            'completedAt': '2026-10-10T14:35:00Z',
            'metrics': {'stepsVisited': 2},
            'schemaVersion': 1,
          },
        ),
        throwsFormatException,
      );
    });
  });
}
