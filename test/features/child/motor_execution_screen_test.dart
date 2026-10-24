import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/motor_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/motor_execution_screen.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  const first = MotorStepConfig(
    id: 'step-one',
    instruction: 'Levanta los brazos lentamente.',
    durationSeconds: 30,
  );
  const second = MotorStepConfig(
    id: 'step-two',
    instruction: 'Estira las manos hacia arriba.',
    durationSeconds: 90,
    repetitions: 5,
  );
  const third = MotorStepConfig(
    id: 'step-three',
    instruction: 'Descansa cuando lo necesites.',
  );

  Widget buildSubject({
    MotorActivityConfig configuration = const MotorActivityConfig(
      steps: [first, second, third],
    ),
    ActivityStatus status = ActivityStatus.assigned,
    _FakeMotorPersistence? persistence,
  }) {
    return MaterialApp(
      home: MotorExecutionScreen(
        activity: _activity(configuration: configuration, status: status),
        configuration: configuration,
        persistence: persistence ?? _FakeMotorPersistence(),
      ),
    );
  }

  testWidgets('registra el inicio antes de mostrar el primer paso', (
    tester,
  ) async {
    final persistence = _FakeMotorPersistence();
    await tester.pumpWidget(buildSubject(persistence: persistence));

    expect(find.text('Iniciando actividad...'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(persistence.startCalls, 1);
    expect(find.text('Paso 1 de 3'), findsOneWidget);
  });

  testWidgets('muestra configuración válida y primer paso real', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Guía de estiramiento'), findsWidgets);
    expect(
      find.text('Sigue cada indicación a tu propio ritmo.'),
      findsOneWidget,
    );
    expect(find.text('Paso 1 de 3'), findsOneWidget);
    expect(find.text(first.instruction), findsOneWidget);
    expect(find.text('Duración sugerida: 30 segundos'), findsOneWidget);
    expect(find.byKey(const ValueKey('motor-step-step-one')), findsOneWidget);
  });

  testWidgets('conserva navegación y no duplica pasos visitados', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final persistence = _FakeMotorPersistence();
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Siguiente paso'));
    await tester.pump();
    expect(find.text('Paso 2 de 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('motor-step-step-two')), findsOneWidget);

    await tester.tap(find.text('Siguiente paso'));
    await tester.pump();
    expect(find.text('Paso 3 de 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('motor-step-step-three')), findsOneWidget);

    await tester.tap(find.text('Paso anterior'));
    await tester.pump();
    await tester.tap(find.text('Siguiente paso'));
    await tester.pump();
    await tester.tap(find.text('Finalizar guía'));
    await tester.pumpAndSettle();

    expect(persistence.lastMetrics?.stepsVisited, 3);
    expect(persistence.completedSessionIds, ['session-1']);
  });

  testWidgets('muestra duración y repeticiones cuando ambas existen', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente paso'));
    await tester.pump();

    expect(
      find.text('Duración sugerida: 1 minuto y 30 segundos'),
      findsOneWidget,
    );
    expect(find.text('Repeticiones: 5'), findsOneWidget);
  });

  testWidgets('no inventa duración ni repeticiones ausentes', (tester) async {
    const configuration = MotorActivityConfig(steps: [third]);
    await tester.pumpWidget(buildSubject(configuration: configuration));
    await tester.pumpAndSettle();

    expect(find.text(third.instruction), findsOneWidget);
    expect(find.textContaining('Duración sugerida:'), findsNothing);
    expect(find.textContaining('Repeticiones:'), findsNothing);
  });

  testWidgets('finaliza, conserva ActivityStatus y repite con nueva sesión', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = MotorActivityConfig(steps: [second]);
    final activity = _activity(configuration: configuration);
    final activityBefore = activity.toMap();
    final persistence = _FakeMotorPersistence();
    await tester.pumpWidget(
      MaterialApp(
        home: MotorExecutionScreen(
          activity: activity,
          configuration: configuration,
          persistence: persistence,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finalizar guía'));
    await tester.pumpAndSettle();

    expect(find.text('¡Terminaste la guía!'), findsOneWidget);
    expect(persistence.lastMetrics?.stepsVisited, 1);
    expect(activity.toMap(), activityBefore);
    expect(activity.status, ActivityStatus.assigned);

    await tester.tap(find.text('Repetir guía'));
    await tester.pumpAndSettle();
    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(find.text('Paso 1 de 1'), findsOneWidget);
  });

  testWidgets('bloquea dobles envíos durante el guardado', (tester) async {
    const configuration = MotorActivityConfig(steps: [first]);
    final persistence = _FakeMotorPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finalizar guía'));
    await tester.pump();

    expect(find.text('Guardando resultado...'), findsOneWidget);
    expect(persistence.completeCalls, 1);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    pendingCompletion.complete();
    await tester.pumpAndSettle();
    expect(persistence.completeCalls, 1);
  });

  testWidgets('un error de inicio permite reintentar', (tester) async {
    final persistence = _FakeMotorPersistence()..startFailures = 1;
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos iniciar la actividad.'), findsOneWidget);
    expect(find.text('Paso 1 de 3'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(persistence.startCalls, 2);
    expect(find.text('Paso 1 de 3'), findsOneWidget);
  });

  testWidgets('un cierre fallido se reintenta sobre la misma sesión', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = MotorActivityConfig(steps: [first]);
    final persistence = _FakeMotorPersistence()..completeFailures = 1;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finalizar guía'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar guardado'), findsOneWidget);

    await tester.tap(find.text('Reintentar guardado'));
    await tester.pumpAndSettle();

    expect(persistence.startCalls, 1);
    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(find.text('¡Terminaste la guía!'), findsOneWidget);
  });

  testWidgets('confirma salida e interrumpe antes de regresar', (tester) async {
    final persistence = _FakeMotorPersistence();
    await tester.pumpWidget(_navigationSubject(persistence));

    await tester.tap(find.text('Abrir guía'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver a mis actividades'));
    await tester.pumpAndSettle();

    expect(find.text('Salir de la actividad'), findsOneWidget);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
    expect(find.text('Abrir guía'), findsOneWidget);
  });

  testWidgets('Atrás de Android exige confirmar la interrupción', (
    tester,
  ) async {
    final persistence = _FakeMotorPersistence();
    await tester.pumpWidget(_navigationSubject(persistence));

    await tester.tap(find.text('Abrir guía'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Salir de la actividad'), findsOneWidget);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(persistence.interruptedSessionIds, ['session-1']);
  });

  testWidgets('configuración vacía no crea una sesión', (tester) async {
    final persistence = _FakeMotorPersistence();
    await tester.pumpWidget(
      buildSubject(
        configuration: const MotorActivityConfig(),
        persistence: persistence,
      ),
    );
    await tester.pump();

    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
    expect(persistence.startCalls, 0);
  });

  testWidgets('configuración inválida y estado bloqueado no ejecutan', (
    tester,
  ) async {
    final persistence = _FakeMotorPersistence();
    const invalidConfiguration = MotorActivityConfig(
      steps: [
        MotorStepConfig(
          id: 'bad-step',
          instruction: 'Movimiento',
          durationSeconds: 0,
          repetitions: 0,
        ),
      ],
    );
    await tester.pumpWidget(
      buildSubject(
        configuration: invalidConfiguration,
        persistence: persistence,
      ),
    );
    await tester.pump();
    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);

    await tester.pumpWidget(
      buildSubject(status: ActivityStatus.completed, persistence: persistence),
    );
    await tester.pump();
    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
    expect(persistence.startCalls, 0);
  });
}

Widget _navigationSubject(_FakeMotorPersistence persistence) {
  const configuration = MotorActivityConfig(
    steps: [
      MotorStepConfig(
        id: 'step-one',
        instruction: 'Levanta los brazos lentamente.',
      ),
    ],
  );
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => MotorExecutionScreen(
                  activity: _activity(configuration: configuration),
                  configuration: configuration,
                  persistence: persistence,
                ),
              ),
            ),
            child: const Text('Abrir guía'),
          ),
        ),
      ),
    ),
  );
}

ActivityModel _activity({
  required MotorActivityConfig configuration,
  ActivityStatus status = ActivityStatus.assigned,
}) {
  return ActivityModel(
    id: 'activity-id',
    therapyId: 'therapy-id',
    childId: 'child-id',
    psychologistId: 'psychologist-id',
    title: 'Guía de estiramiento',
    description: '',
    type: ActivityType.motor,
    difficulty: 1,
    instructions: 'Sigue cada indicación a tu propio ritmo.',
    configuration: configuration.toMap(),
    status: status,
    createdAt: DateTime(2026),
  );
}

class _FakeMotorPersistence implements MotorExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  Completer<void>? pendingCompletion;
  MotorExecutionMetrics? lastMetrics;
  final List<String> startedSessionIds = [];
  final List<String> completedSessionIds = [];
  final List<String> interruptedSessionIds = [];

  @override
  Future<String> startSession({required String activityId}) async {
    startCalls++;
    if (startFailures > 0) {
      startFailures--;
      throw StateError('start failure');
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
    final pending = pendingCompletion;
    if (pending != null) {
      pendingCompletion = null;
      await pending.future;
    }
    if (completeFailures > 0) {
      completeFailures--;
      throw StateError('complete failure');
    }
  }

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    return null;
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    return null;
  }

  @override
  Future<void> interruptSession(String sessionId) async {
    interruptedSessionIds.add(sessionId);
  }
}
