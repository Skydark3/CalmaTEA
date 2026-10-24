import 'package:flutter/foundation.dart';

import '../../../../models/activity_execution_result_model.dart';
import '../../../../models/activity_execution_session_model.dart';
import '../../../../services/activity_execution_result_service.dart';
import '../../../../services/activity_execution_session_service.dart';

enum PictogramExecutionPersistenceState {
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

abstract interface class PictogramExecutionPersistence {
  Future<String> startSession({required String activityId});

  Future<void> completeSession({
    required String sessionId,
    required PictogramExecutionMetrics metrics,
  });

  Future<void> interruptSession(String sessionId);

  Future<ActivityExecutionSessionModel?> getSession(String sessionId);

  Future<ActivityExecutionResultModel?> getResult(String sessionId);
}

class PictogramExecutionServicePersistence
    implements PictogramExecutionPersistence {
  final ActivityExecutionSessionService _sessionService;
  final ActivityExecutionResultService _resultService;

  PictogramExecutionServicePersistence({
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
    required PictogramExecutionMetrics metrics,
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

class PictogramExecutionController extends ChangeNotifier {
  final String activityId;
  final PictogramExecutionPersistence _persistence;

  PictogramExecutionPersistenceState _state =
      PictogramExecutionPersistenceState.idle;
  String? _sessionId;
  int _interactionsCount = 0;
  PictogramExecutionMetrics? _pendingMetrics;
  bool _disposed = false;

  PictogramExecutionController({
    required this.activityId,
    required PictogramExecutionPersistence persistence,
  }) : _persistence = persistence {
    if (activityId.trim().isEmpty) {
      throw ArgumentError.value(activityId, 'activityId', 'No puede vaciarse.');
    }
  }

  PictogramExecutionPersistenceState get state => _state;
  String? get sessionId => _sessionId;
  int get interactionsCount => _interactionsCount;

  bool get isBusy =>
      _state == PictogramExecutionPersistenceState.starting ||
      _state == PictogramExecutionPersistenceState.saving ||
      _state == PictogramExecutionPersistenceState.interrupting;

  Future<void> start() async {
    if (isBusy || _sessionId != null) return;
    _setState(PictogramExecutionPersistenceState.starting);
    try {
      final createdSessionId = await _persistence.startSession(
        activityId: activityId,
      );
      if (createdSessionId.trim().isEmpty) {
        throw StateError('El servicio devolvió un sessionId vacío.');
      }
      _sessionId = createdSessionId;
      _setState(PictogramExecutionPersistenceState.ready);
    } catch (_) {
      _setState(PictogramExecutionPersistenceState.startFailure);
    }
  }

  void recordInteraction() {
    if (_state != PictogramExecutionPersistenceState.ready) return;
    _interactionsCount++;
    _notify();
  }

  Future<bool> finish() async {
    if (_state != PictogramExecutionPersistenceState.ready ||
        _interactionsCount <= 0) {
      return false;
    }

    _pendingMetrics = PictogramExecutionMetrics(
      interactionsCount: _interactionsCount,
    );
    return _completePendingResult();
  }

  Future<bool> retryCompletion() async {
    if (_state != PictogramExecutionPersistenceState.completionFailure ||
        _pendingMetrics == null) {
      return false;
    }
    return _completePendingResult();
  }

  Future<bool> _completePendingResult() async {
    final currentSessionId = _sessionId;
    final metrics = _pendingMetrics;
    if (currentSessionId == null || metrics == null) return false;

    _setState(PictogramExecutionPersistenceState.saving);
    try {
      await _persistence.completeSession(
        sessionId: currentSessionId,
        metrics: metrics,
      );
      _setState(PictogramExecutionPersistenceState.completed);
      return true;
    } catch (_) {
      if (await _isCompletionPersisted(currentSessionId)) {
        _setState(PictogramExecutionPersistenceState.completed);
        return true;
      }
      _setState(PictogramExecutionPersistenceState.completionFailure);
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
          persistedMetrics is PictogramExecutionMetrics &&
          persistedMetrics.interactionsCount ==
              expectedMetrics.interactionsCount;
    } catch (_) {
      return false;
    }
  }

  Future<bool> interrupt() async {
    if (_state != PictogramExecutionPersistenceState.ready &&
        _state != PictogramExecutionPersistenceState.interruptionFailure) {
      return false;
    }
    final currentSessionId = _sessionId;
    if (currentSessionId == null) return false;

    _setState(PictogramExecutionPersistenceState.interrupting);
    try {
      await _persistence.interruptSession(currentSessionId);
      _setState(PictogramExecutionPersistenceState.interrupted);
      return true;
    } catch (_) {
      _setState(PictogramExecutionPersistenceState.interruptionFailure);
      return false;
    }
  }

  Future<void> startNewExecution() async {
    if (_state != PictogramExecutionPersistenceState.completed) return;
    _sessionId = null;
    _interactionsCount = 0;
    _pendingMetrics = null;
    _setState(PictogramExecutionPersistenceState.idle);
    await start();
  }

  void _setState(PictogramExecutionPersistenceState value) {
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
