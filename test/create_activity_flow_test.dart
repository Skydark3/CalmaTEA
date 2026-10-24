import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/activities/config/models/activity_configurations.dart';
import 'package:tea_app/features/child/activities/execution/activity_preview_router.dart';
import 'package:tea_app/features/psychologist/activities/presentation/create_activity_screen.dart';
import 'package:tea_app/features/psychologist/activities/presentation/widgets/activity_card.dart';
import 'package:tea_app/models/activity_model.dart';
import 'package:tea_app/models/child_model.dart';
import 'package:tea_app/models/therapy_model.dart';

void main() {
  for (final type in ActivityType.values) {
    testWidgets('configura y asigna ${type.name} en una sola escritura', (
      tester,
    ) async {
      var createCalls = 0;
      ActivityModel? activitySentToConfiguration;
      ActivityModel? activitySentToCreate;

      await tester.pumpWidget(
        _CreationHost(
          activityCreator: (activity) async {
            createCalls++;
            activitySentToCreate = activity;
            expect(activity.id, 'draft-${type.name}');
            expect(activity.type, type);
            expect(activity.configuration, _validConfiguration(type));
            expect(activity.status, ActivityStatus.assigned);
            return activity.id;
          },
          configurationOpener: (context, activity) async {
            activitySentToConfiguration = activity;
            return activity.copyWith(configuration: _validConfiguration(type));
          },
          activityIdProvider: () => 'draft-${type.name}',
        ),
      );

      await _openAndSubmit(tester, type);

      expect(createCalls, 1);
      expect(activitySentToConfiguration?.id, 'draft-${type.name}');
      expect(activitySentToConfiguration?.configuration, isEmpty);
      expect(activitySentToCreate?.configuration, isNotEmpty);
      final previewResolution = buildActivityPreviewRouter().resolve(
        activitySentToCreate!,
      );
      expect(previewResolution.canStart, isTrue);
      expect(previewResolution.hasValidConfiguration, isTrue);
      expect(
        find.byKey(const ValueKey('creation-result-configured')),
        findsOneWidget,
      );

      final configured = activitySentToConfiguration!.copyWith(
        configuration: _validConfiguration(type),
      );
      if (type == ActivityType.dragDrop) {
        final parsed = DragDropActivityConfig.fromMap(configured.configuration);
        expect(parsed.items, hasLength(1));
        expect(parsed.targets, hasLength(1));
        expect(parsed.items.single.targetId, parsed.targets.single.id);
      }
      if (type == ActivityType.pictogram) {
        final parsed = PictogramActivityConfig.fromMap(
          configured.configuration,
        );
        expect(parsed.options, hasLength(1));
      }
    });
  }

  testWidgets('cancelar configuración no crea ni asigna la actividad', (
    tester,
  ) async {
    var createCalls = 0;
    await tester.pumpWidget(
      _CreationHost(
        activityCreator: (activity) async {
          createCalls++;
          return 'pending-activity';
        },
        configurationOpener: (context, activity) async => null,
      ),
    );

    await _openAndSubmit(tester, ActivityType.sequence);

    expect(createCalls, 0);
    expect(find.text('Crear actividad'), findsOneWidget);
    expect(find.textContaining('no se guardó ni se asignó'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('creation-result-configured')),
      findsNothing,
    );
  });

  testWidgets('reintentar configuración crea una sola vez', (tester) async {
    var createCalls = 0;
    var configurationCalls = 0;
    await tester.pumpWidget(
      _CreationHost(
        activityCreator: (activity) async {
          createCalls++;
          return 'single-activity';
        },
        configurationOpener: (context, activity) async {
          configurationCalls++;
          if (configurationCalls == 1) {
            throw StateError('fallo controlado');
          }
          return activity.copyWith(
            configuration: _validConfiguration(ActivityType.sequence),
          );
        },
      ),
    );

    await tester.tap(find.text('Abrir creación'));
    await tester.pumpAndSettle();
    await _fillForm(tester, ActivityType.sequence);
    await tester.tap(find.text('Configurar actividad'));
    await tester.pumpAndSettle();

    expect(createCalls, 0);
    expect(configurationCalls, 1);
    expect(find.text('Configurar actividad'), findsOneWidget);
    expect(find.textContaining('no se guardó'), findsOneWidget);

    await tester.ensureVisible(find.text('Configurar actividad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurar actividad'));
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(configurationCalls, 2);
    expect(
      find.byKey(const ValueKey('creation-result-configured')),
      findsOneWidget,
    );
  });

  testWidgets('configuración inválida impide guardar y asignar', (
    tester,
  ) async {
    var createCalls = 0;
    await tester.pumpWidget(
      _CreationHost(
        activityCreator: (activity) async {
          createCalls++;
          return activity.id;
        },
        configurationOpener: (context, activity) async => activity,
      ),
    );

    await _openAndSubmit(tester, ActivityType.timer);

    expect(createCalls, 0);
    expect(
      find.textContaining('configuración válida antes de guardar'),
      findsOneWidget,
    );
  });

  testWidgets('reintento de escritura conserva el mismo id configurado', (
    tester,
  ) async {
    final attemptedIds = <String>[];
    var createCalls = 0;
    await tester.pumpWidget(
      _CreationHost(
        activityCreator: (activity) async {
          createCalls++;
          attemptedIds.add(activity.id);
          if (createCalls == 1) throw StateError('sin confirmación');
          return activity.id;
        },
        configurationOpener: (context, activity) async => activity.copyWith(
          configuration: _validConfiguration(ActivityType.sequence),
        ),
        activityIdProvider: () => 'stable-draft-id',
      ),
    );

    await _openAndSubmit(tester, ActivityType.sequence);
    expect(find.text('Reintentar guardar y asignar'), findsOneWidget);

    await tester.ensureVisible(find.text('Reintentar guardar y asignar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reintentar guardar y asignar'));
    await tester.pumpAndSettle();

    expect(createCalls, 2);
    expect(attemptedIds, ['stable-draft-id', 'stable-draft-id']);
    expect(
      find.byKey(const ValueKey('creation-result-configured')),
      findsOneWidget,
    );
  });

  testWidgets('la tarjeta profesional identifica actividad incompleta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityCard(activity: _activity(ActivityType.dragDrop)),
        ),
      ),
    );

    expect(find.text('Pendiente de configuración'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivityCard(
            activity: _activity(
              ActivityType.dragDrop,
              configuration: _validConfiguration(ActivityType.dragDrop),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Pendiente de configuración'), findsNothing);
  });
}

class _CreationHost extends StatefulWidget {
  final ActivityCreator activityCreator;
  final ActivityConfigurationOpener configurationOpener;
  final ActivityIdProvider? activityIdProvider;

  const _CreationHost({
    required this.activityCreator,
    required this.configurationOpener,
    this.activityIdProvider,
  });

  @override
  State<_CreationHost> createState() => _CreationHostState();
}

class _CreationHostState extends State<_CreationHost> {
  ActivityCreationResult? _result;

  Future<void> _open(BuildContext navigatorContext) async {
    final result = await Navigator.of(navigatorContext)
        .push<ActivityCreationResult>(
          MaterialPageRoute(
            builder: (_) => CreateActivityScreen(
              therapy: _therapy,
              child: _child,
              activityCreator: widget.activityCreator,
              configurationOpener: widget.configurationOpener,
              psychologistIdProvider: () => 'psychologist-id',
              activityIdProvider:
                  widget.activityIdProvider ?? () => 'draft-activity',
            ),
          ),
        );
    if (!mounted || result == null) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (navigatorContext) => Center(
            child: _result == null
                ? ElevatedButton(
                    onPressed: () => _open(navigatorContext),
                    child: const Text('Abrir creación'),
                  )
                : Text(
                    _result!.status.name,
                    key: ValueKey('creation-result-${_result!.status.name}'),
                  ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openAndSubmit(WidgetTester tester, ActivityType type) async {
  await tester.tap(find.text('Abrir creación'));
  await tester.pumpAndSettle();
  await _fillForm(tester, type);
  await tester.tap(find.text('Configurar actividad'));
  await tester.pumpAndSettle();
}

Future<void> _fillForm(WidgetTester tester, ActivityType type) async {
  final titleField = find.byType(EditableText).first;
  await tester.enterText(titleField, 'Actividad ${type.displayName}');
  await tester.tap(find.byType(DropdownButtonFormField<ActivityType>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(type.displayName).last);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Configurar actividad'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

final _child = ChildModel(
  id: 'child-id',
  psychologistId: 'psychologist-id',
  fullName: 'Paciente de prueba',
  birthDate: DateTime(2015),
  supportLevel: '1',
  createdAt: DateTime(2026),
);

final _therapy = TherapyModel(
  id: 'therapy-id',
  childId: 'child-id',
  psychologistId: 'psychologist-id',
  type: TherapyType.occupational,
  status: TherapyStatus.active,
  startDate: DateTime(2026),
  createdAt: DateTime(2026),
);

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

Map<String, dynamic> _validConfiguration(ActivityType type) {
  return switch (type) {
    ActivityType.sequence => const SequenceActivityConfig(
      items: [SequenceItemConfig(id: 'step-1', label: 'Paso', order: 0)],
    ).toMap(),
    ActivityType.dragDrop => const DragDropActivityConfig(
      items: [
        DragDropItemConfig(
          id: 'item-1',
          label: 'Manzana',
          targetId: 'target-1',
        ),
      ],
      targets: [DragDropTargetConfig(id: 'target-1', label: 'Frutas')],
    ).toMap(),
    ActivityType.matching => const MatchingActivityConfig(
      pairs: [MatchingPairConfig(id: 'pair-1', left: 'Sol', right: 'Día')],
    ).toMap(),
    ActivityType.pictogram => const PictogramActivityConfig(
      options: [PictogramOptionConfig(id: 'option-1', label: 'Agua')],
    ).toMap(),
    ActivityType.emotion => const EmotionActivityConfig(
      options: [
        EmotionOptionConfig(
          id: 'emotion-1',
          label: 'Alegría',
          prompt: '¿Cómo se siente?',
          expectedValue: 'alegría',
        ),
      ],
    ).toMap(),
    ActivityType.tracing => const TracingActivityConfig(
      pattern: 'Letra',
      value: 'A',
    ).toMap(),
    ActivityType.timer => const TimerActivityConfig(
      durationSeconds: 30,
    ).toMap(),
    ActivityType.motor => const MotorActivityConfig(
      steps: [MotorStepConfig(id: 'motor-1', instruction: 'Levanta brazos')],
    ).toMap(),
  };
}
