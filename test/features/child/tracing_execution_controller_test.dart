import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/tracing_execution_controller.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  test('inicia una sola sesión ante llamadas simultáneas', () async {
    final persistence = _FakeTracingPersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;
    final controller = _controller(persistence);

    final firstStart = controller.start();
    final secondStart = controller.start();
    expect(persistence.startCalls, 1);

    pendingStart.complete('session-1');
    await Future.wait([firstStart, secondStart]);

    expect(controller.sessionId, 'session-1');
    expect(controller.strokesCount, 0);
    expect(controller.state, TracingExecutionPersistenceState.ready);
  });

  test('permite reintentar un inicio fallido', () async {
    final persistence = _FakeTracingPersistence()..startFailures = 1;
    final controller = _controller(persistence);

    await controller.start();
    expect(controller.state, TracingExecutionPersistenceState.startFailure);

    await controller.start();
    expect(persistence.startCalls, 2);
    expect(controller.sessionId, 'session-2');
  });

  test('solo eventos finalizados incrementan la métrica agregada', () async {
    final controller = _controller(_FakeTracingPersistence());
    await controller.start();

    expect(controller.strokesCount, 0);
    controller
      ..recordCompletedStroke()
      ..recordCompletedStroke();

    expect(controller.strokesCount, 2);
  });

  test('ignora eventos fuera de una sesión lista', () {
    final controller = _controller(_FakeTracingPersistence());

    controller.recordCompletedStroke();

    expect(controller.strokesCount, 0);
  });

  test('no finaliza sin un trazo contabilizable', () async {
    final persistence = _FakeTracingPersistence();
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.finish(), isFalse);
    expect(persistence.completeCalls, 0);
  });

  test('finaliza con mismo sessionId y métricas permitidas', () async {
    final persistence = _FakeTracingPersistence();
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..recordCompletedStroke()
      ..recordCompletedStroke();

    expect(await controller.finish(), isTrue);

    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.toMap(), {
      'practiceCompleted': true,
      'strokesCount': 2,
    });
    expect(persistence.lastMetrics?.toMap().keys, {
      'practiceCompleted',
      'strokesCount',
    });
    expect(controller.state, TracingExecutionPersistenceState.completed);
  });

  test('evita cierres duplicados mientras guarda', () async {
    final persistence = _FakeTracingPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    final controller = _controller(persistence);
    await controller.start();
    controller.recordCompletedStroke();

    final firstFinish = controller.finish();
    final secondFinish = controller.finish();
    expect(await secondFinish, isFalse);
    expect(persistence.completeCalls, 1);

    pendingCompletion.complete();
    expect(await firstFinish, isTrue);
    expect(persistence.completeCalls, 1);
  });

  test('reintenta cierre con sesión y métricas conservadas', () async {
    final persistence = _FakeTracingPersistence()..completeFailures = 1;
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..recordCompletedStroke()
      ..recordCompletedStroke();

    expect(await controller.finish(), isFalse);
    expect(await controller.retryCompletion(), isTrue);

    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(persistence.lastMetrics?.strokesCount, 2);
  });

  test('confirma un cierre ambiguo antes de volver a escribir', () async {
    final persistence = _FakeTracingPersistence()
      ..completeFailures = 1
      ..persistBeforeFailure = true;
    final controller = _controller(persistence);
    await controller.start();
    controller.recordCompletedStroke();

    expect(await controller.finish(), isTrue);
    expect(persistence.completeCalls, 1);
    expect(controller.state, TracingExecutionPersistenceState.completed);
  });

  test('interrumpe sin crear un resultado', () async {
    final persistence = _FakeTracingPersistence();
    final controller = _controller(persistence);
    await controller.start();
    controller.recordCompletedStroke();

    expect(await controller.interrupt(), isTrue);
    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
  });

  test('nueva ejecución usa otro sessionId y reinicia conteo', () async {
    final persistence = _FakeTracingPersistence();
    final controller = _controller(persistence);
    await controller.start();
    controller.recordCompletedStroke();
    await controller.finish();

    await controller.startNewExecution();

    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(controller.sessionId, 'session-2');
    expect(controller.strokesCount, 0);
  });

  test('rechaza IDs y métricas Tracing inválidas', () {
    expect(
      () => TracingExecutionController(
        activityId: ' ',
        persistence: _FakeTracingPersistence(),
      ),
      throwsArgumentError,
    );
    expect(
      () => TracingExecutionMetrics(practiceCompleted: false, strokesCount: 1),
      throwsArgumentError,
    );
    expect(
      () => TracingExecutionMetrics(practiceCompleted: true, strokesCount: 0),
      throwsArgumentError,
    );
  });
}

TracingExecutionController _controller(
  TracingExecutionPersistence persistence,
) {
  return TracingExecutionController(
    activityId: 'activity-tracing',
    persistence: persistence,
  );
}

class _FakeTracingPersistence implements TracingExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  bool persistBeforeFailure = false;
  Completer<String>? pendingStart;
  Completer<void>? pendingCompletion;
  TracingExecutionMetrics? lastMetrics;
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
    final id = pending == null ? 'session-$startCalls' : await pending.future;
    pendingStart = null;
    startedSessionIds.add(id);
    return id;
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required TracingExecutionMetrics metrics,
  }) async {
    completeCalls++;
    completedSessionIds.add(sessionId);
    lastMetrics = metrics;
    final pending = pendingCompletion;
    if (pending != null) {
      pendingCompletion = null;
      await pending.future;
    }
    if (completeFailures > 0) {
      completeFailures--;
      if (persistBeforeFailure) persistedCompletions.add(sessionId);
      throw StateError('complete failure');
    }
    persistedCompletions.add(sessionId);
  }

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    if (!persistedCompletions.contains(sessionId)) return null;
    return ActivityExecutionResultModel(
      id: sessionId,
      activityId: 'activity-tracing',
      therapyId: 'therapy-1',
      childId: 'child-1',
      psychologistId: 'psychologist-1',
      childUserId: 'child-user-1',
      activityType: ActivityType.tracing,
      completedAt: DateTime(2026),
      metrics:
          lastMetrics ??
          TracingExecutionMetrics(practiceCompleted: true, strokesCount: 1),
    );
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    if (!persistedCompletions.contains(sessionId)) return null;
    return ActivityExecutionSessionModel(
      id: sessionId,
      activityId: 'activity-tracing',
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
