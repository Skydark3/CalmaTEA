import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/activity_model.dart';
import '../../../activities/config/models/activity_configuration.dart';
import '../../../activities/config/models/activity_configurations.dart';
import 'activity_execution_ui_text.dart';
import 'sequence_execution_controller.dart';
import 'sequence_execution_utils.dart';
import 'widgets/activity_visual_components.dart';

typedef SequenceInitialOrderBuilder = List<SequenceItemConfig> Function(
  List<SequenceItemConfig> correctItems,
);

Future<void> openSequenceExecution(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! SequenceActivityConfig) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SequenceExecutionScreen(
        activity: activity,
        configuration: configuration,
      ),
    ),
  );
}

class SequenceExecutionScreen extends StatefulWidget {
  final ActivityModel activity;
  final SequenceActivityConfig configuration;
  final SequenceInitialOrderBuilder? initialOrderBuilder;
  final SequenceExecutionPersistence? persistence;
  final bool previewMode;

  const SequenceExecutionScreen({
    super.key,
    required this.activity,
    required this.configuration,
    this.initialOrderBuilder,
    this.persistence,
    this.previewMode = false,
  });

  @override
  State<SequenceExecutionScreen> createState() =>
      _SequenceExecutionScreenState();
}

class _SequenceExecutionScreenState extends State<SequenceExecutionScreen> {
  late final List<SequenceItemConfig> _correctItems;
  late List<SequenceItemConfig> _currentItems;
  late final SequenceExecutionController _controller;
  String? _feedback;
  bool _exitDialogVisible = false;
  bool _allowPop = false;

  bool get _canRun =>
      widget.activity.type == ActivityType.sequence &&
      (widget.activity.status == ActivityStatus.assigned ||
          widget.activity.status == ActivityStatus.inProgress) &&
      widget.configuration.isValid &&
      _correctItems.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _correctItems = correctSequenceOrder(widget.configuration);
    _currentItems = _createInitialItems();
    _controller = SequenceExecutionController(
      activityId: widget.activity.id,
      itemsCount: _correctItems.isEmpty ? 1 : _correctItems.length,
      persistence: widget.persistence ?? SequenceExecutionServicePersistence(),
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

  List<SequenceItemConfig> _createInitialItems() {
    final candidate =
        widget.initialOrderBuilder?.call(List.unmodifiable(_correctItems)) ??
        initialSequenceOrder(_correctItems);
    final expectedIds = _correctItems.map((item) => item.id).toSet();
    final candidateIds = candidate.map((item) => item.id).toSet();
    if (candidate.length != _correctItems.length ||
        candidateIds.length != expectedIds.length ||
        !candidateIds.containsAll(expectedIds)) {
      return initialSequenceOrder(_correctItems);
    }
    return List.of(candidate);
  }

  void _reorder(int oldIndex, int newIndex) {
    if (_controller.state != SequenceExecutionPersistenceState.ready) return;
    setState(() {
      _currentItems = moveSequenceItem(_currentItems, oldIndex, newIndex);
      _feedback = null;
    });
  }

  void _moveBy(int index, int offset) {
    if (_controller.state != SequenceExecutionPersistenceState.ready) return;
    final targetIndex = index + offset;
    if (targetIndex < 0 || targetIndex >= _currentItems.length) return;
    setState(() {
      _currentItems = moveSequenceItem(_currentItems, index, targetIndex);
      _feedback = null;
    });
  }

  Future<void> _checkOrder() async {
    final isCorrect = isSequenceOrderCorrect(_currentItems, _correctItems);
    if (!isCorrect) {
      await _controller.checkOrder(isCorrect: false);
      if (!mounted) return;
      setState(() {
        _feedback = 'Todavía hay pasos por ordenar. ¡Inténtalo otra vez!';
      });
      return;
    }

    setState(() => _feedback = null);
    final saved = await _controller.checkOrder(isCorrect: true);
    if (!mounted || !saved) return;
    setState(
      () => _feedback = ActivityExecutionUiText.saved(
        previewMode: widget.previewMode,
      ),
    );
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

  Future<void> _repeat() async {
    setState(() {
      _currentItems = _createInitialItems();
      _feedback = null;
    });
    await _controller.startNewExecution();
  }

  Future<void> _requestExit() async {
    if (_exitDialogVisible) return;
    final state = _controller.state;
    if (state == SequenceExecutionPersistenceState.completed ||
        state == SequenceExecutionPersistenceState.interrupted ||
        state == SequenceExecutionPersistenceState.startFailure ||
        state == SequenceExecutionPersistenceState.idle) {
      _popAfterAllowing();
      return;
    }

    if (state == SequenceExecutionPersistenceState.starting ||
        state == SequenceExecutionPersistenceState.saving ||
        state == SequenceExecutionPersistenceState.interrupting) {
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

    if (state == SequenceExecutionPersistenceState.completionFailure) {
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
        appBar: AppBar(title: const Text('Secuencia')),
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
    if (persistenceState == SequenceExecutionPersistenceState.idle ||
        persistenceState == SequenceExecutionPersistenceState.starting) {
      return _SequenceStatusScaffold(
        title: widget.activity.title,
        message: 'Iniciando actividad...',
        showProgress: true,
      );
    }
    if (persistenceState == SequenceExecutionPersistenceState.startFailure) {
      return _SequenceStatusScaffold(
        title: widget.activity.title,
        message: 'No pudimos iniciar la actividad.',
        primaryLabel: 'Reintentar',
        onPrimary: _controller.start,
        secondaryLabel: 'Volver',
        onSecondary: _requestExit,
      );
    }

    final isCompleted =
        persistenceState == SequenceExecutionPersistenceState.completed;
    final isSaving =
        persistenceState == SequenceExecutionPersistenceState.saving;
    final hasCompletionFailure =
        persistenceState == SequenceExecutionPersistenceState.completionFailure;
    final customInstructions = widget.activity.instructions.trim();
    final instructions = customInstructions.isEmpty
        ? 'Ordena los pasos y luego pulsa Comprobar.'
        : customInstructions;

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ActivityVisualHeader(
                  icon: Icons.format_list_numbered_rounded,
                  title: widget.activity.title,
                  instructions: instructions,
                  progressLabel: '${_currentItems.length} pasos para ordenar',
                  compact: true,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: IgnorePointer(
                    ignoring:
                        persistenceState !=
                        SequenceExecutionPersistenceState.ready,
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: _currentItems.length,
                      onReorderItem: _reorder,
                      itemBuilder: (context, index) {
                        final item = _currentItems[index];
                        return _SequenceStepCard(
                          key: ValueKey(item.id),
                          item: item,
                          position: index + 1,
                          canMoveUp: index > 0,
                          canMoveDown: index < _currentItems.length - 1,
                          onMoveUp: () => _moveBy(index, -1),
                          onMoveDown: () => _moveBy(index, 1),
                          dragHandle: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.drag_handle_rounded),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (isSaving) ...[
                  const SizedBox(height: 12),
                  _SequenceProgressMessage(
                    message: ActivityExecutionUiText.saving(
                      previewMode: widget.previewMode,
                    ),
                  ),
                ],
                if (hasCompletionFailure) ...[
                  const SizedBox(height: 12),
                  _SequenceMessage(
                    message: ActivityExecutionUiText.completionFailure(
                      previewMode: widget.previewMode,
                    ),
                    isSuccess: false,
                  ),
                ],
                if (_feedback != null) ...[
                  const SizedBox(height: 12),
                  _SequenceMessage(message: _feedback!, isSuccess: isCompleted),
                ],
                const SizedBox(height: 14),
                if (isCompleted)
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
                else ...[
                  ElevatedButton.icon(
                    onPressed:
                        persistenceState ==
                            SequenceExecutionPersistenceState.ready
                        ? _checkOrder
                        : null,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      isSaving
                          ? ActivityExecutionUiText.busyLabel(
                              previewMode: widget.previewMode,
                            )
                          : 'Comprobar',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : _requestExit,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Volver'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SequenceStatusScaffold extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _SequenceStatusScaffold({
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

class _SequenceProgressMessage extends StatelessWidget {
  final String message;

  const _SequenceProgressMessage({required this.message});

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

class _SequenceMessage extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const _SequenceMessage({required this.message, required this.isSuccess});

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

class _SequenceStepCard extends StatelessWidget {
  final SequenceItemConfig item;
  final int position;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final Widget dragHandle;

  const _SequenceStepCard({
    super.key,
    required this.item,
    required this.position,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso $position: ${item.label}',
      child: AnimatedContainer(
        duration: activityMotionDuration(context),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ActivityIllustrationBadge(
                    icon: activityIconForLabel(
                      item.label,
                      fallback: Icons.route_rounded,
                    ),
                    size: 48,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: AppColors.textOnPrimary,
                      child: Text(
                        '$position',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: canMoveUp ? onMoveUp : null,
                    tooltip: 'Mover ${item.label} hacia arriba',
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  IconButton(
                    onPressed: canMoveDown ? onMoveDown : null,
                    tooltip: 'Mover ${item.label} hacia abajo',
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
              Semantics(label: 'Arrastrar ${item.label}', child: dragHandle),
            ],
          ),
        ),
      ),
    );
  }
}
