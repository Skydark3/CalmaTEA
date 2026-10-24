import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/timer_execution_utils.dart';

void main() {
  group('formato del temporizador', () {
    test('formatea segundos y minutos', () {
      expect(formatTimerDuration(30), '00:30');
      expect(formatTimerDuration(90), '01:30');
    });

    test('formatea horas y nunca muestra valores negativos', () {
      expect(formatTimerDuration(3600), '01:00:00');
      expect(formatTimerDuration(7384), '02:03:04');
      expect(formatTimerDuration(-1), '00:00');
    });
  });

  test('cuenta por tiempo monotónico, pausa y continúa sin acelerarse', () {
    final clock = FakeTimerMonotonicClock();
    final controller = TimerCountdownController(
      durationSeconds: 3,
      clock: clock,
    );

    controller.start();
    clock.advance(const Duration(milliseconds: 1200));
    expect(controller.remainingSeconds, 2);

    controller.pause();
    clock.advance(const Duration(seconds: 5));
    expect(controller.remainingSeconds, 2);

    controller.start();
    clock.advance(const Duration(milliseconds: 800));
    expect(controller.remainingSeconds, 1);
  });

  test('reinicia la duración y limita el tiempo restante a cero', () {
    final clock = FakeTimerMonotonicClock();
    final controller = TimerCountdownController(
      durationSeconds: 1,
      clock: clock,
    );

    controller.start();
    clock.advance(const Duration(seconds: 4));
    expect(controller.remainingSeconds, 0);
    expect(controller.progress, 1);

    controller.reset();
    expect(controller.remainingSeconds, 1);
    expect(controller.progress, 0);
    expect(controller.isRunning, isFalse);
  });

  test('redondea segundos activos hacia arriba y limita al total', () {
    final clock = FakeTimerMonotonicClock();
    final controller = TimerCountdownController(
      durationSeconds: 3,
      clock: clock,
    );

    controller.start();
    clock.advance(const Duration(milliseconds: 1));
    expect(controller.elapsedSeconds, 1);
    clock.advance(const Duration(milliseconds: 999));
    expect(controller.elapsedSeconds, 1);
    clock.advance(const Duration(seconds: 5));
    expect(controller.elapsedSeconds, 3);
  });

  test('el tiempo activo excluye intervalos en pausa', () {
    final clock = FakeTimerMonotonicClock();
    final controller = TimerCountdownController(
      durationSeconds: 10,
      clock: clock,
    );

    controller.start();
    clock.advance(const Duration(milliseconds: 1200));
    controller.pause();
    clock.advance(const Duration(seconds: 20));
    expect(controller.elapsedSeconds, 2);

    controller.start();
    clock.advance(const Duration(milliseconds: 800));
    expect(controller.elapsedSeconds, 2);
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
