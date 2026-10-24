import 'package:flutter/foundation.dart';

import '../../../../models/activity_execution_result_model.dart';
import '../../../../models/activity_execution_session_model.dart';
import '../../../../services/activity_execution_result_service.dart';
import '../../../../services/activity_execution_session_service.dart';

enum TimerExecutionPersistenceState {
  idle,
  starting,
  ready,
  saving,
  completed,
  startFailure,
  completionFailure,
  interrupting,
  interruptionFailure,
  interrupted,
}

abstract interface class TimerExecutionPersistence {
  Future<String> startSession({required String activityId});

  Future<void> completeSession({
    required String sessionId,
    required TimerExecutionMetrics metrics,
  });

  Future<void> interruptSession(String sessionId);

  Future<ActivityExecutionSessionModel?> getSession(String sessionId);

  Future<ActivityExecutionResultModel?> getResult(String sessionId);
}

class TimerExecutionServicePersistence implements TimerExecutionPersistence {
  final ActivityExecutionSessionService _sessionService;
  final ActivityExecutionResultService _resultService;

  TimerExecutionServicePersistence({
    ActivityExecutionSessionService? sessionService,
    ActivityExecutionResultService? resultService,
  }) : _sessionService = sessionService ?? ActivityExecutionSessionService(),
       _resultService = resultService ?? ActivityExecutionResultService();

  @override
  Future<String> startSession({required String activityId}) {
    return _sessionService.startSession(activityId: activityId);
  }

  @override
  Future<void> completeSession({
    required String sessionId,
    required TimerExecutionMetrics metrics,
  }) {
    return _sessionService.completeSession(
      sessionId: sessionId,
      metrics: metrics,
    );
  }

  @override
  Future<void> interruptSession(String sessionId) {
    return _sessionService.interruptSession(sessionId);
  }

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) {
    return _sessionService.getOwnSession(sessionId);
  }

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) {
    return _resultService.getOwnResult(sessionId);
  }
}

class TimerExecutionController extends ChangeNotifier {
  final String activityId;
  final TimerExecutionPersistence _persistence;

  TimerExecutionPersistenceState _state = TimerExecutionPersistenceState.idle;
  String? _sessionId;
  TimerExecutionMetrics? _pendingMetrics;
  bool _disposed = false;

  TimerExecutionController({
    required this.activityId,
    required TimerExecutionPersistence persistence,
  }) : _persistence = persistence {
    if (activityId.trim().isEmpty) {
      throw ArgumentError.value(activityId, 'activityId', 'No puede vaciarse.');
    }
  }

  TimerExecutionPersistenceState get state => _state;
  String? get sessionId => _sessionId;
  TimerExecutionMetrics? get pendingMetrics => _pendingMetrics;

  bool get isBusy =>
      _state == TimerExecutionPersistenceState.starting ||
      _state == TimerExecutionPersistenceState.saving ||
      _state == TimerExecutionPersistenceState.interrupting;

  Future<bool> start() async {
    if (isBusy || _sessionId != null) return false;
    _setState(TimerExecutionPersistenceState.starting);
    try {
      final createdSessionId = await _persistence.startSession(
        activityId: activityId,
      );
      if (createdSessionId.trim().isEmpty) {
        throw StateError('El servicio devolvió un sessionId vacío.');
      }
      _sessionId = createdSessionId;
      _setState(TimerExecutionPersistenceState.ready);
      return true;
    } catch (_) {
      _setState(TimerExecutionPersistenceState.startFailure);
      return false;
    }
  }

  Future<bool> finish({
    required int configuredDurationSeconds,
    required int elapsedSeconds,
  }) async {
    if (_state != TimerExecutionPersistenceState.ready) return false;
    _pendingMetrics = TimerExecutionMetrics(
      configuredDurationSeconds: configuredDurationSeconds,
      elapsedSeconds: elapsedSeconds,
    );
    return _completePendingResult();
  }

  Future<bool> retryCompletion() async {
    if (_state != TimerExecutionPersistenceState.completionFailure ||
        _pendingMetrics == null) {
      return false;
    }
    return _completePendingResult();
  }

  Future<bool> _completePendingResult() async {
    final currentSessionId = _sessionId;
    final metrics = _pendingMetrics;
    if (currentSessionId == null || metrics == null) return false;

    _setState(TimerExecutionPersistenceState.saving);
    try {
      await _persistence.completeSession(
        sessionId: currentSessionId,
        metrics: metrics,
      );
      _setState(TimerExecutionPersistenceState.completed);
      return true;
    } catch (_) {
      if (await _isCompletionPersisted(currentSessionId)) {
        _setState(TimerExecutionPersistenceState.completed);
        return true;
      }
      _setState(TimerExecutionPersistenceState.completionFailure);
      return false;
    }
  }

  Future<bool> _isCompletionPersisted(String currentSessionId) async {
    try {
      final session = await _persistence.getSession(currentSessionId);
      final result = await _persistence.getResult(currentSessionId);
      final expectedMetrics = _pendingMetrics;
      final persistedMetrics = result?.metrics;
      return session?.status == ActivityExecutionSessionStatus.completed &&
          session?.id == currentSessionId &&
          session?.activityId == activityId &&
          result?.id == currentSessionId &&
          result?.activityId == activityId &&
          expectedMetrics != null &&
          result?.activityType == expectedMetrics.activityType &&
          persistedMetrics is TimerExecutionMetrics &&
          persistedMetrics.configuredDurationSeconds ==
              expectedMetrics.configuredDurationSeconds &&
          persistedMetrics.elapsedSeconds == expectedMetrics.elapsedSeconds;
    } catch (_) {
      return false;
    }
  }

  Future<bool> interrupt() async {
    if (_state != TimerExecutionPersistenceState.ready &&
        _state != TimerExecutionPersistenceState.interruptionFailure) {
      return false;
    }
    final currentSessionId = _sessionId;
    if (currentSessionId == null) return false;

    _setState(TimerExecutionPersistenceState.interrupting);
    try {
      await _persistence.interruptSession(currentSessionId);
      _setState(TimerExecutionPersistenceState.interrupted);
      return true;
    } catch (_) {
      _setState(TimerExecutionPersistenceState.interruptionFailure);
      return false;
    }
  }

  void resetForNewExecution() {
    if (_state != TimerExecutionPersistenceState.completed) return;
    _sessionId = null;
    _pendingMetrics = null;
    _setState(TimerExecutionPersistenceState.idle);
  }

  void _setState(TimerExecutionPersistenceState value) {
    _state = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
