import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/activity_model.dart';
import '../../../activities/config/models/activity_configuration.dart';
import '../../../activities/config/models/activity_configurations.dart';
import 'activity_execution_ui_text.dart';
import 'tracing_execution_controller.dart';
import 'tracing_execution_utils.dart';
import 'widgets/activity_visual_components.dart';

Future<void> openTracingExecution(
  BuildContext context,
  ActivityModel activity,
  ActivityConfiguration configuration,
) async {
  if (configuration is! TracingActivityConfig) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => TracingExecutionScreen(
        activity: activity,
        configuration: configuration,
      ),
    ),
  );
}

class TracingExecutionScreen extends StatefulWidget {
  final ActivityModel activity;
  final TracingActivityConfig configuration;
  final TracingExecutionPersistence? persistence;
  final bool previewMode;

  const TracingExecutionScreen({
    super.key,
    required this.activity,
    required this.configuration,
    this.persistence,
    this.previewMode = false,
  });

  @override
  State<TracingExecutionScreen> createState() => _TracingExecutionScreenState();
}

class _TracingExecutionScreenState extends State<TracingExecutionScreen> {
  late final TracingExecutionController _controller;
  final List<List<Offset>> _strokes = [];
  bool _isFinished = false;
  bool _exitDialogVisible = false;
  bool _allowPop = false;
  int? _activePointer;

  bool get _canRun =>
      widget.activity.type == ActivityType.tracing &&
      (widget.activity.status == ActivityStatus.assigned ||
          widget.activity.status == ActivityStatus.inProgress) &&
      widget.configuration.isValid &&
      widget.configuration.pattern.trim().isNotEmpty &&
      widget.configuration.value.trim().isNotEmpty;

  TracingGuideKind get _guideKind =>
      resolveTracingGuide(widget.configuration.value);

  @override
  void initState() {
    super.initState();
    _controller = TracingExecutionController(
      activityId: widget.activity.id,
      persistence: widget.persistence ?? TracingExecutionServicePersistence(),
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
    _activePointer = null;
    _strokes.clear();
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _startStroke(PointerDownEvent event, Size surfaceSize) {
    if (_controller.state != TracingExecutionPersistenceState.ready ||
        _activePointer != null) {
      return;
    }
    setState(() {
      _activePointer = event.pointer;
      _strokes.add([normalizeTracingPoint(event.localPosition, surfaceSize)]);
    });
  }

  void _extendStroke(PointerMoveEvent event, Size surfaceSize) {
    if (_strokes.isEmpty || event.pointer != _activePointer) return;
    setState(() {
      _strokes.last.add(
        normalizeTracingPoint(event.localPosition, surfaceSize),
      );
    });
  }

  void _finishStroke(PointerEvent event, {required bool cancelled}) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    if (!cancelled) _controller.recordCompletedStroke();
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    setState(_strokes.clear);
  }

  Future<void> _finish() async {
    if (_controller.strokesCount <= 0 ||
        _controller.state != TracingExecutionPersistenceState.ready) {
      return;
    }
    setState(() {
      _activePointer = null;
      _strokes.clear();
    });
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
      _strokes.clear();
      _activePointer = null;
      _isFinished = false;
    });
    await _controller.startNewExecution();
  }

  Future<void> _requestExit() async {
    if (_exitDialogVisible) return;
    final state = _controller.state;
    if (state == TracingExecutionPersistenceState.completed ||
        state == TracingExecutionPersistenceState.interrupted ||
        state == TracingExecutionPersistenceState.startFailure ||
        state == TracingExecutionPersistenceState.idle) {
      _popAfterAllowing();
      return;
    }

    if (state == TracingExecutionPersistenceState.starting ||
        state == TracingExecutionPersistenceState.saving ||
        state == TracingExecutionPersistenceState.interrupting) {
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

    if (state == TracingExecutionPersistenceState.completionFailure) {
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
      setState(() {
        _activePointer = null;
        _strokes.clear();
      });
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
        appBar: AppBar(title: const Text('Trazado')),
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
    if (persistenceState == TracingExecutionPersistenceState.idle ||
        persistenceState == TracingExecutionPersistenceState.starting) {
      return PopScope<void>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestExit();
        },
        child: _TracingStatusScaffold(
          title: widget.activity.title,
          message: 'Iniciando actividad...',
          showProgress: true,
        ),
      );
    }
    if (persistenceState == TracingExecutionPersistenceState.startFailure) {
      return PopScope<void>(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestExit();
        },
        child: _TracingStatusScaffold(
          title: widget.activity.title,
          message: 'No pudimos iniciar la actividad.',
          primaryLabel: 'Reintentar',
          onPrimary: _controller.start,
          secondaryLabel: 'Volver',
          onSecondary: _requestExit,
        ),
      );
    }

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
          child: _isFinished
              ? _buildFinished(context)
              : _buildPractice(context),
        ),
      ),
    );
  }

  Widget _buildPractice(BuildContext context) {
    final instructions = widget.activity.instructions.trim();
    final difficultyHint = widget.configuration.difficultyHint;
    final persistenceState = _controller.state;
    final canInteract =
        persistenceState == TracingExecutionPersistenceState.ready;
    final isSaving =
        persistenceState == TracingExecutionPersistenceState.saving;
    final hasCompletionFailure =
        persistenceState == TracingExecutionPersistenceState.completionFailure;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        ActivityVisualHeader(
          icon: Icons.gesture_rounded,
          title: widget.activity.title,
          instructions: instructions.isEmpty
              ? 'Sigue la guía con el dedo a tu propio ritmo.'
              : instructions,
          progressLabel: _strokes.isEmpty
              ? 'Listo para comenzar'
              : '${_strokes.length} ${_strokes.length == 1 ? 'trazo' : 'trazos'}',
          accent: AppColors.secondary,
          compact: true,
        ),
        const SizedBox(height: 18),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: AppColors.cardBg,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo de trazado: ${widget.configuration.pattern}'),
                const SizedBox(height: 6),
                Text(
                  'Valor a trazar: ${widget.configuration.value}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (difficultyHint != null &&
                    difficultyHint.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline_rounded,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          difficultyHint,
                          key: const ValueKey('tracing-difficulty-hint'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_guideKind == TracingGuideKind.freeform) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Referencia: ${widget.configuration.value}. Practica este valor como dibujo libre.',
              key: const ValueKey('tracing-freeform-message'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final surfaceSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Semantics(
                    label:
                        'Superficie de dibujo para ${widget.configuration.value}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: RawGestureDetector(
                        key: const ValueKey('tracing-canvas'),
                        behavior: HitTestBehavior.opaque,
                        gestures: {
                          EagerGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                EagerGestureRecognizer
                              >(EagerGestureRecognizer.new, (_) {}),
                        },
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) =>
                              _startStroke(event, surfaceSize),
                          onPointerMove: (event) =>
                              _extendStroke(event, surfaceSize),
                          onPointerUp: (event) =>
                              _finishStroke(event, cancelled: false),
                          onPointerCancel: (event) =>
                              _finishStroke(event, cancelled: true),
                          child: CustomPaint(
                            key: ValueKey('tracing-guide-${_guideKind.name}'),
                            painter: _TracingPainter(
                              guideKind: _guideKind,
                              guideValue: widget.configuration.value,
                              strokes: _strokes,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            _strokes.isEmpty
                ? 'Aún no has realizado un trazo. Puedes comenzar cuando quieras.'
                : _strokes.length == 1
                ? '1 trazo realizado.'
                : '${_strokes.length} trazos realizados.',
            key: const ValueKey('tracing-stroke-count'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: !canInteract || _strokes.isEmpty ? null : _undo,
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Deshacer'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: !canInteract || _strokes.isEmpty ? null : _clear,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Limpiar'),
              ),
            ),
          ],
        ),
        if (isSaving) ...[
          const SizedBox(height: 12),
          _TracingProgressMessage(
            message: ActivityExecutionUiText.saving(
              previewMode: widget.previewMode,
            ),
          ),
        ],
        if (hasCompletionFailure) ...[
          const SizedBox(height: 12),
          _TracingMessage(
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
          onPressed:
              canInteract &&
                  !hasCompletionFailure &&
                  _controller.strokesCount > 0
              ? _finish
              : null,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Terminar práctica'),
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

  Widget _buildFinished(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.draw_rounded, size: 72, color: AppColors.success),
            const SizedBox(height: 20),
            Text(
              '¡Terminaste tu práctica de trazado!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _repeat,
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
      ),
    );
  }
}

class _TracingStatusScaffold extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _TracingStatusScaffold({
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
                TextButton(
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

class _TracingProgressMessage extends StatelessWidget {
  final String message;

  const _TracingProgressMessage({required this.message});

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

class _TracingMessage extends StatelessWidget {
  final String message;

  const _TracingMessage({required this.message});

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

class _TracingPainter extends CustomPainter {
  final TracingGuideKind guideKind;
  final String guideValue;
  final List<List<Offset>> strokes;

  const _TracingPainter({
    required this.guideKind,
    required this.guideValue,
    required this.strokes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.surface);
    _paintGuide(canvas, size);

    final strokePaint = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final first = denormalizeTracingPoint(stroke.first, size);
      if (stroke.length == 1) {
        canvas.drawCircle(first, strokePaint.strokeWidth / 2, strokePaint);
        continue;
      }
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in stroke.skip(1)) {
        final local = denormalizeTracingPoint(point, size);
        path.lineTo(local.dx, local.dy);
      }
      canvas.drawPath(path, strokePaint);
    }
  }

  void _paintGuide(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = AppColors.pending.withValues(alpha: 0.45)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final padding = size.shortestSide * 0.18;
    final guideRect = Rect.fromLTWH(
      padding,
      padding,
      size.width - (padding * 2),
      size.height - (padding * 2),
    );

    switch (guideKind) {
      case TracingGuideKind.typographic:
        final textPainter = TextPainter(
          text: TextSpan(
            text: guideValue,
            style: TextStyle(
              color: AppColors.pending.withValues(alpha: 0.4),
              fontSize: size.shortestSide * 0.62,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: size.width);
        textPainter.paint(
          canvas,
          Offset(
            (size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2,
          ),
        );
      case TracingGuideKind.circle:
        canvas.drawOval(guideRect, guidePaint);
      case TracingGuideKind.square:
        canvas.drawRect(guideRect, guidePaint);
      case TracingGuideKind.triangle:
        final path = Path()
          ..moveTo(size.width / 2, guideRect.top)
          ..lineTo(guideRect.right, guideRect.bottom)
          ..lineTo(guideRect.left, guideRect.bottom)
          ..close();
        canvas.drawPath(path, guidePaint);
      case TracingGuideKind.freeform:
        break;
    }

    if (guideKind != TracingGuideKind.freeform) {
      final (start, end) = switch (guideKind) {
        TracingGuideKind.typographic => (
          Offset(guideRect.left, size.height / 2),
          Offset(guideRect.right, size.height / 2),
        ),
        TracingGuideKind.circle => (
          Offset(size.width / 2, guideRect.top),
          Offset(guideRect.right, size.height / 2),
        ),
        TracingGuideKind.square => (guideRect.topLeft, guideRect.topRight),
        TracingGuideKind.triangle => (
          Offset(size.width / 2, guideRect.top),
          guideRect.bottomLeft,
        ),
        TracingGuideKind.freeform => (Offset.zero, Offset.zero),
      };
      _paintEndpoint(canvas, start, 'Inicio', AppColors.success);
      _paintEndpoint(canvas, end, 'Fin', AppColors.warning);
    }
  }

  void _paintEndpoint(Canvas canvas, Offset point, String label, Color color) {
    canvas.drawCircle(point, 10, Paint()..color = AppColors.surface);
    canvas.drawCircle(point, 7, Paint()..color = color);
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, point + const Offset(12, -8));
  }

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) => true;
}
