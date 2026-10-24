import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/matching_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/matching_execution_screen.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  const first = MatchingPairConfig(id: 'a', left: 'Gato', right: 'Animal');
  const second = MatchingPairConfig(id: 'b', left: 'Azul', right: 'Color');

  Widget buildSubject({
    MatchingActivityConfig configuration = const MatchingActivityConfig(
      pairs: [first, second],
    ),
    MatchingAnswerOrderBuilder? answerOrderBuilder,
    ActivityStatus status = ActivityStatus.assigned,
    _FakeMatchingPersistence? persistence,
  }) {
    return MaterialApp(
      home: MatchingExecutionScreen(
        activity: _activity(configuration: configuration, status: status),
        configuration: configuration,
        answerOrderBuilder: answerOrderBuilder ?? (answers) => List.of(answers),
        persistence: persistence ?? _FakeMatchingPersistence(),
      ),
    );
  }

  testWidgets('registra el inicio antes de habilitar el juego', (tester) async {
    final persistence = _FakeMatchingPersistence();
    await tester.pumpWidget(buildSubject(persistence: persistence));

    expect(find.text('Iniciando actividad...'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(persistence.startCalls, 1);
    expect(find.text('Elementos'), findsOneWidget);
  });

  testWidgets('muestra configuración válida y progreso', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Relacionar conceptos'), findsWidgets);
    expect(find.text('Elementos'), findsOneWidget);
    expect(find.text('Respuestas'), findsOneWidget);
    expect(find.text('0 de 2 relaciones completadas'), findsOneWidget);
    expect(find.text('Gato'), findsOneWidget);
    expect(find.text('Animal'), findsOneWidget);
  });

  testWidgets('identifica claramente el elemento seleccionado', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gato'));
    await tester.pump();

    expect(find.text('Seleccionado'), findsOneWidget);
  });

  testWidgets('persiste métricas reales al completar todas las relaciones', (
    tester,
  ) async {
    const configuration = MatchingActivityConfig(pairs: [first, second]);
    final activity = _activity(configuration: configuration);
    final persistence = _FakeMatchingPersistence();
    await tester.pumpWidget(
      MaterialApp(
        home: MatchingExecutionScreen(
          activity: activity,
          configuration: configuration,
          answerOrderBuilder: (answers) => List.of(answers),
          persistence: persistence,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gato'));
    await tester.tap(find.text('Color'));
    await tester.pump();
    await tester.tap(find.text('Animal'));
    await tester.pump();
    await tester.tap(find.text('Azul'));
    await tester.tap(find.text('Color'));
    await tester.pumpAndSettle();

    expect(find.text('¡Muy bien! Tu resultado fue guardado.'), findsOneWidget);
    expect(find.text('2 de 2 relaciones completadas'), findsOneWidget);
    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.relationsCompleted, 2);
    expect(persistence.lastMetrics?.checksCount, 3);
    expect(activity.status, ActivityStatus.assigned);
    expect(activity.configuration, configuration.toMap());
  });

  testWidgets('una respuesta incorrecta permite reintentar', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gato'));
    await tester.tap(find.text('Color'));
    await tester.pump();

    expect(find.text('Intenta con otra opción.'), findsOneWidget);
    expect(find.text('Seleccionado'), findsOneWidget);
    expect(find.text('0 de 2 relaciones completadas'), findsOneWidget);
  });

  testWidgets('respuestas repetidas conservan la mecánica existente', (
    tester,
  ) async {
    const configuration = MatchingActivityConfig(
      pairs: [
        MatchingPairConfig(id: 'a', left: 'Casa', right: 'Vivienda'),
        MatchingPairConfig(id: 'b', left: 'Hogar', right: 'Vivienda'),
      ],
    );
    await tester.pumpWidget(buildSubject(configuration: configuration));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Casa'));
    await tester.tap(find.text('Vivienda').at(1));
    await tester.pump();
    await tester.tap(find.text('Hogar'));
    await tester.tap(find.text('Vivienda').at(0));
    await tester.pumpAndSettle();

    expect(find.text('¡Muy bien! Tu resultado fue guardado.'), findsOneWidget);
    expect(find.text('2 de 2 relaciones completadas'), findsOneWidget);
  });

  testWidgets('repetir crea una nueva sesión independiente', (tester) async {
    const configuration = MatchingActivityConfig(pairs: [first]);
    final persistence = _FakeMatchingPersistence();
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gato'));
    await tester.tap(find.text('Animal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repetir'));
    await tester.pumpAndSettle();

    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(find.text('0 de 1 relaciones completadas'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
  });

  testWidgets('bloquea interacciones durante el guardado', (tester) async {
    const configuration = MatchingActivityConfig(pairs: [first]);
    final persistence = _FakeMatchingPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gato'));
    await tester.tap(find.text('Animal'));
    await tester.pump();

    expect(find.text('Guardando resultado...'), findsOneWidget);
    expect(persistence.completeCalls, 1);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    pendingCompletion.complete();
    await tester.pumpAndSettle();
    expect(persistence.completeCalls, 1);
  });

  testWidgets('un error de inicio permite reintentar', (tester) async {
    final persistence = _FakeMatchingPersistence()..startFailures = 1;
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos iniciar la actividad.'), findsOneWidget);
    expect(find.text('Elementos'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(persistence.startCalls, 2);
    expect(find.text('Elementos'), findsOneWidget);
  });

  testWidgets('un cierre fallido se reintenta sobre la misma sesión', (
    tester,
  ) async {
    const configuration = MatchingActivityConfig(pairs: [first]);
    final persistence = _FakeMatchingPersistence()..completeFailures = 1;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gato'));
    await tester.tap(find.text('Animal'));
    await tester.pumpAndSettle();

    expect(find.text('Reintentar guardado'), findsOneWidget);
    await tester.tap(find.text('Reintentar guardado'));
    await tester.pumpAndSettle();

    expect(persistence.startCalls, 1);
    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(find.text('¡Muy bien! Tu resultado fue guardado.'), findsOneWidget);
  });

  testWidgets('confirma salida e interrumpe antes de regresar', (tester) async {
    final persistence = _FakeMatchingPersistence();
    await tester.pumpWidget(_navigationSubject(persistence));

    await tester.tap(find.text('Abrir Matching'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Salir de la actividad'), findsOneWidget);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
    expect(find.text('Abrir Matching'), findsOneWidget);
  });

  testWidgets('Atrás de Android también exige confirmar la interrupción', (
    tester,
  ) async {
    final persistence = _FakeMatchingPersistence();
    await tester.pumpWidget(_navigationSubject(persistence));

    await tester.tap(find.text('Abrir Matching'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Salir de la actividad'), findsOneWidget);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(persistence.interruptedSessionIds, ['session-1']);
  });

  testWidgets('configuración inválida no crea una sesión', (tester) async {
    final persistence = _FakeMatchingPersistence();
    await tester.pumpWidget(
      buildSubject(
        configuration: const MatchingActivityConfig(),
        persistence: persistence,
      ),
    );
    await tester.pump();

    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
    expect(find.text('Elementos'), findsNothing);
    expect(persistence.startCalls, 0);
  });

  testWidgets('status completed queda bloqueado sin iniciar', (tester) async {
    final persistence = _FakeMatchingPersistence();
    await tester.pumpWidget(
      buildSubject(status: ActivityStatus.completed, persistence: persistence),
    );
    await tester.pump();

    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
    expect(persistence.startCalls, 0);
  });
}

Widget _navigationSubject(_FakeMatchingPersistence persistence) {
  const configuration = MatchingActivityConfig(
    pairs: [MatchingPairConfig(id: 'a', left: 'Gato', right: 'Animal')],
  );
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => MatchingExecutionScreen(
                  activity: _activity(configuration: configuration),
                  configuration: configuration,
                  persistence: persistence,
                ),
              ),
            ),
            child: const Text('Abrir Matching'),
          ),
        ),
      ),
    ),
  );
}

ActivityModel _activity({
  required MatchingActivityConfig configuration,
  ActivityStatus status = ActivityStatus.assigned,
}) {
  return ActivityModel(
    id: 'activity-id',
    therapyId: 'therapy-id',
    childId: 'child-id',
    psychologistId: 'psychologist-id',
    title: 'Relacionar conceptos',
    description: '',
    type: ActivityType.matching,
    difficulty: 1,
    instructions: 'Relaciona cada elemento con su respuesta.',
    configuration: configuration.toMap(),
    status: status,
    createdAt: DateTime(2026),
  );
}

class _FakeMatchingPersistence implements MatchingExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  Completer<void>? pendingCompletion;
  MatchingExecutionMetrics? lastMetrics;
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
    required MatchingExecutionMetrics metrics,
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
