import 'package:flutter/material.dart';

import '../../../../../models/activity_execution_result_model.dart';

class ExecutionMetricsView extends StatelessWidget {
  final ActivityExecutionResultModel result;

  const ExecutionMetricsView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final rows = _rowsFor(result.metrics);
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          _MetricRow(label: rows[index].$1, value: rows[index].$2),
          if (index < rows.length - 1) const Divider(height: 24),
        ],
      ],
    );
  }

  static List<(String, String)> _rowsFor(ActivityExecutionMetrics metrics) {
    return switch (metrics) {
      SequenceExecutionMetrics value => [
        ('Cantidad de elementos', '${value.itemsCount}'),
        ('Comprobaciones realizadas', '${value.checksCount}'),
      ],
      MatchingExecutionMetrics value => [
        ('Relaciones completadas', '${value.relationsCompleted}'),
        ('Comprobaciones realizadas', '${value.checksCount}'),
      ],
      MotorExecutionMetrics value => [
        ('Pasos visitados en pantalla', '${value.stepsVisited}'),
      ],
      EmotionExecutionMetrics value => [
        ('Ejercicios revisados', '${value.exercisesReviewed}'),
      ],
      DragDropExecutionMetrics value => [
        ('Elementos colocados', '${value.itemsPlaced}'),
        ('Comprobaciones realizadas', '${value.checksCount}'),
      ],
      PictogramExecutionMetrics value => [
        ('Interacciones realizadas', '${value.interactionsCount}'),
      ],
      TracingExecutionMetrics value => [
        ('Práctica realizada', value.practiceCompleted ? 'Sí' : 'No'),
        if (value.strokesCount != null)
          ('Trazos registrados', '${value.strokesCount}'),
      ],
      TimerExecutionMetrics value => [
        (
          'Duración configurada',
          _formatSeconds(value.configuredDurationSeconds),
        ),
        ('Tiempo activo transcurrido', _formatSeconds(value.elapsedSeconds)),
      ],
    };
  }

  static String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    if (minutes == 0) return '$seconds s';
    if (remaining == 0) return '$minutes min';
    return '$minutes min $remaining s';
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 16),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
