import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/activity_model.dart';
import '../../../activities/config/models/activity_configuration.dart';
import '../../../activities/config/models/activity_configurations.dart';
import 'activity_execution_ui_text.dart';
import 'matching_execution_controller.dart';
import 'matching_execution_utils.dart';
import 'widgets/activity_visual_components.dart';

typedef MatchingAnswerOrderBuilder = List<MatchingAnswerOption> Function(
  List<MatchingAnswerOption> answers,
);

Future<void> openMatchingExecution(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! MatchingActivityConfig) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MatchingExecutionScreen(
        activity: activity,
        configuration: configuration,
      ),
    ),
  );
}

class MatchingExecutionScreen extends StatefulWidget {
  final ActivityModel activity;
  final MatchingActivityConfig configuration;
  final MatchingAnswerOrderBuilder? answerOrderBuilder;
  final MatchingExecutionPersistence? persistence;
  final bool previewMode;

  const MatchingExecutionScreen({
    super.key,
    required this.activity,
    required this.configuration,
    this.answerOrderBuilder,
    this.persistence,
    this.previewMode = false,
  });

  @override
  State<MatchingExecutionScreen> createState() =>
      _MatchingExecutionScreenState();
}

class _MatchingExecutionScreenState extends State<MatchingExecutionScreen> {
  late final List<MatchingPairConfig> _pairs;
  late List<MatchingAnswerOption> _answers;
  late final MatchingExecutionController _controller;
  final Set<String> _completedPairIds = {};
  final Set<String> _usedAnswerIds = {};
  String? _selectedPairId;
  String? _feedback;
  bool _exitDialogVisible = false;
  bool _allowPop = false;

  bool get _canRun =>
      widget.activity.type == ActivityType.matching &&
      (widget.activity.status == ActivityStatus.assigned ||
          widget.activity.status == ActivityStatus.inProgress) &&
      widget.configuration.isValid &&
      _pairs.isNotEmpty;

  bool get _isCompleted =>
      _pairs.isNotEmpty && _completedPairIds.length == _pairs.length;

  @override
  void initState() {
    super.initState();
    _pairs = List.unmodifiable(widget.configuration.pairs);
    _answers = _createAnswerOrder();
    _controller = MatchingExecutionController(
      activityId: widget.activity.id,
      relationsCount: _pairs.isEmpty ? 1 : _pairs.length,
      persistence: widget.persistence ?? MatchingExecutionServicePersistence(),
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

  List<MatchingAnswerOption> _createAnswerOrder() {
    final available = matchingAnswerOptions(widget.configuration);
    final candidate =
        widget.answerOrderBuilder?.call(List.unmodifiable(available)) ??
        initialMatchingAnswerOrder(available);
    final expectedIds = available.map((answer) => answer.id).toSet();
    final candidateIds = candidate.map((answer) => answer.id).toSet();
    if (candidate.length != available.length ||
        candidateIds.length != expectedIds.length ||
        !candidateIds.containsAll(expectedIds)) {
      return initialMatchingAnswerOrder(available);
    }
    return List.of(candidate);
  }

  void _selectPair(MatchingPairConfig pair) {
    if (_controller.state != MatchingExecutionPersistenceState.ready ||
        _completedPairIds.contains(pair.id) ||
        _isCompleted) {
      return;
    }
    setState(() {
      _selectedPairId = pair.id;
      _feedback = null;
    });
  }

  Future<void> _selectAnswer(MatchingAnswerOption answer) async {
    if (_controller.state != MatchingExecutionPersistenceState.ready ||
        _usedAnswerIds.contains(answer.id) ||
        _isCompleted) {
      return;
    }
    final selectedId = _selectedPairId;
    if (selectedId == null) {
      setState(() => _feedback = 'Selecciona primero un elemento.');
      return;
    }

    final pair = _pairs.firstWhere((item) => item.id == selectedId);
    if (isMatchingAnswerCorrect(pair, answer)) {
      setState(() {
        _completedPairIds.add(pair.id);
        _usedAnswerIds.add(answer.id);
        _selectedPairId = null;
        _feedback = _isCompleted ? null : '¡Muy bien! Encontraste la relación.';
      });

      final saved = await _controller.recordCheck(
        relationsCompleted: _completedPairIds.length,
      );
      if (!mounted || !saved) return;
      setState(
        () => _feedback = ActivityExecutionUiText.saved(
          previewMode: widget.previewMode,
        ),
      );
      return;
    }

    await _controller.recordCheck(relationsCompleted: _completedPairIds.length);
    if (!mounted) return;
    setState(() => _feedback = 'Intenta con otra opción.');
  }

  Future<void> _repeat() async {
    setState(() {
      _answers = _createAnswerOrder();
      _completedPairIds.clear();
      _usedAnswerIds.clear();
      _selectedPairId = null;
      _feedback = null;
    });
    await _controller.startNewExecution();
  }

  Future<void> _retryCompletion() async {
    final saved = await _controller.retryCompletion();
    if (!mounted || !saved) return;
    setState(
      () => _feedback = ActivityExecutionUiText.saved(
        previewMode: widget.previewMode,
      ),
    );
  }

  Future<void> _requestExit() async {
    if (_exitDialogVisible) return;
    final state = _controller.state;
    if (state == MatchingExecutionPersistenceState.completed ||
        state == MatchingExecutionPersistenceState.interrupted ||
        state == MatchingExecutionPersistenceState.startFailure ||
        state == MatchingExecutionPersistenceState.idle) {
      _popAfterAllowing();
      return;
    }

    if (state == MatchingExecutionPersistenceState.starting ||
        state == MatchingExecutionPersistenceState.saving ||
        state == MatchingExecutionPersistenceState.interrupting) {
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

    if (state == MatchingExecutionPersistenceState.completionFailure) {
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
        appBar: AppBar(title: const Text('Emparejamiento')),
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
    if (persistenceState == MatchingExecutionPersistenceState.idle ||
        persistenceState == MatchingExecutionPersistenceState.starting) {
      scaffold = _MatchingStatusScaffold(
        title: widget.activity.title,
        message: 'Iniciando actividad...',
        showProgress: true,
      );
    } else if (persistenceState ==
        MatchingExecutionPersistenceState.startFailure) {
      scaffold = _MatchingStatusScaffold(
        title: widget.activity.title,
        message: 'No pudimos iniciar la actividad.',
        primaryLabel: 'Reintentar',
        onPrimary: _controller.start,
        secondaryLabel: 'Volver',
        onSecondary: _requestExit,
      );
    } else {
      final isPersisted =
          persistenceState == MatchingExecutionPersistenceState.completed;
      final isSaving =
          persistenceState == MatchingExecutionPersistenceState.saving;
      final hasCompletionFailure =
          persistenceState ==
          MatchingExecutionPersistenceState.completionFailure;
      final customInstructions = widget.activity.instructions.trim();
      final instructions = customInstructions.isEmpty
          ? 'Selecciona un elemento y luego busca su respuesta.'
          : customInstructions;

      scaffold = Scaffold(
        appBar: AppBar(
          title: Text(widget.activity.title, overflow: TextOverflow.ellipsis),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ActivityVisualHeader(
                  icon: Icons.compare_arrows_rounded,
                  title: widget.activity.title,
                  instructions: instructions,
                  progressLabel:
                      '${_completedPairIds.length} de ${_pairs.length} relaciones completadas',
                  progress: _completedPairIds.length / _pairs.length,
                  compact: true,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: IgnorePointer(
                    ignoring:
                        persistenceState !=
                        MatchingExecutionPersistenceState.ready,
                    child: SingleChildScrollView(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final elements = _MatchingColumn(
                            title: 'Elementos',
                            children: _pairs
                                .map(
                                  (pair) => _MatchingChoiceCard(
                                    text: pair.left,
                                    semanticLabel: 'Elemento ${pair.left}',
                                    selected: _selectedPairId == pair.id,
                                    completed: _completedPairIds.contains(
                                      pair.id,
                                    ),
                                    onTap: () => _selectPair(pair),
                                  ),
                                )
                                .toList(growable: false),
                          );
                          final answers = _MatchingColumn(
                            title: 'Respuestas',
                            children: _answers
                                .map(
                                  (answer) => _MatchingChoiceCard(
                                    text: answer.text,
                                    semanticLabel: 'Respuesta ${answer.text}',
                                    completed: _usedAnswerIds.contains(
                                      answer.id,
                                    ),
                                    onTap: () => _selectAnswer(answer),
                                  ),
                                )
                                .toList(growable: false),
                          );

                          if (constraints.maxWidth >= 600) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: elements),
                                const SizedBox(width: 20),
                                Expanded(child: answers),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              elements,
                              const SizedBox(height: 20),
                              answers,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (isSaving) ...[
                  const SizedBox(height: 12),
                  _MatchingProgressMessage(
                    message: ActivityExecutionUiText.saving(
                      previewMode: widget.previewMode,
                    ),
                  ),
                ],
                if (hasCompletionFailure) ...[
                  const SizedBox(height: 12),
                  _MatchingMessage(
                    message: ActivityExecutionUiText.completionFailure(
                      previewMode: widget.previewMode,
                    ),
                    isSuccess: false,
                  ),
                ],
                if (_feedback != null) ...[
                  const SizedBox(height: 12),
                  _MatchingMessage(message: _feedback!, isSuccess: isPersisted),
                ],
                const SizedBox(height: 14),
                if (isPersisted)
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        key: const ValueKey('activity-execution-return'),
                        onPressed: _requestExit,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Volver a mis actividades'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _repeat,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Repetir'),
                      ),
                    ],
                  )
                else if (hasCompletionFailure)
                  ElevatedButton.icon(
                    onPressed: _retryCompletion,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      ActivityExecutionUiText.retryLabel(
                        previewMode: widget.previewMode,
                      ),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : _requestExit,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Volver'),
                  ),
              ],
            ),
          ),
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
}

class _MatchingStatusScaffold extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _MatchingStatusScaffold({
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

class _MatchingProgressMessage extends StatelessWidget {
  final String message;

  const _MatchingProgressMessage({required this.message});

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

class _MatchingMessage extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const _MatchingMessage({required this.message, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSuccess ? AppColors.mintLight : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              color: isSuccess ? AppColors.success : AppColors.primaryDark,
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

class _MatchingColumn extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MatchingColumn({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MatchingChoiceCard extends StatelessWidget {
  final String text;
  final String semanticLabel;
  final bool selected;
  final bool completed;
  final VoidCallback onTap;

  const _MatchingChoiceCard({
    required this.text,
    required this.semanticLabel,
    this.selected = false,
    this.completed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.divider;
    final backgroundColor = completed
        ? AppColors.mintLight
        : selected
        ? AppColors.cardBg
        : AppColors.surface;

    return Semantics(
      button: true,
      selected: selected,
      enabled: !completed,
      label: semanticLabel,
      child: AnimatedContainer(
        duration: activityMotionDuration(context),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: completed ? AppColors.success : borderColor,
            width: selected || completed ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: completed ? null : onTap,
            borderRadius: BorderRadius.circular(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    ActivityIllustrationBadge(
                      icon: completed
                          ? Icons.check_rounded
                          : activityIconForLabel(text),
                      selected: selected || completed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const Text('Seleccionado'),
                    ],
                    if (completed) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
