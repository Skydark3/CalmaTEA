import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/timer_execution_controller.dart';
import 'package:tea_app/features/child/activities/execution/timer_execution_screen.dart';
import 'package:tea_app/features/child/activities/execution/timer_execution_utils.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  Widget buildSubject({
    TimerActivityConfig configuration = const TimerActivityConfig(
      durationSeconds: 90,
      label: 'Respiración tranquila',
    ),
    ActivityStatus status = ActivityStatus.assigned,
    TimerCountdownController? controller,
    _FakeTimerPersistence? persistence,
  }) {
    return MaterialApp(
      home: TimerExecutionScreen(
        activity: _activity(configuration: configuration, status: status),
        configuration: configuration,
        countdownController: controller,
        persistence: persistence ?? _FakeTimerPersistence(),
      ),
    );
  }

  testWidgets('muestra configuración válida sin iniciar automáticamente', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Práctica con tiempo'), findsWidgets);
    expect(find.text('Respiración tranquila'), findsOneWidget);
    expect(find.text('Respira con calma.'), findsOneWidget);
    expect(find.text('01:30'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
    expect(find.text('Pausar'), findsNothing);
  });

  testWidgets('muestra correctamente una duración con horas', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 3600),
      ),
    );

    expect(find.text('01:00:00'), findsOneWidget);
    expect(find.text('Respiración tranquila'), findsNothing);
  });

  testWidgets('inicio, cuenta regresiva, pausa y continuación son manuales', (
    tester,
  ) async {
    final clock = FakeTimerMonotonicClock();
    final controller = TimerCountdownController(
      durationSeconds: 4,
      clock: clock,
    );
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 4),
        controller: controller,
      ),
    );

    expect(clock.isRunning, isFalse);
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(clock.isRunning, isTrue);
    expect(find.text('Pausar'), findsOneWidget);

    clock.advance(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('00:03'), findsOneWidget);

    await tester.tap(find.text('Pausar'));
    await tester.pump();
    expect(clock.isRunning, isFalse);
    expect(find.text('Continuar'), findsOneWidget);

    clock.advance(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:03'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pump();
    clock.advance(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('00:02'), findsOneWidget);
  });

  testWidgets('reiniciar restaura duración original y detiene el reloj', (
    tester,
  ) async {
    final clock = FakeTimerMonotonicClock();
    final controller = TimerCountdownController(
      durationSeconds: 5,
      clock: clock,
    );
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 5),
        controller: controller,
      ),
    );

    await tester.tap(find.text('Iniciar'));
    clock.advance(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('00:03'), findsOneWidget);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();

    expect(find.text('00:05'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
    expect(clock.isRunning, isFalse);
  });

  testWidgets('un segundo finaliza en cero sin modificar la actividad', (
    tester,
  ) async {
    const configuration = TimerActivityConfig(durationSeconds: 1);
    final activity = _activity(configuration: configuration);
    final activityBefore = activity.toMap();
    final clock = FakeTimerMonotonicClock();
    final controller = TimerCountdownController(
      durationSeconds: 1,
      clock: clock,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TimerExecutionScreen(
          activity: activity,
          configuration: configuration,
          countdownController: controller,
          persistence: _FakeTimerPersistence(),
        ),
      ),
    );

    await tester.tap(find.text('Iniciar'));
    clock.advance(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('¡Terminó el tiempo!'), findsOneWidget);
    expect(find.text('Repetir'), findsOneWidget);
    expect(find.text('Volver a mis actividades'), findsOneWidget);
    expect(controller.remainingSeconds, 0);
    expect(activity.toMap(), activityBefore);
    expect(activity.status, ActivityStatus.assigned);

    await tester.tap(find.text('Repetir'));
    await tester.pump();
    expect(find.text('00:01'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets('se pausa en segundo plano y no se reanuda automáticamente', (
    tester,
  ) async {
    final clock = FakeTimerMonotonicClock();
    final controller = TimerCountdownController(
      durationSeconds: 5,
      clock: clock,
    );
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 5),
        controller: controller,
      ),
    );

    await tester.tap(find.text('Iniciar'));
    clock.advance(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 150));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(clock.isRunning, isFalse);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('00:04'), findsOneWidget);

    clock.advance(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('00:04'), findsOneWidget);
    expect(clock.isRunning, isFalse);
  });

  testWidgets('libera reloj y ticker al salir de la pantalla', (tester) async {
    final clock = FakeTimerMonotonicClock();
    final controller = TimerCountdownController(
      durationSeconds: 5,
      clock: clock,
    );
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 5),
        controller: controller,
      ),
    );
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(clock.isRunning, isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 2));

    expect(clock.isRunning, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configuración inválida y status bloqueado no se ejecutan', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 0),
      ),
    );
    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
    expect(find.text('Iniciar'), findsNothing);

    await tester.pumpWidget(buildSubject(status: ActivityStatus.completed));
    await tester.pump();
    expect(find.text('No pudimos preparar esta actividad.'), findsOneWidget);
  });

  testWidgets('crea una sola sesión al pulsar Iniciar', (tester) async {
    final clock = FakeTimerMonotonicClock();
    final countdown = TimerCountdownController(
      durationSeconds: 5,
      clock: clock,
    );
    final persistence = _FakeTimerPersistence();
    final pendingStart = Completer<String>();
    persistence.pendingStart = pendingStart;
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 5),
        controller: countdown,
        persistence: persistence,
      ),
    );

    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(persistence.startCalls, 1);
    expect(clock.isRunning, isFalse);
    expect(find.text('Iniciando...'), findsOneWidget);

    pendingStart.complete('session-1');
    await tester.pump();
    await tester.pump();
    expect(persistence.startCalls, 1);
    expect(clock.isRunning, isTrue);
  });

  testWidgets('error de inicio permite reintentar sin adelantar el reloj', (
    tester,
  ) async {
    final clock = FakeTimerMonotonicClock();
    final countdown = TimerCountdownController(
      durationSeconds: 5,
      clock: clock,
    );
    final persistence = _FakeTimerPersistence()..startFailures = 1;
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 5),
        controller: countdown,
        persistence: persistence,
      ),
    );

    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    await tester.pump();
    expect(find.text('No pudimos iniciar la actividad.'), findsOneWidget);
    expect(clock.isRunning, isFalse);

    await tester.tap(find.text('Reintentar inicio'));
    await tester.pump();
    await tester.pump();
    expect(persistence.startCalls, 2);
    expect(clock.isRunning, isTrue);
  });

  testWidgets('expira una vez y persiste solo métricas agregadas', (
    tester,
  ) async {
    const configuration = TimerActivityConfig(durationSeconds: 2);
    final activity = _activity(configuration: configuration);
    final clock = FakeTimerMonotonicClock();
    final countdown = TimerCountdownController(
      durationSeconds: 2,
      clock: clock,
    );
    final persistence = _FakeTimerPersistence();
    await tester.pumpWidget(
      MaterialApp(
        home: TimerExecutionScreen(
          activity: activity,
          configuration: configuration,
          countdownController: countdown,
          persistence: persistence,
        ),
      ),
    );

    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    clock.advance(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(persistence.completeCalls, 1);
    expect(persistence.completedSessionIds, ['session-1']);
    expect(persistence.lastMetrics?.toMap(), {
      'configuredDurationSeconds': 2,
      'elapsedSeconds': 2,
    });
    expect(find.text('¡Terminó el tiempo!'), findsOneWidget);
    expect(activity.status, ActivityStatus.assigned);

    await tester.pump(const Duration(seconds: 2));
    expect(persistence.completeCalls, 1);
  });

  testWidgets('fallo de guardado reintenta sesión y métricas congeladas', (
    tester,
  ) async {
    final clock = FakeTimerMonotonicClock();
    final countdown = TimerCountdownController(
      durationSeconds: 1,
      clock: clock,
    );
    final persistence = _FakeTimerPersistence()..completeFailures = 1;
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 1),
        controller: countdown,
        persistence: persistence,
      ),
    );

    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    expect(find.text('Reintentar guardado'), findsOneWidget);
    await tester.tap(find.text('Reintentar guardado'));
    await tester.pump();
    await tester.pump();

    expect(persistence.startedSessionIds, ['session-1']);
    expect(persistence.completedSessionIds, ['session-1', 'session-1']);
    expect(persistence.lastMetrics?.elapsedSeconds, 1);
    expect(find.text('¡Terminó el tiempo!'), findsOneWidget);
  });

  testWidgets('cancelar salida restaura reloj y Atrás interrumpe', (
    tester,
  ) async {
    final clock = FakeTimerMonotonicClock();
    final countdown = TimerCountdownController(
      durationSeconds: 10,
      clock: clock,
    );
    final persistence = _FakeTimerPersistence();
    await tester.pumpWidget(_navigationSubject(persistence, countdown));
    await tester.tap(find.text('Abrir Timer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    expect(clock.isRunning, isTrue);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(clock.isRunning, isFalse);
    await tester.tap(find.text('Continuar aquí'));
    await tester.pump();
    await tester.pump();
    expect(clock.isRunning, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Salir de la actividad'), findsOneWidget);
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(persistence.interruptedSessionIds, ['session-1']);
    expect(persistence.completeCalls, 0);
    expect(find.text('Abrir Timer'), findsOneWidget);
  });

  testWidgets('Repetir prepara otra sesión al siguiente inicio', (
    tester,
  ) async {
    final clock = FakeTimerMonotonicClock();
    final countdown = TimerCountdownController(
      durationSeconds: 1,
      clock: clock,
    );
    final persistence = _FakeTimerPersistence();
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 1),
        controller: countdown,
        persistence: persistence,
      ),
    );

    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    await tester.tap(find.text('Repetir'));
    await tester.pump();

    expect(persistence.startCalls, 1);
    expect(find.text('Iniciar'), findsOneWidget);
    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    await tester.pump();
    expect(persistence.startedSessionIds, ['session-1', 'session-2']);
  });

  testWidgets('expiración al pausar lifecycle finaliza una sola vez', (
    tester,
  ) async {
    final clock = FakeTimerMonotonicClock();
    final countdown = TimerCountdownController(
      durationSeconds: 1,
      clock: clock,
    );
    final persistence = _FakeTimerPersistence();
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      buildSubject(
        configuration: const TimerActivityConfig(durationSeconds: 1),
        controller: countdown,
        persistence: persistence,
      ),
    );

    await tester.tap(find.text('Iniciar'));
    await tester.pump();
    clock.advance(const Duration(milliseconds: 1100));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();

    expect(persistence.completeCalls, 1);
    expect(persistence.lastMetrics?.elapsedSeconds, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(persistence.completeCalls, 1);
    expect(clock.isRunning, isFalse);
  });
}

class FakeTimerMonotonicClock implements TimerMonotonicClock {
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;

  @override
  Duration get elapsed => _elapsed;

  @override
  bool get isRunning => _isRunning;

  void advance(Duration duration) {
    if (_isRunning) _elapsed += duration;
  }

  @override
  void reset() => _elapsed = Duration.zero;

  @override
  void start() => _isRunning = true;

  @override
  void stop() => _isRunning = false;
}

ActivityModel _activity({
  required TimerActivityConfig configuration,
  ActivityStatus status = ActivityStatus.assigned,
}) {
  return ActivityModel(
    id: 'activity-id',
    therapyId: 'therapy-id',
    childId: 'child-id',
    psychologistId: 'psychologist-id',
    title: 'Práctica con tiempo',
    description: '',
    type: ActivityType.timer,
    difficulty: 1,
    instructions: 'Respira con calma.',
    configuration: configuration.toMap(),
    status: status,
    createdAt: DateTime(2026),
  );
}

Widget _navigationSubject(
  _FakeTimerPersistence persistence,
  TimerCountdownController countdown,
) {
  const configuration = TimerActivityConfig(durationSeconds: 10);
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => TimerExecutionScreen(
                  activity: _activity(configuration: configuration),
                  configuration: configuration,
                  countdownController: countdown,
                  persistence: persistence,
                ),
              ),
            ),
            child: const Text('Abrir Timer'),
          ),
        ),
      ),
    ),
  );
}

class _FakeTimerPersistence implements TimerExecutionPersistence {
  int startCalls = 0;
  int completeCalls = 0;
  int startFailures = 0;
  int completeFailures = 0;
  Completer<String>? pendingStart;
  TimerExecutionMetrics? lastMetrics;
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
    required TimerExecutionMetrics metrics,
  }) async {
    completeCalls++;
    completedSessionIds.add(sessionId);
    lastMetrics = metrics;
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
