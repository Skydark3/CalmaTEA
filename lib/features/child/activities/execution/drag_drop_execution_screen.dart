import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/activity_model.dart';
import '../../../activities/config/models/activity_configuration.dart';
import '../../../activities/config/models/activity_configurations.dart';
import 'activity_execution_ui_text.dart';
import 'drag_drop_execution_controller.dart';
import 'drag_drop_execution_utils.dart';
import 'widgets/activity_visual_components.dart';

Future<void> openDragDropExecution(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! DragDropActivityConfig) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => DragDropExecutionScreen(
        activity: activity,
        configuration: configuration,
      ),
    ),
  );
}

class DragDropExecutionScreen extends StatefulWidget {
  final ActivityModel activity;
  final DragDropActivityConfig configuration;
  final DragDropExecutionPersistence? persistence;
  final bool previewMode;

  const DragDropExecutionScreen({
    super.key,
    required this.activity,
    required this.configuration,
    this.persistence,
    this.previewMode = false,
  });

  @override
  State<DragDropExecutionScreen> createState() =>
      _DragDropExecutionScreenState();
}

class _DragDropExecutionScreenState extends State<DragDropExecutionScreen> {
  late final DragDropExecutionController _controller;
  final Set<String> _placedItemIds = {};
  String? _selectedItemId;
  String? _feedback;
  bool _isFinished = false;
  bool _exitDialogVisible = false;
  bool _allowPop = false;

  List<DragDropItemConfig> get _items => widget.configuration.items;
  List<DragDropTargetConfig> get _targets => widget.configuration.targets;

  bool get _canRun =>
      widget.activity.type == ActivityType.dragDrop &&
      (widget.activity.status == ActivityStatus.assigned ||
          widget.activity.status == ActivityStatus.inProgress) &&
      widget.configuration.isValid &&
      _items.isNotEmpty &&
      _targets.isNotEmpty;

  bool get _isCompleted => _placedItemIds.length == _items.length;

  @override
  void initState() {
    super.initState();
    _controller = DragDropExecutionController(
      activityId: widget.activity.id,
      itemIds: _items.isEmpty
          ? const <String>{'invalid-item'}
          : _items.map((item) => item.id),
      persistence: widget.persistence ?? DragDropExecutionServicePersistence(),
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

  DragDropItemConfig? get _selectedItem {
    final selectedId = _selectedItemId;
    if (selectedId == null) return null;
    for (final item in _items) {
      if (item.id == selectedId && !_placedItemIds.contains(item.id)) {
        return item;
      }
    }
    return null;
  }

  List<DragDropItemConfig> _itemsForTarget(String targetId) {
    return _items
        .where(
          (item) =>
              item.targetId == targetId && _placedItemIds.contains(item.id),
        )
        .toList(growable: false);
  }

  void _selectItem(DragDropItemConfig item) {
    if (_controller.state != DragDropExecutionPersistenceState.ready) return;
    if (_placedItemIds.contains(item.id)) return;
    setState(() {
      _selectedItemId = item.id;
      _feedback = null;
    });
  }

  void _tryPlaceItem(DragDropItemConfig item, DragDropTargetConfig target) {
    if (_controller.state != DragDropExecutionPersistenceState.ready) return;
    if (_placedItemIds.contains(item.id)) return;

    final isCorrect = isDragDropRelationCorrect(item, target);
    _controller.registerCheck(itemId: item.id, isCorrect: isCorrect);
    setState(() {
      if (isCorrect) {
        _placedItemIds.add(item.id);
        if (_selectedItemId == item.id) _selectedItemId = null;
        _feedback = '¡Muy bien! Encontraste el destino.';
      } else {
        _selectedItemId = item.id;
        _feedback = 'Intenta con otro destino.';
      }
    });
    if (_isCompleted) _finishExecution();
  }

  void _trySelectedItem(DragDropTargetConfig target) {
    final item = _selectedItem;
    if (item != null) _tryPlaceItem(item, target);
  }

  Future<void> _finishExecution() async {
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
      _placedItemIds.clear();
      _selectedItemId = null;
      _feedback = null;
      _isFinished = false;
    });
    await _controller.startNewExecution();
  }

  Future<void> _requestExit() async {
    if (_exitDialogVisible) return;
    final state = _controller.state;
    if (state == DragDropExecutionPersistenceState.completed ||
        state == DragDropExecutionPersistenceState.interrupted ||
        state == DragDropExecutionPersistenceState.startFailure ||
        state == DragDropExecutionPersistenceState.idle) {
      _popAfterAllowing();
      return;
    }

    if (state == DragDropExecutionPersistenceState.starting ||
        state == DragDropExecutionPersistenceState.saving ||
        state == DragDropExecutionPersistenceState.interrupting) {
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

    if (state == DragDropExecutionPersistenceState.completionFailure) {
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
        appBar: AppBar(title: const Text('Arrastrar y soltar')),
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
    if (persistenceState == DragDropExecutionPersistenceState.idle ||
        persistenceState == DragDropExecutionPersistenceState.starting) {
      return PopScope<void>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestExit();
        },
        child: _DragDropStatusScaffold(
          title: widget.activity.title,
          message: 'Iniciando actividad...',
          showProgress: true,
        ),
      );
    }
    if (persistenceState == DragDropExecutionPersistenceState.startFailure) {
      return PopScope<void>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestExit();
        },
        child: _DragDropStatusScaffold(
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

    final availableItems = _items
        .where((item) => !_placedItemIds.contains(item.id))
        .toList(growable: false);
    final canInteract =
        persistenceState == DragDropExecutionPersistenceState.ready;
    final isSaving =
        persistenceState == DragDropExecutionPersistenceState.saving;
    final hasCompletionFailure =
        persistenceState == DragDropExecutionPersistenceState.completionFailure;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ActivityVisualHeader(
                  key: const ValueKey('drag-drop-progress'),
                  icon: Icons.open_with_rounded,
                  title: widget.activity.title,
                  instructions: 'Arrastra un elemento o tócalo y después elige su destino.',
                  progressLabel:
                      '${_placedItemIds.length} de ${_items.length} elementos colocados',
                  progress: _placedItemIds.length / _items.length,
                  accent: AppColors.mint,
                  compact: true,
                ),
                if (isSaving) ...[
                  const SizedBox(height: 14),
                  _DragDropProgressMessage(
                    message: ActivityExecutionUiText.saving(
                      previewMode: widget.previewMode,
                    ),
                  ),
                ],
                if (hasCompletionFailure) ...[
                  const SizedBox(height: 14),
                  _DragDropMessage(
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
                const SizedBox(height: 20),
                Text(
                  'Elementos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (availableItems.isEmpty)
                  const _EmptyItemsMessage()
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = constraints.maxWidth >= 520
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final item in availableItems)
                            SizedBox(
                              width: itemWidth,
                              child: _DraggableItemCard(
                                key: ValueKey('drag-drop-item-${item.id}'),
                                item: item,
                                isSelected: item.id == _selectedItemId,
                                isEnabled: canInteract,
                                onTap: () => _selectItem(item),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 24),
                Text('Destinos', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final targetWidth = constraints.maxWidth >= 520
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final target in _targets)
                          SizedBox(
                            width: targetWidth,
                            child: _DropTargetCard(
                              key: ValueKey('drag-drop-target-${target.id}'),
                              target: target,
                              placedItems: _itemsForTarget(target.id),
                              hasSelectedItem: _selectedItem != null,
                              onTap: () => _trySelectedItem(target),
                              onAccept: (item) => _tryPlaceItem(item, target),
                              canAccept: (item) =>
                                  canInteract &&
                                  !_placedItemIds.contains(item.id),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (_feedback != null) ...[
                  const SizedBox(height: 18),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _feedback!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : _requestExit,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Volver'),
                ),
              ],
            ),
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

class _DragDropStatusScaffold extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _DragDropStatusScaffold({
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

class _DragDropProgressMessage extends StatelessWidget {
  final String message;

  const _DragDropProgressMessage({required this.message});

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

class _DragDropMessage extends StatelessWidget {
  final String message;

  const _DragDropMessage({required this.message});

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

class _DraggableItemCard extends StatelessWidget {
  final DragDropItemConfig item;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _DraggableItemCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = _ItemCardContent(
      label: item.label,
      isSelected: isSelected,
      onTap: isEnabled ? onTap : null,
    );
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${item.label}${isSelected ? ', seleccionado' : ''}',
      child: LongPressDraggable<DragDropItemConfig>(
        data: item,
        maxSimultaneousDrags: isEnabled ? 1 : 0,
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: _ItemCardContent(
              label: item.label,
              isSelected: true,
              onTap: null,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: card),
        child: card,
      ),
    );
  }
}

class _ItemCardContent extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ItemCardContent({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: activityMotionDuration(context),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.mintLight : AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.primaryDark : AppColors.divider,
          width: isSelected ? 3 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.mint.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ActivityIllustrationBadge(
                      icon: activityIconForLabel(
                        label,
                        fallback: isSelected
                            ? Icons.touch_app_rounded
                            : Icons.drag_indicator_rounded,
                      ),
                      selected: isSelected,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (isSelected) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Seleccionado',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
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

class _DropTargetCard extends StatelessWidget {
  final DragDropTargetConfig target;
  final List<DragDropItemConfig> placedItems;
  final bool hasSelectedItem;
  final VoidCallback onTap;
  final ValueChanged<DragDropItemConfig> onAccept;
  final bool Function(DragDropItemConfig item) canAccept;

  const _DropTargetCard({
    super.key,
    required this.target,
    required this.placedItems,
    required this.hasSelectedItem,
    required this.onTap,
    required this.onAccept,
    required this.canAccept,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragDropItemConfig>(
      onWillAcceptWithDetails: (details) => canAccept(details.data),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidates, rejected) {
        final isHighlighted = candidates.isNotEmpty;
        return Semantics(
          button: true,
          label: 'Destino ${target.label}',
          hint: hasSelectedItem
              ? 'Toca para comprobar el elemento seleccionado'
              : 'Arrastra un elemento hasta este destino',
          child: AnimatedScale(
            scale: isHighlighted ? 1.015 : 1,
            duration: activityMotionDuration(context),
            child: AnimatedContainer(
              duration: activityMotionDuration(context),
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isHighlighted ? AppColors.mintLight : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isHighlighted
                      ? AppColors.primaryDark
                      : AppColors.secondary,
                  width: isHighlighted ? 3 : 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 116),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              ActivityIllustrationBadge(
                                icon: activityIconForLabel(
                                  target.label,
                                  fallback: Icons.move_to_inbox_rounded,
                                ),
                                selected: isHighlighted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  target.label,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          if (placedItems.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final item in placedItems)
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey('placed-item-${item.id}'),
                                    duration: activityMotionDuration(context),
                                    tween: Tween(begin: 0.92, end: 1),
                                    builder: (context, value, child) =>
                                        Transform.scale(
                                          scale: value,
                                          child: child,
                                        ),
                                    child: Chip(
                                      avatar: const Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                      ),
                                      label: Text(item.label),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyItemsMessage extends StatelessWidget {
  const _EmptyItemsMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mintLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Todos los elementos están en sus destinos.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
