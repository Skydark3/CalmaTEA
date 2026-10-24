import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/features/activities/config/activity_configuration_factory.dart';
import 'package:tea_app/features/activities/config/models/activity_configuration.dart';
import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/models/activity_model.dart';

void main() {
  group('Activity configurations', () {
    final validConfigurations = <ActivityType, ActivityConfiguration>{
      ActivityType.sequence: const SequenceActivityConfig(
        items: [SequenceItemConfig(id: 's1', label: 'Primero', order: 1)],
      ),
      ActivityType.dragDrop: const DragDropActivityConfig(
        items: [DragDropItemConfig(id: 'i1', label: 'Objeto', targetId: 't1')],
        targets: [DragDropTargetConfig(id: 't1', label: 'Destino')],
      ),
      ActivityType.matching: const MatchingActivityConfig(
        pairs: [MatchingPairConfig(id: 'p1', left: 'Casa', right: 'Hogar')],
      ),
      ActivityType.pictogram: const PictogramActivityConfig(
        options: [PictogramOptionConfig(id: 'p1', label: 'Comer')],
      ),
      ActivityType.emotion: const EmotionActivityConfig(
        options: [
          EmotionOptionConfig(
            id: 'e1',
            label: 'Alegría',
            prompt: '¿Qué emoción representa?',
            expectedValue: 'alegria',
          ),
        ],
      ),
      ActivityType.tracing: const TracingActivityConfig(
        pattern: 'letter',
        value: 'A',
      ),
      ActivityType.timer: const TimerActivityConfig(durationSeconds: 60),
      ActivityType.motor: const MotorActivityConfig(
        steps: [
          MotorStepConfig(id: 'm1', instruction: 'Levantar ambos brazos'),
        ],
      ),
    };

    test('empty configuration remains unconfigured for every type', () {
      for (final type in ActivityType.values) {
        expect(ActivityConfigurationFactory.fromMap(type, const {}), isNull);
      }
    });

    test('factory returns the typed configuration for every ActivityType', () {
      final expectedTypes = <ActivityType, Type>{
        ActivityType.sequence: SequenceActivityConfig,
        ActivityType.dragDrop: DragDropActivityConfig,
        ActivityType.matching: MatchingActivityConfig,
        ActivityType.pictogram: PictogramActivityConfig,
        ActivityType.emotion: EmotionActivityConfig,
        ActivityType.tracing: TracingActivityConfig,
        ActivityType.timer: TimerActivityConfig,
        ActivityType.motor: MotorActivityConfig,
      };

      for (final entry in validConfigurations.entries) {
        final parsed = ActivityConfigurationFactory.fromMap(
          entry.key,
          entry.value.toMap(),
        );
        expect(parsed.runtimeType, expectedTypes[entry.key]);
      }
    });

    test('each type has at least one valid serializable configuration', () {
      for (final entry in validConfigurations.entries) {
        final map = entry.value.toMap();
        final parsed = ActivityConfigurationFactory.fromMap(entry.key, map);

        expect(entry.value.isValid, isTrue);
        expect(parsed, isNotNull);
        expect(parsed!.isValid, isTrue);
        expect(parsed.toMap(), equals(map));
      }
    });

    test('timer rejects non-positive duration', () {
      const zeroDuration = TimerActivityConfig(durationSeconds: 0);
      const negativeDuration = TimerActivityConfig(durationSeconds: -10);

      expect(zeroDuration.isValid, isFalse);
      expect(negativeDuration.isValid, isFalse);
    });

    test('version defaults to one and survives a round trip', () {
      const configuration = MatchingActivityConfig(
        pairs: [MatchingPairConfig(id: 'p1', left: 'Sol', right: 'Día')],
      );

      final map = configuration.toMap();
      final parsed = ActivityConfigurationFactory.fromMap(
        ActivityType.matching,
        map,
      );

      expect(map['version'], currentActivityConfigurationVersion);
      expect(parsed!.version, currentActivityConfigurationVersion);
      expect(parsed.toMap(), equals(map));
    });
  });
}
