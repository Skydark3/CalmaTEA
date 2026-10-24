import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/child/activities/execution/activity_preview_persistence.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';

void main() {
  test(
    'Preview completa los ocho motores solo con persistencia efímera',
    () async {
      final sequence = SequencePreviewPersistence();
      final sequenceId = await sequence.startSession(activityId: 'sequence');
      await sequence.completeSession(
        sessionId: sequenceId,
        metrics: SequenceExecutionMetrics(itemsCount: 1, checksCount: 1),
      );

      final matching = MatchingPreviewPersistence();
      final matchingId = await matching.startSession(activityId: 'matching');
      await matching.completeSession(
        sessionId: matchingId,
        metrics: MatchingExecutionMetrics(
          relationsCompleted: 1,
          checksCount: 1,
        ),
      );

      final emotion = EmotionPreviewPersistence();
      final emotionId = await emotion.startSession(activityId: 'emotion');
      await emotion.completeSession(
        sessionId: emotionId,
        metrics: EmotionExecutionMetrics(exercisesReviewed: 1),
      );

      final pictogram = PictogramPreviewPersistence();
      final pictogramId = await pictogram.startSession(activityId: 'pictogram');
      await pictogram.completeSession(
        sessionId: pictogramId,
        metrics: PictogramExecutionMetrics(interactionsCount: 1),
      );

      final dragDrop = DragDropPreviewPersistence();
      final dragDropId = await dragDrop.startSession(activityId: 'drag-drop');
      await dragDrop.completeSession(
        sessionId: dragDropId,
        metrics: DragDropExecutionMetrics(itemsPlaced: 1, checksCount: 1),
      );

      final timer = TimerPreviewPersistence();
      final timerId = await timer.startSession(activityId: 'timer');
      await timer.completeSession(
        sessionId: timerId,
        metrics: TimerExecutionMetrics(
          configuredDurationSeconds: 1,
          elapsedSeconds: 1,
        ),
      );

      final tracing = TracingPreviewPersistence();
      final tracingId = await tracing.startSession(activityId: 'tracing');
      await tracing.completeSession(
        sessionId: tracingId,
        metrics: TracingExecutionMetrics(
          practiceCompleted: true,
          strokesCount: 1,
        ),
      );

      final motor = MotorPreviewPersistence();
      final motorId = await motor.startSession(activityId: 'motor');
      await motor.completeSession(
        sessionId: motorId,
        metrics: MotorExecutionMetrics(stepsVisited: 1),
      );

      for (final entry in <(ActivityPreviewPersistenceLifecycle, String)>[
        (sequence, sequenceId),
        (matching, matchingId),
        (emotion, emotionId),
        (pictogram, pictogramId),
        (dragDrop, dragDropId),
        (timer, timerId),
        (tracing, tracingId),
        (motor, motorId),
      ]) {
        expect(entry.$2, startsWith('preview-session-'));
        await entry.$1.interruptSession(entry.$2);
        expect(await entry.$1.getSession(entry.$2), isNull);
        expect(await entry.$1.getResult(entry.$2), isNull);
      }
    },
  );
}
