import '../../../../models/activity_execution_result_model.dart';
import '../../../../models/activity_execution_session_model.dart';
import 'drag_drop_execution_controller.dart';
import 'emotion_execution_controller.dart';
import 'matching_execution_controller.dart';
import 'motor_execution_controller.dart';
import 'pictogram_execution_controller.dart';
import 'sequence_execution_controller.dart';
import 'timer_execution_controller.dart';
import 'tracing_execution_controller.dart';

/// Ciclo de vida efímero para Preview.
///
/// No contiene servicios Firebase ni conserva sesiones o resultados. El token
/// local solo permite que los controladores existentes ejecuten su flujo de UI.
abstract interface class ActivityPreviewPersistenceLifecycle {
  Future<String> startSession({required String activityId});

  Future<void> interruptSession(String sessionId);

  Future<ActivityExecutionSessionModel?> getSession(String sessionId);

  Future<ActivityExecutionResultModel?> getResult(String sessionId);
}

abstract class _ActivityPreviewPersistenceBase
    implements ActivityPreviewPersistenceLifecycle {
  static int _nextSession = 0;

  @override
  Future<String> startSession({required String activityId}) async {
    _nextSession++;
    return 'preview-session-$_nextSession';
  }

  @override
  Future<void> interruptSession(String sessionId) async {}

  @override
  Future<ActivityExecutionSessionModel?> getSession(String sessionId) async {
    return null;
  }

  @override
  Future<ActivityExecutionResultModel?> getResult(String sessionId) async {
    return null;
  }
}

class SequencePreviewPersistence extends _ActivityPreviewPersistenceBase
    implements SequenceExecutionPersistence {
  @override
  Future<void> completeSession({
    required String sessionId,
    required SequenceExecutionMetrics metrics,
  }) async {}
}

class MatchingPreviewPersistence extends _ActivityPreviewPersistenceBase
    implements MatchingExecutionPersistence {
  @override
  Future<void> completeSession({
    required String sessionId,
    required MatchingExecutionMetrics metrics,
  }) async {}
}

class EmotionPreviewPersistence extends _ActivityPreviewPersistenceBase
    implements EmotionExecutionPersistence {
  @override
  Future<void> completeSession({
    required String sessionId,
    required EmotionExecutionMetrics metrics,
  }) async {}
}

class PictogramPreviewPersistence extends _ActivityPreviewPersistenceBase
    implements PictogramExecutionPersistence {
  @override
  Future<void> completeSession({
    required String sessionId,
    required PictogramExecutionMetrics metrics,
  }) async {}
}

class DragDropPreviewPersistence extends _ActivityPreviewPersistenceBase
    implements DragDropExecutionPersistence {
  @override
  Future<void> completeSession({
    required String sessionId,
    required DragDropExecutionMetrics metrics,
  }) async {}
}

class TimerPreviewPersistence extends _ActivityPreviewPersistenceBase
    implements TimerExecutionPersistence {
  @override
  Future<void> completeSession({
    required String sessionId,
    required TimerExecutionMetrics metrics,
  }) async {}
}

class TracingPreviewPersistence extends _ActivityPreviewPersistenceBase
    implements TracingExecutionPersistence {
  @override
  Future<void> completeSession({
    required String sessionId,
    required TracingExecutionMetrics metrics,
  }) async {}
}

class MotorPreviewPersistence extends _ActivityPreviewPersistenceBase
    implements MotorExecutionPersistence {
  @override
  Future<void> completeSession({
    required String sessionId,
    required MotorExecutionMetrics metrics,
  }) async {}
}
