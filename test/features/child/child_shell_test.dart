import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/child_shell.dart';
import 'package:tea_app/features/activities/execution/activity_execution_router.dart';
import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/drag_drop_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/drag_drop_execution_screen.dart';
import 'package:tea_app/features/child/activities/execution/emotion_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/emotion_execution_screen.dart';
import 'package:tea_app/features/child/activities/execution/matching_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/matching_execution_screen.dart';
import 'package:tea_app/features/child/activities/execution/motor_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/motor_execution_screen.dart';
import 'package:tea_app/features/child/activities/execution/pictogram_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/pictogram_execution_screen.dart';
import 'package:tea_app/features/child/activities/execution/sequence_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/sequence_execution_screen.dart';
import 'package:tea_app/features/child/activities/execution/timer_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/timer_execution_screen.dart';
import 'package:tea_app/features/child/activities/execution/tracing_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/tracing_execution_screen.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';
import 'package:tea_app/models/user_model.dart';

void main() {
  final childUser = UserModel(
    id: 'child-auth-uid',
    name: 'Alex',
    email: 'alex@example.com',
    role: UserRole.child,
    childId: 'child-document-id',
    createdAt: DateTime(2026),
  );

  Widget buildSubject({Future<void> Function()? onSignOut}) {
    return MaterialApp(
      home: ChildShell(
        user: childUser,
        activitiesStream: Stream.value(const []),
        onSignOut: onSignOut ?? () async {},
      ),
    );
  }

  testWidgets('muestra el saludo y abre la pestaña de actividades', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Hola, Alex'), findsOneWidget);
    expect(find.text('¿Listo para comenzar?'), findsOneWidget);

    await tester.tap(find.text('Ir a mis actividades'));
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía no hay actividades disponibles.'),
      findsOneWidget,
    );
  });

  testWidgets('el perfil muestra solo datos básicos y permite cerrar sesión', (
    tester,
  ) async {
    var signOutCalled = false;
    await tester.pumpWidget(
      buildSubject(onSignOut: () async => signOutCalled = true),
    );

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);
    expect(find.text('Paciente'), findsOneWidget);
    expect(find.text('child-document-id'), findsNothing);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();

    expect(signOutCalled, isTrue);
  });

  testWidgets('flags por defecto no abren motores ni ruta de persistencia', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'activity-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Actividad protegida',
      description: '',
      type: ActivityType.sequence,
      difficulty: 1,
      instructions: '',
      configuration: const SequenceActivityConfig(
        items: [SequenceItemConfig(id: 's1', label: 'Paso', order: 0)],
      ).toMap(),
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Esta actividad estará disponible próximamente.'),
      findsOneWidget,
    );
    expect(find.text('Comprobar'), findsNothing);
  });

  testWidgets('muestra actividades asignadas sin datos administrativos', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'activity-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Ordenar mi mochila',
      description: 'Organiza los objetos en el orden correcto.',
      type: ActivityType.sequence,
      difficulty: 1,
      instructions: 'Instrucciones internas',
      configuration: const {},
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();

    expect(find.text('Ordenar mi mochila'), findsOneWidget);
    expect(find.text('Secuencia'), findsOneWidget);
    expect(find.text('Asignada'), findsOneWidget);
    expect(find.text('Pendiente de preparación'), findsOneWidget);
    expect(
      find.text('Esta actividad todavía está siendo preparada.'),
      findsOneWidget,
    );
    expect(find.text('Comenzar'), findsNothing);
    expect(find.text('activity-id'), findsNothing);
    expect(find.text('therapy-id'), findsNothing);
    expect(find.text('psychologist-id'), findsNothing);
    expect(find.text('Instrucciones internas'), findsNothing);
  });

  testWidgets('actividad Sequence válida abre su motor desde el router', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'activity-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Preparar mi mochila',
      description: '',
      type: ActivityType.sequence,
      difficulty: 1,
      instructions: '',
      configuration: const SequenceActivityConfig(
        items: [SequenceItemConfig(id: 's1', label: 'Abrir mochila', order: 0)],
      ).toMap(),
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
          executionRouter: _sequenceRouter(),
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();

    expect(find.text('Comenzar'), findsOneWidget);
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('Comprobar'), findsOneWidget);
    expect(find.text('Abrir mochila'), findsOneWidget);
  });

  testWidgets('actividad Matching válida abre su motor desde el router', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'matching-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Relacionar objetos',
      description: '',
      type: ActivityType.matching,
      difficulty: 1,
      instructions: '',
      configuration: const MatchingActivityConfig(
        pairs: [MatchingPairConfig(id: 'p1', left: 'Sol', right: 'Día')],
      ).toMap(),
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
          executionRouter: _matchingRouter(),
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('Elementos'), findsOneWidget);
    expect(find.text('Respuestas'), findsOneWidget);
    expect(find.text('Sol'), findsOneWidget);
    expect(find.text('Día'), findsOneWidget);
  });

  testWidgets('actividad Emotion válida abre su motor desde el router', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'emotion-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Reconocer emociones',
      description: '',
      type: ActivityType.emotion,
      difficulty: 1,
      instructions: '',
      configuration: const EmotionActivityConfig(
        options: [
          EmotionOptionConfig(
            id: 'e1',
            label: 'Alegría',
            prompt: '¿Cómo podría sentirse?',
            expectedValue: 'alegría',
          ),
        ],
      ).toMap(),
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
          executionRouter: _emotionRouter(),
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 1 de 1'), findsOneWidget);
    expect(find.text('Alegría'), findsOneWidget);
    expect(find.text('¿Cómo podría sentirse?'), findsOneWidget);
  });

  testWidgets('actividad Pictogram válida abre su motor desde el router', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'pictogram-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Elegir una opción',
      description: '',
      type: ActivityType.pictogram,
      difficulty: 1,
      instructions: '',
      configuration: const PictogramActivityConfig(
        options: [PictogramOptionConfig(id: 'p1', label: 'Agua')],
      ).toMap(),
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
          executionRouter: _pictogramRouter(),
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('Elige una opción'), findsOneWidget);
    expect(find.text('Agua'), findsOneWidget);
    expect(find.text('Aún no has seleccionado una opción.'), findsOneWidget);
  });

  testWidgets('actividad DragDrop válida abre su motor desde el router', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'drag-drop-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Clasificar objetos',
      description: '',
      type: ActivityType.dragDrop,
      difficulty: 1,
      instructions: '',
      configuration: const DragDropActivityConfig(
        items: [
          DragDropItemConfig(
            id: 'item-id',
            label: 'Manzana',
            targetId: 'target-id',
          ),
        ],
        targets: [DragDropTargetConfig(id: 'target-id', label: 'Frutas')],
      ).toMap(),
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
          executionRouter: _dragDropRouter(),
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('Elementos'), findsOneWidget);
    expect(find.text('Destinos'), findsOneWidget);
    expect(find.text('0 de 1 elementos colocados'), findsOneWidget);
  });

  testWidgets('actividad Timer válida abre su motor desde el router', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'timer-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Tiempo de calma',
      description: '',
      type: ActivityType.timer,
      difficulty: 1,
      instructions: 'Respira lentamente.',
      configuration: const TimerActivityConfig(
        durationSeconds: 30,
        label: 'Respiración',
      ).toMap(),
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
          executionRouter: _timerRouter(),
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('Respiración'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets('actividad Tracing válida abre su motor desde el router', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'tracing-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Trazar la letra A',
      description: '',
      type: ActivityType.tracing,
      difficulty: 1,
      instructions: 'Sigue la guía.',
      configuration: const TracingActivityConfig(
        pattern: 'Letra',
        value: 'A',
      ).toMap(),
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
          executionRouter: _tracingRouter(),
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('Tipo de trazado: Letra'), findsOneWidget);
    expect(find.text('Valor a trazar: A'), findsOneWidget);
    expect(find.byKey(const ValueKey('tracing-canvas')), findsOneWidget);
  });

  testWidgets('actividad Motor válida abre su motor desde el router', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'motor-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Guía de movimiento',
      description: '',
      type: ActivityType.motor,
      difficulty: 1,
      instructions: 'Avanza a tu ritmo.',
      configuration: const MotorActivityConfig(
        steps: [
          MotorStepConfig(id: 'step-id', instruction: 'Levanta los brazos.'),
        ],
      ).toMap(),
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
          executionRouter: _motorRouter(),
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 1'), findsOneWidget);
    expect(find.text('Levanta los brazos.'), findsOneWidget);
    expect(find.text('Finalizar guía'), findsOneWidget);
  });

  testWidgets('Preview ejecuta sin presentar el resultado como guardado', (
    tester,
  ) async {
    final activity = ActivityModel(
      id: 'preview-activity-id',
      therapyId: 'therapy-id',
      childId: 'child-document-id',
      psychologistId: 'psychologist-id',
      title: 'Actividad Preview',
      description: '',
      type: ActivityType.sequence,
      difficulty: 1,
      instructions: '',
      configuration: const SequenceActivityConfig(
        items: [SequenceItemConfig(id: 's1', label: 'Paso único', order: 0)],
      ).toMap(),
      status: ActivityStatus.assigned,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChildShell(
          user: childUser,
          activitiesStream: Stream.value([activity]),
          onSignOut: () async {},
          executionRouter: buildChildActivityExecutionRouter(
            persistentExecutionEnabled: false,
            previewEnabled: true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();

    expect(find.text('Modo de prueba · no guarda resultados'), findsOneWidget);
    await tester.tap(find.text('Probar actividad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comprobar'));
    await tester.pumpAndSettle();

    expect(
      find.text('¡Muy bien! Práctica completada. No se guardaron resultados.'),
      findsOneWidget,
    );
    expect(find.textContaining('resultado fue guardado'), findsNothing);
  });
}

ActivityExecutionRouter _sequenceRouter() {
  return ActivityExecutionRouter(
    handlers: {
      ActivityType.sequence: (context, activity, configuration) async {
        if (configuration is! SequenceActivityConfig) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SequenceExecutionScreen(
              activity: activity,
              configuration: configuration,
              persistence: _SequencePersistenceFake(),
            ),
          ),
        );
      },
    },
  );
}

ActivityExecutionRouter _matchingRouter() {
  return ActivityExecutionRouter(
    handlers: {
      ActivityType.matching: (context, activity, configuration) async {
        if (configuration is! MatchingActivityConfig) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MatchingExecutionScreen(
              activity: activity,
              configuration: configuration,
              persistence: _MatchingPersistenceFake(),
            ),
          ),
        );
      },
    },
  );
}

ActivityExecutionRouter _emotionRouter() {
  return ActivityExecutionRouter(
    handlers: {
      ActivityType.emotion: (context, activity, configuration) async {
        if (configuration is! EmotionActivityConfig) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => EmotionExecutionScreen(
              activity: activity,
              configuration: configuration,
              persistence: _EmotionPersistenceFake(),
            ),
          ),
        );
      },
    },
  );
}

ActivityExecutionRouter _pictogramRouter() {
  return ActivityExecutionRouter(
    handlers: {
      ActivityType.pictogram: (context, activity, configuration) async {
        if (configuration is! PictogramActivityConfig) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => PictogramExecutionScreen(
              activity: activity,
              configuration: configuration,
              persistence: _PictogramPersistenceFake(),
            ),
          ),
        );
      },
    },
  );
}

ActivityExecutionRouter _dragDropRouter() {
  return ActivityExecutionRouter(
    handlers: {
      ActivityType.dragDrop: (context, activity, configuration) async {
        if (configuration is! DragDropActivityConfig) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => DragDropExecutionScreen(
              activity: activity,
              configuration: configuration,
              persistence: _DragDropPersistenceFake(),
            ),
          ),
        );
      },
    },
  );
}

ActivityExecutionRouter _motorRouter() {
  return ActivityExecutionRouter(
    handlers: {
      ActivityType.motor: (context, activity, configuration) async {
        if (configuration is! MotorActivityConfig) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => MotorExecutionScreen(
              activity: activity,
              configuration: configuration,
              persistence: _MotorPersistenceFake(),
            ),
          ),
        );
      },
    },
  );
}

ActivityExecutionRouter _tracingRouter() {
  return ActivityExecutionRouter(
    handlers: {
      ActivityType.tracing: (context, activity, configuration) async {
        if (configuration is! TracingActivityConfig) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => TracingExecutionScreen(
              activity: activity,
              configuration: configuration,
              persistence: _TracingPersistenceFake(),
            ),
          ),
        );
      },
    },
  );
}

ActivityExecutionRouter _timerRouter() {
  return ActivityExecutionRouter(
    handlers: {
      ActivityType.timer: (context, activity, configuration) async {
        if (configuration is! TimerActivityConfig) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => TimerExecutionScreen(
              activity: activity,
              configuration: configuration,
              persistence: _TimerPersistenceFake(),
            ),
          ),
        );
      },
    },
  );
}

class _SequencePersistenceFake implements SequenceExecutionPersistence {
  @override
  Future<String> startSession({required String activityId}) async {
    return 'session-test';
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required SequenceExecutionMetrics metrics,
  }) async {}

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    return null;
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    return null;
  }

  @override
  Future<void> interruptSession(String sessionId) async {}
}

class _MatchingPersistenceFake implements MatchingExecutionPersistence {
  @override
  Future<String> startSession({required String activityId}) async {
    return 'matching-session-test';
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required MatchingExecutionMetrics metrics,
  }) async {}

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    return null;
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    return null;
  }

  @override
  Future<void> interruptSession(String sessionId) async {}
}

class _EmotionPersistenceFake implements EmotionExecutionPersistence {
  @override
  Future<String> startSession({required String activityId}) async {
    return 'emotion-session-test';
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required EmotionExecutionMetrics metrics,
  }) async {}

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    return null;
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    return null;
  }

  @override
  Future<void> interruptSession(String sessionId) async {}
}

class _PictogramPersistenceFake implements PictogramExecutionPersistence {
  @override
  Future<String> startSession({required String activityId}) async {
    return 'session-test';
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required PictogramExecutionMetrics metrics,
  }) async {}

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    return null;
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    return null;
  }

  @override
  Future<void> interruptSession(String sessionId) async {}
}

class _DragDropPersistenceFake implements DragDropExecutionPersistence {
  @override
  Future<String> startSession({required String activityId}) async {
    return 'session-test';
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required DragDropExecutionMetrics metrics,
  }) async {}

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    return null;
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    return null;
  }

  @override
  Future<void> interruptSession(String sessionId) async {}
}

class _MotorPersistenceFake implements MotorExecutionPersistence {
  @override
  Future<String> startSession({required String activityId}) async {
    return 'motor-session-test';
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required MotorExecutionMetrics metrics,
  }) async {}

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    return null;
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    return null;
  }

  @override
  Future<void> interruptSession(String sessionId) async {}
}

class _TracingPersistenceFake implements TracingExecutionPersistence {
  @override
  Future<String> startSession({required String activityId}) async {
    return 'tracing-session-test';
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required TracingExecutionMetrics metrics,
  }) async {}

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    return null;
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    return null;
  }

  @override
  Future<void> interruptSession(String sessionId) async {}
}

class _TimerPersistenceFake implements TimerExecutionPersistence {
  @override
  Future<String> startSession({required String activityId}) async {
    return 'timer-session-test';
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required TimerExecutionMetrics metrics,
  }) async {}

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    return null;
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    return null;
  }

  @override
  Future<void> interruptSession(String sessionId) async {}
}
