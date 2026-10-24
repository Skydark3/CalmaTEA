import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_state.dart';
import '../../../core/theme/app_colors.dart';

/// Panel Familiar / Vista del Cuidador — Pantalla 11 del mockup.
/// Permite al familiar revisar el progreso y la participación del usuario.
class CaregiverPanelScreen extends StatelessWidget {
  const CaregiverPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Panel familiar')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card del usuario ──────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                      child: Text(
                        state.userName[0],
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(state.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 17)),
                        Text('Usuario nivel ${state.userAge}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Resumen', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Detalle', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // ── Cumplimiento de rutina ────────────────────────────
            Text('Cumplimiento de rutina',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: state.weeklyRoutineCompliance,
                      minHeight: 14,
                      borderRadius: BorderRadius.circular(7),
                      color: AppColors.primary,
                      backgroundColor: AppColors.cardBg,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(state.weeklyRoutineCompliance * 100).toInt()}%',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // ── Últimos registros ─────────────────────────────────
            Text('Últimos registros',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (state.activityHistory.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Sin registros aún. Completa algunas actividades.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            else
              ...state.activityHistory.take(5).map(
                (r) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      Icons.check_circle,
                      color: r.accuracy >= 0.7
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    title: Text(r.activityName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${r.formattedTime} • ${r.correctAnswers}/${r.totalQuestions} aciertos'),
                    trailing: Text(
                      '${(r.accuracy * 100).toInt()}%',
                      style: TextStyle(
                        color: r.accuracy >= 0.7
                            ? AppColors.success
                            : AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Ver historial completo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
