import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/pictogram_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/pictogram_execution_screen.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  const water = PictogramOptionConfig(id: 'water-id', label: 'Agua');
  const rest = PictogramOptionConfig(
    id: 'rest-id',
    label: 'Quiero descansar un momento',
    resourceReference: 'future/resource/reference',
  );

  Widget buildSubject({
    PictogramActivityConfig configuration = const PictogramActivityConfig(
      options: [water, rest],
    ),
    ActivityStatus status = ActivityStatus.assigned,
    double textScale = 1,
    _FakePictogramPersistence? persistence,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: PictogramExecutionScreen(
          activity: _activity(configuration: configuration, status: status),
          configuration: configuration,
          persistence: persistence ?? _FakePictogramPersistence(),
        ),
      ),
    );
  }

  testWidgets('muestra únicamente las opciones reales configuradas', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Elige una opción'), findsOneWidget);
    expect(find.text('Agua'), findsOneWidget);
    expect(find.text('Quiero descansar un momento'), findsOneWidget);
    expect(find.text('Aún no has seleccionado una opción.'), findsOneWidget);
    expect(find.textContaining('correct'), findsNothing);
  });

  testWidgets('una sola opción puede seleccionarse y limpiarse', (
    tester,
  ) async {
    const configuration = PictogramActivityConfig(options: [water]);
    await tester.pumpWidget(buildSubject(configuration: configuration));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pictogram-option-water-id')));
    await tester.pump();

    expect(find.text('Has seleccionado: Agua'), findsOneWidget);
    expect(find.text('Limpiar selección'), findsOneWidget);

    await tester.tap(find.text('Limpiar selección'));
    await tester.pump();

    expect(find.text('Aún no has seleccionado una opción.'), findsOneWidget);
    expect(find.text('Limpiar selección'), findsNothing);
  });

  testWidgets('cambia la selección usando el ID estable', (tester) async {
    const duplicateLabel = PictogramOptionConfig(
      id: 'second-water-id',
      label: 'Agua',
    );
    const configuration = PictogramActivityConfig(
      options: [water, duplicateLabel],
    );
    await tester.pumpWidget(buildSubject(configuration: configuration));
    await tester.pumpAndSettle();

    final firstFinder = find.byKey(const ValueKey('pictogram-option-water-id'));
    final secondFinder = find.byKey(
      const ValueKey('pictogram-option-second-water-id'),
    );

    await tester.tap(firstFinder);
    await tester.pump();
    expect(_selectionState(tester, firstFinder), isTrue);
    expect(_selectionState(tester, secondFinder), isFalse);

    await tester.tap(secondFinder);
    await tester.pump();
    expect(_selectionState(tester, firstFinder), isFalse);
    expect(_selectionState(tester, secondFinder), isTrue);
  });

  testWidgets('resourceReference no se muestra ni inicia carga visual', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('future/resource/reference'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('etiquetas extensas soportan pantalla pequeña y texto ampliado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const longOption = PictogramOptionConfig(
      id: 'long-id',
      label: 'Necesito tomar una pausa tranquila antes de continuar con la actividad',
    );

    await tester.pumpWidget(
      buildSubject(
        configuration: const PictogramActivityConfig(options: [longOption]),
        textScale: 1.8,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(longOption.label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inicia una sola sesión antes de habilitar las opciones', (
    tester,
  ) async {
    final persistence = _FakePictogramPersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;

    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pump();

    expect(find.text('Iniciando actividad...'), findsOneWidget);
    expect(persistence.startCalls, 1);
    await tester.pump();
    expect(persistence.startCalls, 1);

    pendingStart.complete('session-1');
    await tester.pumpAndSettle();
    expect(find.text('Elige una opción'), findsOneWidget);
  });

  testWidgets('un error de inicio permite reintentar', (tester) async {
    final persistence = _FakePictogramPersistence()..startFailures = 1;
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos iniciar la actividad.'), findsOneWidget);
    expect(find.text('Elige una opción'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(persistence.startCalls, 2);
    expect(find.text('Elige una opción'), findsOneWidget);
  });

  testWidgets('toques repetidos cuentan sin hacerlo por rebuilds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = PictogramActivityConfig(options: [water]);
    final persistence = _FakePictogramPersistence();
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    final option = find.byKey(const ValueKey('pictogram-option-water-id'));
    await tester.tap(option);
    await tester.pump();
    await tester.pump();
    await tester.tap(option);
    await tester.pump();
    await tester.tap(find.text('Volver a mis actividades'));
    await tester.pumpAndSettle();

    expect(persistence.lastMetrics?.toMap(), {'interactionsCount': 2});
    expect(find.textContaining('correct'), findsNothing);
    expect(find.textContaining('incorrect'), findsNothing);
  });

  testWidgets('finaliza sin persistir la opción y conserva ActivityStatus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = PictogramActivityConfig(options: [rest]);
    final activity = _activity(configuration: configuration);
    final persistence = _FakePictogramPersistence();
    await tester.pumpWidget(
      MaterialApp(
        home: PictogramExecutionScreen(
          activity: activity,
          configuration: configuration,
          persistence: persistence,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pictogram-option-rest-id')));
    await tester.pump();
    await tester.tap(find.text('Volver a mis actividades'));
    await tester.pumpAndSettle();

    expect(find.text('¡Terminaste la actividad!'), findsOneWidget);
    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.toMap(), {'interactionsCount': 1});
    expect(
      persistence.lastMetrics?.toMap().toString(),
      isNot(contains(rest.id)),
    );
    expect(
      persistence.lastMetrics?.toMap().toString(),
      isNot(contains(rest.label)),
    );
    expect(activity.status, ActivityStatus.assigned);
  });

  testWidgets('bloquea dobles envíos mientras guarda', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = PictogramActivityConfig(options: [water]);
    final persistence = _FakePictogramPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pictogram-option-water-id')));
    await tester.pump();
    await tester.tap(find.text('Volver a mis actividades'));
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

  testWidgets('un cierre fallido se reintenta sobre la misma sesión', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = PictogramActivityConfig(options: [water]);
    final persistence = _FakePictogramPersistence()..completeFailures = 1;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pictogram-option-water-id')));
    await tester.pump();
    await tester.tap(find.text('Volver a mis actividades'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar guardado'), findsOneWidget);

    await tester.tap(find.text('Reintentar guardado'));
    await tester.pumpAndSettle();

    expect(persistence.startedSessionIds, ['session-1']);
    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(find.text('¡Terminaste la actividad!'), findsOneWidget);
  });

  testWidgets('salida sin finalizar y Atrás interrumpen sin resultado', (
    tester,
  ) async {
    final persistence = _FakePictogramPersistence();
    await tester.pumpWidget(_navigationSubject(persistence));
    await tester.tap(find.text('Abrir Pictogram'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Volver a mis actividades'));
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
    expect(find.text('Abrir Pictogram'), findsOneWidget);
  });

  testWidgets('repetir crea una nueva sesión con selección limpia', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = PictogramActivityConfig(options: [water]);
    final persistence = _FakePictogramPersistence();
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pictogram-option-water-id')));
    await tester.pump();
    await tester.tap(find.text('Volver a mis actividades'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repetir'));
    await tester.pumpAndSettle();

    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(find.text('Aún no has seleccionado una opción.'), findsOneWidget);
  });

  testWidgets(
    'configuración vacía, inválida y estado bloqueado no se ejecutan',
    (tester) async {
      await tester.pumpWidget(
        buildSubject(configuration: const PictogramActivityConfig()),
      );
      expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
      expect(find.text('Elige una opción'), findsNothing);

      await tester.pumpWidget(
        buildSubject(
          configuration: const PictogramActivityConfig(
            options: [PictogramOptionConfig(id: '', label: 'Agua')],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);

      await tester.pumpWidget(buildSubject(status: ActivityStatus.completed));
      await tester.pump();
      expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
    },
  );

  testWidgets('la interacción no modifica actividad ni configuración', (
    tester,
  ) async {
    const configuration = PictogramActivityConfig(options: [water, rest]);
    final activity = _activity(configuration: configuration);
    final originalActivity = activity.toMap();
    final originalConfiguration = configuration.toMap();
    final persistence = _FakePictogramPersistence();

    await tester.pumpWidget(
      MaterialApp(
        home: PictogramExecutionScreen(
          activity: activity,
          configuration: configuration,
          persistence: persistence,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pictogram-option-rest-id')));
    await tester.pump();
    await tester.tap(find.text('Limpiar selección'));
    await tester.pump();

    expect(activity.toMap(), originalActivity);
    expect(configuration.toMap(), originalConfiguration);
    expect(activity.status, ActivityStatus.assigned);
  });
}

Widget _navigationSubject(_FakePictogramPersistence persistence) {
  const configuration = PictogramActivityConfig(
    options: [PictogramOptionConfig(id: 'water-id', label: 'Agua')],
  );
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PictogramExecutionScreen(
                  activity: _activity(configuration: configuration),
                  configuration: configuration,
                  persistence: persistence,
                ),
              ),
            ),
            child: const Text('Abrir Pictogram'),
          ),
        ),
      ),
    ),
  );
}

bool? _selectionState(WidgetTester tester, Finder optionFinder) {
  final semantics = tester.widget<Semantics>(
    find.descendant(of: optionFinder, matching: find.byType(Semantics)).first,
  );
  return semantics.properties.selected;
}

ActivityModel _activity({
  required PictogramActivityConfig configuration,
  ActivityStatus status = ActivityStatus.assigned,
}) {
  return ActivityModel(
    id: 'activity-id',
    therapyId: 'therapy-id',
    childId: 'child-id',
    psychologistId: 'psychologist-id',
    title: 'Tablero de comunicación',
    description: '',
    type: ActivityType.pictogram,
    difficulty: 1,
    instructions: '',
    configuration: configuration.toMap(),
    status: status,
    createdAt: DateTime(2026),
  );
}

class _FakePictogramPersistence implements PictogramExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  Completer<String>? pendingStart;
  Completer<void>? pendingCompletion;
  PictogramExecutionMetrics? lastMetrics;
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
