import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/sequence_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/sequence_execution_screen.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  const first = SequenceItemConfig(id: 'a', label: 'Abrir mochila', order: 0);
  const second = SequenceItemConfig(
    id: 'b',
    label: 'Guardar cuaderno',
    order: 1,
  );
  const third = SequenceItemConfig(id: 'c', label: 'Cerrar mochila', order: 2);

  Widget buildSubject({
    SequenceActivityConfig configuration = const SequenceActivityConfig(
      items: [first, second, third],
    ),
    SequenceInitialOrderBuilder? initialOrderBuilder,
    ActivityStatus status = ActivityStatus.assigned,
    _FakeSequencePersistence? persistence,
  }) {
    return MaterialApp(
      home: SequenceExecutionScreen(
        activity: _activity(configuration: configuration, status: status),
        configuration: configuration,
        initialOrderBuilder: initialOrderBuilder,
        persistence: persistence ?? _FakeSequencePersistence(),
      ),
    );
  }

  testWidgets('registra el inicio antes de habilitar el juego', (tester) async {
    final persistence = _FakeSequencePersistence();
    await tester.pumpWidget(buildSubject(persistence: persistence));

    expect(find.text('Iniciando actividad...'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(persistence.startCalls, 1);
    expect(find.text('Comprobar'), findsOneWidget);
  });

  testWidgets('muestra titulo, instrucciones y pasos configurados', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Preparar mi mochila'), findsWidgets);
    expect(find.text('Ordena cada paso con cuidado.'), findsOneWidget);
    expect(find.text('Abrir mochila'), findsOneWidget);
    expect(find.text('Guardar cuaderno'), findsOneWidget);
    expect(find.text('Cerrar mochila'), findsOneWidget);
    expect(find.text('Comprobar'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
  });

  testWidgets('un orden incorrecto permite volver a intentarlo', (
    tester,
  ) async {
    final persistence = _FakeSequencePersistence();
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comprobar'));
    await tester.pump();

    expect(
      find.text('Todavía hay pasos por ordenar. ¡Inténtalo otra vez!'),
      findsOneWidget,
    );
    expect(find.text('Comprobar'), findsOneWidget);
    expect(persistence.completeCalls, 0);
  });

  testWidgets('completa, persiste metricas y conserva ActivityStatus', (
    tester,
  ) async {
    const configuration = SequenceActivityConfig(items: [first, second]);
    final activity = _activity(configuration: configuration);
    final persistence = _FakeSequencePersistence();

    await tester.pumpWidget(
      MaterialApp(
        home: SequenceExecutionScreen(
          activity: activity,
          configuration: configuration,
          persistence: persistence,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mover Guardar cuaderno hacia abajo'));
    await tester.pump();
    await tester.tap(find.text('Comprobar'));
    await tester.pumpAndSettle();

    expect(find.text('¡Muy bien! Tu resultado fue guardado.'), findsOneWidget);
    expect(find.text('Volver a mis actividades'), findsOneWidget);
    expect(find.text('Repetir'), findsOneWidget);
    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.itemsCount, 2);
    expect(persistence.lastMetrics?.checksCount, 1);
    expect(activity.status, ActivityStatus.assigned);
    expect(activity.configuration, configuration.toMap());
  });

  testWidgets('deshabilita envios simultaneos durante el guardado', (
    tester,
  ) async {
    const configuration = SequenceActivityConfig(items: [first]);
    final persistence = _FakeSequencePersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comprobar'));
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

  testWidgets('un error de inicio muestra reintento y no habilita el juego', (
    tester,
  ) async {
    final persistence = _FakeSequencePersistence()..startFailures = 1;
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos iniciar la actividad.'), findsOneWidget);
    expect(find.text('Comprobar'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(persistence.startCalls, 2);
    expect(find.text('Comprobar'), findsOneWidget);
  });

  testWidgets('confirma salida e interrumpe antes de regresar', (tester) async {
    final persistence = _FakeSequencePersistence();
    const configuration = SequenceActivityConfig(items: [first, second]);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => SequenceExecutionScreen(
                      activity: _activity(configuration: configuration),
                      configuration: configuration,
                      persistence: persistence,
                    ),
                  ),
                ),
                child: const Text('Abrir Sequence'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir Sequence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Salir de la actividad'), findsOneWidget);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
    expect(find.text('Abrir Sequence'), findsOneWidget);
  });

  testWidgets('configuracion vacia no crea una sesion', (tester) async {
    final persistence = _FakeSequencePersistence();
    await tester.pumpWidget(
      buildSubject(
        configuration: const SequenceActivityConfig(),
        persistence: persistence,
      ),
    );
    await tester.pump();

    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
    expect(find.text('Comprobar'), findsNothing);
    expect(persistence.startCalls, 0);
  });

  testWidgets('status completed queda bloqueado sin iniciar ni modificar', (
    tester,
  ) async {
    final persistence = _FakeSequencePersistence();
    await tester.pumpWidget(
      buildSubject(status: ActivityStatus.completed, persistence: persistence),
    );
    await tester.pump();

    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
    expect(find.text('Comprobar'), findsNothing);
    expect(persistence.startCalls, 0);
  });
}

ActivityModel _activity({
  required SequenceActivityConfig configuration,
  ActivityStatus status = ActivityStatus.assigned,
}) {
  return ActivityModel(
    id: 'activity-id',
    therapyId: 'therapy-id',
    childId: 'child-id',
    psychologistId: 'psychologist-id',
    title: 'Preparar mi mochila',
    description: '',
    type: ActivityType.sequence,
    difficulty: 1,
    instructions: 'Ordena cada paso con cuidado.',
    configuration: configuration.toMap(),
    status: status,
    createdAt: DateTime(2026),
  );
}

class _FakeSequencePersistence implements SequenceExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  Completer<void>? pendingCompletion;
  SequenceExecutionMetrics? lastMetrics;
  final List<String> completedSessionIds = [];
  final List<String> interruptedSessionIds = [];

  @override
  Future<String> startSession({required String activityId}) async {
    startCalls++;
    if (startFailures > 0) {
      startFailures--;
      throw StateError('start failure');
    }
    return 'session-$startCalls';
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required SequenceExecutionMetrics metrics,
  }) async {
    completeCalls++;
    completedSessionIds.add(sessionId);
    lastMetrics = metrics;
    final pending = pendingCompletion;
    if (pending != null) {
      pendingCompletion = null;
      await pending.future;
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
