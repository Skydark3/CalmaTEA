import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Duración breve y respetuosa con la preferencia de reducir movimiento.
Duration activityMotionDuration(
  BuildContext context, [
  Duration duration = const Duration(milliseconds: 220),
]) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery?.disableAnimations == true ||
      mediaQuery?.accessibleNavigation == true) {
    return Duration.zero;
  }
  return duration;
}

class ActivityVisualHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String instructions;
  final String? progressLabel;
  final double? progress;
  final Color accent;
  final bool compact;

  const ActivityVisualHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.instructions,
    this.progressLabel,
    this.progress,
    this.accent = AppColors.primary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveProgress = progress?.clamp(0.0, 1.0);
    if (compact) {
      return Semantics(
        container: true,
        label: progressLabel,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.09),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (progressLabel != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              progressLabel!,
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      instructions,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                    if (effectiveProgress != null) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: effectiveProgress,
                          backgroundColor: AppColors.divider,
                          color: accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      label: progressLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.14), AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: compact ? 42 : 54,
                      height: compact ? 42 : 54,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: compact ? 24 : 30),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              (compact
                                      ? Theme.of(context).textTheme.titleLarge
                                      : Theme.of(context)
                                            .textTheme
                                            .headlineSmall)
                                  ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          instructions,
                          style:
                              (compact
                                      ? Theme.of(context).textTheme.bodyMedium
                                      : Theme.of(context).textTheme.bodyLarge)
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (progressLabel != null) ...[
                SizedBox(height: compact ? 10 : 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        progressLabel!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (compact && effectiveProgress != null)
                      Text(
                        '${(effectiveProgress * 100).round()}%',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                if (effectiveProgress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 9,
                      value: effectiveProgress,
                      backgroundColor: AppColors.divider,
                      color: accent,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityIllustrationBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final double size;

  const ActivityIllustrationBadge({
    super.key,
    required this.icon,
    this.color = AppColors.primaryDark,
    this.selected = false,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.08 : 1,
      duration: activityMotionDuration(context),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: activityMotionDuration(context),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: selected ? AppColors.mintLight : color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.success : color.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Icon(icon, color: selected ? AppColors.success : color),
      ),
    );
  }
}

IconData activityIconForLabel(String label, {IconData? fallback}) {
  final value = label.toLowerCase();
  if (value.contains('agua') || value.contains('beber')) {
    return Icons.water_drop_rounded;
  }
  if (value.contains('comer') || value.contains('comida')) {
    return Icons.restaurant_rounded;
  }
  if (value.contains('casa')) return Icons.home_rounded;
  if (value.contains('escuela') || value.contains('estudi')) {
    return Icons.school_rounded;
  }
  if (value.contains('jugar') || value.contains('juego')) {
    return Icons.sports_esports_rounded;
  }
  if (value.contains('feliz') || value.contains('alegr')) {
    return Icons.sentiment_satisfied_alt_rounded;
  }
  if (value.contains('triste')) return Icons.sentiment_dissatisfied_rounded;
  if (value.contains('calma') || value.contains('respir')) {
    return Icons.spa_rounded;
  }
  return fallback ?? Icons.auto_awesome_rounded;
}
