import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/activity_model.dart';
import '../../../activities/config/models/activity_configuration.dart';
import '../../../activities/config/models/activity_configurations.dart';
import 'activity_execution_ui_text.dart';
import 'motor_execution_controller.dart';
import 'motor_execution_utils.dart';
import 'widgets/activity_visual_components.dart';

Future<void> openMotorExecution(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! MotorActivityConfig) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MotorExecutionScreen(
        activity: activity,
        configuration: configuration,
      ),
    ),
  );
}

class MotorExecutionScreen extends StatefulWidget {
  final ActivityModel activity;
  final MotorActivityConfig configuration;
  final MotorExecutionPersistence? persistence;
  final bool previewMode;

  const MotorExecutionScreen({
    super.key,
    required this.activity,
    required this.configuration,
    this.persistence,
    this.previewMode = false,
  });

  @override
  State<MotorExecutionScreen> createState() => _MotorExecutionScreenState();
}

class _MotorExecutionScreenState extends State<MotorExecutionScreen> {
  late final MotorExecutionController _controller;
  int _currentStepIndex = 0;
  bool _isFinished = false;
  bool _exitDialogVisible = false;
  bool _allowPop = false;

  List<MotorStepConfig> get _steps => widget.configuration.steps;

  bool get _canRun =>
      widget.activity.type == ActivityType.motor &&
      (widget.activity.status == ActivityStatus.assigned ||
          widget.activity.status == ActivityStatus.inProgress) &&
      widget.configuration.isValid &&
      _steps.isNotEmpty;

  MotorStepConfig get _currentStep => _steps[_currentStepIndex];

  @override
  void initState() {
    super.initState();
    _controller = MotorExecutionController(
      activityId: widget.activity.id,
      stepsCount: _steps.isEmpty ? 1 : _steps.length,
      persistence: widget.persistence ?? MotorExecutionServicePersistence(),
    )..addListener(_onControllerChanged);
    if (_canRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.start());
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _goToPreviousStep() {
    if (_controller.state != MotorExecutionPersistenceState.ready ||
        _currentStepIndex == 0) {
      return;
    }
    final previousIndex = _currentStepIndex - 1;
    _controller.visitStep(previousIndex);
    setState(() => _currentStepIndex = previousIndex);
  }

  void _goToNextStep() {
    if (_controller.state != MotorExecutionPersistenceState.ready ||
        _currentStepIndex >= _steps.length - 1) {
      return;
    }
    final nextIndex = _currentStepIndex + 1;
    _controller.visitStep(nextIndex);
    setState(() => _currentStepIndex = nextIndex);
  }

  Future<void> _finishGuide() async {
    if (_currentStepIndex != _steps.length - 1) return;
    final saved = await _controller.finish();
    if (!mounted || !saved) return;
    setState(() => _isFinished = true);
  }

  Future<void> _retryCompletion() async {
    final saved = await _controller.retryCompletion();
    if (!mounted || !saved) return;
    setState(() => _isFinished = true);
  }

  Future<void> _repeatGuide() async {
    setState(() {
      _currentStepIndex = 0;
      _isFinished = false;
    });
    await _controller.startNewExecution();
  }

  Future<void> _requestExit() async {
    if (_exitDialogVisible) return;
    final state = _controller.state;
    if (state == MotorExecutionPersistenceState.completed ||
        state == MotorExecutionPersistenceState.interrupted ||
        state == MotorExecutionPersistenceState.startFailure ||
        state == MotorExecutionPersistenceState.idle) {
      _popAfterAllowing();
      return;
    }

    if (state == MotorExecutionPersistenceState.starting ||
        state == MotorExecutionPersistenceState.saving ||
        state == MotorExecutionPersistenceState.interrupting) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ActivityExecutionUiText.waitBeforeExit(
              previewMode: widget.previewMode,
            ),
          ),
        ),
      );
      return;
    }

    if (state == MotorExecutionPersistenceState.completionFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ActivityExecutionUiText.retryBeforeExit(
              previewMode: widget.previewMode,
            ),
          ),
        ),
      );
      return;
    }

    _exitDialogVisible = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Salir de la actividad'),
        content: const Text(
          'Tu intento actual se cerrará. ¿Quieres volver a tus actividades?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuar aquí'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    _exitDialogVisible = false;
    if (shouldExit != true || !mounted) return;

    final interrupted = await _controller.interrupt();
    if (!mounted) return;
    if (interrupted) {
      _popAfterAllowing();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No pudimos cerrar la actividad. Inténtalo otra vez.'),
      ),
    );
  }

  void _popAfterAllowing() {
    if (!mounted || _allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRun) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guía motora')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No pudimos preparar esta actividad.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final persistenceState = _controller.state;
    late final Widget scaffold;
    if (persistenceState == MotorExecutionPersistenceState.idle ||
        persistenceState == MotorExecutionPersistenceState.starting) {
      scaffold = _MotorStatusScaffold(
        title: widget.activity.title,
        message: 'Iniciando actividad...',
        showProgress: true,
      );
    } else if (persistenceState ==
        MotorExecutionPersistenceState.startFailure) {
      scaffold = _MotorStatusScaffold(
        title: widget.activity.title,
        message: 'No pudimos iniciar la actividad.',
        primaryLabel: 'Reintentar',
        onPrimary: _controller.start,
        secondaryLabel: 'Volver',
        onSecondary: _requestExit,
      );
    } else {
      scaffold = Scaffold(
        appBar: AppBar(
          title: Text(widget.activity.title, overflow: TextOverflow.ellipsis),
        ),
        body: SafeArea(
          child: _isFinished
              ? _buildFinished(context)
              : _buildStep(context, persistenceState),
        ),
      );
    }

    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: scaffold,
    );
  }

  Widget _buildStep(
    BuildContext context,
    MotorExecutionPersistenceState persistenceState,
  ) {
    final step = _currentStep;
    final instructions = widget.activity.instructions.trim();
    final isLastStep = _currentStepIndex == _steps.length - 1;
    final canInteract =
        persistenceState == MotorExecutionPersistenceState.ready;
    final isSaving = persistenceState == MotorExecutionPersistenceState.saving;
    final hasCompletionFailure =
        persistenceState == MotorExecutionPersistenceState.completionFailure;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        ActivityVisualHeader(
          key: const ValueKey('motor-step-progress'),
          icon: Icons.directions_run_rounded,
          title: widget.activity.title,
          instructions: instructions.isEmpty
              ? 'Sigue cada indicación con calma.'
              : instructions,
          progressLabel: 'Paso ${_currentStepIndex + 1} de ${_steps.length}',
          progress: (_currentStepIndex + 1) / _steps.length,
          accent: AppColors.mint,
          compact: true,
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: activityMotionDuration(context),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Card(
            key: ValueKey('motor-step-${step.id}'),
            margin: EdgeInsets.zero,
            elevation: 0,
            color: AppColors.cardBg,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  ActivityIllustrationBadge(
                    icon: activityIconForLabel(
                      step.instruction,
                      fallback: Icons.accessibility_new_rounded,
                    ),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    step.instruction,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
                  ),
                  if (step.durationSeconds != null) ...[
                    const SizedBox(height: 18),
                    _StepDetail(
                      icon: Icons.schedule_rounded,
                      text:
                          'Duración sugerida: ${formatMotorDuration(step.durationSeconds!)}',
                    ),
                  ],
                  if (step.repetitions != null) ...[
                    const SizedBox(height: 10),
                    _StepDetail(
                      icon: Icons.repeat_rounded,
                      text: 'Repeticiones: ${step.repetitions}',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (isSaving) ...[
          _MotorProgressMessage(
            message: ActivityExecutionUiText.saving(
              previewMode: widget.previewMode,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (hasCompletionFailure) ...[
          _MotorMessage(
            message: ActivityExecutionUiText.completionFailure(
              previewMode: widget.previewMode,
            ),
          ),
          const SizedBox(height: 14),
        ],
        OutlinedButton.icon(
          onPressed: canInteract && _currentStepIndex > 0
              ? _goToPreviousStep
              : null,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Paso anterior'),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: hasCompletionFailure
              ? _retryCompletion
              : canInteract
              ? (isLastStep ? _finishGuide : _goToNextStep)
              : null,
          icon: Icon(
            hasCompletionFailure
                ? Icons.refresh_rounded
                : isLastStep
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded,
          ),
          label: Text(
            hasCompletionFailure
                ? ActivityExecutionUiText.retryLabel(
                    previewMode: widget.previewMode,
                  )
                : isSaving
                ? ActivityExecutionUiText.busyLabel(
                    previewMode: widget.previewMode,
                  )
                : isLastStep
                ? 'Finalizar guía'
                : 'Siguiente paso',
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          key: const ValueKey('activity-execution-return'),
          onPressed: isSaving ? null : _requestExit,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Volver a mis actividades'),
        ),
      ],
    );
  }

  Widget _buildFinished(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_walk_rounded,
              size: 72,
              color: AppColors.success,
            ),
            const SizedBox(height: 20),
            Text(
              '¡Terminaste la guía!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Has recorrido todas las instrucciones de esta guía.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _repeatGuide,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Repetir guía'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('activity-execution-return'),
              onPressed: _requestExit,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Volver a mis actividades'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MotorStatusScaffold extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _MotorStatusScaffold({
    required this.title,
    required this.message,
    this.showProgress = false,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showProgress) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
              ] else ...[
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
              ],
              Text(message, textAlign: TextAlign.center),
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel!),
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MotorProgressMessage extends StatelessWidget {
  final String message;

  const _MotorProgressMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _MotorMessage extends StatelessWidget {
  final String message;

  const _MotorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDetail extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StepDetail({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
