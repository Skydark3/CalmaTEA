import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/activity_model.dart';
import '../../../services/activity_execution_session_service.dart';
import '../../activities/execution/activity_execution_router.dart';

class ChildActivitiesScreen extends StatelessWidget {
  final Stream<List<ActivityModel>> activitiesStream;
  final ActivityExecutionRouter executionRouter;
  final ActiveExecutionSessionCoordinator? sessionCoordinator;

  const ChildActivitiesScreen({
    super.key,
    required this.activitiesStream,
    this.executionRouter = const ActivityExecutionRouter(),
    this.sessionCoordinator,
  });

  Future<bool> _preparePersistentExecution(
    BuildContext context,
    ActivityModel activity,
  ) async {
    if (executionRouter.mode != ActivityExecutionMode.persistent) return true;
    final coordinator =
        sessionCoordinator ?? ActivityExecutionSessionService();
    try {
      await coordinator.startSession(activityId: activity.id);
      return true;
    } on ActiveExecutionSessionConflict catch (conflict) {
      if (!context.mounted) return false;
      if (!conflict.canInterrupt) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hay otra actividad en curso y no puede cerrarse desde esta cuenta.',
            ),
          ),
        );
        return false;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Actividad en curso'),
          content: const Text(
            'Ya tienes otra actividad abierta. ¿Deseas interrumpirla para comenzar esta actividad?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Interrumpir y continuar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return false;

      await coordinator.interruptSession(conflict.sessionId);
      await coordinator.startSession(activityId: activity.id);
      return true;
    }
  }

  Future<void> _openActivity(
    BuildContext context,
    ActivityModel activity,
  ) async {
    try {
      if (!await _preparePersistentExecution(context, activity)) return;
      if (!context.mounted) return;
      final resolution = await executionRouter.open(context, activity);
      final message = resolution.childMessage;
      if (!context.mounted || message == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos preparar esta actividad.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mis actividades',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<List<ActivityModel>>(
                stream: activitiesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const LoadingView(
                      message: 'Cargando tus actividades...',
                    );
                  }

                  if (snapshot.hasError) {
                    return const _ActivitiesMessage(
                      icon: Icons.error_outline_rounded,
                      message: 'No pudimos cargar tus actividades. Inténtalo nuevamente más tarde.',
                    );
                  }

                  final activities = snapshot.data ?? const <ActivityModel>[];
                  if (activities.isEmpty) {
                    return const _ActivitiesMessage(
                      icon: Icons.extension_outlined,
                      message: 'Todavía no hay actividades disponibles.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 28),
                    itemCount: activities.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      final resolution = executionRouter.resolve(activity);
                      return _ChildActivityCard(
                        activity: activity,
                        resolution: resolution,
                        isPreview: executionRouter.isPreview,
                        onStart: () => _openActivity(context, activity),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final ActivityExecutionResolution resolution;
  final bool isPreview;
  final VoidCallback onStart;

  const _ChildActivityCard({
    required this.activity,
    required this.resolution,
    required this.isPreview,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final isConfigured = resolution.hasValidConfiguration;
    final childMessage = resolution.childMessage;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.mintLight,
                  foregroundColor: AppColors.primaryDark,
                  child: Icon(Icons.extension_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.type.displayName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (activity.description.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                activity.description.trim(),
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textSecondary, height: 1.35),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActivityChip(
                  icon: activity.status == ActivityStatus.inProgress
                      ? Icons.play_circle_outline_rounded
                      : Icons.assignment_outlined,
                  label: activity.status.displayName,
                  backgroundColor: AppColors.secondaryLight,
                ),
                if (isPreview && resolution.canStart)
                  const _ActivityChip(
                    icon: Icons.visibility_outlined,
                    label: 'Modo de prueba · no guarda resultados',
                    backgroundColor: AppColors.cardBg,
                  ),
                _ActivityChip(
                  icon: isConfigured
                      ? Icons.check_circle_outline_rounded
                      : Icons.schedule_rounded,
                  label: isConfigured
                      ? 'Configuración disponible'
                      : 'Pendiente de preparación',
                  backgroundColor: isConfigured
                      ? AppColors.mintLight
                      : AppColors.cardBg,
                ),
              ],
            ),
            if (!resolution.canStart && childMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                childMessage,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary, height: 1.35),
              ),
            ],
            if (resolution.canStart) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(isPreview ? 'Probar actividad' : 'Comenzar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;

  const _ActivityChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitiesMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ActivitiesMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: AppColors.cardBg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.primary),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
