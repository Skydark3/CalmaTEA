import 'package:flutter/foundation.dart';

import '../../../../models/activity_execution_result_model.dart';
import '../../../../models/activity_execution_session_model.dart';
import '../../../../services/activity_execution_result_service.dart';
import '../../../../services/activity_execution_session_service.dart';

enum TracingExecutionPersistenceState {
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

abstract interface class TracingExecutionPersistence {
  Future<String> startSession({required String activityId});

  Future<void> completeSession({
    required String sessionId,
    required TracingExecutionMetrics metrics,
  });

  Future<void> interruptSession(String sessionId);

  Future<ActivityExecutionSessionModel?> getSession(String sessionId);

  Future<ActivityExecutionResultModel?> getResult(String sessionId);
}

class TracingExecutionServicePersistence
    implements TracingExecutionPersistence {
  final ActivityExecutionSessionService _sessionService;
  final ActivityExecutionResultService _resultService;

  TracingExecutionServicePersistence({
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
    required TracingExecutionMetrics metrics,
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

/// Persiste solo el total agregado de gestos de trazado finalizados.
///
/// Los puntos, coordenadas y representaciones del dibujo permanecen fuera de
/// este controlador y nunca forman parte de sus eventos ni de su estado.
class TracingExecutionController extends ChangeNotifier {
  final String activityId;
  final TracingExecutionPersistence _persistence;

  TracingExecutionPersistenceState _state =
      TracingExecutionPersistenceState.idle;
  String? _sessionId;
  int _strokesCount = 0;
  TracingExecutionMetrics? _pendingMetrics;
  bool _disposed = false;

  TracingExecutionController({
    required this.activityId,
    required TracingExecutionPersistence persistence,
  }) : _persistence = persistence {
    if (activityId.trim().isEmpty) {
      throw ArgumentError.value(activityId, 'activityId', 'No puede vaciarse.');
    }
  }

  TracingExecutionPersistenceState get state => _state;
  String? get sessionId => _sessionId;
  int get strokesCount => _strokesCount;

  bool get isBusy =>
      _state == TracingExecutionPersistenceState.starting ||
      _state == TracingExecutionPersistenceState.saving ||
      _state == TracingExecutionPersistenceState.interrupting;

  Future<void> start() async {
    if (isBusy || _sessionId != null) return;
    _setState(TracingExecutionPersistenceState.starting);
    try {
      final createdSessionId = await _persistence.startSession(
        activityId: activityId,
      );
      if (createdSessionId.trim().isEmpty) {
        throw StateError('El servicio devolvió un sessionId vacío.');
      }
      _sessionId = createdSessionId;
      _setState(TracingExecutionPersistenceState.ready);
    } catch (_) {
      _setState(TracingExecutionPersistenceState.startFailure);
    }
  }

  /// Registra un gesto ya finalizado; no recibe ni conserva sus puntos.
  void recordCompletedStroke() {
    if (_state != TracingExecutionPersistenceState.ready) return;
    _strokesCount++;
    _notify();
  }

  Future<bool> finish() async {
    if (_state != TracingExecutionPersistenceState.ready ||
        _strokesCount <= 0) {
      return false;
    }

    _pendingMetrics = TracingExecutionMetrics(
      practiceCompleted: true,
      strokesCount: _strokesCount,
    );
    return _completePendingResult();
  }

  Future<bool> retryCompletion() async {
    if (_state != TracingExecutionPersistenceState.completionFailure ||
        _pendingMetrics == null) {
      return false;
    }
    return _completePendingResult();
  }

  Future<bool> _completePendingResult() async {
    final currentSessionId = _sessionId;
    final metrics = _pendingMetrics;
    if (currentSessionId == null || metrics == null) return false;

    _setState(TracingExecutionPersistenceState.saving);
    try {
      await _persistence.completeSession(
        sessionId: currentSessionId,
        metrics: metrics,
      );
      _setState(TracingExecutionPersistenceState.completed);
      return true;
    } catch (_) {
      if (await _isCompletionPersisted(currentSessionId)) {
        _setState(TracingExecutionPersistenceState.completed);
        return true;
      }
      _setState(TracingExecutionPersistenceState.completionFailure);
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
          persistedMetrics is TracingExecutionMetrics &&
          persistedMetrics.practiceCompleted ==
              expectedMetrics.practiceCompleted &&
          persistedMetrics.strokesCount == expectedMetrics.strokesCount;
    } catch (_) {
      return false;
    }
  }

  Future<bool> interrupt() async {
    if (_state != TracingExecutionPersistenceState.ready &&
        _state != TracingExecutionPersistenceState.interruptionFailure) {
      return false;
    }
    final currentSessionId = _sessionId;
    if (currentSessionId == null) return false;

    _setState(TracingExecutionPersistenceState.interrupting);
    try {
      await _persistence.interruptSession(currentSessionId);
      _setState(TracingExecutionPersistenceState.interrupted);
      return true;
    } catch (_) {
      _setState(TracingExecutionPersistenceState.interruptionFailure);
      return false;
    }
  }

  Future<void> startNewExecution() async {
    if (_state != TracingExecutionPersistenceState.completed) return;
    _sessionId = null;
    _strokesCount = 0;
    _pendingMetrics = null;
    _setState(TracingExecutionPersistenceState.idle);
    await start();
  }

  void _setState(TracingExecutionPersistenceState value) {
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
