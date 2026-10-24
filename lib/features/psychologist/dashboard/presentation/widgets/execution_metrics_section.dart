import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../models/user_model.dart';
import '../../../../../services/psychologist_execution_metrics_service.dart';
import '../../models/psychologist_execution_metrics.dart';

enum _ExecutionMetricsError { connection, permission }

class ExecutionMetricsSection extends StatefulWidget {
  final UserModel user;
  final bool enabled;
  final bool isVisible;
  final PsychologistExecutionMetricsDataSource? dataSource;

  const ExecutionMetricsSection({
    super.key,
    required this.user,
    required this.enabled,
    required this.isVisible,
    this.dataSource,
  });

  @override
  State<ExecutionMetricsSection> createState() =>
      _ExecutionMetricsSectionState();
}

class _ExecutionMetricsSectionState extends State<ExecutionMetricsSection> {
  PsychologistExecutionMetricsDataSource? _dataSource;
  PsychologistExecutionMetrics? _metrics;
  _ExecutionMetricsError? _error;
  bool _isLoading = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _configureDataSource();
    if (_canLoad) _loadMetrics();
  }

  @override
  void didUpdateWidget(covariant ExecutionMetricsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final userChanged =
        oldWidget.user.id != widget.user.id ||
        oldWidget.user.role != widget.user.role;
    final enabledChanged = oldWidget.enabled != widget.enabled;
    final sourceChanged = oldWidget.dataSource != widget.dataSource;

    if (userChanged || enabledChanged || sourceChanged) {
      _requestGeneration++;
      _metrics = null;
      _error = null;
      _isLoading = false;
      _configureDataSource();
      if (_canLoad) _loadMetrics();
      return;
    }

    if (!oldWidget.isVisible && widget.isVisible && _canLoad) {
      _loadMetrics();
    }
  }

  bool get _canLoad =>
      widget.enabled &&
      widget.isVisible &&
      widget.user.role == UserRole.psychologist &&
      _dataSource != null;

  void _configureDataSource() {
    if (!widget.enabled || widget.user.role != UserRole.psychologist) {
      _dataSource = null;
      return;
    }
    _dataSource = widget.dataSource ?? PsychologistExecutionMetricsService();
  }

  Future<void> _loadMetrics() async {
    final dataSource = _dataSource;
    if (dataSource == null || _isLoading) return;

    final requestedUserId = widget.user.id;
    final generation = ++_requestGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final metrics = await dataSource.loadMetrics(
        psychologistId: requestedUserId,
      );
      if (!mounted ||
          generation != _requestGeneration ||
          requestedUserId != widget.user.id) {
        return;
      }
      setState(() {
        _metrics = metrics;
        _isLoading = false;
      });
    } on PsychologistExecutionMetricsAccessDenied {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = _ExecutionMetricsError.permission;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error controlado al cargar métricas de ejecución: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = _ExecutionMetricsError.connection;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    super.dispose();
  }

  Widget _buildError(BuildContext context, {required bool compact}) {
    final permission =
        widget.user.role != UserRole.psychologist ||
        _error == _ExecutionMetricsError.permission;
    final message = permission
        ? 'No tienes permiso para consultar estas estadísticas.'
        : compact
        ? 'No pudimos actualizar las estadísticas. Se muestran los últimos datos confirmados.'
        : 'No pudimos cargar las estadísticas de actividad.';

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.error.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            if (!permission)
              TextButton(
                onPressed: _loadMetrics,
                child: const Text('Reintentar'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(PsychologistExecutionMetrics metrics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ExecutionMetricCard(
                label: 'Ejecuciones registradas',
                value: metrics.totalExecutions,
                icon: Icons.playlist_play_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ExecutionMetricCard(
                label: 'Ejecuciones completadas',
                value: metrics.completedExecutions,
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ExecutionMetricCard(
                label: 'Ejecuciones interrumpidas',
                value: metrics.interruptedExecutions,
                icon: Icons.pause_circle_outline_rounded,
                color: AppColors.pending,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ExecutionMetricCard(
                label: 'Sesiones sin cierre registrado',
                value: metrics.unclosedExecutions,
                icon: Icons.schedule_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    return Column(
      key: const Key('execution-metrics-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Actividad en CalmaTEA',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.user.role == UserRole.psychologist)
              IconButton(
                key: const Key('refresh-execution-metrics'),
                onPressed: _isLoading ? null : _loadMetrics,
                tooltip: 'Actualizar estadísticas',
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Indicadores descriptivos del uso registrado en CalmaTEA.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (widget.user.role != UserRole.psychologist)
          _buildError(context, compact: false)
        else if (_metrics == null && _isLoading)
          const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),
          )
        else if (_metrics == null && _error != null)
          _buildError(context, compact: false)
        else if (_metrics != null) ...[
          if (_error != null) ...[
            _buildError(context, compact: true),
            const SizedBox(height: 10),
          ],
          Stack(
            children: [
              _buildMetrics(_metrics!),
              if (_isLoading)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Color(0x33FFFFFF),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ExecutionMetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _ExecutionMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
