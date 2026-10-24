import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/pictogram_execution_controller.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  test('inicia una sola sesión ante llamadas simultáneas', () async {
    final persistence = _FakePictogramPersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;
    final controller = _controller(persistence);

    final firstStart = controller.start();
    final secondStart = controller.start();
    expect(persistence.startCalls, 1);

    pendingStart.complete('session-1');
    await Future.wait([firstStart, secondStart]);

    expect(controller.sessionId, 'session-1');
    expect(controller.interactionsCount, 0);
    expect(controller.state, PictogramExecutionPersistenceState.ready);
  });

  test('permite reintentar un inicio fallido', () async {
    final persistence = _FakePictogramPersistence()..startFailures = 1;
    final controller = _controller(persistence);

    await controller.start();
    expect(controller.state, PictogramExecutionPersistenceState.startFailure);

    await controller.start();
    expect(persistence.startCalls, 2);
    expect(controller.sessionId, 'session-2');
  });

  test(
    'mostrar opciones o notificar listeners no cuenta interacciones',
    () async {
      final controller = _controller(_FakePictogramPersistence());
      await controller.start();

      expect(controller.interactionsCount, 0);
    },
  );

  test('cada selección deliberada cuenta una interacción', () async {
    final controller = _controller(_FakePictogramPersistence());
    await controller.start();

    controller
      ..recordInteraction()
      ..recordInteraction()
      ..recordInteraction();

    expect(controller.interactionsCount, 3);
  });

  test('no finaliza si no existieron interacciones', () async {
    final persistence = _FakePictogramPersistence();
    final controller = _controller(persistence);
    await controller.start();

    expect(await controller.finish(), isFalse);
    expect(persistence.completeCalls, 0);
  });

  test('finaliza con mismo sessionId y conteo agregado', () async {
    final persistence = _FakePictogramPersistence();
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..recordInteraction()
      ..recordInteraction();

    expect(await controller.finish(), isTrue);

    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.toMap(), {'interactionsCount': 2});
    expect(controller.state, PictogramExecutionPersistenceState.completed);
  });

  test('evita cierres duplicados durante el guardado', () async {
    final persistence = _FakePictogramPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    final controller = _controller(persistence);
    await controller.start();
    controller.recordInteraction();

    final firstFinish = controller.finish();
    final secondFinish = controller.finish();
    expect(await secondFinish, isFalse);
    expect(persistence.completeCalls, 1);

    pendingCompletion.complete();
    expect(await firstFinish, isTrue);
    expect(persistence.completeCalls, 1);
  });

  test('reintenta el cierre con sesión y métrica conservadas', () async {
    final persistence = _FakePictogramPersistence()..completeFailures = 1;
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..recordInteraction()
      ..recordInteraction();

    expect(await controller.finish(), isFalse);
    expect(await controller.retryCompletion(), isTrue);

    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(persistence.lastMetrics?.toMap(), {'interactionsCount': 2});
  });

  test('confirma un cierre ambiguo antes de volver a escribir', () async {
    final persistence = _FakePictogramPersistence()
      ..completeFailures = 1
      ..persistBeforeFailure = true;
    final controller = _controller(persistence);
    await controller.start();
    controller.recordInteraction();

    expect(await controller.finish(), isTrue);
    expect(persistence.completeCalls, 1);
    expect(controller.state, PictogramExecutionPersistenceState.completed);
  });

  test('interrumpe sin crear un resultado', () async {
    final persistence = _FakePictogramPersistence();
    final controller = _controller(persistence);
    await controller.start();
    controller.recordInteraction();

    expect(await controller.interrupt(), isTrue);
    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
  });

  test('una nueva ejecución usa otro sessionId y reinicia el conteo', () async {
    final persistence = _FakePictogramPersistence();
    final controller = _controller(persistence);
    await controller.start();
    controller.recordInteraction();
    await controller.finish();

    await controller.startNewExecution();

    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(controller.sessionId, 'session-2');
    expect(controller.interactionsCount, 0);
  });

  test('rechaza IDs y métricas Pictogram inválidas', () {
    expect(
      () => PictogramExecutionController(
        activityId: ' ',
        persistence: _FakePictogramPersistence(),
      ),
      throwsArgumentError,
    );
    expect(
      () => PictogramExecutionMetrics(interactionsCount: 0),
      throwsArgumentError,
    );
  });
}

PictogramExecutionController _controller(
  PictogramExecutionPersistence persistence,
) {
  return PictogramExecutionController(
    activityId: 'activity-pictogram',
    persistence: persistence,
  );
}

class _FakePictogramPersistence implements PictogramExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  bool persistBeforeFailure = false;
  Completer<String>? pendingStart;
  Completer<void>? pendingCompletion;
  PictogramExecutionMetrics? lastMetrics;
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
    required PictogramExecutionMetrics metrics,
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
      activityId: 'activity-pictogram',
      therapyId: 'therapy-1',
      childId: 'child-1',
      psychologistId: 'psychologist-1',
      childUserId: 'child-user-1',
      activityType: ActivityType.pictogram,
      completedAt: DateTime(2026),
      metrics: lastMetrics ?? PictogramExecutionMetrics(interactionsCount: 1),
    );
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    if (!persistedCompletions.contains(sessionId)) return null;
    return ActivityExecutionSessionModel(
      id: sessionId,
      activityId: 'activity-pictogram',
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
