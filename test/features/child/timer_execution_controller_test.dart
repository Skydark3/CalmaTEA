import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/timer_execution_controller.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  test('inicia una sola sesión ante llamadas simultáneas', () async {
    final persistence = _FakeTimerPersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;
    final controller = _controller(persistence);

    final firstStart = controller.start();
    final secondStart = controller.start();
    expect(persistence.startCalls, 1);
    expect(await secondStart, isFalse);

    pendingStart.complete('session-1');
    expect(await firstStart, isTrue);
    expect(controller.sessionId, 'session-1');
    expect(controller.state, TimerExecutionPersistenceState.ready);
  });

  test('permite reintentar un inicio fallido', () async {
    final persistence = _FakeTimerPersistence()..startFailures = 1;
    final controller = _controller(persistence);

    expect(await controller.start(), isFalse);
    expect(controller.state, TimerExecutionPersistenceState.startFailure);

    expect(await controller.start(), isTrue);
    expect(persistence.startCalls, 2);
    expect(controller.sessionId, 'session-2');
  });

  test('finaliza con mismo sessionId y métricas temporales exactas', () async {
    final persistence = _FakeTimerPersistence();
    final controller = _controller(persistence);
    await controller.start();

    expect(
      await controller.finish(
        configuredDurationSeconds: 60,
        elapsedSeconds: 60,
      ),
      isTrue,
    );

    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.toMap(), {
      'configuredDurationSeconds': 60,
      'elapsedSeconds': 60,
    });
    expect(controller.state, TimerExecutionPersistenceState.completed);
  });

  test('evita cierres duplicados mientras guarda', () async {
    final persistence = _FakeTimerPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    final controller = _controller(persistence);
    await controller.start();

    final firstFinish = controller.finish(
      configuredDurationSeconds: 10,
      elapsedSeconds: 10,
    );
    final secondFinish = controller.finish(
      configuredDurationSeconds: 10,
      elapsedSeconds: 10,
    );
    expect(await secondFinish, isFalse);
    expect(persistence.completeCalls, 1);

    pendingCompletion.complete();
    expect(await firstFinish, isTrue);
    expect(persistence.completeCalls, 1);
  });

  test('reintenta cierre con sesión y métricas congeladas', () async {
    final persistence = _FakeTimerPersistence()..completeFailures = 1;
    final controller = _controller(persistence);
    await controller.start();

    expect(
      await controller.finish(
        configuredDurationSeconds: 30,
        elapsedSeconds: 30,
      ),
      isFalse,
    );
    expect(await controller.retryCompletion(), isTrue);

    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(controller.pendingMetrics?.toMap(), {
      'configuredDurationSeconds': 30,
      'elapsedSeconds': 30,
    });
  });

  test('confirma un cierre ambiguo antes de volver a escribir', () async {
    final persistence = _FakeTimerPersistence()
      ..completeFailures = 1
      ..persistBeforeFailure = true;
    final controller = _controller(persistence);
    await controller.start();

    expect(
      await controller.finish(configuredDurationSeconds: 5, elapsedSeconds: 5),
      isTrue,
    );
    expect(persistence.completeCalls, 1);
    expect(controller.state, TimerExecutionPersistenceState.completed);
  });

  test('interrumpe sin crear resultado', () async {
    final persistence = _FakeTimerPersistence();
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.interrupt(), isTrue);
    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
  });

  test('reintenta una interrupción fallida con la misma sesión', () async {
    final persistence = _FakeTimerPersistence()..interruptFailures = 1;
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.interrupt(), isFalse);
    expect(
      controller.state,
      TimerExecutionPersistenceState.interruptionFailure,
    );
    expect(await controller.interrupt(), isTrue);
    expect(persistence.interruptedSessionIds, ['session-1', 'session-1']);
  });

  test('prepara una nueva ejecución sin crearla anticipadamente', () async {
    final persistence = _FakeTimerPersistence();
    final controller = _controller(persistence);
    await controller.start();
    await controller.finish(configuredDurationSeconds: 5, elapsedSeconds: 5);

    controller.resetForNewExecution();
    expect(controller.state, TimerExecutionPersistenceState.idle);
    expect(controller.sessionId, isNull);
    expect(controller.pendingMetrics, isNull);
    expect(persistence.startCalls, 1);

    await controller.start();
    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
  });

  test('no finaliza ni interrumpe antes de iniciar sesión', () async {
    final persistence = _FakeTimerPersistence();
    final controller = _controller(persistence);

    expect(
      await controller.finish(configuredDurationSeconds: 5, elapsedSeconds: 5),
      isFalse,
    );
    expect(await controller.interrupt(), isFalse);
    expect(persistence.completeCalls, 0);
    expect(persistence.interruptedSessionIds, isEmpty);
  });

  test('rechaza IDs y métricas Timer inválidas', () {
    expect(
      () => TimerExecutionController(
        activityId: ' ',
        persistence: _FakeTimerPersistence(),
      ),
      throwsArgumentError,
    );
    expect(
      () => TimerExecutionMetrics(
        configuredDurationSeconds: 0,
        elapsedSeconds: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => TimerExecutionMetrics(
        configuredDurationSeconds: 5,
        elapsedSeconds: 0,
      ),
      throwsArgumentError,
    );
  });
}

TimerExecutionController _controller(TimerExecutionPersistence persistence) {
  return TimerExecutionController(
    activityId: 'activity-timer',
    persistence: persistence,
  );
}

class _FakeTimerPersistence implements TimerExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  int interruptFailures = 0;
  bool persistBeforeFailure = false;
  Completer<String>? pendingStart;
  Completer<void>? pendingCompletion;
  TimerExecutionMetrics? lastMetrics;
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
    required TimerExecutionMetrics metrics,
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
      activityId: 'activity-timer',
      therapyId: 'therapy-1',
      childId: 'child-1',
      psychologistId: 'psychologist-1',
      childUserId: 'child-user-1',
      activityType: ActivityType.timer,
      completedAt: DateTime(2026),
      metrics:
          lastMetrics ??
          TimerExecutionMetrics(
            configuredDurationSeconds: 5,
            elapsedSeconds: 5,
          ),
    );
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    if (!persistedCompletions.contains(sessionId)) return null;
    return ActivityExecutionSessionModel(
      id: sessionId,
      activityId: 'activity-timer',
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
    if (interruptFailures > 0) {
      interruptFailures--;
      throw StateError('interrupt failure');
    }
  }
}
