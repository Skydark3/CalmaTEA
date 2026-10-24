abstract interface class TimerMonotonicClock {
  Duration get elapsed;
  bool get isRunning;

  void start();
  void stop();
  void reset();
}

class StopwatchTimerMonotonicClock implements TimerMonotonicClock {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  bool get isRunning => _stopwatch.isRunning;

  @override
  void start() => _stopwatch.start();

  @override
  void stop() => _stopwatch.stop();

  @override
  void reset() => _stopwatch.reset();
}

class TimerCountdownController {
  final int totalSeconds;
  final TimerMonotonicClock _clock;
  Duration _elapsedBeforeCurrentRun = Duration.zero;

  TimerCountdownController({
    required int durationSeconds,
    TimerMonotonicClock? clock,
  }) : totalSeconds = durationSeconds < 0 ? 0 : durationSeconds,
       _clock = clock ?? StopwatchTimerMonotonicClock();

  bool get isRunning => _clock.isRunning;

  Duration get elapsed =>
      _elapsedBeforeCurrentRun +
      (_clock.isRunning ? _clock.elapsed : Duration.zero);

  int get remainingSeconds {
    final totalMilliseconds = totalSeconds * 1000;
    final remainingMilliseconds = totalMilliseconds - elapsed.inMilliseconds;
    if (remainingMilliseconds <= 0) return 0;
    return (remainingMilliseconds + 999) ~/ 1000;
  }

  double get progress {
    if (totalSeconds <= 0) return 1;
    final totalMilliseconds = totalSeconds * 1000;
    final elapsedMilliseconds = elapsed.inMilliseconds.clamp(
      0,
      totalMilliseconds,
    );
    return elapsedMilliseconds / totalMilliseconds;
  }

  bool get isFinished => remainingSeconds == 0;

  /// Segundos activos redondeados hacia arriba y limitados a la duración.
  int get elapsedSeconds {
    if (elapsed.inMilliseconds <= 0 || totalSeconds <= 0) return 0;
    final roundedUp = (elapsed.inMilliseconds + 999) ~/ 1000;
    return roundedUp.clamp(0, totalSeconds);
  }

  void start() {
    if (isRunning || isFinished) return;
    _clock.reset();
    _clock.start();
  }

  void pause() {
    if (!isRunning) return;
    _elapsedBeforeCurrentRun += _clock.elapsed;
    _clock.stop();
    _clock.reset();
  }

  void reset() {
    _clock.stop();
    _clock.reset();
    _elapsedBeforeCurrentRun = Duration.zero;
  }

  void dispose() => reset();
}

String formatTimerDuration(int totalSeconds) {
  final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;
  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = seconds.toString().padLeft(2, '0');

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minuteText:$secondText';
  }
  return '$minuteText:$secondText';
}
