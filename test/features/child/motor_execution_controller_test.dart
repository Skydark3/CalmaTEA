import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/motor_execution_controller.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  test('inicia una sola sesión ante llamadas simultáneas', () async {
    final persistence = _FakeMotorPersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;
    final controller = _controller(persistence);

    final firstStart = controller.start();
    final secondStart = controller.start();
    expect(persistence.startCalls, 1);

    pendingStart.complete('session-1');
    await Future.wait([firstStart, secondStart]);

    expect(controller.sessionId, 'session-1');
    expect(controller.stepsVisited, 1);
    expect(controller.state, MotorExecutionPersistenceState.ready);
  });

  test('permite reintentar un inicio fallido', () async {
    final persistence = _FakeMotorPersistence()..startFailures = 1;
    final controller = _controller(persistence);

    await controller.start();
    expect(controller.state, MotorExecutionPersistenceState.startFailure);

    await controller.start();
    expect(persistence.startCalls, 2);
    expect(controller.sessionId, 'session-2');
    expect(controller.state, MotorExecutionPersistenceState.ready);
  });

  test('cuenta pasos distintos mostrados sin duplicar revisitas', () async {
    final persistence = _FakeMotorPersistence();
    final controller = _controller(persistence);
    await controller.start();

    controller.visitStep(1);
    controller.visitStep(0);
    controller.visitStep(1);
    controller.visitStep(2);

    expect(controller.stepsVisited, 3);
  });

  test(
    'rechaza índices inválidos y no finaliza antes de visitar todo',
    () async {
      final persistence = _FakeMotorPersistence();
      final controller = _controller(persistence);
      await controller.start();

      expect(() => controller.visitStep(3), throwsRangeError);
      expect(await controller.finish(), isFalse);
      expect(persistence.completeCalls, 0);
    },
  );

  test('finaliza con el mismo sessionId y stepsVisited reales', () async {
    final persistence = _FakeMotorPersistence();
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..visitStep(1)
      ..visitStep(2);

    expect(await controller.finish(), isTrue);

    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.stepsVisited, 3);
    expect(controller.state, MotorExecutionPersistenceState.completed);
  });

  test(
    'evita cierres duplicados mientras el guardado está pendiente',
    () async {
      final persistence = _FakeMotorPersistence();
      final pendingCompletion = Completer<void>();
      persistence.pendingCompletion = pendingCompletion;
      final controller = _controller(persistence);
      await controller.start();
      controller
        ..visitStep(1)
        ..visitStep(2);

      final firstCompletion = controller.finish();
      final duplicateCompletion = controller.finish();

      expect(await duplicateCompletion, isFalse);
      expect(persistence.completeCalls, 1);
      pendingCompletion.complete();
      expect(await firstCompletion, isTrue);
      expect(persistence.completeCalls, 1);
    },
  );

  test(
    'reintenta el cierre fallido con sesión y métricas conservadas',
    () async {
      final persistence = _FakeMotorPersistence()..completeFailures = 1;
      final controller = _controller(persistence);
      await controller.start();
      controller
        ..visitStep(1)
        ..visitStep(2);

      expect(await controller.finish(), isFalse);
      expect(
        controller.state,
        MotorExecutionPersistenceState.completionFailure,
      );
      expect(await controller.retryCompletion(), isTrue);

      expect(persistence.startCalls, 1);
      expect(persistence.completedSessionIds, ['session-1', 'session-1']);
      expect(persistence.metricsHistory[0].stepsVisited, 3);
      expect(persistence.metricsHistory[1].stepsVisited, 3);
    },
  );

  test('confirma un cierre ambiguo antes de volver a escribir', () async {
    final persistence = _FakeMotorPersistence()
      ..completeFailures = 1
      ..commitBeforeCompleteFailure = true;
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..visitStep(1)
      ..visitStep(2);

    expect(await controller.finish(), isTrue);
    expect(controller.state, MotorExecutionPersistenceState.completed);
    expect(persistence.completeCalls, 1);
  });

  test('interrumpe sin crear resultado', () async {
    final persistence = _FakeMotorPersistence();
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.interrupt(), isTrue);
    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
    expect(controller.state, MotorExecutionPersistenceState.interrupted);
  });

  test(
    'una nueva ejecución obtiene otro sessionId y reinicia visitas',
    () async {
      final persistence = _FakeMotorPersistence();
      final controller = _controller(persistence);
      await controller.start();
      controller
        ..visitStep(1)
        ..visitStep(2);
      await controller.finish();

      await controller.startNewExecution();

      expect(persistence.startedSessionIds, ['session-1', 'session-2']);
      expect(controller.sessionId, 'session-2');
      expect(controller.stepsVisited, 1);
      expect(controller.state, MotorExecutionPersistenceState.ready);
    },
  );
}

MotorExecutionController _controller(MotorExecutionPersistence persistence) {
  return MotorExecutionController(
    activityId: 'activity-motor',
    stepsCount: 3,
    persistence: persistence,
  );
}

class _FakeMotorPersistence implements MotorExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  bool commitBeforeCompleteFailure = false;
  Completer<String>? pendingStart;
  Completer<void>? pendingCompletion;
  MotorExecutionMetrics? lastMetrics;
  final List<MotorExecutionMetrics> metricsHistory = [];
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
    required MotorExecutionMetrics metrics,
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
      activityId: 'activity-motor',
      therapyId: 'therapy-1',
      childId: 'child-1',
      psychologistId: 'psychologist-1',
      childUserId: 'child-user-1',
      activityType: ActivityType.motor,
      completedAt: DateTime(2026),
      metrics: lastMetrics ?? MotorExecutionMetrics(stepsVisited: 3),
    );
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    if (!persistedCompletions.contains(sessionId)) return null;
    return ActivityExecutionSessionModel(
      id: sessionId,
      activityId: 'activity-motor',
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
