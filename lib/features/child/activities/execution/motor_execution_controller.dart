import 'package:flutter/foundation.dart';

import '../../../../models/activity_execution_result_model.dart';
import '../../../../models/activity_execution_session_model.dart';
import '../../../../services/activity_execution_result_service.dart';
import '../../../../services/activity_execution_session_service.dart';

enum MotorExecutionPersistenceState {
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

abstract interface class MotorExecutionPersistence {
  Future<String> startSession({required String activityId});

  Future<void> completeSession({
    required String sessionId,
    required MotorExecutionMetrics metrics,
  });

  Future<void> interruptSession(String sessionId);

  Future<ActivityExecutionSessionModel?> getSession(String sessionId);

  Future<ActivityExecutionResultModel?> getResult(String sessionId);
}

class MotorExecutionServicePersistence implements MotorExecutionPersistence {
  final ActivityExecutionSessionService _sessionService;
  final ActivityExecutionResultService _resultService;

  MotorExecutionServicePersistence({
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
    required MotorExecutionMetrics metrics,
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

class MotorExecutionController extends ChangeNotifier {
  final String activityId;
  final int stepsCount;
  final MotorExecutionPersistence _persistence;

  MotorExecutionPersistenceState _state = MotorExecutionPersistenceState.idle;
  String? _sessionId;
  final Set<int> _visitedStepIndexes = {};
  MotorExecutionMetrics? _pendingMetrics;
  bool _disposed = false;

  MotorExecutionController({
    required this.activityId,
    required this.stepsCount,
    required MotorExecutionPersistence persistence,
  }) : _persistence = persistence {
    if (activityId.trim().isEmpty) {
      throw ArgumentError.value(activityId, 'activityId', 'No puede vaciarse.');
    }
    if (stepsCount <= 0) {
      throw ArgumentError.value(
        stepsCount,
        'stepsCount',
        'Debe ser mayor que cero.',
      );
    }
  }

  MotorExecutionPersistenceState get state => _state;
  String? get sessionId => _sessionId;
  int get stepsVisited => _visitedStepIndexes.length;

  bool get isBusy =>
      _state == MotorExecutionPersistenceState.starting ||
      _state == MotorExecutionPersistenceState.saving ||
      _state == MotorExecutionPersistenceState.interrupting;

  Future<void> start() async {
    if (isBusy || _sessionId != null) return;
    _setState(MotorExecutionPersistenceState.starting);
    try {
      final createdSessionId = await _persistence.startSession(
        activityId: activityId,
      );
      if (createdSessionId.trim().isEmpty) {
        throw StateError('El servicio devolvió un sessionId vacío.');
      }
      _sessionId = createdSessionId;
      _visitedStepIndexes.add(0);
      _setState(MotorExecutionPersistenceState.ready);
    } catch (_) {
      _setState(MotorExecutionPersistenceState.startFailure);
    }
  }

  void visitStep(int stepIndex) {
    if (_state != MotorExecutionPersistenceState.ready) return;
    if (stepIndex < 0 || stepIndex >= stepsCount) {
      throw RangeError.range(stepIndex, 0, stepsCount - 1, 'stepIndex');
    }
    if (_visitedStepIndexes.add(stepIndex)) _notify();
  }

  Future<bool> finish() async {
    if (_state != MotorExecutionPersistenceState.ready ||
        _visitedStepIndexes.length != stepsCount) {
      return false;
    }

    _pendingMetrics = MotorExecutionMetrics(
      stepsVisited: _visitedStepIndexes.length,
    );
    return _completePendingResult();
  }

  Future<bool> retryCompletion() async {
    if (_state != MotorExecutionPersistenceState.completionFailure ||
        _pendingMetrics == null) {
      return false;
    }
    return _completePendingResult();
  }

  Future<bool> _completePendingResult() async {
    final currentSessionId = _sessionId;
    final metrics = _pendingMetrics;
    if (currentSessionId == null || metrics == null) return false;

    _setState(MotorExecutionPersistenceState.saving);
    try {
      await _persistence.completeSession(
        sessionId: currentSessionId,
        metrics: metrics,
      );
      _setState(MotorExecutionPersistenceState.completed);
      return true;
    } catch (_) {
      if (await _isCompletionPersisted(currentSessionId)) {
        _setState(MotorExecutionPersistenceState.completed);
        return true;
      }
      _setState(MotorExecutionPersistenceState.completionFailure);
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
          persistedMetrics is MotorExecutionMetrics &&
          persistedMetrics.stepsVisited == expectedMetrics.stepsVisited;
    } catch (_) {
      return false;
    }
  }

  Future<bool> interrupt() async {
    if (_state != MotorExecutionPersistenceState.ready &&
        _state != MotorExecutionPersistenceState.interruptionFailure) {
      return false;
    }
    final currentSessionId = _sessionId;
    if (currentSessionId == null) return false;

    _setState(MotorExecutionPersistenceState.interrupting);
    try {
      await _persistence.interruptSession(currentSessionId);
      _setState(MotorExecutionPersistenceState.interrupted);
      return true;
    } catch (_) {
      _setState(MotorExecutionPersistenceState.interruptionFailure);
      return false;
    }
  }

  Future<void> startNewExecution() async {
    if (_state != MotorExecutionPersistenceState.completed) return;
    _sessionId = null;
    _visitedStepIndexes.clear();
    _pendingMetrics = null;
    _setState(MotorExecutionPersistenceState.idle);
    await start();
  }

  void _setState(MotorExecutionPersistenceState value) {
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
