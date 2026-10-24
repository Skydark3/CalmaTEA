<<<<<<<<<<import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/activity_configuration_summary.dart';
import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/psychologist/activities/configuration/activity_configuration_router.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  test('los ocho ActivityType resuelven un configurador profesional', () {
    const expectedScreens = {
      ActivityType.sequence: 'SequenceConfigurationScreen',
      ActivityType.dragDrop: 'DragDropConfigurationScreen',
      ActivityType.matching: 'MatchingConfigurationScreen',
      ActivityType.pictogram: 'PictogramConfigurationScreen',
      ActivityType.emotion: 'EmotionConfigurationScreen',
      ActivityType.tracing: 'TracingConfigurationScreen',
      ActivityType.timer: 'TimerConfigurationScreen',
      ActivityType.motor: 'MotorConfigurationScreen',
    };

    expect(expectedScreens.length, ActivityType.values.length);
    for (final type in ActivityType.values) {
      final activity = _activity(type);
      expect(ActivityConfigurationRouter.supports(type), isTrue);
      expect(
        ActivityConfigurationRouter.resolve(activity).runtimeType.toString(),
        expectedScreens[type],
      );
    }
  });

  test('configuration vacía produce estado no configurado', () {
    final summary = ActivityConfigurationSummary.fromActivity(
      _activity(ActivityType.sequence),
    );

    expect(summary.status, ActivityConfigurationStatus.unconfigured);
    expect(summary.actionLabel, 'Configurar actividad');
  });

  test('cada configuración válida produce su resumen profesional', () {
    final cases = <ActivityType, ({Map<String, dynamic> map, String title})>{
      ActivityType.sequence: (
        map: const SequenceActivityConfig(
          items: [SequenceItemConfig(id: '1', label: 'Paso', order: 0)],
        ).toMap(),
        title: 'Secuencia configurada',
      ),
      ActivityType.dragDrop: (
        map: const DragDropActivityConfig(
          items: [
            DragDropItemConfig(id: '1', label: 'Manzana', targetId: 't1'),
          ],
          targets: [DragDropTargetConfig(id: 't1', label: 'Frutas')],
        ).toMap(),
        title: 'Arrastrar y soltar configurado',
      ),
      ActivityType.matching: (
        map: const MatchingActivityConfig(
          pairs: [MatchingPairConfig(id: '1', left: 'A', right: 'B')],
        ).toMap(),
        title: 'Emparejamiento configurado',
      ),
      ActivityType.pictogram: (
        map: const PictogramActivityConfig(
          options: [PictogramOptionConfig(id: '1', label: 'Comer')],
        ).toMap(),
        title: 'Pictogramas configurados',
      ),
      ActivityType.emotion: (
        map: const EmotionActivityConfig(
          options: [
            EmotionOptionConfig(
              id: '1',
              label: 'Felicidad',
              prompt: 'Recibe un regalo',
              expectedValue: 'felicidad',
            ),
          ],
        ).toMap(),
        title: 'Emociones configuradas',
      ),
      ActivityType.tracing: (
        map: const TracingActivityConfig(pattern: 'Letra', value: 'A').toMap(),
        title: 'Trazado configurado',
      ),
      ActivityType.timer: (
        map: const TimerActivityConfig(durationSeconds: 90).toMap(),
        title: 'Temporizador configurado',
      ),
      ActivityType.motor: (
        map: const MotorActivityConfig(
          steps: [MotorStepConfig(id: '1', instruction: 'Levantar brazos')],
        ).toMap(),
        title: 'Actividad motora configurada',
      ),
    };

    expect(cases.length, ActivityType.values.length);
    for (final entry in cases.entries) {
      final summary = ActivityConfigurationSummary.fromActivity(
        _activity(entry.key, configuration: entry.value.map),
      );
      expect(summary.status, ActivityConfigurationStatus.configured);
      expect(summary.title, entry.value.title);
      expect(summary.detail, isNotEmpty);
      expect(summary.actionLabel, 'Editar configuración');
    }
  });

  test('configuration inválida produce estado controlado sin excepción', () {
    final summary = ActivityConfigurationSummary.fromActivity(
      _activity(
        ActivityType.timer,
        configuration: const {'version': 1, 'durationSeconds': 0},
      ),
    );

    expect(summary.status, ActivityConfigurationStatus.invalid);
    expect(
      summary.title,
      'No pudimos interpretar la configuración de esta actividad.',
    );
    expect(summary.actionLabel, 'Editar configuración');
  });

  test('map malformado produce estado inválido sin propagar el error', () {
    late ActivityConfigurationSummary summary;

    expect(
      () => summary = ActivityConfigurationSummary.fromActivity(
        _activity(
          ActivityType.timer,
          configuration: const {
            'version': 1,
            'durationSeconds': 'valor-no-numérico',
          },
        ),
      ),
      returnsNormally,
    );
    expect(summary.status, ActivityConfigurationStatus.invalid);
  });
}

ActivityModel _activity(
  ActivityType type, {
  Map<String, dynamic> configuration = const {},
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
    status: ActivityStatus.assigned,
    createdAt: DateTime(2026),
  );
}
