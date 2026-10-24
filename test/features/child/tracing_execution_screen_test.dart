import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/tracing_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/tracing_execution_screen.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  Widget buildSubject({
    TracingActivityConfig configuration = const TracingActivityConfig(
      pattern: 'Letra',
      value: 'A',
      difficultyHint: 'Sigue la guía lentamente.',
    ),
    ActivityStatus status = ActivityStatus.assigned,
    _FakeTracingPersistence? persistence,
  }) {
    return MaterialApp(
      home: TracingExecutionScreen(
        activity: _activity(configuration: configuration, status: status),
        configuration: configuration,
        persistence: persistence ?? _FakeTracingPersistence(),
      ),
    );
  }

  testWidgets('muestra configuración, instrucciones y dificultad reales', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Practicar trazado'), findsWidgets);
    expect(find.text('Repasa la guía con tu dedo.'), findsOneWidget);
    expect(find.text('Tipo de trazado: Letra'), findsOneWidget);
    expect(find.text('Valor a trazar: A'), findsOneWidget);
    expect(find.text('Sigue la guía lentamente.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tracing-guide-typographic')),
      findsOneWidget,
    );
  });

  testWidgets('letras y números utilizan referencia tipográfica', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tracing-guide-typographic')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      buildSubject(
        configuration: const TracingActivityConfig(
          pattern: 'Número',
          value: '2',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tracing-guide-typographic')),
      findsOneWidget,
    );
    expect(find.text('Valor a trazar: 2'), findsOneWidget);
  });

  testWidgets('muestra las tres formas geométricas soportadas', (tester) async {
    const cases = <String, String>{
      'círculo': 'circle',
      'cuadrado': 'square',
      'triángulo': 'triangle',
    };

    for (final entry in cases.entries) {
      await tester.pumpWidget(
        buildSubject(
          configuration: TracingActivityConfig(
            pattern: 'Forma',
            value: entry.key,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('tracing-guide-${entry.value}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('valor no reconocido se presenta como dibujo libre', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        configuration: const TracingActivityConfig(
          pattern: 'Creación personal',
          value: 'Mi casa',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tracing-guide-freeform')),
      findsOneWidget,
    );
    expect(
      find.text('Referencia: Mi casa. Practica este valor como dibujo libre.'),
      findsOneWidget,
    );
  });

  testWidgets('deshacer y limpiar conservan los trazos practicados', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final persistence = _FakeTracingPersistence();
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    await _drawStroke(tester, const Offset(-35, -35), const Offset(70, 70));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tracing-stroke-count')),
      200,
    );
    expect(find.text('1 trazo realizado.'), findsOneWidget);

    await _drawStroke(tester, const Offset(35, -35), const Offset(-70, 70));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('tracing-stroke-count')),
      200,
    );
    expect(find.text('2 trazos realizados.'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Deshacer'), 200);
    await tester.tap(find.text('Deshacer'));
    await tester.pump();
    expect(find.text('1 trazo realizado.'), findsOneWidget);

    await tester.tap(find.text('Limpiar'));
    await tester.pump();
    expect(
      find.text(
        'Aún no has realizado un trazo. Puedes comenzar cuando quieras.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Terminar práctica'));
    await tester.pumpAndSettle();
    expect(persistence.lastMetrics?.strokesCount, 2);
  });

  testWidgets('termina y repite localmente sin modificar ActivityModel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = TracingActivityConfig(pattern: 'Letra', value: 'B');
    final activity = _activity(configuration: configuration);
    final activityBefore = activity.toMap();
    final configurationBefore = configuration.toMap();
    await tester.pumpWidget(
      MaterialApp(
        home: TracingExecutionScreen(
          activity: activity,
          configuration: configuration,
          persistence: _FakeTracingPersistence(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final finishButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Terminar práctica'),
    );
    expect(finishButton.onPressed, isNull);

    await _drawStroke(tester, const Offset(-30, 0), const Offset(60, 0));
    await tester.scrollUntilVisible(find.text('Terminar práctica'), 200);
    await tester.tap(find.text('Terminar práctica'));
    await tester.pumpAndSettle();

    expect(find.text('¡Terminaste tu práctica de trazado!'), findsOneWidget);
    expect(find.text('Repetir'), findsOneWidget);
    expect(find.text('Volver a mis actividades'), findsOneWidget);
    expect(activity.toMap(), activityBefore);
    expect(configuration.toMap(), configurationBefore);
    expect(activity.status, ActivityStatus.assigned);

    await tester.tap(find.text('Repetir'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Aún no has realizado un trazo. Puedes comenzar cuando quieras.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('configuración vacía, inválida y estado bloqueado no ejecutan', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        configuration: const TracingActivityConfig(pattern: '', value: ''),
      ),
    );
    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
    expect(find.byKey(const ValueKey('tracing-canvas')), findsNothing);

    await tester.pumpWidget(
      buildSubject(
        configuration: const TracingActivityConfig(pattern: 'Letra', value: ''),
      ),
    );
    await tester.pump();
    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);

    await tester.pumpWidget(buildSubject(status: ActivityStatus.completed));
    await tester.pump();
    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
  });

  testWidgets('crea una sesión antes de habilitar el Canvas', (tester) async {
    final persistence = _FakeTracingPersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;

    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pump();

    expect(find.text('Iniciando actividad...'), findsOneWidget);
    expect(find.byKey(const ValueKey('tracing-canvas')), findsNothing);
    expect(persistence.startCalls, 1);
    await tester.pump();
    expect(persistence.startCalls, 1);

    pendingStart.complete('session-1');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tracing-canvas')), findsOneWidget);
  });

  testWidgets('error de inicio permite reintentar sin dibujar antes', (
    tester,
  ) async {
    final persistence = _FakeTracingPersistence()..startFailures = 1;
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos iniciar la actividad.'), findsOneWidget);
    expect(find.byKey(const ValueKey('tracing-canvas')), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(persistence.startCalls, 2);
    expect(find.byKey(const ValueKey('tracing-canvas')), findsOneWidget);
  });

  testWidgets('bloquea doble finalización mientras guarda', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final persistence = _FakeTracingPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    await _drawStroke(tester, const Offset(-20, 0), const Offset(40, 0));
    await tester.scrollUntilVisible(find.text('Terminar práctica'), 200);
    await tester.tap(find.text('Terminar práctica'));
    await tester.pump();

    expect(find.text('Guardando resultado...'), findsOneWidget);
    expect(persistence.completeCalls, 1);
    pendingCompletion.complete();
    await tester.pumpAndSettle();
    expect(persistence.completeCalls, 1);
  });

  testWidgets('cierre fallido reintenta la misma sesión sin dibujo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final persistence = _FakeTracingPersistence()..completeFailures = 1;
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    await _drawStroke(tester, const Offset(-20, 0), const Offset(40, 0));
    await tester.scrollUntilVisible(find.text('Terminar práctica'), 200);
    await tester.tap(find.text('Terminar práctica'));
    await tester.pumpAndSettle();

    expect(persistence.completeCalls, 1);
    await _scrollToBottom(tester);
    expect(find.text('Reintentar guardado'), findsOneWidget);
    expect(find.text('1 trazo realizado.'), findsNothing);
    await tester.tap(find.text('Reintentar guardado'));
    await tester.pumpAndSettle();

    expect(persistence.startedSessionIds, ['session-1']);
    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(find.text('¡Terminaste tu práctica de trazado!'), findsOneWidget);
  });

  testWidgets('salida y Atrás interrumpen sin resultado', (tester) async {
    final persistence = _FakeTracingPersistence();
    await tester.pumpWidget(_navigationSubject(persistence));
    await tester.tap(find.text('Abrir Tracing'));
    await tester.pumpAndSettle();

    await _scrollToBottom(tester);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Salir de la actividad'), findsOneWidget);
    await tester.tap(find.text('Continuar aquí'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Salir de la actividad'), findsOneWidget);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
    expect(find.text('Abrir Tracing'), findsOneWidget);
  });
}

Future<void> _drawStroke(
  WidgetTester tester,
  Offset startDelta,
  Offset dragDelta,
) async {
  final canvas = find.byKey(const ValueKey('tracing-canvas'));
  await tester.ensureVisible(canvas);
  await tester.pump();
  await tester.dragFrom(tester.getCenter(canvas) + startDelta, dragDelta);
  await tester.pump();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollable = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pumpAndSettle();
}

ActivityModel _activity({
  required TracingActivityConfig configuration,
  ActivityStatus status = ActivityStatus.assigned,
}) {
  return ActivityModel(
    id: 'activity-id',
    therapyId: 'therapy-id',
    childId: 'child-id',
    psychologistId: 'psychologist-id',
    title: 'Practicar trazado',
    description: '',
    type: ActivityType.tracing,
    difficulty: 1,
    instructions: 'Repasa la guía con tu dedo.',
    configuration: configuration.toMap(),
    status: status,
    createdAt: DateTime(2026),
  );
}

Widget _navigationSubject(_FakeTracingPersistence persistence) {
  const configuration = TracingActivityConfig(pattern: 'Letra', value: 'A');
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => TracingExecutionScreen(
                  activity: _activity(configuration: configuration),
                  configuration: configuration,
                  persistence: persistence,
                ),
              ),
            ),
            child: const Text('Abrir Tracing'),
          ),
        ),
      ),
    ),
  );
}

class _FakeTracingPersistence implements TracingExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  Completer<String>? pendingStart;
  Completer<void>? pendingCompletion;
  TracingExecutionMetrics? lastMetrics;
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
    final pending = pendingStart;
    final id = pending == null ? 'session-$startCalls' : await pending.future;
    pendingStart = null;
    startedSessionIds.add(id);
    return id;
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required TracingExecutionMetrics metrics,
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
