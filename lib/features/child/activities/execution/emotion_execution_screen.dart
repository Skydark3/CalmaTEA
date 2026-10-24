import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/activity_model.dart';
import '../../../activities/config/models/activity_configuration.dart';
import '../../../activities/config/models/activity_configurations.dart';
import 'activity_execution_ui_text.dart';
import 'emotion_execution_controller.dart';
import 'widgets/activity_visual_components.dart';

Future<void> openEmotionExecution(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! EmotionActivityConfig) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EmotionExecutionScreen(
        activity: activity,
        configuration: configuration,
      ),
    ),
  );
}

class EmotionExecutionScreen extends StatefulWidget {
  final ActivityModel activity;
  final EmotionActivityConfig configuration;
  final EmotionExecutionPersistence? persistence;
  final bool previewMode;

  const EmotionExecutionScreen({
    super.key,
    required this.activity,
    required this.configuration,
    this.persistence,
    this.previewMode = false,
  });

  @override
  State<EmotionExecutionScreen> createState() => _EmotionExecutionScreenState();
}

class _EmotionExecutionScreenState extends State<EmotionExecutionScreen> {
  final _answerController = TextEditingController();
  late final EmotionExecutionController _controller;
  int _currentIndex = 0;
  bool _isReviewed = false;
  bool _isFinished = false;
  bool _exitDialogVisible = false;
  bool _allowPop = false;

  List<EmotionOptionConfig> get _exercises => widget.configuration.options;

  bool get _canRun =>
      widget.activity.type == ActivityType.emotion &&
      (widget.activity.status == ActivityStatus.assigned ||
          widget.activity.status == ActivityStatus.inProgress) &&
      widget.configuration.isValid &&
      _exercises.isNotEmpty;

  EmotionOptionConfig get _currentExercise => _exercises[_currentIndex];

  @override
  void initState() {
    super.initState();
    _controller = EmotionExecutionController(
      activityId: widget.activity.id,
      exercisesCount: _exercises.isEmpty ? 1 : _exercises.length,
      persistence: widget.persistence ?? EmotionExecutionServicePersistence(),
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
    _answerController
      ..clear()
      ..dispose();
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _reviewAnswer() {
    if (_controller.state != EmotionExecutionPersistenceState.ready) return;
    if (_answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Escribe una respuesta antes de continuar.')),
      );
      return;
    }

    _controller.markExerciseReviewed(_currentIndex);
    setState(() => _isReviewed = true);
  }

  Future<void> _continue() async {
    if (!_isReviewed ||
        _controller.state != EmotionExecutionPersistenceState.ready) {
      return;
    }
    if (_currentIndex == _exercises.length - 1) {
      final saved = await _controller.finish();
      if (!mounted || !saved) return;
      _answerController.clear();
      setState(() => _isFinished = true);
      return;
    }

    _answerController.clear();
    setState(() {
      _currentIndex++;
      _isReviewed = false;
    });
  }

  Future<void> _retryCompletion() async {
    final saved = await _controller.retryCompletion();
    if (!mounted || !saved) return;
    _answerController.clear();
    setState(() => _isFinished = true);
  }

  Future<void> _repeat() async {
    _answerController.clear();
    setState(() {
      _currentIndex = 0;
      _isReviewed = false;
      _isFinished = false;
    });
    await _controller.startNewExecution();
  }

  Future<void> _requestExit() async {
    if (_exitDialogVisible) return;
    final state = _controller.state;
    if (state == EmotionExecutionPersistenceState.completed ||
        state == EmotionExecutionPersistenceState.interrupted ||
        state == EmotionExecutionPersistenceState.startFailure ||
        state == EmotionExecutionPersistenceState.idle) {
      _popAfterAllowing();
      return;
    }

    if (state == EmotionExecutionPersistenceState.starting ||
        state == EmotionExecutionPersistenceState.saving ||
        state == EmotionExecutionPersistenceState.interrupting) {
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

    if (state == EmotionExecutionPersistenceState.completionFailure) {
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
      _answerController.clear();
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
        appBar: AppBar(title: const Text('Emociones')),
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
    if (persistenceState == EmotionExecutionPersistenceState.idle ||
        persistenceState == EmotionExecutionPersistenceState.starting) {
      scaffold = _EmotionStatusScaffold(
        title: widget.activity.title,
        message: 'Iniciando actividad...',
        showProgress: true,
      );
    } else if (persistenceState ==
        EmotionExecutionPersistenceState.startFailure) {
      scaffold = _EmotionStatusScaffold(
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
              : _buildExercise(context, persistenceState),
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

  Widget _buildExercise(
    BuildContext context,
    EmotionExecutionPersistenceState persistenceState,
  ) {
    final exercise = _currentExercise;
    final canInteract =
        persistenceState == EmotionExecutionPersistenceState.ready;
    final isSaving =
        persistenceState == EmotionExecutionPersistenceState.saving;
    final hasCompletionFailure =
        persistenceState == EmotionExecutionPersistenceState.completionFailure;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        ActivityVisualHeader(
          icon: activityIconForLabel(
            exercise.label,
            fallback: Icons.mood_rounded,
          ),
          title: exercise.label,
          instructions: exercise.prompt,
          progressLabel:
              'Pregunta ${_currentIndex + 1} de ${_exercises.length}',
          progress: (_currentIndex + 1) / _exercises.length,
          accent: AppColors.secondary,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _answerController,
          enabled: canInteract && !_isReviewed,
          minLines: 3,
          maxLines: 5,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (canInteract && !_isReviewed) _reviewAnswer();
          },
          decoration: const InputDecoration(
            labelText: 'Tu respuesta',
            hintText: 'Escribe aquí lo que piensas',
            alignLabelWithHint: true,
          ),
        ),
        if (_isReviewed) ...[
          const SizedBox(height: 18),
          const _EmotionMessage(message: 'Gracias por compartir tu respuesta.'),
        ],
        if (isSaving) ...[
          const SizedBox(height: 18),
          _EmotionProgressMessage(
            message: ActivityExecutionUiText.saving(
              previewMode: widget.previewMode,
            ),
          ),
        ],
        if (hasCompletionFailure) ...[
          const SizedBox(height: 18),
          _EmotionMessage(
            message: ActivityExecutionUiText.completionFailure(
              previewMode: widget.previewMode,
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (hasCompletionFailure)
          ElevatedButton.icon(
            onPressed: _retryCompletion,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              ActivityExecutionUiText.retryLabel(
                previewMode: widget.previewMode,
              ),
            ),
          )
        else if (_isReviewed)
          ElevatedButton.icon(
            onPressed: canInteract ? _continue : null,
            icon: Icon(
              _currentIndex == _exercises.length - 1
                  ? Icons.check_rounded
                  : Icons.arrow_forward_rounded,
            ),
            label: Text(
              isSaving
                  ? ActivityExecutionUiText.busyLabel(
                      previewMode: widget.previewMode,
                    )
                  : _currentIndex == _exercises.length - 1
                  ? 'Finalizar'
                  : 'Siguiente',
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: canInteract ? _reviewAnswer : null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Revisar respuesta'),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: isSaving ? null : _requestExit,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Volver'),
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
              Icons.check_circle_rounded,
              size: 72,
              color: AppColors.success,
            ),
            const SizedBox(height: 20),
            Text(
              '¡Terminaste la actividad!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              key: const ValueKey('activity-execution-return'),
              onPressed: _requestExit,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Volver a mis actividades'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _repeat,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Repetir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmotionStatusScaffold extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _EmotionStatusScaffold({
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

class _EmotionProgressMessage extends StatelessWidget {
  final String message;

  const _EmotionProgressMessage({required this.message});

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

class _EmotionMessage extends StatelessWidget {
  final String message;

  const _EmotionMessage({required this.message});

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
