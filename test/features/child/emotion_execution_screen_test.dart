import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/emotion_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/emotion_execution_screen.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  const first = EmotionOptionConfig(
    id: 'e1',
    label: 'Alegría',
    prompt: '¿Cómo podría sentirse alguien al recibir un regalo?',
    expectedValue: 'alegría',
  );
  const second = EmotionOptionConfig(
    id: 'e2',
    label: 'Calma',
    prompt: '¿Qué emoción transmite una respiración tranquila?',
    expectedValue: 'calma',
  );

  Widget buildSubject({
    EmotionActivityConfig configuration = const EmotionActivityConfig(
      options: [first, second],
    ),
    ActivityStatus status = ActivityStatus.assigned,
    _FakeEmotionPersistence? persistence,
  }) {
    return MaterialApp(
      home: EmotionExecutionScreen(
        activity: _activity(configuration: configuration, status: status),
        configuration: configuration,
        persistence: persistence ?? _FakeEmotionPersistence(),
      ),
    );
  }

  testWidgets('registra el inicio antes de habilitar los ejercicios', (
    tester,
  ) async {
    final persistence = _FakeEmotionPersistence();
    await tester.pumpWidget(buildSubject(persistence: persistence));

    expect(find.text('Iniciando actividad...'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(persistence.startCalls, 1);
    expect(find.text('Pregunta 1 de 2'), findsOneWidget);
  });

  testWidgets('muestra ejercicios reales y progreso local', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 1 de 2'), findsOneWidget);
    expect(find.text('Alegría'), findsOneWidget);
    expect(
      find.text('¿Cómo podría sentirse alguien al recibir un regalo?'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Revisar respuesta'), findsOneWidget);
  });

  testWidgets('una respuesta vacía no revisa el ejercicio', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revisar respuesta'));
    await tester.pump();

    expect(
      find.text('Escribe una respuesta antes de continuar.'),
      findsOneWidget,
    );
    expect(find.text('Siguiente'), findsNothing);
  });

  testWidgets('la retroalimentación es neutral y no clasifica la respuesta', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'una respuesta personal');
    await tester.tap(find.text('Revisar respuesta'));
    await tester.pump();

    expect(find.text('Gracias por compartir tu respuesta.'), findsOneWidget);
    expect(find.textContaining('coincide'), findsNothing);
    expect(find.textContaining('referencia'), findsNothing);
    expect(find.textContaining('incorrect'), findsNothing);
    expect(find.text('Siguiente'), findsOneWidget);
  });

  testWidgets('avanza entre preguntas y elimina la respuesta anterior', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'contenido temporal');
    await tester.tap(find.text('Revisar respuesta'));
    await tester.pump();
    await tester.tap(find.text('Siguiente'));
    await tester.pump();

    expect(find.text('Pregunta 2 de 2'), findsOneWidget);
    expect(find.text('Calma'), findsOneWidget);
    expect(
      find.text('¿Qué emoción transmite una respiración tranquila?'),
      findsOneWidget,
    );
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);
  });

  testWidgets('finaliza con métrica agregada y sin persistir texto personal', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = EmotionActivityConfig(options: [first]);
    final activity = _activity(configuration: configuration);
    final persistence = _FakeEmotionPersistence();
    const personalAnswer = 'contenido privado que no debe persistirse';
    await tester.pumpWidget(
      MaterialApp(
        home: EmotionExecutionScreen(
          activity: activity,
          configuration: configuration,
          persistence: persistence,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), personalAnswer);
    await tester.tap(find.text('Revisar respuesta'));
    await tester.pump();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.text('¡Terminaste la actividad!'), findsOneWidget);
    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.toMap(), {'exercisesReviewed': 1});
    expect(
      persistence.lastMetrics?.toMap().toString(),
      isNot(contains(personalAnswer)),
    );
    expect(find.text(personalAnswer), findsNothing);
    expect(activity.status, ActivityStatus.assigned);
    expect(activity.configuration, configuration.toMap());
  });

  testWidgets('repetir crea otra sesión y empieza sin respuesta', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = EmotionActivityConfig(options: [first]);
    final persistence = _FakeEmotionPersistence();
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'respuesta temporal');
    await tester.tap(find.text('Revisar respuesta'));
    await tester.pump();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repetir'));
    await tester.pumpAndSettle();

    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(find.text('Pregunta 1 de 1'), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);
  });

  testWidgets('bloquea dobles envíos durante el guardado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = EmotionActivityConfig(options: [first]);
    final persistence = _FakeEmotionPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'respuesta temporal');
    await tester.tap(find.text('Revisar respuesta'));
    await tester.pump();
    await tester.tap(find.text('Finalizar'));
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
    final persistence = _FakeEmotionPersistence()..startFailures = 1;
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos iniciar la actividad.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(persistence.startCalls, 2);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('un cierre fallido se reintenta sobre la misma sesión', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = EmotionActivityConfig(options: [first]);
    final persistence = _FakeEmotionPersistence()..completeFailures = 1;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'respuesta temporal');
    await tester.tap(find.text('Revisar respuesta'));
    await tester.pump();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar guardado'), findsOneWidget);

    await tester.tap(find.text('Reintentar guardado'));
    await tester.pumpAndSettle();

    expect(persistence.startCalls, 1);
    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(find.text('¡Terminaste la actividad!'), findsOneWidget);
  });

  testWidgets('confirma salida e interrumpe sin resultado', (tester) async {
    final persistence = _FakeEmotionPersistence();
    await tester.pumpWidget(_navigationSubject(persistence));

    await tester.tap(find.text('Abrir Emotion'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'respuesta no persistida');
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Salir de la actividad'), findsOneWidget);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
    expect(find.text('Abrir Emotion'), findsOneWidget);
  });

  testWidgets('Atrás de Android exige confirmar la interrupción', (
    tester,
  ) async {
    final persistence = _FakeEmotionPersistence();
    await tester.pumpWidget(_navigationSubject(persistence));

    await tester.tap(find.text('Abrir Emotion'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Salir de la actividad'), findsOneWidget);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(persistence.interruptedSessionIds, ['session-1']);
  });

  testWidgets('configuración inválida y status bloqueado no crean sesión', (
    tester,
  ) async {
    final persistence = _FakeEmotionPersistence();
    await tester.pumpWidget(
      buildSubject(
        configuration: const EmotionActivityConfig(),
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

Widget _navigationSubject(_FakeEmotionPersistence persistence) {
  const configuration = EmotionActivityConfig(
    options: [
      EmotionOptionConfig(
        id: 'e1',
        label: 'Alegría',
        prompt: '¿Cómo podría sentirse alguien al recibir un regalo?',
        expectedValue: 'alegría',
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
                builder: (_) => EmotionExecutionScreen(
                  activity: _activity(configuration: configuration),
                  configuration: configuration,
                  persistence: persistence,
                ),
              ),
            ),
            child: const Text('Abrir Emotion'),
          ),
        ),
      ),
    ),
  );
}

ActivityModel _activity({
  required EmotionActivityConfig configuration,
  ActivityStatus status = ActivityStatus.assigned,
}) {
  return ActivityModel(
    id: 'activity-id',
    therapyId: 'therapy-id',
    childId: 'child-id',
    psychologistId: 'psychologist-id',
    title: 'Reconocer emociones',
    description: '',
    type: ActivityType.emotion,
    difficulty: 1,
    instructions: '',
    configuration: configuration.toMap(),
    status: status,
    createdAt: DateTime(2026),
  );
}

class _FakeEmotionPersistence implements EmotionExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  Completer<void>? pendingCompletion;
  EmotionExecutionMetrics? lastMetrics;
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
    required EmotionExecutionMetrics metrics,
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
