import 'package:flutter/foundation.dart';

import '../../../../models/activity_execution_result_model.dart';
import '../../../../models/activity_execution_session_model.dart';
import '../../../../services/activity_execution_result_service.dart';
import '../../../../services/activity_execution_session_service.dart';

enum DragDropExecutionPersistenceState {
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

abstract interface class DragDropExecutionPersistence {
  Future<String> startSession({required String activityId});

  Future<void> completeSession({
    required String sessionId,
    required DragDropExecutionMetrics metrics,
  });

  Future<void> interruptSession(String sessionId);

  Future<ActivityExecutionSessionModel?> getSession(String sessionId);

  Future<ActivityExecutionResultModel?> getResult(String sessionId);
}

class DragDropExecutionServicePersistence
    implements DragDropExecutionPersistence {
  final ActivityExecutionSessionService _sessionService;
  final ActivityExecutionResultService _resultService;

  DragDropExecutionServicePersistence({
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
    required DragDropExecutionMetrics metrics,
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

class DragDropExecutionController extends ChangeNotifier {
  final String activityId;
  final Set<String> _configuredItemIds;
  final DragDropExecutionPersistence _persistence;

  DragDropExecutionPersistenceState _state =
      DragDropExecutionPersistenceState.idle;
  String? _sessionId;
  final Set<String> _placedItemIds = {};
  int _checksCount = 0;
  DragDropExecutionMetrics? _pendingMetrics;
  bool _disposed = false;

  DragDropExecutionController({
    required this.activityId,
    required Iterable<String> itemIds,
    required DragDropExecutionPersistence persistence,
  }) : _configuredItemIds = Set.unmodifiable(itemIds),
       _persistence = persistence {
    if (activityId.trim().isEmpty) {
      throw ArgumentError.value(activityId, 'activityId', 'No puede vaciarse.');
    }
    if (_configuredItemIds.isEmpty ||
        _configuredItemIds.any((itemId) => itemId.trim().isEmpty)) {
      throw ArgumentError.value(
        itemIds,
        'itemIds',
        'Debe contener identificadores válidos.',
      );
    }
  }

  DragDropExecutionPersistenceState get state => _state;
  String? get sessionId => _sessionId;
  int get itemsPlaced => _placedItemIds.length;
  int get checksCount => _checksCount;

  bool get isBusy =>
      _state == DragDropExecutionPersistenceState.starting ||
      _state == DragDropExecutionPersistenceState.saving ||
      _state == DragDropExecutionPersistenceState.interrupting;

  Future<void> start() async {
    if (isBusy || _sessionId != null) return;
    _setState(DragDropExecutionPersistenceState.starting);
    try {
      final createdSessionId = await _persistence.startSession(
        activityId: activityId,
      );
      if (createdSessionId.trim().isEmpty) {
        throw StateError('El servicio devolvió un sessionId vacío.');
      }
      _sessionId = createdSessionId;
      _setState(DragDropExecutionPersistenceState.ready);
    } catch (_) {
      _setState(DragDropExecutionPersistenceState.startFailure);
    }
  }

  bool registerCheck({required String itemId, required bool isCorrect}) {
    if (_state != DragDropExecutionPersistenceState.ready) return false;
    if (!_configuredItemIds.contains(itemId)) {
      throw ArgumentError.value(itemId, 'itemId', 'Elemento no configurado.');
    }
    if (_placedItemIds.contains(itemId)) return false;

    _checksCount++;
    if (isCorrect) _placedItemIds.add(itemId);
    _notify();
    return isCorrect;
  }

  Future<bool> finish() async {
    if (_state != DragDropExecutionPersistenceState.ready ||
        _placedItemIds.length != _configuredItemIds.length) {
      return false;
    }

    _pendingMetrics = DragDropExecutionMetrics(
      itemsPlaced: _placedItemIds.length,
      checksCount: _checksCount,
    );
    return _completePendingResult();
  }

  Future<bool> retryCompletion() async {
    if (_state != DragDropExecutionPersistenceState.completionFailure ||
        _pendingMetrics == null) {
      return false;
    }
    return _completePendingResult();
  }

  Future<bool> _completePendingResult() async {
    final currentSessionId = _sessionId;
    final metrics = _pendingMetrics;
    if (currentSessionId == null || metrics == null) return false;

    _setState(DragDropExecutionPersistenceState.saving);
    try {
      await _persistence.completeSession(
        sessionId: currentSessionId,
        metrics: metrics,
      );
      _setState(DragDropExecutionPersistenceState.completed);
      return true;
    } catch (_) {
      if (await _isCompletionPersisted(currentSessionId)) {
        _setState(DragDropExecutionPersistenceState.completed);
        return true;
      }
      _setState(DragDropExecutionPersistenceState.completionFailure);
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
          persistedMetrics is DragDropExecutionMetrics &&
          persistedMetrics.itemsPlaced == expectedMetrics.itemsPlaced &&
          persistedMetrics.checksCount == expectedMetrics.checksCount;
    } catch (_) {
      return false;
    }
  }

  Future<bool> interrupt() async {
    if (_state != DragDropExecutionPersistenceState.ready &&
        _state != DragDropExecutionPersistenceState.interruptionFailure) {
      return false;
    }
    final currentSessionId = _sessionId;
    if (currentSessionId == null) return false;

    _setState(DragDropExecutionPersistenceState.interrupting);
    try {
      await _persistence.interruptSession(currentSessionId);
      _setState(DragDropExecutionPersistenceState.interrupted);
      return true;
    } catch (_) {
      _setState(DragDropExecutionPersistenceState.interruptionFailure);
      return false;
    }
  }

  Future<void> startNewExecution() async {
    if (_state != DragDropExecutionPersistenceState.completed) return;
    _sessionId = null;
    _placedItemIds.clear();
    _checksCount = 0;
    _pendingMetrics = null;
    _setState(DragDropExecutionPersistenceState.idle);
    await start();
  }

  void _setState(DragDropExecutionPersistenceState value) {
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
