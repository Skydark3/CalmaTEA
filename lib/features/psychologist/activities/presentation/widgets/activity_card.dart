import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../activities/config/activity_configuration_summary.dart';
import '../../../../../models/activity_model.dart';

class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback? onTap;

  const ActivityCard({super.key, required this.activity, this.onTap});

  @override
  Widget build(BuildContext context) {
    final description = activity.description.trim();
    final configurationStatus = ActivityConfigurationSummary.fromActivity(
      activity,
    ).status;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.mintLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _ActivityLabel(text: activity.type.displayName),
                        _ActivityLabel(text: activity.status.displayName),
                        if (configurationStatus !=
                            ActivityConfigurationStatus.configured)
                          _ActivityLabel(
                            text:
                                configurationStatus ==
                                    ActivityConfigurationStatus.unconfigured
                                ? 'Pendiente de configuración'
                                : 'Configuración inválida',
                            foregroundColor: AppColors.warning,
                            backgroundColor: AppColors.warning.withValues(
                              alpha: 0.12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dificultad: ${activity.difficulty}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityLabel extends StatelessWidget {
  final String text;
  final Color foregroundColor;
  final Color backgroundColor;

  const _ActivityLabel({
    required this.text,
    this.foregroundColor = AppColors.primaryDark,
    this.backgroundColor = const Color(0x2E7BB3F0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: foregroundColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
