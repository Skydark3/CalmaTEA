import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/calmatea_button.dart';
import '../../../../models/activity_model.dart';
import '../../../../models/child_model.dart';
import '../../../../models/therapy_model.dart';
import '../../../../services/activity_service.dart';
import '../../activities/presentation/activity_detail_screen.dart';
import '../../activities/presentation/create_activity_screen.dart';
import '../../activities/presentation/widgets/activity_card.dart';
import 'edit_therapy_screen.dart';

class TherapyDetailScreen extends StatefulWidget {
  final TherapyModel therapy;
  final ChildModel child;

  const TherapyDetailScreen({
    super.key,
    required this.therapy,
    required this.child,
  });

  @override
  State<TherapyDetailScreen> createState() => _TherapyDetailScreenState();
}

class _TherapyDetailScreenState extends State<TherapyDetailScreen> {
  final ActivityService _activityService = ActivityService();
  late TherapyModel _therapy;
  Stream<List<ActivityModel>>? _activitiesStream;

  @override
  void initState() {
    super.initState();
    _therapy = widget.therapy;
    _activitiesStream = _createActivitiesStream();
  }

  Stream<List<ActivityModel>> _createActivitiesStream() {
    return _activityService.watchActivitiesByTherapy(
      _therapy.id,
      _therapy.psychologistId,
    );
  }

  Stream<List<ActivityModel>> get _activeActivitiesStream {
    return _activitiesStream ??= _createActivitiesStream();
  }

  void _retryActivities() {
    setState(() => _activitiesStream = _createActivitiesStream());
  }

  Future<void> _openEditTherapy() async {
    final updatedTherapy = await Navigator.of(context).push<TherapyModel>(
      MaterialPageRoute(
        builder: (_) =>
            EditTherapyScreen(therapy: _therapy, child: widget.child),
      ),
    );

    if (updatedTherapy == null || !mounted) return;
    setState(() => _therapy = updatedTherapy);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terapia actualizada correctamente'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _openCreateActivity() async {
    final result = await Navigator.of(context).push<ActivityCreationResult>(
      MaterialPageRoute(
        builder: (_) =>
            CreateActivityScreen(therapy: _therapy, child: widget.child),
      ),
    );

    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Actividad creada, configurada y asignada correctamente'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _openActivityDetail(ActivityModel activity) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(
          activity: activity,
          therapy: _therapy,
          child: widget.child,
        ),
      ),
    );
  }

  Widget _buildCreateActivityButton() {
    return SizedBox(
      width: double.infinity,
      child: CalmaTeaButton(
        text: 'Crear actividad',
        icon: Icons.add_rounded,
        isOutlined: true,
        onPressed: _openCreateActivity,
      ),
    );
  }

  Widget _buildActivitiesSection() {
    return StreamBuilder<List<ActivityModel>>(
      stream: _activeActivitiesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('No pudimos cargar las actividades.'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _retryActivities,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 8),
                  _buildCreateActivityButton(),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 16),
                  _buildCreateActivityButton(),
                ],
              ),
            ),
          );
        }

        final activities = snapshot.data ?? const <ActivityModel>[];
        if (activities.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.assignment_outlined,
                        color: AppColors.mint,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Esta terapia todavía no tiene actividades configuradas.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCreateActivityButton(),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            for (var index = 0; index < activities.length; index++) ...[
              ActivityCard(
                activity: activities[index],
                onTap: () => _openActivityDetail(activities[index]),
              ),
              if (index < activities.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
            _buildCreateActivityButton(),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = <String>[
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final notes = _therapy.notes?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la terapia')),
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
                      Icons.psychology_outlined,
                      size: 34,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _therapy.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.child.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
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
                      _therapy.status.displayName,
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
              'Información de la terapia',
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
                      icon: Icons.psychology_outlined,
                      label: 'Tipo de terapia',
                      value: _therapy.name,
                    ),
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.info_outline_rounded,
                      label: 'Estado',
                      value: _therapy.status.displayName,
                    ),
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha de inicio',
                      value: _formatDate(_therapy.startDate),
                    ),
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.event_available_outlined,
                      label: 'Fecha de finalización',
                      value: _therapy.endDate == null
                          ? 'Sin fecha de finalización'
                          : _formatDate(_therapy.endDate!),
                    ),
                    const Divider(height: 28),
                    _InfoRow(
                      icon: Icons.notes_rounded,
                      label: 'Notas',
                      value: notes == null || notes.isEmpty
                          ? 'No hay notas registradas'
                          : notes,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Actividades terapéuticas',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActivitiesSection(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: CalmaTeaButton(
                text: 'Editar terapia',
                icon: Icons.edit_outlined,
                onPressed: _openEditTherapy,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
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
