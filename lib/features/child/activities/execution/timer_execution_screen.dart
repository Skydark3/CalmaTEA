import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/activity_model.dart';
import '../../../activities/config/models/activity_configuration.dart';
import '../../../activities/config/models/activity_configurations.dart';
import 'activity_execution_ui_text.dart';
import 'timer_execution_controller.dart';
import 'timer_execution_utils.dart';
import 'widgets/activity_visual_components.dart';

Future<void> openTimerExecution(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! TimerActivityConfig) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => TimerExecutionScreen(
        activity: activity,
        configuration: configuration,
      ),
    ),
  );
}

class TimerExecutionScreen extends StatefulWidget {
  final ActivityModel activity;
  final TimerActivityConfig configuration;
  final TimerCountdownController? countdownController;
  final TimerExecutionPersistence? persistence;
  final bool previewMode;

  const TimerExecutionScreen({
    super.key,
    required this.activity,
    required this.configuration,
    this.countdownController,
    this.persistence,
    this.previewMode = false,
  });

  @override
  State<TimerExecutionScreen> createState() => _TimerExecutionScreenState();
}

class _TimerExecutionScreenState extends State<TimerExecutionScreen>
    with WidgetsBindingObserver {
  late final TimerCountdownController _countdown;
  late final TimerExecutionController _controller;
  Timer? _interfaceTicker;
  bool _hasStarted = false;
  bool _completionRequested = false;
  bool _exitDialogVisible = false;
  bool _allowPop = false;

  bool get _canRun =>
      widget.activity.type == ActivityType.timer &&
      (widget.activity.status == ActivityStatus.assigned ||
          widget.activity.status == ActivityStatus.inProgress) &&
      widget.configuration.isValid &&
      widget.configuration.durationSeconds > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _countdown =
        widget.countdownController ??
        TimerCountdownController(
          durationSeconds: widget.configuration.durationSeconds,
        );
    _controller = TimerExecutionController(
      activityId: widget.activity.id,
      persistence: widget.persistence ?? TimerExecutionServicePersistence(),
    )..addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _countdown.isRunning) {
      _pause();
    }
  }

  Future<void> _startOrContinue() async {
    if (_countdown.isFinished || _controller.isBusy) return;
    if (_controller.state == TimerExecutionPersistenceState.idle ||
        _controller.state == TimerExecutionPersistenceState.startFailure) {
      final started = await _controller.start();
      if (!mounted || !started) return;
    }
    if (_controller.state != TimerExecutionPersistenceState.ready) return;
    _interfaceTicker?.cancel();
    _countdown.start();
    _hasStarted = true;
    _interfaceTicker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _refreshTime(),
    );
    setState(() {});
  }

  void _refreshTime() {
    if (!mounted) return;
    if (_countdown.isFinished) {
      _interfaceTicker?.cancel();
      _interfaceTicker = null;
      _countdown.pause();
      if (!_completionRequested) unawaited(_completeExpiredTimer());
    }
    setState(() {});
  }

  Future<void> _completeExpiredTimer() async {
    if (_completionRequested || !_countdown.isFinished) return;
    _completionRequested = true;
    final saved = await _controller.finish(
      configuredDurationSeconds: widget.configuration.durationSeconds,
      elapsedSeconds: _countdown.elapsedSeconds,
    );
    if (!mounted || !saved) return;
    setState(() {});
  }

  Future<void> _retryCompletion() async {
    final saved = await _controller.retryCompletion();
    if (!mounted || !saved) return;
    setState(() {});
  }

  void _pause() {
    _countdown.pause();
    _interfaceTicker?.cancel();
    _interfaceTicker = null;
    if (_countdown.isFinished && !_completionRequested) {
      unawaited(_completeExpiredTimer());
    }
    if (mounted) setState(() {});
  }

  void _reset() {
    if (_controller.isBusy ||
        _controller.state == TimerExecutionPersistenceState.completionFailure) {
      return;
    }
    _interfaceTicker?.cancel();
    _interfaceTicker = null;
    _countdown.reset();
    if (_controller.state == TimerExecutionPersistenceState.completed) {
      _controller.resetForNewExecution();
    }
    setState(() {
      _hasStarted = false;
      _completionRequested = false;
    });
  }

  Future<void> _requestExit() async {
    if (_exitDialogVisible) return;
    final state = _controller.state;
    if (state == TimerExecutionPersistenceState.idle ||
        state == TimerExecutionPersistenceState.startFailure ||
        state == TimerExecutionPersistenceState.completed ||
        state == TimerExecutionPersistenceState.interrupted) {
      _popAfterAllowing();
      return;
    }

    if (state == TimerExecutionPersistenceState.starting ||
        state == TimerExecutionPersistenceState.saving ||
        state == TimerExecutionPersistenceState.interrupting) {
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

    if (state == TimerExecutionPersistenceState.completionFailure) {
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

    final wasRunning = _countdown.isRunning;
    if (wasRunning) _pause();
    if (_countdown.isFinished) {
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
    if (!mounted) return;
    if (shouldExit != true) {
      if (wasRunning) await _startOrContinue();
      return;
    }

    final interrupted = await _controller.interrupt();
    if (!mounted) return;
    if (interrupted) {
      _countdown.reset();
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _interfaceTicker?.cancel();
    _countdown.dispose();
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRun) {
      return Scaffold(
        appBar: AppBar(title: const Text('Temporizador')),
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

    final label = widget.configuration.label?.trim();
    final instructions = widget.activity.instructions.trim();
    final persistenceState = _controller.state;
    final isCompleted =
        persistenceState == TimerExecutionPersistenceState.completed;
    final isAwaitingCompletion = _countdown.isFinished && !isCompleted;
    final timerDiameter = MediaQuery.sizeOf(context).height < 700
        ? 150.0
        : 220.0;

    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.activity.title, overflow: TextOverflow.ellipsis),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              ActivityVisualHeader(
                icon: Icons.timer_rounded,
                title: label != null && label.isNotEmpty
                    ? label
                    : widget.activity.title,
                instructions: instructions.isEmpty
                    ? 'Avanza con calma hasta que termine el tiempo.'
                    : instructions,
                progressLabel: _countdown.isFinished
                    ? 'Tiempo completado'
                    : '${_countdown.remainingSeconds} segundos restantes',
                progress: _countdown.progress,
                compact: true,
              ),
              const SizedBox(height: 28),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: AppColors.cardBg,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Center(
                    child: SizedBox.square(
                      dimension: timerDiameter,
                      child: TweenAnimationBuilder<double>(
                        duration: activityMotionDuration(context),
                        tween: Tween(end: _countdown.progress),
                        builder: (context, progress, child) => Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 16,
                              strokeCap: StrokeCap.round,
                              backgroundColor: AppColors.surface,
                              color: AppColors.mint,
                            ),
                            Center(child: child),
                          ],
                        ),
                        child: Semantics(
                          liveRegion: true,
                          label:
                              '${_countdown.remainingSeconds} segundos restantes',
                          child: Text(
                            formatTimerDuration(_countdown.remainingSeconds),
                            key: const ValueKey('timer-remaining-time'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (isCompleted)
                _buildFinishedControls(context)
              else if (isAwaitingCompletion)
                _buildCompletionControls(context)
              else
                _buildRunningControls(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunningControls(BuildContext context) {
    final persistenceState = _controller.state;
    final isStarting =
        persistenceState == TimerExecutionPersistenceState.starting;
    final hasStartFailure =
        persistenceState == TimerExecutionPersistenceState.startFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasStartFailure) ...[
          const _TimerMessage(message: 'No pudimos iniciar la actividad.'),
          const SizedBox(height: 12),
        ],
        if (isStarting)
          const ElevatedButton(onPressed: null, child: Text('Iniciando...'))
        else if (_countdown.isRunning)
          ElevatedButton.icon(
            onPressed: _pause,
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pausar'),
          )
        else
          ElevatedButton.icon(
            onPressed: _startOrContinue,
            icon: Icon(
              _hasStarted ? Icons.play_arrow_rounded : Icons.timer_rounded,
            ),
            label: Text(
              hasStartFailure
                  ? 'Reintentar inicio'
                  : _hasStarted
                  ? 'Continuar'
                  : 'Iniciar',
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _controller.isBusy ? null : _reset,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Reiniciar'),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _requestExit,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Volver'),
        ),
      ],
    );
  }

  Widget _buildCompletionControls(BuildContext context) {
    final hasFailure =
        _controller.state == TimerExecutionPersistenceState.completionFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasFailure) ...[
          _TimerMessage(
            message: ActivityExecutionUiText.completionFailure(
              previewMode: widget.previewMode,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _retryCompletion,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              ActivityExecutionUiText.retryLabel(
                previewMode: widget.previewMode,
              ),
            ),
          ),
        ] else
          _TimerProgressMessage(
            message: ActivityExecutionUiText.saving(
              previewMode: widget.previewMode,
            ),
          ),
      ],
    );
  }

  Widget _buildFinishedControls(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¡Terminó el tiempo!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Repetir'),
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
    );
  }
}

class _TimerProgressMessage extends StatelessWidget {
  final String message;

  const _TimerProgressMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(message)),
      ],
    );
  }
}

class _TimerMessage extends StatelessWidget {
  final String message;

  const _TimerMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mintLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}
