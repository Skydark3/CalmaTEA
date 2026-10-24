import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configuration.dart';
import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/activities/execution/activity_execution_router.dart';
import 'package:tea_app/features/child/child_shell.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  const validConfigurations = <ActivityType, ActivityConfiguration>{
    ActivityType.sequence: SequenceActivityConfig(
      items: [SequenceItemConfig(id: 's1', label: 'Paso', order: 0)],
    ),
    ActivityType.dragDrop: DragDropActivityConfig(
      items: [DragDropItemConfig(id: 'i1', label: 'Objeto', targetId: 't1')],
      targets: [DragDropTargetConfig(id: 't1', label: 'Destino')],
    ),
    ActivityType.matching: MatchingActivityConfig(
      pairs: [MatchingPairConfig(id: 'p1', left: 'Sol', right: 'Día')],
    ),
    ActivityType.pictogram: PictogramActivityConfig(
      options: [PictogramOptionConfig(id: 'p1', label: 'Comer')],
    ),
    ActivityType.emotion: EmotionActivityConfig(
      options: [
        EmotionOptionConfig(
          id: 'e1',
          label: 'Alegría',
          prompt: '¿Cómo se siente?',
          expectedValue: 'alegria',
        ),
      ],
    ),
    ActivityType.tracing: TracingActivityConfig(pattern: 'Letra', value: 'A'),
    ActivityType.timer: TimerActivityConfig(durationSeconds: 60),
    ActivityType.motor: MotorActivityConfig(
      steps: [MotorStepConfig(id: 'm1', instruction: 'Levantar brazos')],
    ),
  };

  const router = ActivityExecutionRouter();

  test('configuration vacía devuelve unconfigured', () {
    final resolution = router.resolve(_activity(ActivityType.sequence));

    expect(resolution.state, ActivityExecutionState.unconfigured);
    expect(resolution.canStart, isFalse);
    expect(
      resolution.childMessage,
      'Esta actividad todavía está siendo preparada.',
    );
  });

  test('configuration inválida devuelve invalidConfiguration', () {
    final resolution = router.resolve(
      _activity(
        ActivityType.timer,
        configuration: const {'version': 1, 'durationSeconds': 0},
      ),
    );

    expect(resolution.state, ActivityExecutionState.invalidConfiguration);
    expect(resolution.canStart, isFalse);
    expect(resolution.childMessage, 'No pudimos preparar esta actividad.');
  });

  test('sequence válida queda reconocida aunque su motor no exista', () {
    final resolution = router.resolve(
      _activity(
        ActivityType.sequence,
        configuration: validConfigurations[ActivityType.sequence]!.toMap(),
      ),
    );

    expect(resolution.type, ActivityType.sequence);
    expect(resolution.hasValidConfiguration, isTrue);
    expect(resolution.state, ActivityExecutionState.engineUnavailable);
    expect(resolution.canStart, isTrue);
  });

  test('los ocho ActivityType son reconocidos y resuelven configuración', () {
    expect(validConfigurations.length, ActivityType.values.length);

    for (final type in ActivityType.values) {
      expect(router.recognizes(type), isTrue);
      final resolution = router.resolve(
        _activity(type, configuration: validConfigurations[type]!.toMap()),
      );
      expect(resolution.type, type);
      expect(resolution.hasValidConfiguration, isTrue);
      expect(resolution.state, ActivityExecutionState.engineUnavailable);
    }
  });

  test('completed y cancelled no son ejecutables', () {
    for (final status in [ActivityStatus.completed, ActivityStatus.cancelled]) {
      final resolution = router.resolve(
        _activity(
          ActivityType.sequence,
          configuration: validConfigurations[ActivityType.sequence]!.toMap(),
          status: status,
        ),
      );

      expect(resolution.state, ActivityExecutionState.blockedStatus);
      expect(resolution.canStart, isFalse);
    }
  });

  test('assigned e inProgress con configuración válida son aceptadas', () {
    for (final status in [ActivityStatus.assigned, ActivityStatus.inProgress]) {
      final resolution = router.resolve(
        _activity(
          ActivityType.sequence,
          configuration: validConfigurations[ActivityType.sequence]!.toMap(),
          status: status,
        ),
      );

      expect(resolution.state, ActivityExecutionState.engineUnavailable);
      expect(resolution.canStart, isTrue);
    }
  });

  test('un handler registrado convierte el resultado en ready', () {
    final readyRouter = ActivityExecutionRouter(
      handlers: {
        ActivityType.sequence: (context, activity, configuration) async {},
      },
    );
    final resolution = readyRouter.resolve(
      _activity(
        ActivityType.sequence,
        configuration: validConfigurations[ActivityType.sequence]!.toMap(),
      ),
    );

    expect(resolution.state, ActivityExecutionState.ready);
    expect(resolution.canStart, isTrue);
    expect(resolution.childMessage, isNull);
  });

  test('flag apagado mantiene bloqueada la navegacion de los ocho motores', () {
    final disabledRouter = buildChildActivityExecutionRouter(
      persistentExecutionEnabled: false,
      previewEnabled: false,
    );

    for (final type in ActivityType.values) {
      final resolution = disabledRouter.resolve(
        _activity(type, configuration: validConfigurations[type]!.toMap()),
      );
      expect(resolution.state, ActivityExecutionState.engineUnavailable);
    }
  });

  test('flag encendido registra los ocho motores existentes', () {
    final enabledRouter = buildChildActivityExecutionRouter(
      persistentExecutionEnabled: true,
      previewEnabled: false,
    );

    for (final type in ActivityType.values) {
      final resolution = enabledRouter.resolve(
        _activity(type, configuration: validConfigurations[type]!.toMap()),
      );
      expect(resolution.state, ActivityExecutionState.ready);
    }
    expect(enabledRouter.mode, ActivityExecutionMode.persistent);
  });

  test('Preview registra los ocho motores sin modo persistente', () {
    final previewRouter = buildChildActivityExecutionRouter(
      persistentExecutionEnabled: false,
      previewEnabled: true,
    );

    for (final type in ActivityType.values) {
      final resolution = previewRouter.resolve(
        _activity(type, configuration: validConfigurations[type]!.toMap()),
      );
      expect(resolution.state, ActivityExecutionState.ready);
    }
    expect(previewRouter.mode, ActivityExecutionMode.preview);
    expect(previewRouter.isPreview, isTrue);
  });

  test('flags de Preview y persistencia simultáneos bloquean los motores', () {
    final invalidRouter = buildChildActivityExecutionRouter(
      persistentExecutionEnabled: true,
      previewEnabled: true,
    );

    for (final type in ActivityType.values) {
      final resolution = invalidRouter.resolve(
        _activity(type, configuration: validConfigurations[type]!.toMap()),
      );
      expect(resolution.state, ActivityExecutionState.engineUnavailable);
    }
  });
}

ActivityModel _activity(
  ActivityType type, {
  Map<String, dynamic> configuration = const {},
  ActivityStatus status = ActivityStatus.assigned,
}) {
  return ActivityModel(
    id: 'activity-id',
    therapyId: 'therapy-id',
    childId: 'child-id',
    psychologistId: 'psychologist-id',
    title: 'Actividad',
    description: '',
    type: type,
    difficulty: 1,
    instructions: '',
    configuration: configuration,
    status: status,
    createdAt: DateTime(2026),
  );
}
