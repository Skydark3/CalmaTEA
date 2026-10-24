import 'package:flutter/foundation.dart';

import '../../../../models/activity_execution_result_model.dart';
import '../../../../models/activity_execution_session_model.dart';
import '../../../../services/activity_execution_result_service.dart';
import '../../../../services/activity_execution_session_service.dart';

enum SequenceExecutionPersistenceState {
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

abstract interface class SequenceExecutionPersistence {
  Future<String> startSession({required String activityId});

  Future<void> completeSession({
    required String sessionId,
    required SequenceExecutionMetrics metrics,
  });

  Future<void> interruptSession(String sessionId);

  Future<ActivityExecutionSessionModel?> getSession(String sessionId);

  Future<ActivityExecutionResultModel?> getResult(String sessionId);
}

class SequenceExecutionServicePersistence
    implements SequenceExecutionPersistence {
  final ActivityExecutionSessionService _sessionService;
  final ActivityExecutionResultService _resultService;

  SequenceExecutionServicePersistence({
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
    required SequenceExecutionMetrics metrics,
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

class SequenceExecutionController extends ChangeNotifier {
  final String activityId;
  final int itemsCount;
  final SequenceExecutionPersistence _persistence;

  SequenceExecutionPersistenceState _state =
      SequenceExecutionPersistenceState.idle;
  String? _sessionId;
  int _checksCount = 0;
  SequenceExecutionMetrics? _pendingMetrics;
  bool _disposed = false;

  SequenceExecutionController({
    required this.activityId,
    required this.itemsCount,
    required SequenceExecutionPersistence persistence,
  }) : _persistence = persistence {
    if (activityId.trim().isEmpty) {
      throw ArgumentError.value(activityId, 'activityId', 'No puede vaciarse.');
    }
    if (itemsCount <= 0) {
      throw ArgumentError.value(
        itemsCount,
        'itemsCount',
        'Debe ser mayor que cero.',
      );
    }
  }

  SequenceExecutionPersistenceState get state => _state;
  String? get sessionId => _sessionId;
  int get checksCount => _checksCount;

  bool get isBusy =>
      _state == SequenceExecutionPersistenceState.starting ||
      _state == SequenceExecutionPersistenceState.saving ||
      _state == SequenceExecutionPersistenceState.interrupting;

  Future<void> start() async {
    if (isBusy || _sessionId != null) return;
    _setState(SequenceExecutionPersistenceState.starting);
    try {
      final createdSessionId = await _persistence.startSession(
        activityId: activityId,
      );
      if (createdSessionId.trim().isEmpty) {
        throw StateError('El servicio devolvio un sessionId vacio.');
      }
      _sessionId = createdSessionId;
      _setState(SequenceExecutionPersistenceState.ready);
    } catch (_) {
      _setState(SequenceExecutionPersistenceState.startFailure);
    }
  }

  Future<bool> checkOrder({required bool isCorrect}) async {
    if (_state != SequenceExecutionPersistenceState.ready) return false;
    _checksCount++;
    _notify();
    if (!isCorrect) return false;

    _pendingMetrics = SequenceExecutionMetrics(
      itemsCount: itemsCount,
      checksCount: _checksCount,
    );
    return _completePendingResult();
  }

  Future<bool> retryCompletion() async {
    if (_state != SequenceExecutionPersistenceState.completionFailure ||
        _pendingMetrics == null) {
      return false;
    }
    return _completePendingResult();
  }

  Future<bool> _completePendingResult() async {
    final currentSessionId = _sessionId;
    final metrics = _pendingMetrics;
    if (currentSessionId == null || metrics == null) return false;

    _setState(SequenceExecutionPersistenceState.saving);
    try {
      await _persistence.completeSession(
        sessionId: currentSessionId,
        metrics: metrics,
      );
      _setState(SequenceExecutionPersistenceState.completed);
      return true;
    } catch (_) {
      if (await _isCompletionPersisted(currentSessionId)) {
        _setState(SequenceExecutionPersistenceState.completed);
        return true;
      }
      _setState(SequenceExecutionPersistenceState.completionFailure);
      return false;
    }
  }

  Future<bool> _isCompletionPersisted(String currentSessionId) async {
    try {
      final session = await _persistence.getSession(currentSessionId);
      final result = await _persistence.getResult(currentSessionId);
      final expectedType = _pendingMetrics?.activityType;
      return session?.status == ActivityExecutionSessionStatus.completed &&
          session?.id == currentSessionId &&
          session?.activityId == activityId &&
          result?.id == currentSessionId &&
          result?.activityId == activityId &&
          expectedType != null &&
          result?.activityType == expectedType;
    } catch (_) {
      return false;
    }
  }

  Future<bool> interrupt() async {
    if (_state != SequenceExecutionPersistenceState.ready &&
        _state != SequenceExecutionPersistenceState.interruptionFailure) {
      return false;
    }
    final currentSessionId = _sessionId;
    if (currentSessionId == null) return false;

    _setState(SequenceExecutionPersistenceState.interrupting);
    try {
      await _persistence.interruptSession(currentSessionId);
      _setState(SequenceExecutionPersistenceState.interrupted);
      return true;
    } catch (_) {
      _setState(SequenceExecutionPersistenceState.interruptionFailure);
      return false;
    }
  }

  Future<void> startNewExecution() async {
    if (_state != SequenceExecutionPersistenceState.completed) return;
    _sessionId = null;
    _checksCount = 0;
    _pendingMetrics = null;
    _setState(SequenceExecutionPersistenceState.idle);
    await start();
  }

  void _setState(SequenceExecutionPersistenceState value) {
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
