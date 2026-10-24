import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/sequence_execution_controller.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  test('inicia una sola sesion ante llamadas simultaneas', () async {
    final persistence = _FakeSequencePersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;
    final controller = _controller(persistence);

    final firstStart = controller.start();
    final secondStart = controller.start();
    expect(persistence.startCalls, 1);

    pendingStart.complete('session-1');
    await Future.wait([firstStart, secondStart]);

    expect(controller.sessionId, 'session-1');
    expect(controller.state, SequenceExecutionPersistenceState.ready);
  });

  test('permite reintentar un inicio fallido sin dobles pulsaciones', () async {
    final persistence = _FakeSequencePersistence()..startFailures = 1;
    final controller = _controller(persistence);

    await controller.start();
    expect(controller.state, SequenceExecutionPersistenceState.startFailure);

    await controller.start();
    expect(persistence.startCalls, 2);
    expect(controller.sessionId, 'session-2');
    expect(controller.state, SequenceExecutionPersistenceState.ready);
  });

  test(
    'finaliza con el mismo sessionId y metricas reales de Sequence',
    () async {
      final persistence = _FakeSequencePersistence();
      final controller = _controller(persistence);
      await controller.start();

      expect(await controller.checkOrder(isCorrect: false), isFalse);
      expect(await controller.checkOrder(isCorrect: true), isTrue);

      expect(persistence.completedSessionIds, ['session-1']);
      expect(persistence.lastMetrics?.itemsCount, 3);
      expect(persistence.lastMetrics?.checksCount, 2);
      expect(controller.state, SequenceExecutionPersistenceState.completed);
    },
  );

  test('reintenta el cierre fallido sin crear una sesion nueva', () async {
    final persistence = _FakeSequencePersistence()..completeFailures = 1;
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.checkOrder(isCorrect: true), isFalse);
    expect(
      controller.state,
      SequenceExecutionPersistenceState.completionFailure,
    );
    expect(await controller.retryCompletion(), isTrue);

    expect(persistence.startCalls, 1);
    expect(persistence.completeCalls, 2);
    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
  });

  test('confirma un cierre ambiguo antes de volver a escribir', () async {
    final persistence = _FakeSequencePersistence()
      ..completeFailures = 1
      ..commitBeforeCompleteFailure = true;
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.checkOrder(isCorrect: true), isTrue);
    expect(controller.state, SequenceExecutionPersistenceState.completed);
    expect(persistence.completeCalls, 1);
  });

  test('interrumpe voluntariamente sin crear resultado', () async {
    final persistence = _FakeSequencePersistence();
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.interrupt(), isTrue);
    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
    expect(controller.state, SequenceExecutionPersistenceState.interrupted);
  });

  test('una repeticion crea otro sessionId y conserva el anterior', () async {
    final persistence = _FakeSequencePersistence();
    final controller = _controller(persistence);
    await controller.start();
    await controller.checkOrder(isCorrect: true);

    await controller.startNewExecution();

    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(controller.sessionId, 'session-2');
    expect(controller.checksCount, 0);
    expect(controller.state, SequenceExecutionPersistenceState.ready);
  });
}

SequenceExecutionController _controller(
  SequenceExecutionPersistence persistence,
) {
  return SequenceExecutionController(
    activityId: 'activity-sequence',
    itemsCount: 3,
    persistence: persistence,
  );
}

class _FakeSequencePersistence implements SequenceExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  bool commitBeforeCompleteFailure = false;
  Completer<String>? pendingStart;
  SequenceExecutionMetrics? lastMetrics;
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
    required SequenceExecutionMetrics metrics,
  }) async {
    completeCalls++;
    completedSessionIds.add(sessionId);
    lastMetrics = metrics;
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
      activityId: 'activity-sequence',
      therapyId: 'therapy-1',
      childId: 'child-1',
      psychologistId: 'psychologist-1',
      childUserId: 'child-user-1',
      activityType: ActivityType.sequence,
      completedAt: DateTime(2026),
      metrics:
          lastMetrics ??
          SequenceExecutionMetrics(itemsCount: 3, checksCount: 1),
    );
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    if (!persistedCompletions.contains(sessionId)) return null;
    return ActivityExecutionSessionModel(
      id: sessionId,
      activityId: 'activity-sequence',
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
