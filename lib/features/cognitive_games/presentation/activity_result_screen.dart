import 'package:flutter/material.dart';
import '../../../core/models/activity_result.dart';
import '../../../core/theme/app_colors.dart';
import 'activities_menu_screen.dart';

/// Pantalla de Resultado de Actividad — Pantalla 7 del mockup.
/// Muestra aciertos, errores, tiempo y nivel al finalizar una actividad.
class ActivityResultScreen extends StatelessWidget {
  final ActivityResult result;
  const ActivityResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final bool isPerfect = result.wrongAnswers == 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // ── Ícono de resultado ────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isPerfect
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isPerfect ? Icons.check_circle : Icons.emoji_events,
                    size: 60,
                    color: isPerfect ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¡Muy bien!',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.primaryDark,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Has completado la actividad',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 40),
              // ── Cuadro de resultados ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Resultados',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _ResultRow(
                      label: 'Aciertos',
                      value: '${result.correctAnswers}/${result.totalQuestions}',
                      color: AppColors.success,
                      icon: Icons.check,
                    ),
                    _ResultRow(
                      label: 'Errores',
                      value: '${result.wrongAnswers}',
                      color: AppColors.error,
                      icon: Icons.close,
                    ),
                    _ResultRow(
                      label: 'Tiempo',
                      value: result.formattedTime,
                      color: AppColors.primary,
                      icon: Icons.timer_outlined,
                    ),
                    _ResultRow(
                      label: 'Nivel',
                      value: '${result.level}',
                      color: AppColors.accent,
                      icon: Icons.star,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // ── Botones ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Ver detalle'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ActivitiesMenuScreen()),
                  ),
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ResultRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
