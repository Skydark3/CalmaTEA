import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/app_state.dart';
import '../../../core/models/routine_item.dart';
import '../../../core/theme/app_colors.dart';

/// Pantalla de Rutina Diaria — Pantalla 4 del mockup.
/// Lista todas las actividades del día con horarios y estados.
class DailyRoutineScreen extends StatelessWidget {
  const DailyRoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutina diaria'),
        leading: const Icon(Icons.calendar_today_outlined),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            child: LinearProgressIndicator(
              value: state.routineProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              color: AppColors.accent,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.dailyRoutine.length,
        itemBuilder: (context, index) {
          final item = state.dailyRoutine[index];
          return _RoutineCard(item: item, index: index);
        },
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final RoutineItem item;
  final int index;
  const _RoutineCard({required this.item, required this.index});

  Color get _statusColor {
    switch (item.status) {
      case RoutineStatus.completed:
        return AppColors.success;
      case RoutineStatus.inProgress:
        return AppColors.warning;
      case RoutineStatus.pending:
        return AppColors.pending;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case RoutineStatus.completed:
        return 'Completada';
      case RoutineStatus.inProgress:
        return 'En progreso';
      case RoutineStatus.pending:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(item.iconEmoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          title: Text(
            item.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
              color: item.isCompleted
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            item.time,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: _statusColor,
                size: 28,
              ),
              const SizedBox(height: 2),
              Text(
                _statusLabel,
                style: TextStyle(fontSize: 10, color: _statusColor),
              ),
            ],
          ),
          onTap: item.isCompleted
              ? null
              : () {
                  state.completeRoutineItem(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('¡${item.title} completada! +10 puntos 🎉'),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
        ),
      ),
    );
  }
}
