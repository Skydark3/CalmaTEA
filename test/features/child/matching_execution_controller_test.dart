import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/matching_execution_controller.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  test('inicia una sola sesión ante llamadas simultáneas', () async {
    final persistence = _FakeMatchingPersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;
    final controller = _controller(persistence);

    final firstStart = controller.start();
    final secondStart = controller.start();
    expect(persistence.startCalls, 1);

    pendingStart.complete('session-1');
    await Future.wait([firstStart, secondStart]);

    expect(controller.sessionId, 'session-1');
    expect(controller.state, MatchingExecutionPersistenceState.ready);
  });

  test('permite reintentar un inicio fallido', () async {
    final persistence = _FakeMatchingPersistence()..startFailures = 1;
    final controller = _controller(persistence);

    await controller.start();
    expect(controller.state, MatchingExecutionPersistenceState.startFailure);

    await controller.start();
    expect(persistence.startCalls, 2);
    expect(controller.sessionId, 'session-2');
    expect(controller.state, MatchingExecutionPersistenceState.ready);
  });

  test('registra comprobaciones y relaciones completadas reales', () async {
    final persistence = _FakeMatchingPersistence();
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.recordCheck(relationsCompleted: 0), isFalse);
    expect(await controller.recordCheck(relationsCompleted: 1), isFalse);
    expect(await controller.recordCheck(relationsCompleted: 2), isTrue);

    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.relationsCompleted, 2);
    expect(persistence.lastMetrics?.checksCount, 3);
    expect(controller.state, MatchingExecutionPersistenceState.completed);
  });

  test(
    'evita cierres duplicados mientras el guardado está pendiente',
    () async {
      final persistence = _FakeMatchingPersistence();
      final pendingCompletion = Completer<void>();
      persistence.pendingCompletion = pendingCompletion;
      final controller = _controller(persistence);
      await controller.start();

      final firstCompletion = controller.recordCheck(relationsCompleted: 2);
      final duplicateCompletion = controller.recordCheck(relationsCompleted: 2);

      expect(await duplicateCompletion, isFalse);
      expect(persistence.completeCalls, 1);
      pendingCompletion.complete();
      expect(await firstCompletion, isTrue);
      expect(persistence.completeCalls, 1);
    },
  );

  test('reintenta el cierre fallido con la misma sesión y métricas', () async {
    final persistence = _FakeMatchingPersistence()..completeFailures = 1;
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.recordCheck(relationsCompleted: 2), isFalse);
    expect(
      controller.state,
      MatchingExecutionPersistenceState.completionFailure,
    );
    expect(await controller.retryCompletion(), isTrue);

    expect(persistence.startCalls, 1);
    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(
      persistence.metricsHistory[0].toMap(),
      persistence.metricsHistory[1].toMap(),
    );
  });

  test('confirma un cierre ambiguo antes de volver a escribir', () async {
    final persistence = _FakeMatchingPersistence()
      ..completeFailures = 1
      ..commitBeforeCompleteFailure = true;
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.recordCheck(relationsCompleted: 2), isTrue);
    expect(controller.state, MatchingExecutionPersistenceState.completed);
    expect(persistence.completeCalls, 1);
  });

  test('interrumpe voluntariamente sin crear un resultado', () async {
    final persistence = _FakeMatchingPersistence();
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.interrupt(), isTrue);
    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
    expect(controller.state, MatchingExecutionPersistenceState.interrupted);
  });

  test('una nueva ejecución obtiene otro sessionId', () async {
    final persistence = _FakeMatchingPersistence();
    final controller = _controller(persistence);
    await controller.start();
    await controller.recordCheck(relationsCompleted: 2);

    await controller.startNewExecution();

    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(controller.sessionId, 'session-2');
    expect(controller.checksCount, 0);
    expect(controller.state, MatchingExecutionPersistenceState.ready);
  });
}

MatchingExecutionController _controller(
  MatchingExecutionPersistence persistence,
) {
  return MatchingExecutionController(
    activityId: 'activity-matching',
    relationsCount: 2,
    persistence: persistence,
  );
}

class _FakeMatchingPersistence implements MatchingExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  bool commitBeforeCompleteFailure = false;
  Completer<String>? pendingStart;
  Completer<void>? pendingCompletion;
  MatchingExecutionMetrics? lastMetrics;
  final List<MatchingExecutionMetrics> metricsHistory = [];
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
    required MatchingExecutionMetrics metrics,
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
      activityId: 'activity-matching',
      therapyId: 'therapy-1',
      childId: 'child-1',
      psychologistId: 'psychologist-1',
      childUserId: 'child-user-1',
      activityType: ActivityType.matching,
      completedAt: DateTime(2026),
      metrics:
          lastMetrics ??
          MatchingExecutionMetrics(relationsCompleted: 2, checksCount: 1),
    );
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    if (!persistedCompletions.contains(sessionId)) return null;
    return ActivityExecutionSessionModel(
      id: sessionId,
      activityId: 'activity-matching',
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
