import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/drag_drop_execution_controller.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  test('inicia una sola sesión ante llamadas simultáneas', () async {
    final persistence = _FakeDragDropPersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;
    final controller = _controller(persistence);

    final firstStart = controller.start();
    final secondStart = controller.start();
    expect(persistence.startCalls, 1);

    pendingStart.complete('session-1');
    await Future.wait([firstStart, secondStart]);

    expect(controller.sessionId, 'session-1');
    expect(controller.state, DragDropExecutionPersistenceState.ready);
  });

  test('permite reintentar un inicio fallido', () async {
    final persistence = _FakeDragDropPersistence()..startFailures = 1;
    final controller = _controller(persistence);

    await controller.start();
    expect(controller.state, DragDropExecutionPersistenceState.startFailure);

    await controller.start();
    expect(persistence.startCalls, 2);
    expect(controller.sessionId, 'session-2');
  });

  test('cuenta cada comprobación real, correcta o incorrecta', () async {
    final controller = _controller(_FakeDragDropPersistence());
    await controller.start();

    expect(
      controller.registerCheck(itemId: 'apple', isCorrect: false),
      isFalse,
    );
    expect(controller.registerCheck(itemId: 'apple', isCorrect: true), isTrue);

    expect(controller.itemsPlaced, 1);
    expect(controller.checksCount, 2);
  });

  test('una colocación correcta repetida no duplica el elemento', () async {
    final controller = _controller(_FakeDragDropPersistence());
    await controller.start();

    expect(controller.registerCheck(itemId: 'apple', isCorrect: true), isTrue);
    expect(controller.registerCheck(itemId: 'apple', isCorrect: true), isFalse);

    expect(controller.itemsPlaced, 1);
    expect(controller.checksCount, 1);
  });

  test('rechaza elementos desconocidos y no finaliza incompleto', () async {
    final persistence = _FakeDragDropPersistence();
    final controller = _controller(persistence);
    await controller.start();

    expect(
      () => controller.registerCheck(itemId: 'unknown', isCorrect: true),
      throwsArgumentError,
    );
    controller.registerCheck(itemId: 'apple', isCorrect: true);
    expect(await controller.finish(), isFalse);
    expect(persistence.completeCalls, 0);
  });

  test('finaliza con el mismo sessionId y métricas agregadas reales', () async {
    final persistence = _FakeDragDropPersistence();
    final controller = _controller(persistence);
    await controller.start();
    controller
      ..registerCheck(itemId: 'apple', isCorrect: false)
      ..registerCheck(itemId: 'apple', isCorrect: true)
      ..registerCheck(itemId: 'carrot', isCorrect: true);

    expect(await controller.finish(), isTrue);

    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.toMap(), {
      'itemsPlaced': 2,
      'checksCount': 3,
    });
    expect(controller.state, DragDropExecutionPersistenceState.completed);
  });

  test('evita cierres duplicados durante el guardado', () async {
    final persistence = _FakeDragDropPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    final controller = _controller(persistence);
    await controller.start();
    _completeItems(controller);

    final firstFinish = controller.finish();
    final secondFinish = controller.finish();
    expect(await secondFinish, isFalse);
    expect(persistence.completeCalls, 1);

    pendingCompletion.complete();
    expect(await firstFinish, isTrue);
    expect(persistence.completeCalls, 1);
  });

  test('reintenta el cierre con sesión y métricas conservadas', () async {
    final persistence = _FakeDragDropPersistence()..completeFailures = 1;
    final controller = _controller(persistence);
    await controller.start();
    _completeItems(controller);

    expect(await controller.finish(), isFalse);
    expect(await controller.retryCompletion(), isTrue);

    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(persistence.lastMetrics?.toMap(), {
      'itemsPlaced': 2,
      'checksCount': 2,
    });
  });

  test('confirma un cierre ambiguo antes de volver a escribir', () async {
    final persistence = _FakeDragDropPersistence()
      ..completeFailures = 1
      ..persistBeforeFailure = true;
    final controller = _controller(persistence);
    await controller.start();
    _completeItems(controller);

    expect(await controller.finish(), isTrue);
    expect(persistence.completeCalls, 1);
    expect(controller.state, DragDropExecutionPersistenceState.completed);
  });

  test('interrumpe la sesión sin crear un resultado', () async {
    final persistence = _FakeDragDropPersistence();
    final controller = _controller(persistence);
    await controller.start();
    controller.registerCheck(itemId: 'apple', isCorrect: false);

    expect(await controller.interrupt(), isTrue);
    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
  });

  test('una nueva ejecución usa otro sessionId y reinicia métricas', () async {
    final persistence = _FakeDragDropPersistence();
    final controller = _controller(persistence);
    await controller.start();
    _completeItems(controller);
    await controller.finish();

    await controller.startNewExecution();

    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(controller.sessionId, 'session-2');
    expect(controller.itemsPlaced, 0);
    expect(controller.checksCount, 0);
  });

  test('rechaza configuración y métricas DragDrop inválidas', () {
    expect(
      () => DragDropExecutionController(
        activityId: 'activity-drag-drop',
        itemIds: const <String>[],
        persistence: _FakeDragDropPersistence(),
      ),
      throwsArgumentError,
    );
    expect(
      () => DragDropExecutionMetrics(itemsPlaced: 0, checksCount: 1),
      throwsArgumentError,
    );
    expect(
      () => DragDropExecutionMetrics(itemsPlaced: 1, checksCount: 0),
      throwsArgumentError,
    );
  });
}

DragDropExecutionController _controller(
  DragDropExecutionPersistence persistence,
) {
  return DragDropExecutionController(
    activityId: 'activity-drag-drop',
    itemIds: const ['apple', 'carrot'],
    persistence: persistence,
  );
}

void _completeItems(DragDropExecutionController controller) {
  controller
    ..registerCheck(itemId: 'apple', isCorrect: true)
    ..registerCheck(itemId: 'carrot', isCorrect: true);
}

class _FakeDragDropPersistence implements DragDropExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  bool persistBeforeFailure = false;
  Completer<String>? pendingStart;
  Completer<void>? pendingCompletion;
  DragDropExecutionMetrics? lastMetrics;
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
    required DragDropExecutionMetrics metrics,
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
      activityId: 'activity-drag-drop',
      therapyId: 'therapy-1',
      childId: 'child-1',
      psychologistId: 'psychologist-1',
      childUserId: 'child-user-1',
      activityType: ActivityType.dragDrop,
      completedAt: DateTime(2026),
      metrics:
          lastMetrics ??
          DragDropExecutionMetrics(itemsPlaced: 2, checksCount: 2),
    );
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    if (!persistedCompletions.contains(sessionId)) return null;
    return ActivityExecutionSessionModel(
      id: sessionId,
      activityId: 'activity-drag-drop',
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
