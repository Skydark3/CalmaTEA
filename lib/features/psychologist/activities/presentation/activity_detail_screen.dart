import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/calmatea_button.dart';
import '../../../activities/config/activity_configuration_summary.dart';
import '../../../../models/activity_model.dart';
import '../../../../models/child_model.dart';
import '../../../../models/therapy_model.dart';
import '../configuration/activity_configuration_router.dart';
import 'edit_activity_screen.dart';

class ActivityDetailScreen extends StatefulWidget {
  final ActivityModel activity;
  final TherapyModel therapy;
  final ChildModel child;

  const ActivityDetailScreen({
    super.key,
    required this.activity,
    required this.therapy,
    required this.child,
  });

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  ActivityModel? _updatedActivity;

  ActivityModel get _activity => _updatedActivity ?? widget.activity;

  Future<void> _openEditActivity() async {
    final updatedActivity = await Navigator.of(context).push<ActivityModel>(
      MaterialPageRoute(
        builder: (_) => EditActivityScreen(
          activity: _activity,
          therapy: widget.therapy,
          child: widget.child,
        ),
      ),
    );

    if (updatedActivity == null || !mounted) return;
    setState(() => _updatedActivity = updatedActivity);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Actividad actualizada correctamente'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openActivityConfiguration() async {
    final updatedActivity = await ActivityConfigurationRouter.open(
      context,
      _activity,
    );

    if (updatedActivity == null || !mounted) return;
    setState(() => _updatedActivity = updatedActivity);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ConfiguraciÃ³n guardada correctamente'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    final description = activity.description.trim();
    final instructions = activity.instructions.trim();
    final configurationSummary = ActivityConfigurationSummary.fromActivity(
      activity,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la actividad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: AppColors.mintLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      size: 34,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    activity.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity.type.displayName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ContextLine(label: 'Paciente', value: widget.child.fullName),
                  const SizedBox(height: 6),
                  _ContextLine(label: 'Terapia', value: widget.therapy.name),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      activity.status.displayName,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'InformaciÃ³n general',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.title_rounded,
                      label: 'TÃ­tulo',
                      value: activity.title,
                    ),
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.category_outlined,
                      label: 'Tipo',
                      value: activity.type.displayName,
                    ),
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.info_outline_rounded,
                      label: 'Estado',
                      value: activity.status.displayName,
                    ),
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.tune_rounded,
                      label: 'Dificultad',
                      value: 'Dificultad: ${activity.difficulty}',
                    ),
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.description_outlined,
                      label: 'DescripciÃ³n',
                      value: description.isEmpty
                          ? 'No hay descripciÃ³n registrada'
                          : description,
                    ),
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.list_alt_rounded,
                      label: 'Instrucciones',
                      value: instructions.isEmpty
                          ? 'No hay instrucciones registradas'
                          : instructions,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ConfiguraciÃ³n de la actividad',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.extension_outlined, color: AppColors.mint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            configurationSummary.title,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            configurationSummary.detail,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                          ),
                          if (configurationSummary.canConfigure) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: CalmaTeaButton(
                                text: configurationSummary.actionLabel,
                                icon: Icons.tune_rounded,
                                isOutlined: true,
                                onPressed: _openActivityConfiguration,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: CalmaTeaButton(
                text: 'Editar actividad',
                icon: Icons.edit_outlined,
                onPressed: _openEditActivity,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ContextLine extends StatelessWidget {
  final String label;
  final String value;

  const _ContextLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textPrimary, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
