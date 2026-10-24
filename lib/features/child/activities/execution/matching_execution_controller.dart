import 'package:flutter/foundation.dart';

import '../../../../models/activity_execution_result_model.dart';
import '../../../../models/activity_execution_session_model.dart';
import '../../../../services/activity_execution_result_service.dart';
import '../../../../services/activity_execution_session_service.dart';

enum MatchingExecutionPersistenceState {
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

abstract interface class MatchingExecutionPersistence {
  Future<String> startSession({required String activityId});

  Future<void> completeSession({
    required String sessionId,
    required MatchingExecutionMetrics metrics,
  });

  Future<void> interruptSession(String sessionId);

  Future<ActivityExecutionSessionModel?> getSession(String sessionId);

  Future<ActivityExecutionResultModel?> getResult(String sessionId);
}

class MatchingExecutionServicePersistence
    implements MatchingExecutionPersistence {
  final ActivityExecutionSessionService _sessionService;
  final ActivityExecutionResultService _resultService;

  MatchingExecutionServicePersistence({
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
    required MatchingExecutionMetrics metrics,
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

class MatchingExecutionController extends ChangeNotifier {
  final String activityId;
  final int relationsCount;
  final MatchingExecutionPersistence _persistence;

  MatchingExecutionPersistenceState _state =
      MatchingExecutionPersistenceState.idle;
  String? _sessionId;
  int _checksCount = 0;
  MatchingExecutionMetrics? _pendingMetrics;
  bool _disposed = false;

  MatchingExecutionController({
    required this.activityId,
    required this.relationsCount,
    required MatchingExecutionPersistence persistence,
  }) : _persistence = persistence {
    if (activityId.trim().isEmpty) {
      throw ArgumentError.value(activityId, 'activityId', 'No puede vaciarse.');
    }
    if (relationsCount <= 0) {
      throw ArgumentError.value(
        relationsCount,
        'relationsCount',
        'Debe ser mayor que cero.',
      );
    }
  }

  MatchingExecutionPersistenceState get state => _state;
  String? get sessionId => _sessionId;
  int get checksCount => _checksCount;

  bool get isBusy =>
      _state == MatchingExecutionPersistenceState.starting ||
      _state == MatchingExecutionPersistenceState.saving ||
      _state == MatchingExecutionPersistenceState.interrupting;

  Future<void> start() async {
    if (isBusy || _sessionId != null) return;
    _setState(MatchingExecutionPersistenceState.starting);
    try {
      final createdSessionId = await _persistence.startSession(
        activityId: activityId,
      );
      if (createdSessionId.trim().isEmpty) {
        throw StateError('El servicio devolvió un sessionId vacío.');
      }
      _sessionId = createdSessionId;
      _setState(MatchingExecutionPersistenceState.ready);
    } catch (_) {
      _setState(MatchingExecutionPersistenceState.startFailure);
    }
  }

  Future<bool> recordCheck({required int relationsCompleted}) async {
    if (_state != MatchingExecutionPersistenceState.ready) return false;
    if (relationsCompleted < 0 || relationsCompleted > relationsCount) {
      throw ArgumentError.value(
        relationsCompleted,
        'relationsCompleted',
        'Debe estar entre cero y el total de relaciones.',
      );
    }

    _checksCount++;
    _notify();
    if (relationsCompleted != relationsCount) return false;

    _pendingMetrics = MatchingExecutionMetrics(
      relationsCompleted: relationsCompleted,
      checksCount: _checksCount,
    );
    return _completePendingResult();
  }

  Future<bool> retryCompletion() async {
    if (_state != MatchingExecutionPersistenceState.completionFailure ||
        _pendingMetrics == null) {
      return false;
    }
    return _completePendingResult();
  }

  Future<bool> _completePendingResult() async {
    final currentSessionId = _sessionId;
    final metrics = _pendingMetrics;
    if (currentSessionId == null || metrics == null) return false;

    _setState(MatchingExecutionPersistenceState.saving);
    try {
      await _persistence.completeSession(
        sessionId: currentSessionId,
        metrics: metrics,
      );
      _setState(MatchingExecutionPersistenceState.completed);
      return true;
    } catch (_) {
      if (await _isCompletionPersisted(currentSessionId)) {
        _setState(MatchingExecutionPersistenceState.completed);
        return true;
      }
      _setState(MatchingExecutionPersistenceState.completionFailure);
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
          persistedMetrics is MatchingExecutionMetrics &&
          persistedMetrics.relationsCompleted ==
              expectedMetrics.relationsCompleted &&
          persistedMetrics.checksCount == expectedMetrics.checksCount;
    } catch (_) {
      return false;
    }
  }

  Future<bool> interrupt() async {
    if (_state != MatchingExecutionPersistenceState.ready &&
        _state != MatchingExecutionPersistenceState.interruptionFailure) {
      return false;
    }
    final currentSessionId = _sessionId;
    if (currentSessionId == null) return false;

    _setState(MatchingExecutionPersistenceState.interrupting);
    try {
      await _persistence.interruptSession(currentSessionId);
      _setState(MatchingExecutionPersistenceState.interrupted);
      return true;
    } catch (_) {
      _setState(MatchingExecutionPersistenceState.interruptionFailure);
      return false;
    }
  }

  Future<void> startNewExecution() async {
    if (_state != MatchingExecutionPersistenceState.completed) return;
    _sessionId = null;
    _checksCount = 0;
    _pendingMetrics = null;
    _setState(MatchingExecutionPersistenceState.idle);
    await start();
  }

  void _setState(MatchingExecutionPersistenceState value) {
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
