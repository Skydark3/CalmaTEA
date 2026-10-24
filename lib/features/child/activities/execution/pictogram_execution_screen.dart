import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/activity_model.dart';
import '../../../activities/config/models/activity_configuration.dart';
import '../../../activities/config/models/activity_configurations.dart';
import 'activity_execution_ui_text.dart';
import 'pictogram_execution_controller.dart';
import 'widgets/activity_visual_components.dart';

Future<void> openPictogramExecution(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! PictogramActivityConfig) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => PictogramExecutionScreen(
        activity: activity,
        configuration: configuration,
      ),
    ),
  );
}

class PictogramExecutionScreen extends StatefulWidget {
  final ActivityModel activity;
  final PictogramActivityConfig configuration;
  final PictogramExecutionPersistence? persistence;
  final bool previewMode;

  const PictogramExecutionScreen({
    super.key,
    required this.activity,
    required this.configuration,
    this.persistence,
    this.previewMode = false,
  });

  @override
  State<PictogramExecutionScreen> createState() =>
      _PictogramExecutionScreenState();
}

class _PictogramExecutionScreenState extends State<PictogramExecutionScreen> {
  late final PictogramExecutionController _controller;
  String? _selectedOptionId;
  bool _isFinished = false;
  bool _exitDialogVisible = false;
  bool _allowPop = false;

  List<PictogramOptionConfig> get _options => widget.configuration.options;

  bool get _canRun =>
      widget.activity.type == ActivityType.pictogram &&
      (widget.activity.status == ActivityStatus.assigned ||
          widget.activity.status == ActivityStatus.inProgress) &&
      widget.configuration.isValid &&
      _options.isNotEmpty;

  PictogramOptionConfig? get _selectedOption {
    final selectedId = _selectedOptionId;
    if (selectedId == null) return null;
    for (final option in _options) {
      if (option.id == selectedId) return option;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller = PictogramExecutionController(
      activityId: widget.activity.id,
      persistence: widget.persistence ?? PictogramExecutionServicePersistence(),
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
    _selectedOptionId = null;
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _selectOption(PictogramOptionConfig option) {
    if (_controller.state != PictogramExecutionPersistenceState.ready) return;
    _controller.recordInteraction();
    setState(() => _selectedOptionId = option.id);
  }

  void _clearSelection() {
    if (_controller.state != PictogramExecutionPersistenceState.ready) return;
    setState(() => _selectedOptionId = null);
  }

  Future<void> _finishOrExit() async {
    if (_controller.state != PictogramExecutionPersistenceState.ready) return;
    if (_controller.interactionsCount == 0) {
      await _requestExit();
      return;
    }

    setState(() => _selectedOptionId = null);
    final saved = await _controller.finish();
    if (!mounted || !saved) return;
    setState(() => _isFinished = true);
  }

  Future<void> _retryCompletion() async {
    final saved = await _controller.retryCompletion();
    if (!mounted || !saved) return;
    setState(() => _isFinished = true);
  }

  Future<void> _repeat() async {
    setState(() {
      _selectedOptionId = null;
      _isFinished = false;
    });
    await _controller.startNewExecution();
  }

  Future<void> _requestExit() async {
    if (_exitDialogVisible) return;
    final state = _controller.state;
    if (state == PictogramExecutionPersistenceState.completed ||
        state == PictogramExecutionPersistenceState.interrupted ||
        state == PictogramExecutionPersistenceState.startFailure ||
        state == PictogramExecutionPersistenceState.idle) {
      _popAfterAllowing();
      return;
    }

    if (state == PictogramExecutionPersistenceState.starting ||
        state == PictogramExecutionPersistenceState.saving ||
        state == PictogramExecutionPersistenceState.interrupting) {
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

    if (state == PictogramExecutionPersistenceState.completionFailure) {
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
      setState(() => _selectedOptionId = null);
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
        appBar: AppBar(title: const Text('Pictogramas')),
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
    if (persistenceState == PictogramExecutionPersistenceState.idle ||
        persistenceState == PictogramExecutionPersistenceState.starting) {
      return PopScope<void>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestExit();
        },
        child: _PictogramStatusScaffold(
          title: widget.activity.title,
          message: 'Iniciando actividad...',
          showProgress: true,
        ),
      );
    }
    if (persistenceState == PictogramExecutionPersistenceState.startFailure) {
      return PopScope<void>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestExit();
        },
        child: _PictogramStatusScaffold(
          title: widget.activity.title,
          message: 'No pudimos iniciar la actividad.',
          primaryLabel: 'Reintentar',
          onPrimary: _controller.start,
          secondaryLabel: 'Volver',
          onSecondary: _requestExit,
        ),
      );
    }
    if (_isFinished) {
      return PopScope<void>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestExit();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.activity.title, overflow: TextOverflow.ellipsis),
          ),
          body: SafeArea(child: _buildFinished(context)),
        ),
      );
    }

    final canInteract =
        persistenceState == PictogramExecutionPersistenceState.ready;
    final isSaving =
        persistenceState == PictogramExecutionPersistenceState.saving;
    final hasCompletionFailure =
        persistenceState ==
        PictogramExecutionPersistenceState.completionFailure;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 3 : 2;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: LayoutBuilder(
                  builder: (context, gridConstraints) {
                    final itemWidth =
                        (gridConstraints.maxWidth - (columns - 1) * 12) /
                        columns;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ActivityVisualHeader(
                          icon: Icons.forum_rounded,
                          title: 'Elige una opción',
                          instructions:
                              'Toca una tarjeta para comunicar tu elección.',
                          progressLabel: _selectedOption == null
                              ? 'Ninguna opción seleccionada'
                              : 'Opción seleccionada',
                          progress: _selectedOption == null ? 0 : 1,
                          compact: true,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final option in _options)
                              SizedBox(
                                width: itemWidth,
                                height: 150,
                                child: _PictogramOptionCard(
                                  key: ValueKey(
                                    'pictogram-option-${option.id}',
                                  ),
                                  option: option,
                                  isSelected: option.id == _selectedOptionId,
                                  isEnabled: canInteract,
                                  onTap: () => _selectOption(option),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _SelectionConfirmation(option: _selectedOption),
                        if (_selectedOption != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: canInteract ? _clearSelection : null,
                            icon: const Icon(Icons.clear_rounded),
                            label: const Text('Limpiar selección'),
                          ),
                        ],
                        if (isSaving) ...[
                          const SizedBox(height: 12),
                          _PictogramProgressMessage(
                            message: ActivityExecutionUiText.saving(
                              previewMode: widget.previewMode,
                            ),
                          ),
                        ],
                        if (hasCompletionFailure) ...[
                          const SizedBox(height: 12),
                          _PictogramMessage(
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
                        ],
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          key: const ValueKey('activity-execution-return'),
                          onPressed: canInteract && !hasCompletionFailure
                              ? _finishOrExit
                              : null,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Volver a mis actividades'),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
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

class _PictogramStatusScaffold extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _PictogramStatusScaffold({
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

class _PictogramProgressMessage extends StatelessWidget {
  final String message;

  const _PictogramProgressMessage({required this.message});

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

class _PictogramMessage extends StatelessWidget {
  final String message;

  const _PictogramMessage({required this.message});

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

class _PictogramOptionCard extends StatelessWidget {
  final PictogramOptionConfig option;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _PictogramOptionCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${option.label}${isSelected ? ', seleccionada' : ''}',
      child: AnimatedScale(
        scale: isSelected ? 1.025 : 1,
        duration: activityMotionDuration(context),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: activityMotionDuration(context),
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mintLight : AppColors.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : AppColors.divider,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isEnabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ActivityIllustrationBadge(
                      icon: isSelected
                          ? Icons.check_rounded
                          : activityIconForLabel(
                              option.label,
                              fallback: Icons.chat_bubble_outline_rounded,
                            ),
                      selected: isSelected,
                      size: 52,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Center(
                        child: Text(
                          option.label,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                        ),
                      ),
                    ),
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

class _SelectionConfirmation extends StatelessWidget {
  final PictogramOptionConfig? option;

  const _SelectionConfirmation({required this.option});

  @override
  Widget build(BuildContext context) {
    final selectedOption = option;
    return Semantics(
      liveRegion: true,
      child: AnimatedContainer(
        duration: activityMotionDuration(context),
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selectedOption == null
              ? AppColors.surface
              : AppColors.mintLight,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          selectedOption == null
              ? 'Aún no has seleccionado una opción.'
              : 'Has seleccionado: ${selectedOption.label}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
