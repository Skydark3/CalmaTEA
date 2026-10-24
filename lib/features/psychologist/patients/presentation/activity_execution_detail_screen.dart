import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/activity_execution_result_model.dart';
import '../../../../models/activity_execution_session_model.dart';
import '../../../../models/child_model.dart';
import '../../../../models/patient_activity_history_model.dart';
import '../../../../services/patient_activity_history_service.dart';
import 'widgets/execution_metrics_view.dart';

class ActivityExecutionDetailScreen extends StatefulWidget {
  final ChildModel child;
  final PatientActivityHistoryEntry entry;
  final PatientActivityHistoryDataSource dataSource;

  const ActivityExecutionDetailScreen({
    super.key,
    required this.child,
    required this.entry,
    required this.dataSource,
  });

  @override
  State<ActivityExecutionDetailScreen> createState() =>
      _ActivityExecutionDetailScreenState();
}

class _ActivityExecutionDetailScreenState
    extends State<ActivityExecutionDetailScreen> {
  ActivityExecutionResultModel? _result;
  bool _isLoading = false;
  bool _resultMissing = false;
  bool _dataUnavailable = false;
  bool _connectionError = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry.session.status ==
        ActivityExecutionSessionStatus.completed) {
      _loadResult();
    }
  }

  Future<void> _loadResult() async {
    setState(() {
      _isLoading = true;
      _resultMissing = false;
      _dataUnavailable = false;
      _connectionError = false;
    });
    try {
      final result = await widget.dataSource.getResult(entry: widget.entry);
      if (!mounted) return;
      setState(() {
        _result = result;
        _resultMissing = result == null;
        _isLoading = false;
      });
    } on PatientActivityHistoryDataException {
      if (!mounted) return;
      setState(() {
        _dataUnavailable = true;
        _isLoading = false;
      });
    } on PatientActivityHistoryAccessDenied {
      if (!mounted) return;
      setState(() {
        _dataUnavailable = true;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error controlado al cargar resultado: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _connectionError = true;
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('dd/MM/yyyy, HH:mm').format(value.toLocal());
  }

  String _statusLabel(ActivityExecutionSessionStatus status) {
    return switch (status) {
      ActivityExecutionSessionStatus.inProgress => 'En progreso',
      ActivityExecutionSessionStatus.completed => 'Completada',
      ActivityExecutionSessionStatus.interrupted => 'Interrumpida',
    };
  }

  Color _statusColor(ActivityExecutionSessionStatus status) {
    return switch (status) {
      ActivityExecutionSessionStatus.inProgress => AppColors.warning,
      ActivityExecutionSessionStatus.completed => AppColors.success,
      ActivityExecutionSessionStatus.interrupted => AppColors.pending,
    };
  }

  Widget _buildResultSection() {
    final status = widget.entry.session.status;
    if (status == ActivityExecutionSessionStatus.interrupted) {
      return const _NeutralMessage(
        icon: Icons.pause_circle_outline_rounded,
        message: 'Esta ejecución se interrumpió y no tiene un resultado de finalización.',
      );
    }
    if (status == ActivityExecutionSessionStatus.inProgress) {
      return const _NeutralMessage(
        icon: Icons.schedule_rounded,
        message: 'Esta ejecución aún no registra una finalización.',
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_connectionError) {
      return _NeutralMessage(
        icon: Icons.cloud_off_outlined,
        message: 'No pudimos cargar el resultado.',
        action: TextButton.icon(
          onPressed: _loadResult,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (_resultMissing || _dataUnavailable || _result == null) {
      return const _NeutralMessage(
        icon: Icons.info_outline_rounded,
        message: 'Los datos del resultado no están disponibles.',
      );
    }

    final result = _result!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExecutionMetricsView(result: result),
            if (result.durationSeconds != null) ...[
              const Divider(height: 24),
              _DetailRow(
                label: 'Duración total registrada',
                value: '${result.durationSeconds} s',
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.entry.session;
    final activity = widget.entry.activity;
    final statusColor = _statusColor(session.status);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de ejecución')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.child.fullName,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(activity.type.displayName)),
                        Chip(
                          label: Text(_statusLabel(session.status)),
                          side: BorderSide(color: statusColor),
                          labelStyle: TextStyle(color: statusColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Información de la sesión',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Inicio',
                      value: _formatDateTime(session.startedAt),
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      label: 'Finalización',
                      value: session.endedAt == null
                          ? 'Sin finalización registrada'
                          : _formatDateTime(session.endedAt!),
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      label: 'Estado',
                      value: _statusLabel(session.status),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Métricas de interacción',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Estos datos describen interacciones realizadas en CalmaTEA; no constituyen una evaluación clínica.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            _buildResultSection(),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _NeutralMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _NeutralMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
