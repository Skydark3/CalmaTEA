import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/activities/execution/activity_execution_router.dart';
import 'package:tea_app/features/child/activities/child_activities_screen.dart';
import 'package:tea_app/models/activity_model.dart';
import 'package:tea_app/services/activity_execution_session_service.dart';

void main() {
  final activity = ActivityModel(
    id: 'activity-new',
    therapyId: 'therapy-id',
    childId: 'child-id',
    psychologistId: 'psychologist-id',
    title: 'Actividad nueva',
    description: '',
    type: ActivityType.sequence,
    difficulty: 1,
    instructions: '',
    configuration: const SequenceActivityConfig(
      items: [SequenceItemConfig(id: 'step-1', label: 'Paso', order: 0)],
    ).toMap(),
    status: ActivityStatus.assigned,
    createdAt: DateTime(2026),
  );

  Widget subject({
    required ActivityExecutionMode mode,
    required _CoordinatorFake coordinator,
    required VoidCallback onOpen,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ChildActivitiesScreen(
          activitiesStream: Stream.value([activity]),
          sessionCoordinator: coordinator,
          executionRouter: ActivityExecutionRouter(
            mode: mode,
            handlers: {ActivityType.sequence: (_, _, _) async => onOpen()},
          ),
        ),
      ),
    );
  }

  testWidgets('cancela el cierre anterior sin interrumpir ni abrir', (
    tester,
  ) async {
    var opened = false;
    final coordinator = _CoordinatorFake(
      conflict: const ActiveExecutionSessionConflict(
        sessionId: 'session-old',
        activityId: 'activity-old',
        canInterrupt: true,
      ),
    );
    await tester.pumpWidget(
      subject(
        mode: ActivityExecutionMode.persistent,
        coordinator: coordinator,
        onOpen: () => opened = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();
    expect(find.text('Actividad en curso'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(coordinator.startCalls, 1);
    expect(coordinator.interruptedSessionIds, isEmpty);
    expect(opened, isFalse);
  });

  testWidgets('confirmar interrumpe, adquiere el nuevo bloqueo y abre', (
    tester,
  ) async {
    var opened = false;
    final coordinator = _CoordinatorFake(
      conflict: const ActiveExecutionSessionConflict(
        sessionId: 'session-old',
        activityId: 'activity-old',
        canInterrupt: true,
      ),
    );
    await tester.pumpWidget(
      subject(
        mode: ActivityExecutionMode.persistent,
        coordinator: coordinator,
        onOpen: () => opened = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interrumpir y continuar'));
    await tester.pumpAndSettle();

    expect(coordinator.startCalls, 2);
    expect(coordinator.interruptedSessionIds, ['session-old']);
    expect(opened, isTrue);
  });

  testWidgets('una cuenta distinta no puede interrumpir el bloqueo', (
    tester,
  ) async {
    var opened = false;
    final coordinator = _CoordinatorFake(
      conflict: const ActiveExecutionSessionConflict(
        sessionId: 'session-other-account',
        activityId: 'activity-old',
        canInterrupt: false,
      ),
    );
    await tester.pumpWidget(
      subject(
        mode: ActivityExecutionMode.persistent,
        coordinator: coordinator,
        onOpen: () => opened = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no puede cerrarse'), findsOneWidget);
    expect(coordinator.interruptedSessionIds, isEmpty);
    expect(opened, isFalse);
  });

  testWidgets('Preview abre sin adquirir ni liberar bloqueos', (tester) async {
    var opened = false;
    final coordinator = _CoordinatorFake();
    await tester.pumpWidget(
      subject(
        mode: ActivityExecutionMode.preview,
        coordinator: coordinator,
        onOpen: () => opened = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Probar actividad'));
    await tester.pumpAndSettle();

    expect(coordinator.startCalls, 0);
    expect(coordinator.interruptedSessionIds, isEmpty);
    expect(opened, isTrue);
  });
}

class _CoordinatorFake implements ActiveExecutionSessionCoordinator {
  final ActiveExecutionSessionConflict? conflict;
  int startCalls = 0;
  final List<String> interruptedSessionIds = [];

  _CoordinatorFake({this.conflict});

  @override
  Future<String> startSession({required String activityId}) async {
    startCalls += 1;
    if (startCalls == 1 && conflict != null) throw conflict!;
    return 'session-new';
  }

  @override
  Future<void> interruptSession(String sessionId) async {
    interruptedSessionIds.add(sessionId);
  }
}
