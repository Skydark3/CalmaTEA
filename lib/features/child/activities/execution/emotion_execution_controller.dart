import 'package:flutter/foundation.dart';

import '../../../../models/activity_execution_result_model.dart';
import '../../../../models/activity_execution_session_model.dart';
import '../../../../services/activity_execution_result_service.dart';
import '../../../../services/activity_execution_session_service.dart';

enum EmotionExecutionPersistenceState {
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

abstract interface class EmotionExecutionPersistence {
  Future<String> startSession({required String activityId});

  Future<void> completeSession({
    required String sessionId,
    required EmotionExecutionMetrics metrics,
  });

  Future<void> interruptSession(String sessionId);

  Future<ActivityExecutionSessionModel?> getSession(String sessionId);

  Future<ActivityExecutionResultModel?> getResult(String sessionId);
}

class EmotionExecutionServicePersistence
    implements EmotionExecutionPersistence {
  final ActivityExecutionSessionService _sessionService;
  final ActivityExecutionResultService _resultService;

  EmotionExecutionServicePersistence({
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
    required EmotionExecutionMetrics metrics,
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

class EmotionExecutionController extends ChangeNotifier {
  final String activityId;
  final int exercisesCount;
  final EmotionExecutionPersistence _persistence;

  EmotionExecutionPersistenceState _state =
      EmotionExecutionPersistenceState.idle;
  String? _sessionId;
  final Set<int> _reviewedExerciseIndexes = {};
  EmotionExecutionMetrics? _pendingMetrics;
  bool _disposed = false;

  EmotionExecutionController({
    required this.activityId,
    required this.exercisesCount,
    required EmotionExecutionPersistence persistence,
  }) : _persistence = persistence {
    if (activityId.trim().isEmpty) {
      throw ArgumentError.value(activityId, 'activityId', 'No puede vaciarse.');
    }
    if (exercisesCount <= 0) {
      throw ArgumentError.value(
        exercisesCount,
        'exercisesCount',
        'Debe ser mayor que cero.',
      );
    }
  }

  EmotionExecutionPersistenceState get state => _state;
  String? get sessionId => _sessionId;
  int get exercisesReviewed => _reviewedExerciseIndexes.length;

  bool get isBusy =>
      _state == EmotionExecutionPersistenceState.starting ||
      _state == EmotionExecutionPersistenceState.saving ||
      _state == EmotionExecutionPersistenceState.interrupting;

  Future<void> start() async {
    if (isBusy || _sessionId != null) return;
    _setState(EmotionExecutionPersistenceState.starting);
    try {
      final createdSessionId = await _persistence.startSession(
        activityId: activityId,
      );
      if (createdSessionId.trim().isEmpty) {
        throw StateError('El servicio devolvió un sessionId vacío.');
      }
      _sessionId = createdSessionId;
      _setState(EmotionExecutionPersistenceState.ready);
    } catch (_) {
      _setState(EmotionExecutionPersistenceState.startFailure);
    }
  }

  void markExerciseReviewed(int exerciseIndex) {
    if (_state != EmotionExecutionPersistenceState.ready) return;
    if (exerciseIndex < 0 || exerciseIndex >= exercisesCount) {
      throw RangeError.range(
        exerciseIndex,
        0,
        exercisesCount - 1,
        'exerciseIndex',
      );
    }
    if (_reviewedExerciseIndexes.add(exerciseIndex)) _notify();
  }

  Future<bool> finish() async {
    if (_state != EmotionExecutionPersistenceState.ready ||
        _reviewedExerciseIndexes.length != exercisesCount) {
      return false;
    }

    _pendingMetrics = EmotionExecutionMetrics(
      exercisesReviewed: _reviewedExerciseIndexes.length,
    );
    return _completePendingResult();
  }

  Future<bool> retryCompletion() async {
    if (_state != EmotionExecutionPersistenceState.completionFailure ||
        _pendingMetrics == null) {
      return false;
    }
    return _completePendingResult();
  }

  Future<bool> _completePendingResult() async {
    final currentSessionId = _sessionId;
    final metrics = _pendingMetrics;
    if (currentSessionId == null || metrics == null) return false;

    _setState(EmotionExecutionPersistenceState.saving);
    try {
      await _persistence.completeSession(
        sessionId: currentSessionId,
        metrics: metrics,
      );
      _setState(EmotionExecutionPersistenceState.completed);
      return true;
    } catch (_) {
      if (await _isCompletionPersisted(currentSessionId)) {
        _setState(EmotionExecutionPersistenceState.completed);
        return true;
      }
      _setState(EmotionExecutionPersistenceState.completionFailure);
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
          persistedMetrics is EmotionExecutionMetrics &&
          persistedMetrics.exercisesReviewed ==
              expectedMetrics.exercisesReviewed;
    } catch (_) {
      return false;
    }
  }

  Future<bool> interrupt() async {
    if (_state != EmotionExecutionPersistenceState.ready &&
        _state != EmotionExecutionPersistenceState.interruptionFailure) {
      return false;
    }
    final currentSessionId = _sessionId;
    if (currentSessionId == null) return false;

    _setState(EmotionExecutionPersistenceState.interrupting);
    try {
      await _persistence.interruptSession(currentSessionId);
      _setState(EmotionExecutionPersistenceState.interrupted);
      return true;
    } catch (_) {
      _setState(EmotionExecutionPersistenceState.interruptionFailure);
      return false;
    }
  }

  Future<void> startNewExecution() async {
    if (_state != EmotionExecutionPersistenceState.completed) return;
    _sessionId = null;
    _reviewedExerciseIndexes.clear();
    _pendingMetrics = null;
    _setState(EmotionExecutionPersistenceState.idle);
    await start();
  }

  void _setState(EmotionExecutionPersistenceState value) {
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
