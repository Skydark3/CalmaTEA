import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/emotion_execution_controller.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  test('inicia una sola sesión ante llamadas simultáneas', () async {
    final persistence = _FakeEmotionPersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;
    final controller = _controller(persistence);

    final firstStart = controller.start();
    final secondStart = controller.start();
    expect(persistence.startCalls, 1);

    pendingStart.complete('session-1');
    await Future.wait([firstStart, secondStart]);

    expect(controller.sessionId, 'session-1');
    expect(controller.exercisesReviewed, 0);
    expect(controller.state, EmotionExecutionPersistenceState.ready);
  });

  test('permite reintentar un inicio fallido', () async {
    final persistence = _FakeEmotionPersistence()..startFailures = 1;
    final controller = _controller(persistence);

    await controller.start();
    expect(controller.state, EmotionExecutionPersistenceState.startFailure);

    await controller.start();
    expect(persistence.startCalls, 2);
    expect(controller.sessionId, 'session-2');
    expect(controller.state, EmotionExecutionPersistenceState.ready);
  });

  test('mostrar un ejercicio no lo cuenta como revisado', () async {
    final controller = _controller(_FakeEmotionPersistence());
    await controller.start();

    expect(controller.exercisesReviewed, 0);
  });

  test('cuenta ejercicios revisados sin duplicar revisitas', () async {
    final controller = _controller(_FakeEmotionPersistence());
    await controller.start();

    controller
      ..markExerciseReviewed(0)
      ..markExerciseReviewed(1)
      ..markExerciseReviewed(0)
      ..markExerciseReviewed(1);

    expect(controller.exercisesReviewed, 2);
  });

  test(
    'rechaza índices inválidos y no finaliza si faltan ejercicios',
    () async {
      final persistence = _FakeEmotionPersistence();
      final controller = _controller(persistence);
      await controller.start();

      expect(() => controller.markExerciseReviewed(2), throwsRangeError);
      controller.markExerciseReviewed(0);
      expect(await controller.finish(), isFalse);
      expect(persistence.completeCalls, 0);
    },
  );

  test(
    'finaliza con el mismo sessionId y ejercicios revisados reales',
    () async {
      final persistence = _FakeEmotionPersistence();
      final controller = _controller(persistence);
      await controller.start();
      controller
        ..markExerciseReviewed(0)
        ..markExerciseReviewed(1);

      expect(await controller.finish(), isTrue);

      expect(persistence.completedSessionIds, ['session-1']);
      expect(persistence.lastMetrics?.exercisesReviewed, 2);
      expect(persistence.lastMetrics?.toMap(), {'exercisesReviewed': 2});
      expect(controller.state, EmotionExecutionPersistenceState.completed);
    },
  );

  test('evita cierres duplicados durante el guardado', () async {
    final persistence = _FakeEmotionPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..markExerciseReviewed(0)
      ..markExerciseReviewed(1);

    final firstCompletion = controller.finish();
    final duplicateCompletion = controller.finish();

    expect(await duplicateCompletion, isFalse);
    expect(persistence.completeCalls, 1);
    pendingCompletion.complete();
    expect(await firstCompletion, isTrue);
    expect(persistence.completeCalls, 1);
  });

  test('reintenta el cierre con sesión y métrica conservadas', () async {
    final persistence = _FakeEmotionPersistence()..completeFailures = 1;
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..markExerciseReviewed(0)
      ..markExerciseReviewed(1);

    expect(await controller.finish(), isFalse);
    expect(
      controller.state,
      EmotionExecutionPersistenceState.completionFailure,
    );
    expect(await controller.retryCompletion(), isTrue);

    expect(persistence.startCalls, 1);
    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(persistence.metricsHistory[0].toMap(), {'exercisesReviewed': 2});
    expect(persistence.metricsHistory[1].toMap(), {'exercisesReviewed': 2});
  });

  test('confirma un cierre ambiguo antes de volver a escribir', () async {
    final persistence = _FakeEmotionPersistence()
      ..completeFailures = 1
      ..commitBeforeCompleteFailure = true;
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..markExerciseReviewed(0)
      ..markExerciseReviewed(1);

    expect(await controller.finish(), isTrue);
    expect(controller.state, EmotionExecutionPersistenceState.completed);
    expect(persistence.completeCalls, 1);
  });

  test('interrumpe sin crear un resultado', () async {
    final persistence = _FakeEmotionPersistence();
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.interrupt(), isTrue);
    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
    expect(controller.state, EmotionExecutionPersistenceState.interrupted);
  });

  test('una nueva ejecución usa otro sessionId y reinicia el conteo', () async {
    final persistence = _FakeEmotionPersistence();
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..markExerciseReviewed(0)
      ..markExerciseReviewed(1);
    await controller.finish();

    await controller.startNewExecution();

    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(controller.sessionId, 'session-2');
    expect(controller.exercisesReviewed, 0);
    expect(controller.state, EmotionExecutionPersistenceState.ready);
  });

  test('rechaza métricas Emotion sin ejercicios revisados', () {
    expect(
      () => EmotionExecutionMetrics(exercisesReviewed: 0),
      throwsArgumentError,
    );
  });
}

EmotionExecutionController _controller(
  EmotionExecutionPersistence persistence,
) {
  return EmotionExecutionController(
    activityId: 'activity-emotion',
    exercisesCount: 2,
    persistence: persistence,
  );
}

class _FakeEmotionPersistence implements EmotionExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  bool commitBeforeCompleteFailure = false;
  Completer<String>? pendingStart;
  Completer<void>? pendingCompletion;
  EmotionExecutionMetrics? lastMetrics;
  final List<EmotionExecutionMetrics> metricsHistory = [];
  final List<String> startedSessionIds = [];
  final List<String> completedSessionIds = [];
  final List<String> interruptedSessionIds = [];
  final Set<String> persistedCompletions = {};

  @override
  Future<String> startSession({required String activityId}) async {
    startCalls++;
    if (startFailures > 0) {
      startFailures--;
      throw StateError('start failure');
    }
    final pending = pendingStart;
    if (pending != null) {
      pendingStart = null;
      final id = await pending.future;
      startedSessionIds.add(id);
      return id;
    }
    final id = 'session-$startCalls';
    startedSessionIds.add(id);
    return id;
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required EmotionExecutionMetrics metrics,
  }) async {
    completeCalls++;
    completedSessionIds.add(sessionId);
    lastMetrics = metrics;
    metricsHistory.add(metrics);
    final pending = pendingCompletion;
    if (pending != null) {
      pendingCompletion = null;
      await pending.future;
    }
    if (completeFailures > 0) {
      completeFailures--;
      if (commitBeforeCompleteFailure) persistedCompletions.add(sessionId);
      throw StateError('complete failure');
    }
    persistedCompletions.add(sessionId);
  }

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    if (!persistedCompletions.contains(sessionId)) return null;
    return ActivityExecutionResultModel(
      id: sessionId,
      activityId: 'activity-emotion',
      therapyId: 'therapy-1',
      childId: 'child-1',
      psychologistId: 'psychologist-1',
      childUserId: 'child-user-1',
      activityType: ActivityType.emotion,
      completedAt: DateTime(2026),
      metrics: lastMetrics ?? EmotionExecutionMetrics(exercisesReviewed: 2),
    );
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    if (!persistedCompletions.contains(sessionId)) return null;
    return ActivityExecutionSessionModel(
      id: sessionId,
      activityId: 'activity-emotion',
      therapyId: 'therapy-1',
      childId: 'child-1',
      psychologistId: 'psychologist-1',
      childUserId: 'child-user-1',
      status: ActivityExecutionSessionStatus.completed,
      startedAt: DateTime(2026),
      endedAt: DateTime(2026, 1, 1, 0, 1),
    );
  }

  @override
  Future<void> interruptSession(String sessionId) async {
    interruptedSessionIds.add(sessionId);
  }
}
