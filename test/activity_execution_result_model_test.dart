import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  group('ActivityExecutionResultModel', () {
    test('acepta y conserva un resultado agregado válido', () {
      final result = _result(
        activityType: ActivityType.sequence,
        metrics: SequenceExecutionMetrics(itemsCount: 4, checksCount: 2),
      );

      expect(result.id, 'session-id');
      expect(result.activityType, ActivityType.sequence);
      expect(result.schemaVersion, 1);
      expect(result.metrics, isA<SequenceExecutionMetrics>());
    });

    test('rechaza IDs vacíos', () {
      expect(() => _result(id: ''), throwsArgumentError);
      expect(() => _result(activityId: ''), throwsArgumentError);
      expect(() => _result(therapyId: ''), throwsArgumentError);
      expect(() => _result(childId: ''), throwsArgumentError);
      expect(() => _result(psychologistId: ''), throwsArgumentError);
      expect(() => _result(childUserId: ''), throwsArgumentError);
    });

    test('rechaza activityType desconocido', () {
      final map = _validResultMap()..['activityType'] = 'unknownEngine';

      expect(
        () => ActivityExecutionResultModel.fromMap(map),
        throwsFormatException,
      );
    });

    test('rechaza completedAt ausente o inválido', () {
      final missing = _validResultMap()..remove('completedAt');
      final invalid = _validResultMap()..['completedAt'] = 'invalid-date';

      expect(
        () => ActivityExecutionResultModel.fromMap(missing),
        throwsFormatException,
      );
      expect(
        () => ActivityExecutionResultModel.fromMap(invalid),
        throwsFormatException,
      );
    });

    test('valida schemaVersion y no acepta versiones desconocidas', () {
      final missing = _validResultMap()..remove('schemaVersion');
      final unknown = _validResultMap()..['schemaVersion'] = 2;

      expect(
        () => ActivityExecutionResultModel.fromMap(missing),
        throwsFormatException,
      );
      expect(
        () => ActivityExecutionResultModel.fromMap(unknown),
        throwsFormatException,
      );
    });

    test('durationSeconds es opcional y no puede ser negativo', () {
      final withoutDuration = _result();
      final map = withoutDuration.toMap();

      expect(withoutDuration.durationSeconds, isNull);
      expect(map.containsKey('durationSeconds'), isFalse);
      expect(ActivityExecutionResultModel.fromMap(map).durationSeconds, isNull);
      expect(() => _result(durationSeconds: -1), throwsArgumentError);
    });

    test('serializa y deserializa mediante round-trip estricto', () {
      final original = _result(
        activityType: ActivityType.timer,
        metrics: TimerExecutionMetrics(
          configuredDurationSeconds: 60,
          elapsedSeconds: 60,
        ),
        durationSeconds: 63,
      );

      final restored = ActivityExecutionResultModel.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.activityId, original.activityId);
      expect(restored.therapyId, original.therapyId);
      expect(restored.childId, original.childId);
      expect(restored.psychologistId, original.psychologistId);
      expect(restored.childUserId, original.childUserId);
      expect(restored.activityType, original.activityType);
      expect(restored.completedAt, original.completedAt);
      expect(restored.durationSeconds, original.durationSeconds);
      expect(restored.metrics.toMap(), original.metrics.toMap());
      expect(restored.schemaVersion, original.schemaVersion);
    });

    test('rechaza métricas pertenecientes a otro motor', () {
      expect(
        () => _result(
          activityType: ActivityType.emotion,
          metrics: MatchingExecutionMetrics(
            relationsCompleted: 2,
            checksCount: 3,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rechaza discrepancia entre result id y document id', () {
      expect(
        () => ActivityExecutionResultModel.fromMap(
          _validResultMap(),
          id: 'another-session',
        ),
        throwsFormatException,
      );
    });
  });

  group('métricas por motor', () {
    final validMetrics = <ActivityType, Map<String, dynamic>>{
      ActivityType.sequence: {'itemsCount': 4, 'checksCount': 2},
      ActivityType.matching: {'relationsCompleted': 3, 'checksCount': 4},
      ActivityType.emotion: {'exercisesReviewed': 3},
      ActivityType.pictogram: {'interactionsCount': 2},
      ActivityType.dragDrop: {'itemsPlaced': 4, 'checksCount': 5},
      ActivityType.timer: {
        'configuredDurationSeconds': 60,
        'elapsedSeconds': 60,
      },
      ActivityType.tracing: {'practiceCompleted': true, 'strokesCount': 3},
      ActivityType.motor: {'stepsVisited': 4},
    };

    for (final entry in validMetrics.entries) {
      test('acepta métricas válidas para ${entry.key.name}', () {
        final metrics = ActivityExecutionMetrics.fromMap(
          entry.key,
          entry.value,
        );

        expect(metrics.activityType, entry.key);
        expect(metrics.toMap(), entry.value);
      });
    }

    test('rechaza métricas ausentes, negativas o con tipo incorrecto', () {
      expect(
        () => ActivityExecutionMetrics.fromMap(ActivityType.sequence, {
          'itemsCount': 4,
        }),
        throwsFormatException,
      );
      expect(
        () => ActivityExecutionMetrics.fromMap(ActivityType.motor, {
          'stepsVisited': -1,
        }),
        throwsFormatException,
      );
      expect(
        () => ActivityExecutionMetrics.fromMap(ActivityType.pictogram, {
          'interactionsCount': '2',
        }),
        throwsFormatException,
      );
      expect(
        () => ActivityExecutionMetrics.fromMap(ActivityType.tracing, {
          'practiceCompleted': false,
        }),
        throwsFormatException,
      );
    });

    test('rechaza datos personales o detallados no permitidos', () {
      expect(
        () => ActivityExecutionMetrics.fromMap(ActivityType.emotion, {
          'exercisesReviewed': 2,
          'answerText': 'contenido personal',
        }),
        throwsFormatException,
      );
      expect(
        () => ActivityExecutionMetrics.fromMap(ActivityType.pictogram, {
          'interactionsCount': 2,
          'selectedOptionId': 'private-option',
        }),
        throwsFormatException,
      );
      expect(
        () => ActivityExecutionMetrics.fromMap(ActivityType.tracing, {
          'practiceCompleted': true,
          'points': <Map<String, int>>[
            {'x': 1, 'y': 2},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}

ActivityExecutionResultModel _result({
  String id = 'session-id',
  String activityId = 'activity-id',
  String therapyId = 'therapy-id',
  String childId = 'child-id',
  String psychologistId = 'psychologist-id',
  String childUserId = 'child-user-id',
  ActivityType activityType = ActivityType.sequence,
  ActivityExecutionMetrics? metrics,
  int? durationSeconds,
}) {
  return ActivityExecutionResultModel(
    id: id,
    activityId: activityId,
    therapyId: therapyId,
    childId: childId,
    psychologistId: psychologistId,
    childUserId: childUserId,
    activityType: activityType,
    completedAt: DateTime.utc(2026, 10, 10, 12, 5),
    durationSeconds: durationSeconds,
    metrics: metrics ?? SequenceExecutionMetrics(itemsCount: 4, checksCount: 2),
  );
}

Map<String, dynamic> _validResultMap() {
  return {
    'id': 'session-id',
    'activityId': 'activity-id',
    'therapyId': 'therapy-id',
    'childId': 'child-id',
    'psychologistId': 'psychologist-id',
    'childUserId': 'child-user-id',
    'activityType': 'sequence',
    'completedAt': '2026-10-10T12:05:00.000Z',
    'metrics': {'itemsCount': 4, 'checksCount': 2},
    'schemaVersion': 1,
  };
}
