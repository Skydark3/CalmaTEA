import '../../../models/activity_model.dart';
import 'activity_configuration_factory.dart';
import 'models/activity_configurations.dart';
import 'timer_configuration_utils.dart';

enum ActivityConfigurationStatus { unconfigured, configured, invalid }

class ActivityConfigurationSummary {
  final ActivityConfigurationStatus status;
  final String title;
  final String detail;

  const ActivityConfigurationSummary({
    required this.status,
    required this.title,
    required this.detail,
  });

  bool get canConfigure => true;

  String get actionLabel => status == ActivityConfigurationStatus.unconfigured
      ? 'Configurar actividad'
      : 'Editar configuración';

  static ActivityConfigurationSummary fromActivity(ActivityModel activity) {
    if (activity.configuration.isEmpty) {
      return const ActivityConfigurationSummary(
        status: ActivityConfigurationStatus.unconfigured,
        title: 'Esta actividad todavía no tiene una configuración interactiva.',
        detail:
            'Configura los datos necesarios antes de utilizar la actividad.',
      );
    }

    try {
      final configuration = ActivityConfigurationFactory.fromMap(
        activity.type,
        activity.configuration,
      );
      return switch (configuration) {
        SequenceActivityConfig config when config.isValid =>
          ActivityConfigurationSummary._configured(
            'Secuencia configurada',
            _countLabel(config.items.length, 'paso', 'pasos'),
          ),
        MatchingActivityConfig config when config.isValid =>
          ActivityConfigurationSummary._configured(
            'Emparejamiento configurado',
            _countLabel(config.pairs.length, 'par', 'pares'),
          ),
        EmotionActivityConfig config when config.isValid =>
          ActivityConfigurationSummary._configured(
            'Emociones configuradas',
            _countLabel(config.options.length, 'ejercicio', 'ejercicios'),
          ),
        PictogramActivityConfig config when config.isValid =>
          ActivityConfigurationSummary._configured(
            'Pictogramas configurados',
            _countLabel(config.options.length, 'opción', 'opciones'),
          ),
        DragDropActivityConfig config when config.isValid =>
          ActivityConfigurationSummary._configured(
            'Arrastrar y soltar configurado',
            '${config.items.length} elementos · ${config.targets.length} destinos',
          ),
        TimerActivityConfig config when config.isValid =>
          ActivityConfigurationSummary._configured(
            'Temporizador configurado',
            _timerDetail(config),
          ),
        TracingActivityConfig config when config.isValid =>
          ActivityConfigurationSummary._configured(
            'Trazado configurado',
            _tracingDetail(config),
          ),
        MotorActivityConfig config when config.isValid =>
          ActivityConfigurationSummary._configured(
            'Actividad motora configurada',
            _motorDetail(config),
          ),
        _ => const ActivityConfigurationSummary(
          status: ActivityConfigurationStatus.invalid,
          title: 'No pudimos interpretar la configuración de esta actividad.',
          detail: 'Revisa los datos configurados antes de continuar.',
        ),
      };
    } catch (_) {
      return const ActivityConfigurationSummary(
        status: ActivityConfigurationStatus.invalid,
        title: 'No pudimos interpretar la configuración de esta actividad.',
        detail: 'Revisa los datos configurados antes de continuar.',
      );
    }
  }

  const ActivityConfigurationSummary._configured(this.title, this.detail)
    : status = ActivityConfigurationStatus.configured;

  static String _countLabel(int count, String singular, String plural) {
    return '$count ${count == 1 ? singular : plural}';
  }

  static String _timerDetail(TimerActivityConfig config) {
    final label = config.label?.trim();
    final labelDetail = label == null || label.isEmpty ? '' : '\n$label';
    return 'Duración: ${formatTimerDuration(config.durationSeconds)}$labelDetail';
  }

  static String _tracingDetail(TracingActivityConfig config) {
    final hint = config.difficultyHint?.trim();
    final hintDetail = hint == null || hint.isEmpty
        ? ''
        : '\nDificultad: $hint';
    return '${config.pattern} · ${config.value}$hintDetail';
  }

  static String _motorDetail(MotorActivityConfig config) {
    final count = config.steps.length;
    final configuredValues = config.steps
        .where(
          (step) => step.durationSeconds != null || step.repetitions != null,
        )
        .length;
    final valuesDetail = configuredValues == 0
        ? ''
        : '\n$configuredValues con duración o repeticiones definidas';
    return '${_countLabel(count, 'paso', 'pasos')}$valuesDetail';
  }
}
