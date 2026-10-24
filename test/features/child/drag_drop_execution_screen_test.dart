import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/drag_drop_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/drag_drop_execution_screen.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  const apple = DragDropItemConfig(
    id: 'apple-id',
    label: 'Manzana',
    targetId: 'fruits-id',
  );
  const carrot = DragDropItemConfig(
    id: 'carrot-id',
    label: 'Zanahoria',
    targetId: 'vegetables-id',
  );
  const fruits = DragDropTargetConfig(id: 'fruits-id', label: 'Frutas');
  const vegetables = DragDropTargetConfig(
    id: 'vegetables-id',
    label: 'Verduras',
  );

  Widget buildSubject({
    DragDropActivityConfig configuration = const DragDropActivityConfig(
      items: [apple, carrot],
      targets: [fruits, vegetables],
    ),
    ActivityStatus status = ActivityStatus.assigned,
    double textScale = 1,
    _FakeDragDropPersistence? persistence,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: DragDropExecutionScreen(
          activity: _activity(configuration: configuration, status: status),
          configuration: configuration,
          persistence: persistence ?? _FakeDragDropPersistence(),
        ),
      ),
    );
  }

  testWidgets('muestra configuración válida y progreso inicial', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Elementos'), findsOneWidget);
    expect(find.text('Destinos'), findsOneWidget);
    expect(find.text('Manzana'), findsOneWidget);
    expect(find.text('Zanahoria'), findsOneWidget);
    expect(find.text('Frutas'), findsOneWidget);
    expect(find.text('Verduras'), findsOneWidget);
    expect(find.text('0 de 2 elementos colocados'), findsOneWidget);
  });

  testWidgets('selección táctil acepta una relación correcta', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('drag-drop-item-apple-id')));
    await tester.pump();
    expect(find.text('Seleccionado'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('drag-drop-target-fruits-id')));
    await tester.pump();

    expect(find.text('¡Muy bien! Encontraste el destino.'), findsOneWidget);
    expect(find.text('1 de 2 elementos colocados'), findsOneWidget);
    expect(find.byKey(const ValueKey('placed-item-apple-id')), findsOneWidget);
    expect(find.byKey(const ValueKey('drag-drop-item-apple-id')), findsNothing);
  });

  testWidgets('relación incorrecta conserva elemento y permite reintentar', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('drag-drop-item-apple-id')));
    await tester.tap(
      find.byKey(const ValueKey('drag-drop-target-vegetables-id')),
    );
    await tester.pump();

    expect(find.text('Intenta con otro destino.'), findsOneWidget);
    expect(find.text('0 de 2 elementos colocados'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('drag-drop-item-apple-id')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('drag-drop-target-fruits-id')));
    await tester.pump();
    expect(find.text('1 de 2 elementos colocados'), findsOneWidget);
  });

  testWidgets('drag and drop usa la misma validación de relación', (
    tester,
  ) async {
    const configuration = DragDropActivityConfig(
      items: [apple],
      targets: [fruits],
    );
    final persistence = _FakeDragDropPersistence();
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    final item = find.byKey(const ValueKey('drag-drop-item-apple-id'));
    final target = find.byKey(const ValueKey('drag-drop-target-fruits-id'));
    final gesture = await tester.startGesture(tester.getCenter(item));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('¡Terminaste la actividad!'), findsOneWidget);
    expect(persistence.lastMetrics?.toMap(), {
      'itemsPlaced': 1,
      'checksCount': 1,
    });
  });

  testWidgets('varios elementos comparten destino sin consumirlo', (
    tester,
  ) async {
    const banana = DragDropItemConfig(
      id: 'banana-id',
      label: 'Plátano',
      targetId: 'fruits-id',
    );
    const configuration = DragDropActivityConfig(
      items: [apple, banana],
      targets: [fruits],
    );
    await tester.pumpWidget(buildSubject(configuration: configuration));
    await tester.pumpAndSettle();

    await _placeByTouch(tester, 'apple-id', 'fruits-id');
    expect(
      find.byKey(const ValueKey('drag-drop-target-fruits-id')),
      findsOneWidget,
    );

    await _placeByTouch(tester, 'banana-id', 'fruits-id');
    await tester.pumpAndSettle();
    expect(find.text('¡Terminaste la actividad!'), findsOneWidget);
  });

  testWidgets('IDs distinguen elementos y destinos con etiquetas repetidas', (
    tester,
  ) async {
    const firstItem = DragDropItemConfig(
      id: 'first-id',
      label: 'Igual',
      targetId: 'first-target-id',
    );
    const secondItem = DragDropItemConfig(
      id: 'second-id',
      label: 'Igual',
      targetId: 'second-target-id',
    );
    const configuration = DragDropActivityConfig(
      items: [firstItem, secondItem],
      targets: [
        DragDropTargetConfig(id: 'first-target-id', label: 'Destino'),
        DragDropTargetConfig(id: 'second-target-id', label: 'Destino'),
      ],
    );
    await tester.pumpWidget(buildSubject(configuration: configuration));
    await tester.pumpAndSettle();

    await _placeByTouch(tester, 'second-id', 'second-target-id');

    expect(find.byKey(const ValueKey('placed-item-second-id')), findsOneWidget);
    expect(find.byKey(const ValueKey('placed-item-first-id')), findsNothing);
    expect(
      find.byKey(const ValueKey('drag-drop-item-first-id')),
      findsOneWidget,
    );
  });

  testWidgets('un elemento finaliza, repite y no modifica datos persistidos', (
    tester,
  ) async {
    const configuration = DragDropActivityConfig(
      items: [apple],
      targets: [fruits],
    );
    final activity = _activity(configuration: configuration);
    final persistence = _FakeDragDropPersistence();
    final activityBefore = activity.toMap();
    final configurationBefore = configuration.toMap();
    await tester.pumpWidget(
      MaterialApp(
        home: DragDropExecutionScreen(
          activity: activity,
          configuration: configuration,
          persistence: persistence,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _placeByTouch(tester, 'apple-id', 'fruits-id');
    await tester.pumpAndSettle();

    expect(find.text('¡Terminaste la actividad!'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Volver a mis actividades'), 200);
    expect(find.text('Volver a mis actividades'), findsOneWidget);
    expect(find.text('Repetir'), findsOneWidget);
    expect(activity.toMap(), activityBefore);
    expect(configuration.toMap(), configurationBefore);
    expect(activity.status, ActivityStatus.assigned);
    expect(persistence.lastMetrics?.toMap(), {
      'itemsPlaced': 1,
      'checksCount': 1,
    });

    await tester.tap(find.text('Repetir'));
    await tester.pumpAndSettle();

    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
    expect(find.text('0 de 1 elementos colocados'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('drag-drop-item-apple-id')),
      findsOneWidget,
    );
  });

  testWidgets('volver tras completar abandona la ruta del motor', (
    tester,
  ) async {
    final persistence = _FakeDragDropPersistence();
    await tester.pumpWidget(_navigationSubject(persistence));
    await tester.tap(find.text('Abrir DragDrop'));
    await tester.pumpAndSettle();

    await _placeByTouch(tester, 'apple-id', 'fruits-id');
    await tester.pumpAndSettle();
    expect(find.text('¡Terminaste la actividad!'), findsOneWidget);

    final returnButton = find.byKey(
      const ValueKey('activity-execution-return'),
    );
    await tester.ensureVisible(returnButton);
    await tester.tap(returnButton);
    await tester.pumpAndSettle();

    expect(find.text('Abrir DragDrop'), findsOneWidget);
    expect(persistence.completedSessionIds, ['session-1']);
  });

  testWidgets('inicia una sola sesión antes de habilitar el juego', (
    tester,
  ) async {
    final persistence = _FakeDragDropPersistence();
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
    expect(find.text('Elementos'), findsOneWidget);
  });

  testWidgets('un error de inicio permite reintentar', (tester) async {
    final persistence = _FakeDragDropPersistence()..startFailures = 1;
    await tester.pumpWidget(buildSubject(persistence: persistence));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos iniciar la actividad.'), findsOneWidget);
    expect(find.text('Elementos'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(persistence.startCalls, 2);
    expect(find.text('Elementos'), findsOneWidget);
  });

  testWidgets('arrastre y pulsaciones producen métricas equivalentes', (
    tester,
  ) async {
    const configuration = DragDropActivityConfig(
      items: [apple],
      targets: [fruits],
    );
    final touchPersistence = _FakeDragDropPersistence();
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: touchPersistence),
    );
    await tester.pumpAndSettle();
    await _placeByTouch(tester, 'apple-id', 'fruits-id');
    await tester.pumpAndSettle();
    final touchMetrics = touchPersistence.lastMetrics?.toMap();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final dragPersistence = _FakeDragDropPersistence();
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: dragPersistence),
    );
    await tester.pumpAndSettle();
    final item = find.byKey(const ValueKey('drag-drop-item-apple-id'));
    final target = find.byKey(const ValueKey('drag-drop-target-fruits-id'));
    final gesture = await tester.startGesture(tester.getCenter(item));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(touchMetrics, {'itemsPlaced': 1, 'checksCount': 1});
    expect(dragPersistence.lastMetrics?.toMap(), touchMetrics);
  });

  testWidgets('intento incorrecto y corrección cuentan dos comprobaciones', (
    tester,
  ) async {
    const configuration = DragDropActivityConfig(
      items: [apple],
      targets: [fruits, vegetables],
    );
    final persistence = _FakeDragDropPersistence();
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await _placeByTouch(tester, 'apple-id', 'vegetables-id');
    await tester.tap(find.byKey(const ValueKey('drag-drop-target-fruits-id')));
    await tester.pumpAndSettle();

    expect(persistence.lastMetrics?.toMap(), {
      'itemsPlaced': 1,
      'checksCount': 2,
    });
  });

  testWidgets('bloquea envíos duplicados mientras guarda', (tester) async {
    const configuration = DragDropActivityConfig(
      items: [apple],
      targets: [fruits],
    );
    final persistence = _FakeDragDropPersistence();
    final pendingCompletion = Completer<void>();
    persistence.pendingCompletion = pendingCompletion;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await _placeByTouch(tester, 'apple-id', 'fruits-id');
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

  testWidgets('un cierre fallido se reintenta sobre la misma sesión', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const configuration = DragDropActivityConfig(
      items: [apple],
      targets: [fruits],
    );
    final persistence = _FakeDragDropPersistence()..completeFailures = 1;
    await tester.pumpWidget(
      buildSubject(configuration: configuration, persistence: persistence),
    );
    await tester.pumpAndSettle();

    await _placeByTouch(tester, 'apple-id', 'fruits-id');
    await tester.pumpAndSettle();
    expect(find.text('Reintentar guardado'), findsOneWidget);

    await tester.tap(find.text('Reintentar guardado'));
    await tester.pumpAndSettle();

    expect(persistence.startedSessionIds, ['session-1']);
    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(find.text('¡Terminaste la actividad!'), findsOneWidget);
  });

  testWidgets('salida voluntaria y Atrás interrumpen sin resultado', (
    tester,
  ) async {
    final persistence = _FakeDragDropPersistence();
    await tester.pumpWidget(_navigationSubject(persistence));
    await tester.tap(find.text('Abrir DragDrop'));
    await tester.pumpAndSettle();

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
    expect(find.text('Abrir DragDrop'), findsOneWidget);
  });

  testWidgets('configuración vacía, inválida y estado bloqueado no ejecutan', (
    tester,
  ) async {
    final persistence = _FakeDragDropPersistence();
    await tester.pumpWidget(
      buildSubject(
        configuration: const DragDropActivityConfig(),
        persistence: persistence,
      ),
    );
    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);

    const invalidConfiguration = DragDropActivityConfig(
      items: [
        DragDropItemConfig(
          id: 'item-id',
          label: 'Elemento',
          targetId: 'missing-target',
        ),
      ],
      targets: [DragDropTargetConfig(id: 'target-id', label: 'Destino')],
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

  testWidgets('layout acepta etiquetas largas y texto ampliado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const longItem = DragDropItemConfig(
      id: 'long-item-id',
      label: 'Elemento con una etiqueta considerablemente extensa',
      targetId: 'long-target-id',
    );
    const configuration = DragDropActivityConfig(
      items: [longItem],
      targets: [
        DragDropTargetConfig(
          id: 'long-target-id',
          label: 'Destino con una etiqueta considerablemente extensa',
        ),
      ],
    );

    await tester.pumpWidget(
      buildSubject(configuration: configuration, textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(find.text(longItem.label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _navigationSubject(_FakeDragDropPersistence persistence) {
  const configuration = DragDropActivityConfig(
    items: [
      DragDropItemConfig(
        id: 'apple-id',
        label: 'Manzana',
        targetId: 'fruits-id',
      ),
    ],
    targets: [DragDropTargetConfig(id: 'fruits-id', label: 'Frutas')],
  );
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => DragDropExecutionScreen(
                  activity: _activity(configuration: configuration),
                  configuration: configuration,
                  persistence: persistence,
                ),
              ),
            ),
            child: const Text('Abrir DragDrop'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _placeByTouch(
  WidgetTester tester,
  String itemId,
  String targetId,
) async {
  await tester.tap(find.byKey(ValueKey('drag-drop-item-$itemId')));
  await tester.pump();
  await tester.tap(find.byKey(ValueKey('drag-drop-target-$targetId')));
  await tester.pump();
}

ActivityModel _activity({
  required DragDropActivityConfig configuration,
  ActivityStatus status = ActivityStatus.assigned,
}) {
  return ActivityModel(
    id: 'activity-id',
    therapyId: 'therapy-id',
    childId: 'child-id',
    psychologistId: 'psychologist-id',
    title: 'Clasificar elementos',
    description: '',
    type: ActivityType.dragDrop,
    difficulty: 1,
    instructions: '',
    configuration: configuration.toMap(),
    status: status,
    createdAt: DateTime(2026),
  );
}

class _FakeDragDropPersistence implements DragDropExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  Completer<String>? pendingStart;
  Completer<void>? pendingCompletion;
  DragDropExecutionMetrics? lastMetrics;
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
